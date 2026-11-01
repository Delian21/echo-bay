import '../settings/app_settings_store.dart';
import 'first_run.dart';

/// Guest mode: someone who wants to look around before signing the cover.
///
/// A guest is a real local profile — display name "Guest", handle "guest",
/// stored in the same settings rows as anyone else — plus one flag in the
/// settings KV table. That flag is the whole feature: it tells the launch
/// gate to skip the landing page on the next open, and tells the Square to
/// show the "sign the cover to keep your pages" banner.
///
/// Nothing about authored content changes. Posts, keepsakes and messages
/// belong to the device's opaque user id, which sign-up leaves alone — so
/// [finish] (called after a successful sign-up) turns the same sketchbook
/// into a signed one without moving a single row.
class GuestMode {
  /// Marker key: `'true'` while this device is browsing as a guest.
  static const key = 'guest_mode_v1';

  /// Set when the guest dismisses the Square banner, so it stops nagging
  /// on the next open. Cleared whenever guest mode starts or ends.
  static const bannerDismissedKey = 'guest_banner_dismissed_v1';

  static Future<bool> isActive(AppSettingsStore store) async =>
      await store.readString(key) == 'true';

  static Future<bool> bannerDismissed(AppSettingsStore store) async =>
      await store.readString(bannerDismissedKey) == 'true';

  static Future<void> dismissBanner(AppSettingsStore store) =>
      store.writeString(bannerDismissedKey, 'true');

  /// Starts guest mode. The intro flow is marked done at the same time:
  /// the landing page already said what the intro says, and a guest who
  /// then signs up must not be walked through it afterwards.
  static Future<void> start(AppSettingsStore store) async {
    await store.writeString(key, 'true');
    await store.deleteKey(bannerDismissedKey);
    await FirstRun.markCompleted(store);
  }

  /// Ends guest mode — called once the cover is signed. The profile keeps
  /// everything it had (the name typed on the cover replaces "Guest"), so
  /// this only drops the flags.
  static Future<void> finish(AppSettingsStore store) async {
    await store.deleteKey(key);
    await store.deleteKey(bannerDismissedKey);
  }
}
