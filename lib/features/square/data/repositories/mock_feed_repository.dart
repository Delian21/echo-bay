import 'dart:async';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/square_local_datasource.dart';

/// Mock implementation of [FeedRepository].
///
/// Simulates a live server:
///  - seeds the cache with initial posts on first construction;
///  - a [Stream.periodic] "network ticker" pushes a new post into the cache
///    every [incomingPostInterval], exactly like a remote push would;
///  - all reads come from the local cache, never from memory, so the
///    offline-first read path is identical to the real implementation.
class MockFeedRepository implements FeedRepository {
  MockFeedRepository({
    required SquareLocalDatasource localDatasource,
    required AppDatabase db,
    this.localUserId = 'local-user',
    Duration incomingPostInterval = const Duration(seconds: 20),
    bool seedOnStart = true,
    bool startTicker = true,
  })  : _local = localDatasource,
        _db = db,
        _incomingPostInterval = incomingPostInterval {
    if (seedOnStart) {
      _seeded = _seed();
    }
    // Opt-in: the periodic push timer trips flutter_test's pending-timer
    // invariant (teardowns run after the check), so tests disable it.
    if (startTicker) {
      _startTicker();
    }
  }

  final SquareLocalDatasource _local;
  final AppDatabase _db;
  final Duration _incomingPostInterval;
  final _uuid = const Uuid();

  /// The local session's opaque id, injected from the auth seam. Kept as
  /// an instance field — never hardcoded, never interpreted.
  final String localUserId;

  /// Verified-live Unsplash photo ids (curl-checked HTTP 200) used for
  /// simulated "remote" media. Cycled so every image-bearing post gets a
  /// real photo; the card's shimmer/error states handle any network miss.
  static const _photoIds = [
    '1518791841217-8f162f1e1131', // cat
    '1506905925346-21bda4d32df4', // mountain ridge
    '1441974231531-c6227db76b6e', // forest light
    '1529626455594-4ff0802cfb7e', // portrait
    '1470071459604-3b5ec3a7fe05', // foggy valley
    '1500530855697-b586d89ba3ee', // highway dusk
    '1519125323398-675f0ddb6308', // city night
    '1544367567-0f2fcb009e0b', // surfer
    '1469474968028-56623f02e42e', // sunbeam forest
    '1493246507139-91e8fad9978e', // mountains lake
    '1517849845537-4d257902454a', // pug
    '1482192596544-9eb780fc7f66', // coffee desk
    '1533738363-b7f9aef128ce', // neon portrait
    '1506744038136-46273834b3fb', // lake reflection
    '1521747116042-5a810fda9664', // skater
    '1519389950473-47ba0277781c', // team laptops
    '1502082553048-f009c37129b9', // green leaves
    '1477959858617-67f85cf4f1df', // skyline
  ];

  static String _photoUrl(int i) =>
      'https://images.unsplash.com/photo-${_photoIds[i % _photoIds.length]}'
      '?w=1080&q=80&auto=format&fit=crop';

  /// Deterministic blurhash per photo. The mock cannot decode a network
  /// image to run real encoding, so it hashes a stable single color from
  /// the photo id: each post renders its own wash, and the exact
  /// encode-at-write / decode-at-render path a real backend would use is
  /// exercised end to end.
  static String _blurhashFor(String photoId) {
    final seed = photoId.hashCode;
    return BlurHash.fromRgb(
      (seed >> 16) & 0xFF,
      (seed >> 8) & 0xFF,
      seed & 0xFF,
    ).hash;
  }

  Future<void>? _seeded;
  Timer? _ticker;
  int _tickCount = 0;

  // -- FeedRepository -------------------------------------------------------

  @override
  Stream<Either<Failure, List<Post>>> watchFeed() async* {
    // Ensure the seed has landed before the first emission.
    await _seeded;
    yield* _local
        .watchFeed()
        .map((posts) => Right<Failure, List<Post>>(posts));
  }

  @override
  Future<Either<Failure, Unit>> refreshFeed() async {
    // Mock "network refresh": pull simulated remote posts into cache now.
    // Fail-path behaviour is preserved: callers get NetworkFailure when the
    // fake transport is toggled offline (see [setOnline]).
    if (!_online) {
      return left(const NetworkFailure(message: 'offline: refresh unavailable'));
    }
    await _pushRemotePosts(count: 3);
    return right(unit);
  }

