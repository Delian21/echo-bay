import 'package:flutter/material.dart';

/// App-wide motion preference. When [reducedMotion] is true the motion
/// system (staggered cascades, module fade-through, vault pane cross-fade)
/// renders instantly: same tree, zero animation time. The theme cross-fade
/// also collapses to an instant swap.
///
/// A [ChangeNotifier] like [ThemeController] — one boolean, no side
/// effects. Sources: the in-app settings toggle AND the system
/// reduce-motion accessibility setting — the effective value is their
/// OR (the app must honor the OS even if the in-app toggle is off).
/// [syncSystemReducedMotion] is called by the app root whenever the
/// MediaQuery changes.
class MotionController extends ChangeNotifier {
  MotionController({
    this.onReducedMotionChanged,
    bool reducedMotion = false,
  })  : _userReducedMotion = reducedMotion,
        _systemReducedMotion = false;

  /// Called after [setReducedMotion] applies a new value. Fire-and-forget
  /// by contract — implementers must not throw synchronously.
  final void Function(bool reduced)? onReducedMotionChanged;

  bool _userReducedMotion;
  bool _systemReducedMotion;

  /// Effective preference: the user asked OR the OS asked.
  bool get reducedMotion => _userReducedMotion || _systemReducedMotion;

  /// The in-app toggle's own value (what settings displays).
  bool get userReducedMotion => _userReducedMotion;

  void setReducedMotion(bool reduced) {
    if (reduced == _userReducedMotion) return;
    _userReducedMotion = reduced;
    notifyListeners();
    onReducedMotionChanged?.call(reduced);
  }

  /// Pushes the system accessibility flag (MediaQuery.disableAnimations)
  /// into the effective value. Called on every metrics change; no-op when
  /// unchanged so the tree doesn't rebuild spuriously.
  void syncSystemReducedMotion(bool systemReduced) {
    if (systemReduced == _systemReducedMotion) return;
    _systemReducedMotion = systemReduced;
    notifyListeners();
  }
}
