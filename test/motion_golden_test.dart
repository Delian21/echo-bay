import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/design_system/staggered_entrance.dart';
import 'package:superapp/core/theme/app_theme.dart';
import 'package:superapp/core/theme/theme_controller.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';
import 'package:superapp/features/square/domain/repositories/feed_repository.dart';
import 'package:superapp/features/square/ui/square_navigation_shell.dart';
import 'package:superapp/injection.dart' as di;
import 'package:superapp/main.dart';

/// Golden harness for the motion system.
///
/// Locks the *shape* of each animation's first and end frames so a styling
/// regression (opacity curve change, slide distance, theme lerp drift) is
/// caught visually, not just behaviorally.
///
/// Regenerate after an intentional motion change:
///   flutter test test/motion_golden_test.dart --update-goldens
void main() {
  setUp(() async {
    // Minimal DI for SuperApp's shell boot (mirrors theme_transition_test).
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final local = DriftSquareLocalDatasource(db);
    di.sl
      ..registerLazySingleton<AppDatabase>(() => db)
      ..registerLazySingleton<ThemeController>(() => ThemeController())
      ..registerLazySingleton<SquareLocalDatasource>(() => local)
      ..registerLazySingleton<FeedRepository>(
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
  });

  Future<void> pumpFixed(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: child),
    ));
  }

  testWidgets('staggered entrance: first frame (items hidden)', (tester) async {
    await pumpFixed(
      tester,
      ListView(
        children: [
          for (var i = 0; i < 4; i++)
            StaggeredEntrance(
              index: i,
              child: Container(
                height: 120,
                margin: const EdgeInsets.all(8),
                color: Colors.blueGrey,
                alignment: Alignment.center,
                child: Text('item $i'),
              ),
            ),
        ],
      ),
    );
    await tester.pump(); // first build: controller at 0, all items hidden
    await expectLater(
      find.byType(ListView),
      matchesGoldenFile('goldens/stagger_start.png'),
    );
  });

  testWidgets('staggered entrance: mid-cascade frame', (tester) async {
    await pumpFixed(
      tester,
      ListView(
        children: [
          for (var i = 0; i < 4; i++)
            StaggeredEntrance(
              index: i,
              child: Container(
                height: 120,
                margin: const EdgeInsets.all(8),
                color: Colors.blueGrey,
                alignment: Alignment.center,
                child: Text('item $i'),
              ),
            ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    await expectLater(
      find.byType(ListView),
      matchesGoldenFile('goldens/stagger_mid.png'),
    );
  });

  testWidgets('staggered entrance: settled frame (all items visible)',
      (tester) async {
    await pumpFixed(
      tester,
      ListView(
        children: [
          for (var i = 0; i < 4; i++)
            StaggeredEntrance(
              index: i,
              child: Container(
                height: 120,
                margin: const EdgeInsets.all(8),
                color: Colors.blueGrey,
                alignment: Alignment.center,
                child: Text('item $i'),
              ),
            ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byType(ListView),
      matchesGoldenFile('goldens/stagger_end.png'),
    );
  });

  testWidgets('theme cross-fade: mid-lerp frame is a blend, not a hard cut',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const SuperApp());
      await tester.pump();

      di.sl<ThemeController>().setMode(ThemeMode.dark);
      // Pump to the exact midpoint of the 350ms cross-fade.
      await tester.pump(const Duration(milliseconds: 175));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/theme_lerp_mid.png'),
      );
    });
  });

  testWidgets('module fade-through: mid-transition frame', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(
        home: SquareNavigationShell(),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Switch Square -> Calls and catch the incoming body mid fade-through.
      await tester.tap(find.text('The Landline'));
      await tester.pump(const Duration(milliseconds: 120));
      await expectLater(
        find.byType(SquareNavigationShell),
        matchesGoldenFile('goldens/module_fade_through_mid.png'),
      );
    });
  });
}
