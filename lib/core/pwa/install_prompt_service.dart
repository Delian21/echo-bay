import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Chrome's non-standard beforeinstallprompt event, not in the standard
/// web IDL — declared here. `prompt()` shows the native install dialog;
/// `userChoice` resolves to the user's answer.
extension type _BeforeInstallPromptEvent._(JSObject _) implements JSObject {
  external JSPromise prompt();
  external JSPromise<_UserChoice> get userChoice;
}

extension type _UserChoice._(JSObject _) implements JSObject {
  external String get outcome;
}

/// Captures Chrome's `beforeinstallprompt` so the app can show the real
/// in-app install dialog (Settings → "Install Echo Bay") instead of
/// relying on the browser menu. Web-only; every call is a no-op elsewhere.
///
/// Chrome only fires the event once, on a PWA that passes installability
/// (manifest with icons + screenshots, HTTPS, a service worker) and when
/// the user hasn't already installed or dismissed it. If the event never
/// arrives the card simply stays hidden.
class InstallPromptService extends ChangeNotifier {
  InstallPromptService._();

  static final InstallPromptService instance = InstallPromptService._();

  /// The deferred prompt event, kept until [promptInstall] or page unload.
  JSObject? _deferred;

  bool _installed = false;

  /// True when a deferred prompt is waiting (or already installed).
  bool get available => _deferred != null || _installed;

  /// True once the app is running as an installed PWA.
  bool get installed =>
      _installed || web.window.matchMedia('(display-mode: standalone)').matches;

  /// Wire the listeners. Call once from main on web.
  void init() {
    web.window.addEventListener(
      'beforeinstallprompt',
      ((web.Event e) {
        e.preventDefault();
        _deferred = e as JSObject;
        notifyListeners();
      }).toJS,
    );
    web.window.addEventListener(
      'appinstalled',
      ((web.Event _) {
        _installed = true;
        _deferred = null;
        notifyListeners();
      }).toJS,
    );
  }

  /// Shows Chrome's native install dialog. Resolves true if the user
  /// accepted (the appinstalled event then confirms).
  Future<bool> promptInstall() async {
    final deferred = _deferred;
    if (deferred == null) return false;
    _deferred = null;
    notifyListeners();
    final event = _BeforeInstallPromptEvent._(deferred);
    await event.prompt().toDart;
    final choice = await event.userChoice.toDart;
    return choice.outcome == 'accepted';
  }
}
