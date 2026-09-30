import 'dart:async';

import 'package:drift/drift.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/post.dart';

/// Extension for row <-> entity mapping. Kept next to the datasource:
/// mappers are a data-layer concern, the domain never sees drift rows.
extension PostRowMapper on PostRow {
  Post toEntity({
    required bool isLiked,
    required int likesCount,
  }) =>
      Post(
        id: id,
        authorId: authorId,
        authorName: authorName,
        body: body,
        mediaUrl: mediaUrl,
        blurhash: blurhash,
        createdAt: createdAt,
        deletedAt: deletedAt,
        expiresAt: expiresAt,
        isLiked: isLiked,
        likesCount: likesCount,
      );
}

/// Local cache access for the Square. One-shot and stream reads over the
/// drift tables; writes happen only through repositories.
abstract class SquareLocalDatasource {
  /// Injectable clock for expiry checks — tests pass a fixed [DateTime]
  /// factory so boundary behaviour is deterministic.
  DateTime Function() get clock;

  /// Sets the time-travel instant for every subsequent read (null =
  /// present). While set, all reads filter to rows that existed at that
  /// moment; writes are refused (time travel is read-only).
  void setAsOf(DateTime? moment);

  /// Feed, newest first, with like flags and like counts.
  Stream<List<Post>> watchFeed();

  /// Posts created on [day] (local midnight to midnight), newest first.
  /// Tombstoned posts excluded, like the feed.
  Future<List<Post>> postsOnDay(DateTime day);

  /// One author's non-deleted posts, newest first (with like flags and
  /// counts) — the profile grid. Live: re-emits on table changes.
  Stream<List<Post>> watchPostsByAuthor(String authorName);

  /// One-shot [watchPostsByAuthor] for cross-module reads (person sheet).
  Future<List<Post>> findVisiblePostsByAuthor(String authorName);

  Future<void> insertPost(PostsCompanion entry);

  Future<Post?> findPost(String postId);

  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  });

  /// Soft-delete: stamps the tombstone. The post leaves the feed on the
  /// next emission but stays restorable until purged. Own-post
  /// enforcement is the repository's job; the datasource is mechanics.
  Future<void> deletePost(String postId);

  /// Clears the tombstone — the undo path.
  Future<void> restorePost(String postId);

  /// "Keep it": converts an ephemeral post to permanent by clearing
  /// [Post.expiresAt]. Null-safe (permanent posts are untouched).
  Future<void> keepPost(String postId);

  /// Hard-deletes the post (and its likes). Called by the repository
  /// once the undo window has closed.
  Future<void> purgePost(String postId);

  /// Fetches a tombstoned post (ignores the filter) — the undo path
  /// needs the row even though the feed no longer shows it.
  Future<Post?> findPostIncludingDeleted(String postId);
}

