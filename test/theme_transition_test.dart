import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/theme/theme_controller.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';
import 'package:superapp/features/square/domain/repositories/feed_repository.dart';
import 'package:superapp/features/square/ui/square_navigation_shell.dart';
import 'package:superapp/injection.dart' as di;
import 'package:superapp/main.dart';

/// Animated theme cross-fade: the lerp must run without throwing.
///
/// Regression for a bug the widget suite could not see: lerping
/// light <-> dark ThemeData with a generic Tween<ThemeData> throws
/// "Cannot lerp between ThemeData..." on every frame once the themes
/// carry different extension maps (AppThemeExtension). The fix is
/// ThemeDataTween; these tests lock that in by actually running the
/// transition frames.
void main() {
  setUp(() async {
    // Minimal DI for SuperApp's shell boot (main.dart's fallbacks cover
    // ThemeController); the shell reads sl<FeedRepository>() on mount.
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

  testWidgets('theme change cross-fades through mid-lerp frames without error',
      (tester) async {
    // SuperApp consumes the DI-registered controller — the same instance
    // its AnimatedBuilder listens to.
    final controller = di.sl<ThemeController>();

    await tester.pumpWidget(const SuperApp());
    await tester.pump();

    ThemeData appTheme() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;

    // ignore: avoid_print
    print('start: ${appTheme().brightness}');
    // Force a mid-lerp frame: switch to dark and pump only part of the
    // 350ms transition, so ThemeDataTween.evaluate runs between endpoints.
    controller.setMode(ThemeMode.dark);
    await tester.pump(const Duration(milliseconds: 100));
    // ignore: avoid_print
    print('dark+100ms: ${appTheme().brightness}');
    expect(tester.takeException(), isNull);

    // Finish the transition, then flip back mid-flight (rapid toggle path).
    await tester.pump(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('dark+400ms: ${appTheme().brightness}');
    controller.setMode(ThemeMode.light);
    await tester.pump(const Duration(milliseconds: 150));
    // ignore: avoid_print
    print('light+150ms: ${appTheme().brightness}');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 250));
    // ignore: avoid_print
    print('light+400ms: ${appTheme().brightness}');
    expect(tester.takeException(), isNull);

    // The resolved final theme is the light one.
    expect(appTheme().brightness, Brightness.light);
  });

  testWidgets('SuperApp boots SquareNavigationShell as home', (tester) async {
    // Boots the real shell with the minimal DI from setUp; catches wiring
    // regressions like a bad home widget or missing theme.
    await mockNetworkImagesFor(() async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const SuperApp());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SquareNavigationShell), findsOneWidget);
    });
  });
}
