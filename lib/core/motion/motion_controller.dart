import 'package:flutter/material.dart';

/// App-wide motion preference. When [reducedMotion] is true the motion
/// system (staggered cascades, module fade-through, vault pane cross-fade)
/// renders instantly: same tree, zero animation time. The theme cross-fade
/// also collapses to an instant swap.
///
/// A [ChangeNotifier] like [ThemeController] — one boolean, no side
/// effects. Sources: the settings toggle and (later) the platform
/// accessibility flag, wired through the factory seam in injection.dart.
class MotionController extends ChangeNotifier {
  MotionController({
    this.onReducedMotionChanged,
    bool reducedMotion = false,
  })  : _reducedMotion = reducedMotion;

  /// Called after [setReducedMotion] applies a new value. Fire-and-forget
  /// by contract — implementers must not throw synchronously.
  final void Function(bool reduced)? onReducedMotionChanged;

  bool _reducedMotion;
  bool get reducedMotion => _reducedMotion;

  void setReducedMotion(bool reduced) {
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    notifyListeners();
    onReducedMotionChanged?.call(reduced);
  }
}