  @override
  Future<Either<Failure, Post>> createPost({
    required String body,
    String? mediaUrl,
    String authorName = 'You',
  }) async {
    try {
      final post = Post(
        id: _uuid.v4(),
        authorId: localUserId,
        authorName: authorName,
        body: body,
        mediaUrl: mediaUrl,
        createdAt: DateTime.now(),
      );
      await _local.insertPost(PostsCompanion.insert(
        id: post.id,
        authorId: post.authorId,
        authorName: post.authorName,
        body: post.body,
        mediaUrl: Value(post.mediaUrl),
        blurhash: Value(post.mediaUrl == null
            ? null
            : _blurhashFor(post.mediaUrl!)),
        createdAt: post.createdAt,
      ));
      return right(post);
    } catch (e) {
      return left(CacheFailure(message: 'createPost failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleLike({required String postId}) async {
    try {
      final existing = await _local.findPost(postId);
      if (existing == null) {
        return left(const NotFoundFailure(message: 'post not found'));
      }
      await _local.setLiked(
        postId: postId,
        userId: localUserId,
        liked: !existing.isLiked,
      );
      return right(unit);
    } catch (e) {
      return left(CacheFailure(message: 'toggleLike failed', cause: e));
    }
  }

  /// Undo window: tombstoned posts are purged this long after delete.
  /// Within the window, [restorePost] brings the exact post back.
  static const undoWindow = Duration(seconds: 10);

  @override
  Future<Either<Failure, Unit>> deletePost({required String postId}) async {
    try {
      final existing = await _local.findPost(postId);
      if (existing == null) {
        return right(unit); // idempotent — already gone
      }
      // Only the author can delete their own post. Seeded/remote posts
      // (the simulated community) are not the local user's to remove.
      if (existing.authorId != localUserId) {
        return left(const NotFoundFailure(message: 'not your post'));
      }
      await _local.deletePost(postId); // tombstone — restorable
      // Hard-delete once the undo window closes. One timer per delete:
      // restorePost cancels the purge by clearing the tombstone before
      // the timer fires (purge re-checks and no-ops on a restored post
      // only if it wins the race — the DB write order makes the window
      // self-consistent).
      Timer(undoWindow, () async {
        final row = await _local.findPostIncludingDeleted(postId);
        if (row == null || row.deletedAt == null) return;
        await _local.purgePost(postId);
      });
      return right(unit);
    } catch (e) {
      return left(CacheFailure(message: 'deletePost failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> restorePost({required String postId}) async {
    try {
      final row = await _local.findPostIncludingDeleted(postId);
      if (row == null) {
        return left(const NotFoundFailure(message: 'post not found'));
      }
      if (row.deletedAt == null) return right(unit); // never deleted
      await _local.restorePost(postId);
      return right(unit);
    } catch (e) {
      return left(CacheFailure(message: 'restorePost failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> postsOnDay(DateTime day) async {
    try {
      return right(await _local.postsOnDay(day));
    } catch (e) {
      return left(CacheFailure(message: 'postsOnDay failed', cause: e));
    }
  }

  // -- Fake network simulation ----------------------------------------------

  bool _online = true;

  /// Toggle the simulated network. Offline: ticker stops, refresh fails —
  /// lets the UI exercise real offline states without a backend.
  void setOnline(bool online) {
    _online = online;
    online ? _startTicker() : _ticker?.cancel();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_incomingPostInterval, (_) {
      _tickCount++;
      _pushRemotePosts(count: 1);
    });
  }

  Future<void> _seed() async {
    final now = DateTime.now();
    final existing = await _db.select(_db.posts).get();
    if (existing.isNotEmpty) return; // idempotent seed

    const seedAuthors = [
      ('a-1', 'Kai Meridian'),
      ('a-2', 'Nova Okafor'),
      ('a-3', 'Rune Virtanen'),
    ];
    const seedBodies = [
      'Shipped the first architecture cut today. Feels structural, not decorative.',
      'Hot take: offline-first is not a feature, it is a posture.',
      'The feed is just a river. You are all standing in it.',
    ];

    for (var i = 0; i < seedAuthors.length; i++) {
      final url = _photoUrl(i);
      await _local.insertPost(PostsCompanion.insert(
        id: 'seed-$i',
        authorId: seedAuthors[i].$1,
        authorName: seedAuthors[i].$2,
        body: seedBodies[i],
        mediaUrl: Value(url),
        blurhash: Value(_blurhashFor(url)),
        createdAt: now.subtract(Duration(minutes: 15 * (i + 1))),
      ));
    }
  }

  Future<void> _pushRemotePosts({required int count}) async {
    final now = DateTime.now();
    for (var i = 0; i < count; i++) {
      final n = _tickCount * count + i;
      final mediaUrl = n.isEven ? _photoUrl(3 + n) : null;
      await _local.insertPost(PostsCompanion.insert(
        id: _uuid.v4(),
        authorId: 'remote-$n',
        authorName: _remoteAuthor(n),
        body: _remoteBody(n),
        // Every other remote post carries media so the feed exercises
        // both card layouts (text-only and full-bleed image).
        mediaUrl: Value(mediaUrl),
        blurhash: Value(mediaUrl == null ? null : _blurhashFor(mediaUrl)),
        createdAt: now.subtract(Duration(seconds: i)),
      ));
    }
  }

  String _remoteAuthor(int n) {
    const names = ['Ada Loomis', 'Bo Tamm', 'Cyr Vahtra', 'Dag Niemen'];
    return names[n % names.length];
  }

  String _remoteBody(int n) {
    const bodies = [
      'Live from the mock transport: post incoming on the wire.',
      'Ticker says hello — this one arrived without a refresh.',
      'Simulated server push #. The cache never sleeps.',
      'If you can read this offline, the architecture held.',
    ];
    return '${bodies[n % bodies.length]} (tick $n)';
  }

  /// Test/teardown hook. Not part of the repository contract.
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
  }
}
