import 'package:flutter/material.dart';

/// App-wide theme mode state. A [ValueNotifier] rather than a bloc on
/// purpose: it is one enum with no side effects, and MaterialApp consumes
/// it directly.
///
/// Persistence seam: [onModeChanged] is invoked with every [setMode] call.
/// The composition root (injection.dart) wires it to the drift-backed
/// store; the controller itself stays storage-agnostic and test-friendly.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController({this.onModeChanged, ThemeMode initialValue = ThemeMode.system})
      : super(initialValue);

  /// Called after [setMode] applies the new value. Fire-and-forget by
  /// contract — implementers must not throw synchronously.
  final void Function(ThemeMode mode)? onModeChanged;

  void setMode(ThemeMode mode) {
    value = mode;
    onModeChanged?.call(mode);
  }
}
