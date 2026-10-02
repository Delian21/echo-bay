/// Non-web install-prompt backend: installing to the home screen is a
/// browser affordance, so every native build links this stub. It is what
/// keeps `package:web` out of mobile and desktop compiles.
library;

/// The platform seam [InstallPromptService] talks to. The web build
/// supplies a real implementation; everywhere else this no-op stands in.
abstract class InstallPromptBackend {
  /// Whether a native install dialog can currently be shown.
  bool get available;

  /// Whether the app is already running as an installed PWA.
  bool get installed;

  /// Wires the browser listeners, notifying [onChanged] when the state
  /// flips. No-op here.
  void bind({required void Function() onChanged});

  /// Shows the native install dialog. Always false off the web.
  Future<bool> promptInstall();
}

/// Builds the backend for the current platform.
InstallPromptBackend createInstallPromptBackend() =>
    _StubInstallPromptBackend();

class _StubInstallPromptBackend implements InstallPromptBackend {
  @override
  bool get available => false;

  @override
  bool get installed => false;

  @override
  void bind({required void Function() onChanged}) {}

  @override
  Future<bool> promptInstall() async => false;
}
