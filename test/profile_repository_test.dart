import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/profile/user_profile.dart';
import 'package:echo_bay/core/settings/app_settings_store.dart';
import 'package:echo_bay/core/usecase/usecase.dart';
import 'package:echo_bay/features/profile/data/repositories/drift_profile_repository.dart';
import 'package:echo_bay/features/profile/domain/usecases/profile_usecases.dart';
import 'package:echo_bay/features/profile/domain/usecases/watch_own_posts.dart';
import 'package:echo_bay/features/square/data/datasources/square_local_datasource.dart';
import 'package:echo_bay/features/square/data/repositories/mock_feed_repository.dart';

void main() {
  late AppDatabase db;
  late AppSettingsStore store;
  late DriftSquareLocalDatasource square;
  late DriftProfileRepository repo;
  late MockFeedRepository feed;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = AppSettingsStore(db);
    square = DriftSquareLocalDatasource(db);
    repo = DriftProfileRepository(store, square);
    feed = MockFeedRepository(
      localDatasource: square,
      db: db,
      localUserId: 'local-user',
      startTicker: false,
    );
  });

  tearDown(() async {
    feed.dispose();
    await db.close();
  });

  group('DriftProfileRepository', () {
    test('loadProfile returns defaults when nothing stored', () async {
      final result = await repo.loadProfile();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected right'),
        (p) => expect(p.displayName, 'You'),
      );
    });

    test('saveProfile persists name, bio and avatar; load reads them back',
        () async {
      final profile = const UserProfile().copyWith(
        displayName: 'Ada Loomis',
        bio: 'dawn walker, ink drinker',
        avatarPath: '/tmp/avatar.png',
      );
      final saved = await repo.saveProfile(profile);
      expect(saved.isRight(), isTrue);

      final loaded = await repo.loadProfile();
      loaded.fold(
        (_) => fail('expected right'),
        (p) {
          expect(p.displayName, 'Ada Loomis');
          expect(p.bio, 'dawn walker, ink drinker');
          expect(p.avatarPath, '/tmp/avatar.png');
        },
      );
    });

    test('clearing bio removes the stored key', () async {
      await repo.saveProfile(const UserProfile().copyWith(bio: 'temporary'));
      await repo.saveProfile(const UserProfile().copyWith(clearBio: true));
      final loaded = await repo.loadProfile();
      loaded.fold((_) => fail('expected right'), (p) => expect(p.bio, isNull));
    });

    test('watchOwnPosts emits only the user’s own non-deleted posts',
        () async {
      // Seed posts are authored by a-1/a-2/a-3; make some clearly "ours".
      await feed.createPost(body: 'my own square', authorName: 'You');
      await feed.createPost(body: 'another of mine', authorName: 'You');

      final first = await repo.watchOwnPosts().first;
      first.fold(
        (_) => fail('expected right'),
        (posts) {
          expect(posts, isNotEmpty);
          expect(posts.every((p) => p.authorName == 'You'), isTrue);
          expect(posts.map((p) => p.body), contains('my own square'));
        },
      );
    });

    test('watchOwnPosts excludes tombstoned posts', () async {
      final created = await feed.createPost(
          body: 'to be deleted', authorName: 'You');
      final post = created.getOrElse((_) => throw StateError('x'));
      await feed.deletePost(postId: post.id);

      final first = await repo.watchOwnPosts().first;
      first.fold(
        (_) => fail('expected right'),
        (posts) => expect(posts.map((p) => p.body),
            isNot(contains('to be deleted'))),
      );
    });
  });

  group('use cases', () {
    test('LoadProfile delegates to the repository', () async {
      final result = await LoadProfile(repo)(const NoParams());
      expect(result.isRight(), isTrue);
    });

    test('SaveProfile round-trips through the repository', () async {
      final result = await SaveProfile(repo)(
          const UserProfile().copyWith(displayName: 'Nova', bio: 'x'));
      expect(result.isRight(), isTrue);
      final loaded = await LoadProfile(repo)(const NoParams());
      loaded.fold(
        (_) => fail('expected right'),
        (p) {
          expect(p.displayName, 'Nova');
          expect(p.bio, 'x');
        },
      );
    });

    test('WatchOwnPosts yields a live stream', () async {
      final result = await WatchOwnPosts(repo)(const NoParams());
      expect(result.isRight(), isTrue);
      final stream = result.getOrElse((_) => throw StateError('x'));
      await feed.createPost(body: 'grid post', authorName: 'You');
      final posts = (await stream.first).getOrElse(
        (_) => throw StateError('x'),
      );
      expect(posts.map((p) => p.body), contains('grid post'));
    });
  });
}
