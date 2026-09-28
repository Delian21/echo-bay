import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';

void main() {
  late AppDatabase db;
  late DriftSquareLocalDatasource local;
  late MockFeedRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = DriftSquareLocalDatasource(db);
    repo = MockFeedRepository(
      localDatasource: local,
      db: db,
      incomingPostInterval: const Duration(hours: 1),
      startTicker: false,
    );
    // Create an own post to delete.
    await repo.createPost(body: 'a small moment', authorName: 'You');
  });

  tearDown(() async {
    repo.dispose();
    await db.close();
  });

  test('delete hides the post but keeps it restorable for the window', () async {
    final before = (await repo.watchFeed().first)
        .fold((f) => throw StateError('feed failure'), (p) => p);
    expect(before, isNotEmpty);
    final target = before.first;

    final result = await repo.deletePost(postId: target.id);
    expect(result.isRight(), isTrue);

    // Hidden from the feed immediately.
    final after = (await repo.watchFeed().first)
        .fold((f) => throw StateError('feed failure'), (p) => p);
    expect(after.any((p) => p.id == target.id), isFalse);

    // Still restorable inside the window.
    final restore = await repo.restorePost(postId: target.id);
    expect(restore.isRight(), isTrue);

    // And back on the feed — same id, same body (true undo, not repost).
    final restored = (await repo.watchFeed().first)
        .fold((f) => throw StateError('feed failure'), (p) => p);
    final again = restored.where((p) => p.id == target.id).toList();
    expect(again, hasLength(1));
    expect(again.first.body, 'a small moment');
    expect(again.first.authorName, 'You');
  });

  test('restore of a never-deleted post is an idempotent right', () async {
    final feed = (await repo.watchFeed().first)
        .fold((f) => throw StateError('feed failure'), (p) => p);
    final result = await repo.restorePost(postId: feed.first.id);
    expect(result.isRight(), isTrue);
  });

  test('postsOnDay returns only posts created today',
      () async {
    final result = await repo.postsOnDay(DateTime.now());
    final posts = result.fold((f) => throw StateError('postsOnDay failed'), (p) => p);
    expect(posts, isNotEmpty);
    expect(posts.every((p) => _isToday(p.createdAt)), isTrue);
  });

  test('foreign posts cannot be deleted', () async {
    // Seeded posts belong to other authors.
    final feed = (await repo.watchFeed().first)
        .fold((f) => throw StateError('feed failure'), (p) => p);
    final foreign = feed.firstWhere((p) => p.authorId != 'local-user');
    final result = await repo.deletePost(postId: foreign.id);
    expect(result.isLeft(), isTrue);
  });
}

bool _isToday(DateTime at) {
  final now = DateTime.now();
  return at.year == now.year && at.month == now.month && at.day == now.day;
}
