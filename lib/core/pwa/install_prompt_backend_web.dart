/// Web install-prompt backend. Selected by the conditional import in
/// install_prompt_service.dart, so `dart:js_interop` and `package:web`
/// are only ever compiled into the web build.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The platform seam [InstallPromptService] talks to.
abstract class InstallPromptBackend {
  /// Whether a deferred prompt is waiting (or the app is installed).
  bool get available;

  /// Whether the app is already running as an installed PWA.
  bool get installed;

  /// Wires the browser listeners, notifying [onChanged] on every flip.
  void bind({required void Function() onChanged});

  /// Shows Chrome's native install dialog.
  Future<bool> promptInstall();
}

/// Builds the backend for the current platform.
InstallPromptBackend createInstallPromptBackend() =>
    _WebInstallPromptBackend();

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

class _WebInstallPromptBackend implements InstallPromptBackend {
  /// The deferred event, kept until [promptInstall] or page unload.
  JSObject? _deferred;
  bool _installed = false;
  void Function()? _onChanged;

  @override
  bool get available => _deferred != null || _installed;

  @override
  bool get installed =>
      _installed ||
      web.window.matchMedia('(display-mode: standalone)').matches;

  @override
  void bind({required void Function() onChanged}) {
    _onChanged = onChanged;
    web.window.addEventListener(
      'beforeinstallprompt',
      ((web.Event e) {
        e.preventDefault();
        _deferred = e as JSObject;
        _onChanged?.call();
      }).toJS,
    );
    web.window.addEventListener(
      'appinstalled',
      ((web.Event _) {
        _installed = true;
        _deferred = null;
        _onChanged?.call();
      }).toJS,
    );
  }

  @override
  Future<bool> promptInstall() async {
    final deferred = _deferred;
    if (deferred == null) return false;
    _deferred = null;
    _onChanged?.call();
    final event = _BeforeInstallPromptEvent._(deferred);
    await event.prompt().toDart;
    final choice = await event.userChoice.toDart;
    return choice.outcome == 'accepted';
  }
}
