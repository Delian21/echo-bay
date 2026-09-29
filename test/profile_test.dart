import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/profile/profile_controller.dart';
import 'package:echo_bay/core/profile/user_profile.dart';
import 'package:echo_bay/core/settings/app_settings_store.dart';
import 'package:echo_bay/core/theme/app_theme.dart';
import 'package:echo_bay/features/square/data/datasources/square_local_datasource.dart';
import 'package:echo_bay/features/square/data/repositories/mock_feed_repository.dart';

/// Profile: identity + accent persistence and their consumers.
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

  test('profile round trips through the store (name, accent, avatar-clear)',
      () async {
    await store.writeProfile(const UserProfile(
      displayName: 'Kai Meridian',
      accentColor: Color(0xFF6B4A2B),
    ));
    var read = await store.readProfile();
    expect(read.displayName, 'Kai Meridian');
    expect(read.accentColor, const Color(0xFF6B4A2B));

    // Null avatar: the cleared key must stay cleared across sessions.
    await store
        .writeProfile(read.copyWith(avatarPath: '/tmp/avatar.png'));
    read = await store.readProfile();
    expect(read.avatarPath, '/tmp/avatar.png');
    await store.writeProfile(read.copyWith(clearAvatar: true));
    read = await store.readProfile();
    expect(read.avatarPath, isNull);
  });

  test('accent color flows into both theme builders', () {
    const accent = Color(0xFF8E3B46);
    final light = buildLightTheme(accent);
    final dark = buildDarkTheme(accent);
    expect(light.colorScheme.primary, accent);
    expect(dark.colorScheme.primary, accent);
  });

  test('custom accent gets contrast-correct container colors', () {
    // A very light accent: onPrimary must flip to dark to stay readable.
    const pale = Color(0xFFF5D060);
    final lightScheme = buildLightTheme(pale).colorScheme;
    expect(
      AccentDerivation.contrastRatio(
          lightScheme.onPrimary, lightScheme.primary),
      greaterThanOrEqualTo(4.5),
      reason: 'onPrimary must meet WCAG AA on any accent',
    );

    // Same check for a very dark accent.
    const deep = Color(0xFF1A3A6B);
    final deepScheme = buildDarkTheme(deep).colorScheme;
    expect(
      AccentDerivation.contrastRatio(
          deepScheme.onPrimary, deepScheme.primary),
      greaterThanOrEqualTo(4.5),
    );

    // Container/onContainer is a matched pair in both modes.
    for (final scheme in [
      buildLightTheme(pale).colorScheme,
      buildDarkTheme(pale).colorScheme,
      buildLightTheme(deep).colorScheme,
      buildDarkTheme(deep).colorScheme,
    ]) {
      expect(
        AccentDerivation.contrastRatio(
            scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(3.0),
        reason: 'container text must stay readable on any accent',
      );
    }
  });

  test('deriveAccentContainer matches the theme derivation', () {
    const accent = Color(0xFF00897B);
    final scheme = buildLightTheme(accent).colorScheme;
    final d = AccentDerivation.derive(accent, Brightness.light);
    expect(scheme.primaryContainer, d.container);
    expect(scheme.onPrimaryContainer, d.onContainer);
    expect(scheme.onPrimary, d.onPrimary);
  });

  test('ProfileController notifies and persists through the seam', () async {
    final updates = <UserProfile>[];
    final controller = ProfileController(
      onProfileChanged: (p) => updates.add(p),
    );
    addTearDown(controller.dispose);

    controller.update(const UserProfile(displayName: 'Rune'));
    controller.update(const UserProfile(displayName: 'Rune')); // dedupe
    expect(updates.length, 1);
    expect(controller.profile.displayName, 'Rune');
  });

  test('createPost stamps the profile display name on the post', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = MockFeedRepository(
      localDatasource: DriftSquareLocalDatasource(db),
      db: db,
      seedOnStart: false,
      startTicker: false,
    );
    addTearDown(() async {
      await db.close();
    });

    final result = await repo.createPost(
      body: 'hello from my profile',
      authorName: 'Kai Meridian',
    );
    final post = result.fold((f) => throw f, (p) => p);
    expect(post.authorName, 'Kai Meridian');
  });
}
