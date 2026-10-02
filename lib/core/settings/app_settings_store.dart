import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../profile/user_profile.dart';

/// Durable app preferences on top of the [Settings] key-value table.
/// Keyed constants live here so no feature code hardcodes store keys.
class AppSettingsStore {
  AppSettingsStore(this._db);

  final AppDatabase _db;

  static const _themeModeKey = 'theme_mode';
  static const _reducedMotionKey = 'reduced_motion';
  static const _atmosphereSoundsKey = 'atmosphere_sounds';
  static const _atmosphereHapticsKey = 'atmosphere_haptics';
  static const _profileNameKey = 'profile_name';
  static const _profileHandleKey = 'profile_handle';
  static const _profileBioKey = 'profile_bio';
  static const _profileAvatarKey = 'profile_avatar';
  static const _profileAccentKey = 'profile_accent';

  /// Recent search queries, stored as a JSON array (search page).
  static const searchRecentsKey = 'search_recents';

  /// Reads the persisted theme mode; null when never set (or an unknown
  /// value — stale installs keep working instead of crashing).
  Future<ThemeMode?> readThemeMode() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(_themeModeKey)))
        .getSingleOrNull();
    if (row == null) return null;
    return ThemeMode.values.asNameMap()[row.value];
  }

  /// Best-effort write — a failed preference save must never crash the
  /// app (the in-memory value still works for the session).
  Future<void> writeThemeMode(ThemeMode mode) async {
    await _write(_themeModeKey, mode.name);
  }

  /// Reads the reduced-motion preference; null when never set.
  Future<bool?> readReducedMotion() async {
    final row = await _read(_reducedMotionKey);
    if (row == null) return null;
    return row == 'true';
  }

  Future<void> writeReducedMotion(bool reduced) async {
    await _write(_reducedMotionKey, reduced.toString());
  }

  /// Atmosphere sounds opt-in; null when never set (default is off).
  Future<bool?> readAtmosphereSounds() async {
    final row = await _read(_atmosphereSoundsKey);
    if (row == null) return null;
    return row == 'true';
  }

  Future<void> writeAtmosphereSounds(bool enabled) async {
    await _write(_atmosphereSoundsKey, enabled.toString());
  }

  /// Rewind haptic opt-in; null when never set (default is off).
  Future<bool?> readAtmosphereHaptics() async {
    final row = await _read(_atmosphereHapticsKey);
    if (row == null) return null;
    return row == 'true';
  }

  Future<void> writeAtmosphereHaptics(bool enabled) async {
    await _write(_atmosphereHapticsKey, enabled.toString());
  }

  // -- profile ----------------------------------------------------------------

  /// Reads the stored profile; null fields mean "never set" and fall back
  /// to [UserProfile]'s defaults at the controller layer.
  Future<UserProfile> readProfile() async {
    final name = await _read(_profileNameKey);
    final handle = await _read(_profileHandleKey);
    final bio = await _read(_profileBioKey);
    final avatar = await _read(_profileAvatarKey);
    final accent = await _read(_profileAccentKey);
    Color? accentColor;
    if (accent != null) {
      final parsed = int.tryParse(accent.replaceFirst('#', ''), radix: 16);
      if (parsed != null) accentColor = Color(parsed | 0xFF000000);
    }
    return UserProfile(
      displayName: name ?? 'You',
      handle: (handle == null || handle.isEmpty) ? 'you' : handle,
      bio: (bio == null || bio.isEmpty) ? null : bio,
      avatarPath: avatar,
      accentColor: accentColor ?? const UserProfile().accentColor,
    );
  }

  Future<void> writeProfile(UserProfile profile) async {
    await _write(_profileNameKey, profile.displayName);
    await _write(_profileHandleKey, profile.handle);
    // Null bio removes the key so a cleared line stays cleared.
    if (profile.bio == null || profile.bio!.isEmpty) {
      try {
        await (_db.delete(_db.settings)
              ..where((s) => s.key.equals(_profileBioKey)))
            .go();
      } on Object {
        // Advisory persistence; ignore.
      }
    } else {
      await _write(_profileBioKey, profile.bio!);
    }
    // Null avatar removes the key so a cleared picture stays cleared.
    if (profile.avatarPath == null) {
      try {
        await (_db.delete(_db.settings)
              ..where((s) => s.key.equals(_profileAvatarKey)))
            .go();
      } on Object {
        // Advisory persistence; ignore.
      }
    } else {
      await _write(_profileAvatarKey, profile.avatarPath!);
    }
    await _write(
        _profileAccentKey,
        '#${profile.accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}');
  }

  /// Generic typed KV reads/writes for feature keys (search recents).
  /// Same advisory-failure posture as the rest of the store.
  Future<String?> readString(String key) => _read(key);

  Future<void> writeString(String key, String value) => _write(key, value);

  Future<void> deleteKey(String key) async {
    try {
      await (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();
    } on Object {
      // Advisory; ignore.
    }
  }

  Future<String?> _read(String key) async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) async {
    try {
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(key: key, value: value),
          );
    } on Object {
      // Preference persistence is advisory; ignore write failures.
    }
  }
}
