import 'package:drift/drift.dart';

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
        isLiked: isLiked,
        likesCount: likesCount,
      );
}

/// Local cache access for the Square. One-shot and stream reads over the
/// drift tables; writes happen only through repositories.
abstract class SquareLocalDatasource {
  /// Feed, newest first, with like flags and like counts.
  Stream<List<Post>> watchFeed();

  /// Posts created on [day] (local midnight to midnight), newest first.
  /// Tombstoned posts excluded, like the feed.
  Future<List<Post>> postsOnDay(DateTime day);

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

  /// Hard-deletes the post (and its likes). Called by the repository
  /// once the undo window has closed.
  Future<void> purgePost(String postId);

  /// Fetches a tombstoned post (ignores the filter) — the undo path
  /// needs the row even though the feed no longer shows it.
  Future<Post?> findPostIncludingDeleted(String postId);
}

class DriftSquareLocalDatasource implements SquareLocalDatasource {
  DriftSquareLocalDatasource(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Post>> watchFeed() {
    final likes = _db.alias(_db.postLikes, 'pl');
    final query = _db.select(_db.posts).join([
      leftOuterJoin(likes, likes.postId.equalsExp(_db.posts.id)),
    ])
      // Soft-deleted posts are invisible everywhere in the feed; the row
      // itself survives for the undo window (see deletePost/restorePost).
      ..where(_db.posts.deletedAt.isNull())
      ..orderBy([
        OrderingTerm(
          expression: _db.posts.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return const <Post>[];

      // One grouped count for the whole page — cheaper than a correlated
      // subquery per row, and drift re-runs it on every table change.
      // groupBy is load-bearing: without it the aggregate collapses to ONE
      // global row whose arbitrary postId value made random posts display
      // the whole table's like total instead of their own count.
      final countRows = await (_db.selectOnly(_db.postLikes)
            ..addColumns([_db.postLikes.postId, _db.postLikes.postId.count()])
            ..groupBy([_db.postLikes.postId]))
          .get();
      final countByPost = <String, int>{
        for (final row in countRows)
          if (row.read(_db.postLikes.postId) case final postId?)
            postId: row.read(_db.postLikes.postId.count()) ?? 0,
      };

      return rows.map((row) {
        final post = row.readTable(_db.posts);
        final liked = row.readTableOrNull(likes) != null;
        return post.toEntity(
          isLiked: liked,
          likesCount: countByPost[post.id] ?? 0,
        );
      }).toList();
    });
  }

  @override
  Future<void> insertPost(PostsCompanion entry) =>
      _db.into(_db.posts).insertOnConflictUpdate(entry);

  @override
  Future<List<Post>> postsOnDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final likes = _db.alias(_db.postLikes, 'pl');
    final query = _db.select(_db.posts).join([
      leftOuterJoin(likes, likes.postId.equalsExp(_db.posts.id)),
    ])
      ..where(_db.posts.deletedAt.isNull() &
          _db.posts.createdAt.isBetweenValues(start, end))
      ..orderBy([
        OrderingTerm(
          expression: _db.posts.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);
    final rows = await query.get();

    final countRows = await (_db.selectOnly(_db.postLikes)
          ..addColumns([_db.postLikes.postId, _db.postLikes.postId.count()])
          ..groupBy([_db.postLikes.postId]))
        .get();
    final countByPost = <String, int>{
      for (final row in countRows)
        if (row.read(_db.postLikes.postId) case final postId?)
          postId: row.read(_db.postLikes.postId.count()) ?? 0,
    };

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
    final query = _db.select(_db.posts)
      ..where((tbl) => tbl.id.equals(postId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final likedRows = await (_db.select(_db.postLikes)
          ..where((tbl) => tbl.postId.equals(postId)))
        .get();
    return row.toEntity(
      isLiked: likedRows.isNotEmpty,
      likesCount: likedRows.length,
    );
  }

  @override
  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  }) async {
    if (liked) {
      await _db.into(_db.postLikes).insertOnConflictUpdate(PostLikesCompanion(
            postId: Value(postId),
            userId: Value(userId),
            likedAt: Value(DateTime.now()),
          ));
    } else {
      await (_db.delete(_db.postLikes)
            ..where((tbl) =>
                tbl.postId.equals(postId) & tbl.userId.equals(userId)))
          .go();
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    await (_db.update(_db.posts)..where((tbl) => tbl.id.equals(postId)))
        .write(PostsCompanion(deletedAt: Value(DateTime.now())));
  }

  @override
  Future<void> restorePost(String postId) async {
    await (_db.update(_db.posts)..where((tbl) => tbl.id.equals(postId)))
        .write(const PostsCompanion(deletedAt: Value(null)));
  }

  @override
  Future<void> purgePost(String postId) async {
    await (_db.delete(_db.postLikes)
          ..where((tbl) => tbl.postId.equals(postId)))
        .go();
    await (_db.delete(_db.posts)..where((tbl) => tbl.id.equals(postId)))
        .go();
  }

  @override
  Future<Post?> findPostIncludingDeleted(String postId) async {
    final query = _db.select(_db.posts)
      ..where((tbl) => tbl.id.equals(postId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final likedRows = await (_db.select(_db.postLikes)
          ..where((tbl) => tbl.postId.equals(postId)))
        .get();
    return row.toEntity(
      isLiked: likedRows.isNotEmpty,
      likesCount: likedRows.length,
    );
  }
}
