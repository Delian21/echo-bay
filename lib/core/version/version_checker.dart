import 'dart:async';
import 'dart:convert' as convert;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../settings/app_settings_store.dart';
import 'version_gate_stub.dart'
    if (dart.library.js_interop) 'version_gate_web.dart';

/// The get_it locator is passed in (instead of imported) so tests can
/// construct a checker with no DI at all.
typedef SettingsLookup = AppSettingsStore? Function();

/// Detects a freshly deployed web build and tells the UI to offer a
/// refresh.
///
/// How it knows: Flutter writes `version.json` per build, and the build
/// number stamped by `flutter build web --build-number=…` is the field
/// that changes between deploys ([versionHashOf]). The checker fetches
/// it (cache-busted so the browser can't answer from the immutable HTTP
/// cache) and compares against the last hash this install has seen,
/// remembered in the settings store ([appVersionSeenKey]). First-ever
/// visitors never see the banner — only returning browsers after a
/// redeploy do.
///
/// Checks run: once at boot, when the tab becomes visible again
/// (the most common moment to catch a deploy that happened while the
/// user was away), and every [pollInterval] while the app is open.
/// Web-only: on native there are no redeploys to catch.
class VersionChecker extends ChangeNotifier {
  VersionChecker({
    this.pollInterval = const Duration(minutes: 5),
    SettingsLookup? settingsLookup,
  }) : _settingsLookup = settingsLookup ?? _defaultSettingsLookup;

  final Duration pollInterval;
  final SettingsLookup _settingsLookup;

  Timer? _pollTimer;
  bool _checking = false;
  bool _updateAvailable = false;
  String? _seen;
  bool _seenLoaded = false;

  /// True once a NEW deploy has been detected and the user hasn't
  /// refreshed yet. The UI listens for this to show the banner.
  bool get updateAvailable => _updateAvailable;

  /// User declined the banner: hide it until the NEXT deploy (not on
  /// every subsequent check of this same one). Implemented by treating
  /// the current hash as seen — a future hash re-trips the banner.
  Future<void> dismiss() async {
    _updateAvailable = false;
    notifyListeners();
  }

  /// Starts the boot check and the periodic poll. No-op on native.
  void start() {
    if (!kIsWeb) return;
    unawaited(check());
    _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(check()));
  }

  /// Called when the window/tab becomes visible again.
  void onAppResumed() {
    if (kIsWeb) unawaited(check());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> check() async {
    if (_checking || !kIsWeb) return;
    _checking = true;
    try {
      final body = await fetchVersionJsonBody();
      final hash = body == null ? null : versionHashOf(body);
      if (hash == null) return;

      if (!_seenLoaded) {
        final store = _settingsLookup();
        _seen = store == null ? null : await store.readString(appVersionSeenKey);
        _seenLoaded = true;
      }
      final previous = _seen ?? hash; // first visit: seed, never banner
      if (hash != previous) {
        _updateAvailable = true;
        notifyListeners();
      }
      _seen = hash;
      final store = _settingsLookup();
      await store?.writeString(appVersionSeenKey, hash);
    } on Object {
      // Offline or fetch failed: stay quiet, retry on the next poll.
    } finally {
      _checking = false;
    }
  }

  /// Manual refresh path (the banner's action): drop the old service
  /// worker and its caches, then reload into the fresh build.
  Future<void> applyUpdate() async {
    try {
      clearCachesAndWorkers();
    } on Object {
      // Partial cleanup is fine — the reload below proceeds either way.
    }
    _updateAvailable = false;
    notifyListeners();
    reloadPage();
  }
}

/// The deploy fingerprint [VersionChecker] compares between builds: the
/// pubspec version joined with the build number, which only changes
/// when the build passes `--build-number`. Null when the body is not
/// JSON or carries neither field.
String? versionHashOf(String body) {
  try {
    final map = convert.jsonDecode(body) as Map<String, dynamic>;
    final parts = <String>[
      if (map['version'] != null) map['version'].toString(),
      if (map['build_number'] != null) map['build_number'].toString(),
    ];
    return parts.isEmpty ? null : parts.join('+');
  } on Object {
    return null;
  }
}

/// Settings key holding the last-seen version hash.
const String appVersionSeenKey = 'app_version_seen';

AppSettingsStore? _defaultSettingsLookup() {
  try {
    final sl = GetIt.instance;
    return sl.isRegistered<AppSettingsStore>() ? sl<AppSettingsStore>() : null;
  } on Object {
    return null;
  }
}
