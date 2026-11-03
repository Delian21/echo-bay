import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/motion_scope.dart';
import 'sketch_kit.dart';

/// Swipe-to-reply wrapper for a chat bubble.
///
/// The gesture is horizontal only and confined to the direction that feels
/// like \"pull the message back toward me\": rightwards on a peer's bubble
/// (which sits left), leftwards on my own (which sits right). Vertical
/// drags stay with the list, so scrubbing a conversation never trips this.
///
/// The bubble follows the finger a short, damped distance ([maxDrag]), a
/// reply arrow fades in underneath, and releasing past [triggerDistance]
/// calls [onReply] with a light haptic. Anything less springs back.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.isMine,
    required this.onReply,
    required this.child,
    this.enabled = true,
  });

  /// Whose bubble this is — decides which way the swipe is allowed to go.
  final bool isMine;

  final VoidCallback onReply;
  final Widget child;

  /// False on tombstoned bubbles and during edits: nothing to reply to.
  final bool enabled;

  /// Furthest the bubble travels, logical pixels. Past this the gesture
  /// stops reading as \"replying\" and starts reading as \"dragging\".
  static const double maxDrag = 68;

  /// Release point that commits the reply.
  static const double triggerDistance = 44;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..addListener(() {
      if (!mounted) return;
      setState(() => _offset = _from + (_to - _from) * _settle.value);
    });

  /// Signed travel of the bubble: always in the allowed direction.
  double _offset = 0;
  double _from = 0;
  double _to = 0;

  /// The gesture's allowed sign: +1 for a peer's bubble, -1 for mine.
  double get _direction => widget.isMine ? -1 : 1;

  void _settleTo(double target) {
    _from = _offset;
    _to = target;
    if (_reducedMotion) {
      setState(() => _offset = target);
      _settle.value = 1;
      return;
    }
    _settle.forward(from: 0);
  }

  /// The in-app setting and the OS setting, ORed by [MotionScope]. Absent
  /// scope (bare MaterialApp in tests) means full motion.
  bool get _reducedMotion =>
      MotionScope.maybeOf(context)?.reducedMotion ?? false;

  void _onStart(DragStartDetails _) {
    _settle.stop();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    final delta = details.primaryDelta ?? 0;
    // Only accept motion in the allowed direction; the other way is a
    // no-op rather than an elastic overshoot.
    if (delta.sign != 0 && delta.sign != _direction) return;
    setState(() {
      _offset = (_offset + delta).clamp(0.0, SwipeToReply.maxDrag);
    });
  }

  void _onEnd(DragEndDetails _) {
    if (!widget.enabled) {
      _settleTo(0);
      return;
    }
    if (_offset >= SwipeToReply.triggerDistance) {
      // Acknowledge before the bubble springs back: the tap has to feel
      // like it landed. Haptics are absent on web and simply do nothing.
      unawaited(HapticFeedback.lightImpact());
      widget.onReply();
    }
    _settleTo(0);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_offset / SwipeToReply.triggerDistance).clamp(0.0, 1.0);
    final armed = progress >= 1;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      // The arrow lives behind the bubble, at the edge the bubble moves
      // away from — so it is revealed by the drag itself.
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: widget.isMine
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Opacity(
                opacity: progress,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.isMine ? 0 : 8,
                    right: widget.isMine ? 8 : 0,
                  ),
                  child: Semantics(
                    label: armed ? 'Release to reply' : 'Reply',
                    child: SketchIcon(
                      kind: SketchIconKind.arrowBack,
                      size: 18 + 4 * progress,
                      color: theme.colorScheme.primary,
                      seed: 31,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_offset * _direction, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