class DriftSquareLocalDatasource implements SquareLocalDatasource {
  DriftSquareLocalDatasource(this._db, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final AppDatabase _db;

  @override
  final DateTime Function() clock;

  /// Time-travel instant (null = present). Affects every read path.
  DateTime? _asOf;

  /// True while a write lands during time travel — the UI must never
  /// trigger one (read-only constraint); this backstop keeps honest
  /// failures local instead of silently corrupting the past.
  void _assertWritable() {
    if (_asOf != null) {
      throw StateError('writes are refused while time traveling');
    }
  }

  @override
  void setAsOf(DateTime? moment) {
    if (_asOf == moment) return;
    _asOf = moment;
    // Re-emit every live stream so screens redraw as-of immediately.
    _asOfTick.add(_asOf);
  }

  /// Broadcast that the as-of instant changed; merged into read streams
  /// so watchFeed()/watchPostsByAuthor() re-run their queries.
  final _asOfTick = StreamController<DateTime?>.broadcast();

  Stream<DateTime?> get _asOfChanges => _asOfTick.stream.startWith(null);

  /// Expiry visibility clause: ephemeral posts survive only while
  /// [expiresAt] is in the future **of the traveled instant** — an
  /// ephemeral post that had not expired yet on the visited day shows,
  /// one that had already expired does not.
  Expression<bool> get _notExpiredExpr =>
      _db.posts.expiresAt.isNull() |
      _db.posts.expiresAt.isBiggerThanValue(_asOf ?? clock());

  /// Tombstone visibility, present and past: soft-deleted posts are
  /// invisible everywhere. In the present that's plain `deletedAt IS
  /// NULL`; while time traveling, a post deleted *after* the visited
  /// instant still existed then, so the tombstone only hides it from
  /// the moment it was stamped.
  Expression<bool> get _notDeletedExpr {
    final moment = _asOf;
    if (moment == null) {
      return _db.posts.deletedAt.isNull();
    }
    return _db.posts.deletedAt.isNull() |
        _db.posts.deletedAt.isBiggerThanValue(moment);
  }

  /// Rows that existed as of the traveled instant (or all rows in the
  /// present): created by then, not tombstoned by then.
  Expression<bool> get _existedAsOfExpr {
    final moment = _asOf;
    if (moment == null) {
      // Present: only the tombstone filter applies (createdAt bounds
      // would wrongly hide nothing but are pointless without a moment).
      return _notDeletedExpr;
    }
    return _db.posts.createdAt.isSmallerOrEqualValue(moment) &
        _notDeletedExpr;
  }

  /// One-shot expired purge used by app-start cleanup; visible here so
  /// the repository can orchestrate without reaching into the db.
  Future<int> purgeExpired() => _db.purgeExpiredPosts(clock());

  /// Like-count enrichment shared by the watch paths (the grouped
  /// aggregate — groupBy is load-bearing, see the note in watchFeed).
  ///
  /// Time travel aware: a like existed at [moment] when likedAt <= moment
  /// and (unlikedAt is null or unlikedAt > moment) — the same semantics
  /// the post tombstone uses. In the present only live (non-unliked)
  /// likes count.
  Future<Map<String, int>> _likeCounts() async {
    final moment = _asOf;
    final countRows = await (_db.selectOnly(_db.postLikes)
          ..addColumns([_db.postLikes.postId, _db.postLikes.postId.count()])
          ..where(moment == null
              ? _db.postLikes.unlikedAt.isNull()
              : _db.postLikes.likedAt.isSmallerOrEqualValue(moment) &
                  (_db.postLikes.unlikedAt.isNull() |
                      _db.postLikes.unlikedAt.isBiggerThanValue(moment)))
          ..groupBy([_db.postLikes.postId]))
        .get();
    return {
      for (final row in countRows)
        if (row.read(_db.postLikes.postId) case final postId?)
          postId: row.read(_db.postLikes.postId.count()) ?? 0,
    };
  }

  /// Live-like join predicate: only non-unliked rows match, so the
  /// single-user like flag reads straight off the join (row present =
  /// heart on). Unliked rows keep their history for the as-of counts.
  Expression<bool> _liveLikeJoin(PostLikes likes) =>
      likes.postId.equalsExp(_db.posts.id) & likes.unlikedAt.isNull();

  @override
  Stream<List<Post>> watchFeed() {
    final likes = _db.alias(_db.postLikes, 'pl');
    final query = _db.select(_db.posts).join([
      leftOuterJoin(likes, _liveLikeJoin(likes)),
    ])
      // Soft-deleted posts are invisible everywhere in the feed; the row
      // itself survives for the undo window (see deletePost/restorePost).
      // Expired ephemeral posts are filtered at query time (clock-seamed).
      // Time travel: only rows that existed as of the visited instant.
      ..where(_existedAsOfExpr & _notExpiredExpr)
      ..orderBy([
        OrderingTerm(
          expression: _db.posts.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);

    // Time travel: rebuild the query when the as-of instant moves (the
    // where-clauses read _asOf at query build time).
    return _asOfChanges.switchMap((_) => query.watch().asyncMap((rows) async {
          if (rows.isEmpty) return const <Post>[];

          // One grouped count for the whole page — cheaper than a correlated
          // subquery per row, and drift re-runs it on every table change.
          // groupBy is load-bearing: without it the aggregate collapses to ONE
          // global row whose arbitrary postId value made random posts display
          // the whole table's like total instead of their own count.
          final countByPost = await _likeCounts();

          return rows.map((row) {
            final post = row.readTable(_db.posts);
            final liked = row.readTableOrNull(likes) != null;
            return post.toEntity(
              isLiked: liked,
              likesCount: countByPost[post.id] ?? 0,
            );
          }).toList();
        }));
  }

  @override
  Future<void> insertPost(PostsCompanion entry) {
    _assertWritable();
    return _db.into(_db.posts).insertOnConflictUpdate(entry);
  }

  @override
  Future<List<Post>> postsOnDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final likes = _db.alias(_db.postLikes, 'pl');
    final query = _db.select(_db.posts).join([
      leftOuterJoin(likes, _liveLikeJoin(likes)),
    ])
      ..where(_db.posts.createdAt.isBetweenValues(start, end) &
          _existedAsOfExpr &
          _notExpiredExpr)
      ..orderBy([
        OrderingTerm(
          expression: _db.posts.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);
    final rows = await query.get();
    final countByPost = await _likeCounts();

    return rows.map((row) {
      final post = row.readTable(_db.posts);
      final liked = row.readTableOrNull(likes) != null;
      return post.toEntity(
        isLiked: liked,
        likesCount: countByPost[post.id] ?? 0,
      );
    }).toList();
  }

  @override
  Stream<List<Post>> watchPostsByAuthor(String authorName) {
    final likes = _db.alias(_db.postLikes, 'pl');
    final query = _db.select(_db.posts).join([
      leftOuterJoin(likes, _liveLikeJoin(likes)),
    ])
      ..where(_existedAsOfExpr &
          _db.posts.authorName.equals(authorName) &
          _notExpiredExpr)
      ..orderBy([
        OrderingTerm(
          expression: _db.posts.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);

    return _asOfChanges.switchMap((_) => query.watch().asyncMap((rows) async {
          if (rows.isEmpty) return const <Post>[];
          final countByPost = await _likeCounts();
          return rows.map((row) {
            final post = row.readTable(_db.posts);
            final liked = row.readTableOrNull(likes) != null;
            return post.toEntity(
              isLiked: liked,
              likesCount: countByPost[post.id] ?? 0,
            );
          }).toList();
        }));
  }

  @override
  Future<List<Post>> findVisiblePostsByAuthor(String authorName) async {
    final likes = _db.alias(_db.postLikes, 'pl');
    final query = _db.select(_db.posts).join([
      leftOuterJoin(likes, _liveLikeJoin(likes)),
    ])
      ..where(_existedAsOfExpr &
          _db.posts.authorName.equals(authorName) &
          _notExpiredExpr)
      ..orderBy([
        OrderingTerm(
          expression: _db.posts.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);
    final rows = await query.get();
    if (rows.isEmpty) return const <Post>[];
    final countByPost = await _likeCounts();
    return rows.map((row) {
      final post = row.readTable(_db.posts);
      final liked = row.readTableOrNull(likes) != null;
      return post.toEntity(
        isLiked: liked,
        likesCount: countByPost[post.id] ?? 0,
      );
    }).toList();
  }

  @override
  Future<Post?> findPost(String postId) async {
    final row = await _findRowIncludingDeleted(postId);
    if (row == null) return null;
    return _enrichSingle(row);
  }

  @override
  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  }) async {
    _assertWritable();
    // Soft like state (v15): un-liking stamps unliked_at instead of
    // deleting the row, so like history stays reconstructable for time
    // travel. Re-liking clears the tombstone — same row, upserted.
    await _db.into(_db.postLikes).insertOnConflictUpdate(PostLikesCompanion(
          postId: Value(postId),
          userId: Value(userId),
          likedAt: Value(DateTime.now()),
          unlikedAt: Value(liked ? null : DateTime.now()),
        ));
  }

  @override
  Future<void> deletePost(String postId) async {
    _assertWritable();
    await (_db.update(_db.posts)..where((tbl) => tbl.id.equals(postId)))
        .write(PostsCompanion(deletedAt: Value(DateTime.now())));
  }

  @override
  Future<void> restorePost(String postId) async {
    _assertWritable();
    await (_db.update(_db.posts)..where((tbl) => tbl.id.equals(postId)))
        .write(const PostsCompanion(deletedAt: Value(null)));
  }

  @override
  Future<void> keepPost(String postId) async {
    _assertWritable();
    await (_db.update(_db.posts)..where((tbl) => tbl.id.equals(postId)))
        .write(const PostsCompanion(expiresAt: Value(null)));
  }

  @override
  Future<void> purgePost(String postId) async {
    _assertWritable();
    await (_db.delete(_db.postLikes)
          ..where((tbl) => tbl.postId.equals(postId)))
        .go();
    await (_db.delete(_db.posts)..where((tbl) => tbl.id.equals(postId)))
        .go();
  }

  @override
  Future<Post?> findPostIncludingDeleted(String postId) async {
    final row = await _findRowIncludingDeleted(postId);
    if (row == null) return null;
    return _enrichSingle(row);
  }

  Future<PostRow?> _findRowIncludingDeleted(String postId) =>
      (_db.select(_db.posts)..where((tbl) => tbl.id.equals(postId)))
          .getSingleOrNull();

  /// Entity for one row with live like state (unliked rows excluded —
  /// the tombstone is history, not a live like). Time travel does not
  /// apply here: these are point lookups for the write paths.
  Future<Post> _enrichSingle(PostRow row) async {
    final likedRows = await (_db.select(_db.postLikes)
          ..where((tbl) =>
              tbl.postId.equals(row.id) & tbl.unlikedAt.isNull()))
        .get();
    return row.toEntity(
      isLiked: likedRows.isNotEmpty,
      likesCount: likedRows.length,
    );
  }
}
