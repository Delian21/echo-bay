import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion_scope.dart';
import '../theme/app_theme.dart';
import 'sketch_kit.dart';

/// Hand-drawn pull-to-refresh: the sketch kit's open loop winds with your
/// finger, snaps to the trigger line, and laps once while the refresh runs.
///
/// Material's `RefreshIndicator` has no hook for a custom glyph — its arc
/// and arrowhead are baked in — so this owns the overscroll gesture itself,
/// folding the two ways Flutter reports a pull (a clamped top edge reports
/// `OverscrollNotification`, a bouncing one moves `pixels`) into one value.
/// Reduced motion keeps every state and the announcement, dropping only the
/// movement.
class SketchRefreshIndicator extends StatefulWidget {
  const SketchRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.triggerDistance = 72,
    this.pullHint = 'Pull to refresh',
    this.armedHint = 'Let go',
    this.busyHint = 'Refreshing…',
    this.semanticsLabel = 'Refresh feed',
  });

  /// Runs the refresh; the indicator stays up until it completes.
  final Future<void> Function() onRefresh;

  /// The scrollable the gesture is watched on.
  final Widget child;

  /// Pull distance that arms the refresh, in logical pixels.
  final double triggerDistance;

  final String pullHint;
  final String armedHint;
  final String busyHint;

  /// Screen-reader name for the control. Reachable without dragging, which
  /// matters: a gesture-only refresh is otherwise invisible to a reader.
  final String semanticsLabel;

  @override
  State<SketchRefreshIndicator> createState() => _SketchRefreshIndicatorState();
}

class _SketchRefreshIndicatorState extends State<SketchRefreshIndicator>
    with TickerProviderStateMixin {
  /// Normalised pull: 0 hidden, 1 at the trigger, up to 1.6 over-pulled.
  /// Driven directly while the finger is down (the `value` setter stops any
  /// running settle animation) and animated on release.
  late final AnimationController _settle =
      AnimationController(vsync: this, value: 0);

  /// One lap per 900ms while the refresh runs.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// True between the drag that started the gesture and its release.
  bool _dragging = false;
  bool _refreshing = false;

  /// Last value seen during build — read from the gesture handler, where
  /// depending on the inherited widget would not rebuild us anyway.
  bool _reduced = false;

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  @override
  void dispose() {
    _settle.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// The list is at its top edge (the only place a pull means anything).
  bool _atTop(ScrollNotification n) =>
      n.metrics.axisDirection == AxisDirection.down &&
      n.metrics.extentBefore == 0.0;

  bool _onScroll(ScrollNotification n) {
    if (_refreshing) return false;

    if (!_dragging) {
      // Only a real finger starts this — ballistic settling and
      // ScrollController jumps carry no dragDetails and must never arm it.
      if (n is ScrollStartNotification &&
          n.dragDetails != null &&
          n.depth == 0 &&
          _atTop(n)) {
        _dragging = true;
        _settle
          ..stop()
          ..value = 0;
      }
      return false;
    }

    if (n.depth != 0) return false;

    // The user scrolled or rebounded away from the top: the gesture is over.
    if (n.metrics.axisDirection != AxisDirection.down ||
        n.metrics.extentBefore > 0) {
      _cancel();
      return false;
    }

    switch (n) {
      case ScrollUpdateNotification():
        if (n.scrollDelta != null) {
          _settle.value = _clamp(
            _settle.value - n.scrollDelta! / widget.triggerDistance,
            0,
            1.6,
          );
        }
      case OverscrollNotification():
        _settle.value = _clamp(
          _settle.value - n.overscroll / widget.triggerDistance,
          0,
          1.6,
        );
      case ScrollEndNotification():
        _dragging = false;
        _release();
      default:
        break;
    }
    return false;
  }

  void _cancel() {
    if (!_dragging) return;
    _dragging = false;
    _settle.animateTo(
      0,
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _release() async {
    if (_settle.value >= 1.0) {
      await _startRefresh();
      return;
    }
    await _settle.animateTo(
      0,
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _startRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final reduced = _reduced;
    await _settle.animateTo(
      1.0,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    if (!reduced) _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spin
          ..stop()
          ..value = 0;
      }
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    await _settle.animateTo(
      0,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() {});
  }

  /// The semantics path: no drag available, so show the indicator at rest
  /// and run the same refresh.
  Future<void> _fromSemantics() async {
    if (_refreshing || _dragging) return;
    _settle.value = 1.0;
    await _startRefresh();
  }

  Widget _overlay(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = _settle.value;
    final progress = _clamp(v, 0, 1);
    final overPull = _clamp(v - 1, 0, 0.6);
    final armed = v >= 1.0;
    final tint =
        (armed || _refreshing) ? scheme.primary : SketchInk.of(context);
    final hint = _refreshing
        ? widget.busyHint
        : (armed ? widget.armedHint : widget.pullHint);

    return DecoratedBox(
      // A strip of the page's own paper, fading in as you pull, so the
      // glyph never sits on top of feed text half-drawn.
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92 * progress),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.triggerDistance,
            child: Center(
              child: Transform.scale(
                scale: 1 + 0.12 * overPull,
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (context, child) {
                    // Winding follows the finger; the lap is autonomous
                    // motion, so reduced motion holds it still.
                    final angle = _refreshing
                        ? (_reduced ? 0.0 : _spin.value * 2 * math.pi)
                        : (_reduced ? 0.0 : progress * math.pi * 1.5);
                    return Transform.rotate(
                      angle: angle,
                      child: child,
                    );
                  },
                  child: SketchIcon(
                    kind: SketchIconKind.refreshLoop,
                    size: 30,
                    color: tint,
                    seed: 5,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: _clamp((progress - 0.15) / 0.35, 0, 1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                hint,
                style: kHandwrittenTextStyle.copyWith(
                  fontSize: 16,
                  color: tint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AnimatedBuilder(
        // Both controllers repaint the overlay: the settle animations and
        // the spin never call setState, and their listeners are what drive
        // the frame.
        animation: Listenable.merge([_settle, _spin]),
        builder: (context, _) {
          final show = _refreshing || _settle.value > 0.001;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: widget.triggerDistance + 40,
                // Semantics outside, IgnorePointer inside — the other way
                // round makes IgnorePointer mark its subtree
                // `isBlockingUserActions` and the tap action silently dies.
                child: Semantics(
                  container: true,
                  button: true,
                  liveRegion: _refreshing,
                  // One label, ours — the hint text below is decoration.
                  excludeSemantics: true,
                  label: _refreshing ? widget.busyHint : widget.semanticsLabel,
                  onTap: _refreshing ? null : _fromSemantics,
                  // Never intercepts the drag it is listening for.
                  child: IgnorePointer(
                    child: show ? _overlay(context) : const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
