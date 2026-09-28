import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';
import 'package:superapp/features/square/domain/repositories/feed_repository.dart';
import 'package:superapp/features/square/ui/square_card.dart';
import 'package:superapp/features/square/ui/square_feed_view.dart';
import 'package:superapp/features/square/ui/square_post_model.dart';
import 'package:superapp/injection.dart' as di;
import 'package:superapp/main.dart';

// -- helpers -----------------------------------------------------------------

/// In-memory stack per test: no disk, ticker at 1h so it never fires.
(FeedRepository, MockFeedRepository, AppDatabase) _makeRepo() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final local = DriftSquareLocalDatasource(db);
  final mock = MockFeedRepository(
    localDatasource: local,
    db: db,
    incomingPostInterval: const Duration(hours: 1),
    startTicker: false,
  );
  return (mock, mock, db);
}

int _filledHearts(WidgetTester tester) => tester
    .widgetList<Icon>(find.byType(Icon))
    .where((i) =>
        i.icon == Icons.favorite_rounded &&
        i.color == const Color(0xFFE0245E) &&
        i.size == 22.0)
    .length;

Future<void> _doubleTapMedia(WidgetTester tester) async {
  final media = find.descendant(
    of: find.byType(SquareFeedCard),
    matching: find.byType(AspectRatio),
  );
  final center = tester.getCenter(media.first);
  final g1 = await tester.startGesture(center);
  await g1.up();
  await tester.pump(const Duration(milliseconds: 90));
  final g2 = await tester.startGesture(center);
  await g2.up();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('SquarePost model', () {
    test('timeAgo formats minutes, hours, days', () {
      final now = DateTime.now();
      SquarePost post(DateTime ts) => SquarePost(
            id: 't',
            username: 'u',
            userAvatarUrl: '',
            timestamp: ts,
            caption: '',
            likesCount: 0,
            isLiked: false,
          );
      expect(post(now.subtract(const Duration(minutes: 5))).timeAgo, '5m');
      expect(post(now.subtract(const Duration(hours: 3))).timeAgo, '3h');
      expect(post(now.subtract(const Duration(days: 2))).timeAgo, '2d');
    });

    test('likesLabel abbreviates thousands', () {
      SquarePost withLikes(int n) => SquarePost(
            id: 't',
            username: 'u',
            userAvatarUrl: '',
            timestamp: DateTime.now(),
            caption: '',
            likesCount: n,
            isLiked: false,
          );
      expect(withLikes(950).likesLabel, '950');
      expect(withLikes(1240).likesLabel, '1.2k');
      expect(withLikes(45300).likesLabel, '45k');
    });

    test('copyWith toggles like without mutating original', () {
      final p = SquarePost(
        id: 't',
        username: 'u',
        userAvatarUrl: '',
        timestamp: DateTime.now(),
        caption: '',
        likesCount: 5,
        isLiked: false,
      );
      final liked = p.copyWith(isLiked: true, likesCount: 6);
      expect(p.isLiked, false);
      expect(liked.isLiked, true);
      expect(liked.likesCount, 6);
    });
  });

  group('Square feed — repository-backed', () {
    testWidgets('renders feed from drift cache, newest first',
        (tester) async {
      final (repo, mock, db) = _makeRepo();
      addTearDown(() async {
        mock.dispose();
        await db.close();
      });
      // Auto-seed on construction puts 3 posts in the cache.

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(800, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // Seeded authors visible; repository emits newest-first.
        expect(find.byType(SquareFeedCard), findsNWidgets(3));
        expect(find.text('Kai Meridian'), findsOneWidget);
      });
    });

    testWidgets('like via card persists to drift (stream re-emits)',
        (tester) async {
      final (repo, mock, db) = _makeRepo();
      addTearDown(() async {
        mock.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(800, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        expect(_filledHearts(tester), 0);
        await _doubleTapMedia(tester);
        await tester.pump(const Duration(milliseconds: 300));

        // The like round-trips: repository write -> drift table change ->
        // stream re-emit -> red heart rendered from the CACHE, not memory.
        expect(_filledHearts(tester), 1);
      });
    });

    testWidgets('like count reflects the like (1 like = count 1)',
        (tester) async {
      final (repo, mock, db) = _makeRepo();
      addTearDown(() async {
        mock.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(800, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // Seeded posts have zero likes; label shows '0'.
        expect(find.text('0'), findsNWidgets(3));

        await _doubleTapMedia(tester);
        await tester.pump(const Duration(milliseconds: 300));

        // One post now shows count 1, the others stay 0.
        expect(find.text('1'), findsOneWidget);
        expect(find.text('0'), findsNWidgets(2));
      });
    });

    testWidgets('like survives unmount+remount (cache, not memory)',
        (tester) async {
      final (repo, mock, db) = _makeRepo();
      addTearDown(() async {
        mock.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(800, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        // Mount, like, unmount.
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        await _doubleTapMedia(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(_filledHearts(tester), 1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));

        // Remount: a fresh stream from the same cache.
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // The like lives in drift, not in the widget state.
        expect(_filledHearts(tester), 1);
      });
    });

    testWidgets('refresh pulls more posts through the fake transport',
        (tester) async {
      final (repo, mock, db) = _makeRepo();
      addTearDown(() async {
        mock.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        // Tall enough that all six cards build without scrolling: the lazy
        // ListView only constructs cards inside the viewport + cacheExtent.
        await tester.binding.setSurfaceSize(const Size(800, 6000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SquareFeedCard), findsNWidgets(3));

        // Refresh through the fake transport (the gesture path — overscroll
        // drag caught by RefreshIndicator — is viewport-flaky with tall
        // media cards, so the gesture itself is not asserted). The
        // repository -> drift cache -> stream -> UI round-trip is the
        // contract under test.
        final refresh = await repo.refreshFeed();
        expect(refresh.isRight(), isTrue);
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(SquareFeedCard), findsNWidgets(6));
      });
    });
  });

  group('Square navigation shell (DI-wired)', () {
    testWidgets('boots from composition root and renders feed',
        (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final local = DriftSquareLocalDatasource(db);
      di.sl.registerLazySingleton<AppDatabase>(() => db);
      di.sl.registerLazySingleton<SquareLocalDatasource>(() => local);
      di.sl.registerLazySingleton<FeedRepository>(
        () => MockFeedRepository(
          localDatasource: local,
          db: db,
          incomingPostInterval: const Duration(hours: 1),
          seedOnStart: false,
          startTicker: false,
        ),
      );
      addTearDown(() async {
        await di.sl.reset();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        // Mobile shell: hybrid FAB bottom bar with four destinations.
        await tester.binding.setSurfaceSize(const Size(500, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(const SuperApp());
        await tester.pump(const Duration(milliseconds: 500));

        // Bottom bar: Square, Vault, Nexus, Calls + center compose FAB
        // (hybrid M3 bar; Settings is the Square app-bar gear on mobile).
        expect(find.byKey(const ValueKey('fab-bottom-bar')), findsOneWidget);
        expect(find.text('The Square'), findsWidgets);
        expect(find.text('The Vault'), findsOneWidget);
        // Settings is no longer a bottom destination — it's the Square
        // app-bar gear (label lives only in the app bar, no bar label).
        expect(find.text('Settings'), findsNothing);
        expect(find.text('The Hallway'), findsOneWidget);
        expect(find.text('The Landline'), findsOneWidget);
      });
    });
  });
}
