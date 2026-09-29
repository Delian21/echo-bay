import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';
import 'package:superapp/features/square/domain/repositories/feed_repository.dart'
    show FeedRepository;

void main() {
  late AppDatabase db;
  late DriftSquareLocalDatasource datasource;

  /// Fixed "now" so expiry boundaries are deterministic.
  final fixedNow = DateTime(2026, 9, 29, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    datasource = DriftSquareLocalDatasource(db, clock: () => fixedNow);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> insertPost({
    required String id,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) async {
    await datasource.insertPost(PostsCompanion.insert(
      id: id,
      authorId: 'local-user',
      authorName: 'You',
      body: 'post $id',
      createdAt: createdAt ?? fixedNow.subtract(const Duration(hours: 1)),
      expiresAt: Value(expiresAt),
    ));
    return id;
  }

  group('query-time expiry filtering', () {
    test('boundary: post with expiresAt exactly == now is filtered out',
        () async {
      await insertPost(
        id: 'boundary',
        // Exactly at the clock: not in the future -> expired.
        expiresAt: fixedNow,
      );
      await insertPost(
        id: 'still-here',
        expiresAt: fixedNow.add(const Duration(seconds: 1)),
      );
      await insertPost(id: 'permanent');

      final feed = await datasource.watchFeed().first;
      final ids = feed.map((p) => p.id).toSet();
      expect(ids, {'still-here', 'permanent'});
    });

    test('feed, day view, and profile grid all exclude expired posts',
        () async {
      await insertPost(
        id: 'expired',
        expiresAt: fixedNow.subtract(const Duration(minutes: 5)),
        createdAt: fixedNow.subtract(const Duration(hours: 2)),
      );
      await insertPost(id: 'kept-permanent');

      final feed = await datasource.watchFeed().first;
      expect(feed.map((p) => p.id), ['kept-permanent']);

      final day = await datasource.postsOnDay(fixedNow);
      expect(day.map((p) => p.id), ['kept-permanent']);

      final own = await datasource.watchPostsByAuthor('You').first;
      expect(own.map((p) => p.id), ['kept-permanent']);
    });
  });

  group('keep-it conversion', () {
    test('keepPost clears expiresAt so the post stops fading', () async {
      final id = await insertPost(
        id: 'ephemeral',
        expiresAt: fixedNow.add(const Duration(hours: 20)),
      );

      var rows = await datasource.watchFeed().first;
      expect(rows.single.expiresAt, isNotNull);

      await datasource.keepPost(id);

      rows = await datasource.watchFeed().first;
      expect(rows.single.id, 'ephemeral');
      expect(rows.single.expiresAt, isNull);
    });

    test('FeedRepository.keepPost rejects foreign and missing posts',
        () async {
      final repo = MockFeedRepository(
        localDatasource: datasource,
        db: db,
        localUserId: 'local-user',
        startTicker: false,
        seedOnStart: false,
      );
      addTearDown(repo.dispose);

      // Missing post.
      var result = await repo.keepPost(postId: 'nope');
      expect(result.isLeft(), isTrue);

      // Foreign post.
      await datasource.insertPost(PostsCompanion.insert(
        id: 'theirs',
        authorId: 'someone-else',
        authorName: 'R. Virtanen',
        body: 'not mine',
        createdAt: fixedNow.subtract(const Duration(hours: 1)),
      ));
      result = await repo.keepPost(postId: 'theirs');
      expect(result.isLeft(), isTrue);

      // Own ephemeral post converts through the repository seam.
      // createPost stamps wall-clock time, so assert the lifetime delta
      // rather than an absolute instant.
      final created = await repo.createPost(body: 'mine', ephemeral: true);
      final post = created.fold((_) => fail('expected right'), (p) => p);
      expect(post.expiresAt, isNotNull);
      expect(
        post.expiresAt!.isAfter(
          post.createdAt.add(const Duration(hours: 23)),
        ),
        isTrue,
      );

      final kept = await repo.keepPost(postId: post.id);
      expect(kept.isRight(), isTrue);
      final row = await datasource.findPost(post.id);
      expect(row!.expiresAt, isNull);
    });
  });

  group('lazy cleanup', () {
    test('purgeExpiredPosts hard-deletes expired rows only', () async {
      await insertPost(
        id: 'gone',
        expiresAt: fixedNow.subtract(const Duration(seconds: 1)),
      );
      await insertPost(
        id: 'lingers',
        expiresAt: fixedNow.add(const Duration(hours: 3)),
      );
      await insertPost(id: 'permanent');

      final purged = await db.purgeExpiredPosts(fixedNow);
      expect(purged, 1);

      final remaining = await datasource.watchFeed().first;
      final ids = remaining.map((p) => p.id).toSet();
      expect(ids, {'lingers', 'permanent'});

      // The purged row is really gone (hard delete), the others intact.
      expect(await datasource.findPostIncludingDeleted('gone'), isNull);
      expect(await datasource.findPostIncludingDeleted('lingers'), isNotNull);
      expect(
        await datasource.findPostIncludingDeleted('permanent'),
        isNotNull,
      );
    });

    test('purge removes likes of expired posts', () async {
      final id = await insertPost(
        id: 'loved',
        expiresAt: fixedNow.subtract(const Duration(minutes: 1)),
      );
      await datasource.setLiked(
        postId: id,
        userId: 'someone',
        liked: true,
      );

      await db.purgeExpiredPosts(fixedNow);

      final likes = await (db.select(db.postLikes)
            ..where((tbl) => tbl.postId.equals(id)))
          .get();
      expect(likes, isEmpty);
    });
  });
}
