import 'package:flutter/material.dart';

import '../motion/motion_scope.dart';

/// Timing for the staggered entrance cascade.
const kStaggerItemDuration = Duration(milliseconds: 320);
const kStaggerCurve = Curves.easeOutCubic;

/// Staggered entrance for list/feed items: fades in and slides up on the
/// item's first build, offset by [index] so cards cascade down the screen.
///
/// Test-safe by design: the per-item delay is an [Interval] on a single
/// animation (forwarded immediately on first build), not a
/// `Future.delayed` timer, so flutter_test's pending-timer invariant is
/// never tripped. Plays once per State lifetime — rebuilds (stream
/// re-emits, likes, focus changes) do not re-run it.
///
/// Perf contract: the [CurvedAnimation] and slide tween are allocated
/// once in [initState], not per build — rebuilds during the entrance
/// (common with stream-driven lists) reuse the same animation objects,
/// and after the entrance completes the transitions evaluate to
/// constants that RepaintBoundary-cached children never repaint.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    required this.index,
    this.maxStaggerSteps = 8,
    this.baseDelay = const Duration(milliseconds: 40),
  });

  final Widget child;

  /// Position in the list — drives the cascade offset. Items beyond
  /// [maxStaggerSteps] all start at the same (maximum) delay so long lists
  /// do not make the tail wait forever; late scroll-ins still get the
  /// slide-up, just sooner.
  final int index;

  final int maxStaggerSteps;

  /// Delay added per index step.
  final Duration baseDelay;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Animation<Offset> _slide;

  /// Cascade step, clamped so tail items share the max delay.
  late final int _step = widget.index.clamp(0, widget.maxStaggerSteps - 1);

  /// Reduced motion: skip the cascade entirely — items render fully
  /// visible on the first frame (the controller jumps to completion).
  /// Resolved in [didChangeDependencies], not [initState]: inherited
  /// widgets are not readable until after the first dependency pass.
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );

    // Interval shifts the animation's start inside [0..1] instead of using
    // a wall-clock timer — frame-driven, deterministic, test-safe.
    final delayedStart =
        _step * widget.baseDelay.inMilliseconds / _totalDuration.inMilliseconds;
    final end = delayedStart +
        kStaggerItemDuration.inMilliseconds / _totalDuration.inMilliseconds;

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayedStart, end.clamp(0.0, 1.0), curve: kStaggerCurve),
    );
    _slide = _animation.drive(
      Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;
    if (_reduced) {
      _controller.value = 1; // instantly settled, no animation time
    } else if (_controller.value == 0) {
      // First dependency pass under full motion: start the cascade.
      // didChangeDependencies can fire again later (scope change); the
      // value check keeps a completed/running entrance from restarting.
      _controller.forward();
    }
  }

  Duration get _totalDuration =>
      kStaggerItemDuration + widget.baseDelay * _step;

  @override
  void didUpdateWidget(StaggeredEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stagger is a first-build effect: if the list reorders and this
    // element is reused for a different index, the animation has already
    // played — never replay it (jarring) or restart mid-entrance.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
