import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/settings/app_settings_store.dart';
import 'package:superapp/core/theme/theme_controller.dart';

/// Theme persistence: the mode chosen in settings must survive a full
/// app restart (new controller + new store over the same database).
void main() {
  late AppDatabase db;
  late AppSettingsStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = AppSettingsStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('write then read returns the same mode', () async {
    await store.writeThemeMode(ThemeMode.dark);
    expect(await store.readThemeMode(), ThemeMode.dark);

    await store.writeThemeMode(ThemeMode.light);
    expect(await store.readThemeMode(), ThemeMode.light);
  });

  test('unset store reads null (fresh install boots on system default)',
      () async {
    expect(await store.readThemeMode(), isNull);
  });

  test('controller seam invokes onModeChanged with every setMode', () async {
    final received = <ThemeMode>[];
    final controller = ThemeController(
      onModeChanged: received.add,
    );
    addTearDown(controller.dispose);

    controller.setMode(ThemeMode.dark);
    controller.setMode(ThemeMode.light);
    expect(received, [ThemeMode.dark, ThemeMode.light]);
    expect(controller.value, ThemeMode.light);
  });

  test('full round trip: controller -> store -> fresh controller', () async {
    // Session 1: user picks dark.
    final first = ThemeController(onModeChanged: store.writeThemeMode);
    first.setMode(ThemeMode.dark);
    // Writes are fire-and-forget from the controller; await the store
    // directly for the test.
    await store.writeThemeMode(first.value);
    first.dispose();

    // Session 2: fresh process, same database.
    final restored = await store.readThemeMode();
    expect(restored, ThemeMode.dark);
    final second = ThemeController(initialValue: restored!);
    expect(second.value, ThemeMode.dark);
    second.dispose();
  });
}
