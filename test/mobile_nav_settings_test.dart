import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/theme/theme_controller.dart';
import 'package:superapp/features/calls/data/repositories/mock_calls_repository.dart';
import 'package:superapp/features/calls/domain/entities/call.dart';
import 'package:superapp/features/calls/ui/calls_module_view.dart';
import 'package:superapp/features/settings/ui/settings_page.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';
import 'package:superapp/features/square/domain/repositories/feed_repository.dart';
import 'package:superapp/features/square/ui/square_navigation_shell.dart';
import 'package:superapp/injection.dart' as di;

/// In-memory drift stack per test; ticker off so no periodic timer trips
/// flutter_test's pending-timer invariant.
(MockFeedRepository, AppDatabase) _makeFeedRepo() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final local = DriftSquareLocalDatasource(db);
  final mock = MockFeedRepository(
    localDatasource: local,
    db: db,
    incomingPostInterval: const Duration(hours: 1),
    startTicker: false,
  );
  return (mock, db);
}

void main() {
  group('Calls module', () {
    test('CallLogEntry labels: time and duration', () {
      final now = DateTime.now();
      CallLogEntry entry(
        CallDirection direction,
        DateTime at,
        Duration duration,
      ) =>
          CallLogEntry(
            id: 't',
            peerName: 'Kai',
            peerAvatarUrl: '',
            direction: direction,
            at: at,
            duration: duration,
          );

      expect(entry(CallDirection.missed, now, Duration.zero).timeLabel, 'now');
      expect(
        entry(CallDirection.outgoing, now.subtract(const Duration(hours: 3)),
                const Duration(minutes: 4, seconds: 37))
            .durationLabel,
        '4m 37s',
      );
      expect(
        entry(CallDirection.missed, now, const Duration(minutes: 5))
            .durationLabel,
        '',
      );
    });

    testWidgets('recents list renders seeded entries with direction icons',
        (tester) async {
      final repo = MockCallsRepository(connectDelay: Duration.zero);

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(500, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: CallsModuleView(repository: repo),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // Four seeded entries across three directions.
        expect(find.text('Kai Meridian'), findsOneWidget);
        expect(find.text('Rune Virtanen'), findsNWidgets(2));
        expect(find.byIcon(Icons.call_missed_outgoing_rounded),
            findsOneWidget);
        expect(find.byIcon(Icons.call_received_rounded), findsOneWidget);
        expect(find.byIcon(Icons.call_made_rounded), findsNWidgets(2));
      });

      repo.dispose();
    });

    testWidgets('redial: connecting dialog joins into the call screen',
        (tester) async {
      final repo = MockCallsRepository(connectDelay: Duration.zero);

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(500, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: CallsModuleView(repository: repo),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the redial button on the first tile. Two pumps: dialog opens,
        // then placeCall's zero-delay future lands and 'Join' builds.
        // Tap the redial button on the first tile (addressed by tooltip
        // — the icon is the chalk-drawn handset, not a Material icon).
        await tester.tap(find.byTooltip('Call Kai Meridian').first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Join'), findsOneWidget);

        await tester.tap(find.text('Join'));
        // Fixed pumps (route transition + dialog pop): pumpAndSettle can
        // hang on lingering network-image streams, per project convention.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        // Mock call screen mounted with mute/end controls.
        expect(find.byType(MockCallScreen), findsOneWidget);
        expect(find.text('Mute'), findsOneWidget);
        expect(find.text('End'), findsOneWidget);
      });

      repo.dispose();
    });

    testWidgets('offline redial surfaces the failure instead of joining',
        (tester) async {
      final repo = MockCallsRepository(connectDelay: Duration.zero)
        ..setOnline(false);

      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: CallsModuleView(repository: repo),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Call Kai Meridian').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Join'), findsNothing);
      expect(find.textContaining('No connection'), findsOneWidget);

      repo.dispose();
    });
  });

  group('Settings — theme mode', () {
    testWidgets('theme selector drives the ThemeController', (tester) async {
      final themeController = ThemeController();
      addTearDown(themeController.dispose);

      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: SettingsPage(themeController: themeController),
      ));
      await tester.pump();

      expect(themeController.value, ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(themeController.value, ThemeMode.dark);

      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(themeController.value, ThemeMode.light);
    });
  });

  group('Mobile navigation — bottom bar shell', () {
    testWidgets('narrow: hybrid FAB bar switches module bodies', (tester) async {
      final (feedRepo, db) = _makeFeedRepo();
      final callsRepo = MockCallsRepository();
      di.sl
        ..registerLazySingleton<AppDatabase>(() => db)
        ..registerLazySingleton<FeedRepository>(() => feedRepo)
        ..registerLazySingleton<ThemeController>(() => ThemeController());
      addTearDown(() async {
        callsRepo.dispose();
        await di.sl.reset();
        feedRepo.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(500, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: SquareNavigationShell(callsRepository: callsRepo),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // Square first; then Calls via the hybrid bottom bar (M3
        // BottomAppBar + center-docked compose FAB; Settings lives in the
        // Square app bar on mobile). Extra pump after each switch: the
        // StreamBuilder's first event lands one frame after the body.
        expect(find.byKey(const ValueKey('fab-bottom-bar')), findsOneWidget);
        // Two "New post" tooltips: Square app-bar icon + compose FAB.
        expect(find.byTooltip('New post'), findsNWidgets(2));

        // Settings: gear icon in the Square app bar (no bottom destination).
        // Only reachable while the Square is the active module — its app
        // bar unmounts when another module body shows.
        await tester.tap(find.byTooltip('Settings').first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Theme'), findsOneWidget);

        // Settings is a module body swap (not a pushed route): return by
        // selecting Square on the bar (bar labels are the short forms;
        // scoped because the app bar title reads "The Square"), then
        // move on to the Landline.
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('fab-bottom-bar')),
            matching: find.text('Square'),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Landline'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Kai Meridian'), findsOneWidget);
      });
    });

    testWidgets('wide: rail still routes Calls and trailing settings',
        (tester) async {
      final (feedRepo, db) = _makeFeedRepo();
      final callsRepo = MockCallsRepository();
      di.sl
        ..registerLazySingleton<AppDatabase>(() => db)
        ..registerLazySingleton<FeedRepository>(() => feedRepo)
        ..registerLazySingleton<ThemeController>(() => ThemeController());
      addTearDown(() async {
        callsRepo.dispose();
        await di.sl.reset();
        feedRepo.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: SquareNavigationShell(callsRepository: callsRepo),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(NavigationRail), findsOneWidget);
        // Four rail destinations + trailing settings icon button.
        expect(find.text('The Landline'), findsOneWidget);
        await tester.tap(find.text('The Landline'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Kai Meridian'), findsOneWidget);
      });
    });

    testWidgets('wide: tapping trailing Settings renders the page (no rail '
        'index assertion)', (tester) async {
      // Regression: Settings is module index 4 but not a rail destination.
      // Passing selectedIndex=4 tripped NavigationRail's bounds assertion
      // and painted the whole shell red on desktop.
      final (feedRepo, db) = _makeFeedRepo();
      final callsRepo = MockCallsRepository();
      di.sl
        ..registerLazySingleton<AppDatabase>(() => db)
        ..registerLazySingleton<FeedRepository>(() => feedRepo)
        ..registerLazySingleton<ThemeController>(() => ThemeController());
      addTearDown(() async {
        callsRepo.dispose();
        await di.sl.reset();
        feedRepo.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: SquareNavigationShell(callsRepository: callsRepo),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // The trailing settings IconButton (tooltip), not a destination.
        // A second Settings tooltip exists in the Square app bar (the
        // mobile gear renders there on every width).
        await tester.tap(find.byTooltip('Settings').first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Theme'), findsOneWidget);
        expect(find.byType(NavigationRail), findsOneWidget);
      });
    });
  });
}
