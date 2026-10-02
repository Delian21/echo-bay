import 'package:flutter/foundation.dart';

import 'install_prompt_backend_stub.dart'
    if (dart.library.js_interop) 'install_prompt_backend_web.dart';

/// Captures Chrome's `beforeinstallprompt` so the app can show the real
/// in-app install dialog (Settings → "Install Echo Bay") instead of
/// relying on the browser menu.
///
/// Chrome only fires the event once, on a PWA that passes installability
/// (manifest with icons + screenshots, HTTPS, a service worker) and when
/// the user hasn't already installed or dismissed it. If the event never
/// arrives the card simply stays hidden.
///
/// The browser-facing half lives behind a conditional import (see
/// install_prompt_backend_web.dart); native builds link a no-op stub, so
/// `package:web` — a web-only dependency — never enters a mobile or
/// desktop compile.
class InstallPromptService extends ChangeNotifier {
  InstallPromptService._();

  static final InstallPromptService instance = InstallPromptService._();

  late final InstallPromptBackend _backend = createInstallPromptBackend();

  bool _initialized = false;

  /// True when a native install dialog can be shown (or the app is
  /// already installed).
  bool get available => _backend.available || installed;

  /// True once the app is running as an installed PWA.
  bool get installed => _backend.installed;

  /// Wire the listeners. Call once from main on web; a no-op elsewhere.
  void init() {
    if (_initialized) return;
    _initialized = true;
    _backend.bind(onChanged: notifyListeners);
  }

  /// Shows the browser's native install dialog. Resolves true if the
  /// user accepted (the appinstalled event then confirms).
  Future<bool> promptInstall() => _backend.promptInstall();
}
