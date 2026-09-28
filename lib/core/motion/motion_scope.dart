import 'package:flutter/material.dart';

import 'motion_controller.dart';

/// Exposes the app's [MotionController] to the motion widgets via the
/// widget tree — set once at the MaterialApp root, consumed anywhere.
class MotionScope extends InheritedNotifier<MotionController> {
  const MotionScope({
    super.key,
    required MotionController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller; asserts when no scope is above (never in production).
  static MotionController of(BuildContext context) =>
      maybeOf(context) ??
      (throw FlutterError('No MotionScope found above ${context.widget}'));

  /// Null-safe lookup — motion widgets degrade to full animation when
  /// no scope is present (bare MaterialApp in tests).
  static MotionController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MotionScope>()
        ?.notifier;
  }
}
