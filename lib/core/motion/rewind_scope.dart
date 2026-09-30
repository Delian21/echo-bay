import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion_scope.dart';
import 'package:echo_bay/core/atmosphere/atmosphere_controller.dart';
import 'package:echo_bay/injection.dart';

/// The signature "rewind" interaction — the app's undo, staged like
/// reversing a moment (inspired by, not copied from, a certain photo
/// game's time power; see docs/ART_DIRECTION.md IP notes).
///
/// Wrap any subtree whose state can be undone. When [RewindScope.of]
/// `.rewind()` is called, the content plays a ~600ms reversal: a
/// horizontal mirror-wobble (the visual signature of time running
/// backwards), a desaturating color wash, and — on supported platforms —
/// a sharp haptic tick at the moment of reversal. State restoration
/// itself stays the caller's job: undo logic runs in the [onRewind]
/// callback, ideally mid-animation.
///
/// Reduced motion ([MotionScope]): the callback fires immediately, no
/// visual effect — undo must never be blocked by accessibility.
///
/// Prototype scope: wired into Square card like/unlike as the first
/// consumer; Vault unsend and post delete adopt it the same way.
class RewindScope extends StatefulWidget {
  const RewindScope({super.key, required this.child});

  final Widget child;

  static _RewindScopeState? _maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_RewindScopeState>();

  /// Plays the rewind effect; [action] (the undo logic) fires at the
  /// visual midpoint so state flips while the world is still rewinding.
  static void rewind(BuildContext context, VoidCallback action) {
    final state = _maybeOf(context);
    if (state == null) {
      action(); // No scope above (tests, bare scaffolds): just undo.
      return;
    }
    state.play(action);
  }

  @override
  State<RewindScope> createState() => _RewindScopeState();
}

class _RewindScopeState extends State<RewindScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  bool _fired = false;

  void play(VoidCallback action) {
    final reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;
    if (reduced) {
      action();
      return;
    }
    // Light haptic tap — opt-in (atmosphere), never a jolt. Fire-and-
    // forget: DI unavailable (tests) just means no tap.
    try {
      if (sl<AtmosphereController>().hapticsEnabled) {
        HapticFeedback.lightImpact();
      }
    } on Object {
      // No atmosphere controller: skip the tap.
    }
    _fired = false;
    _fx.forward(from: 0);
    // Midpoint state flip — the "moment" reverses while the wash is up.
    // Haptic: a light tap, not a jolt (reduce-motion skips it entirely).
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || _fired) return;
      _fired = true;
      action();
      HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fx,
      builder: (context, child) {
        if (_fx.isDismissed) return child!;
        // Two-phase wobble: overshoot backwards, ease back to rest.
        final t = _fx.value;
        final wobble = math.sin(t * math.pi * 2) * (1 - t) * 0.035;
        final scale = 1.0 + math.sin(t * math.pi) * 0.015;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..rotateZ(wobble),
          child: Opacity(
            opacity: 1.0 - math.sin(t * math.pi) * 0.25,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
