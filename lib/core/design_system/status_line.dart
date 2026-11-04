import 'dart:async';

import 'package:flutter/material.dart';

import '../motion/motion_scope.dart';
import '../profile/status.dart';
import '../theme/app_theme.dart';

/// A status line: one handwritten sentence in a small paper-tag shape.
///
/// Rendering is driven by [expiresAt], not by a stored flag:
///
/// * each build asks [statusIsActive] whether the line is still up at the
///   current moment, so a stale line never renders;
/// * a one-shot [Timer] is armed for the exact remaining lifetime so a
///   status that lapses while the screen is open disappears on time.
///   Nothing runs in the background; the timer only exists while a
///   visible status is on screen.
///
/// When there is no active status the widget renders [placeholder] if one
/// is given (the local profile's invitation to write one) and otherwise
/// nothing at all — no empty space.
///
/// The gesture surface is the whole tag plus a 44px-minimum box when
/// [onTap] is set, per the app's touch-target rule.
class StatusLine extends StatefulWidget {
  const StatusLine({
    super.key,
    this.text,
    this.expiresAt,
    this.placeholder,
    this.onTap,
    this.maxLines = 2,
    this.alignment = Alignment.center,
    this.clock,
  });

  /// The status text as stored. Null/blank = no status.
  final String? text;

  /// When [text] stops showing. Null = never fades.
  final DateTime? expiresAt;

  /// Shown, muted, when there is no active status. Null renders nothing.
  final String? placeholder;

  /// When set, the whole line is a button (profile: opens the editor).
  final VoidCallback? onTap;

  final int maxLines;
  final Alignment alignment;

  /// Test seam: where "now" comes from. Production leaves this null and
  /// the wall clock is read per build; tests inject a movable clock so an
  /// expiry can be observed without waiting real hours.
  final DateTime Function()? clock;

  @override
  State<StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<StatusLine> {
  Timer? _expiry;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _armExpiry();
  }

  @override
  void didUpdateWidget(StatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt ||
        oldWidget.text != widget.text) {
      _armExpiry();
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  /// Wake exactly when the status lapses. A rebuild then re-evaluates the
  /// clock and drops the line. Long fades (3 days) simply hold one timer.
  void _armExpiry() {
    _expiry?.cancel();
    final expiresAt = widget.expiresAt;
    if (expiresAt == null) return;
    final remaining = expiresAt.difference(_now());
    if (remaining <= Duration.zero) return;
    _expiry = Timer(remaining, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final active = statusIsActive(widget.text, widget.expiresAt, now);
    final placeholder = widget.placeholder;
    if (!active && placeholder == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final faded = !active;
    final text = faded ? placeholder! : widget.text!.trim();

    final tag = Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 5),
      decoration: BoxDecoration(
        // Very quiet fill: enough to read as paper, not a button.
        color: scheme.surfaceContainerHighest
            .withValues(alpha: faded ? 0.28 : 0.55),
        border: Border.all(color: context.borderPlain),
        // A tag, not a chat bubble: square bottom-left "nib", rounded rest.
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
          bottomLeft: Radius.circular(3),
        ),
      ),
      child: Text(
        text,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: widget.onTap == null ? TextAlign.start : TextAlign.center,
        style: kHandwrittenTextStyle.copyWith(
          fontSize: 16,
          height: 1.2,
          color: faded
              ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
              : scheme.onSurfaceVariant,
        ),
      ),
    );

    // Motion: a status appearing gets a short fade; reduced motion (in-app
    // toggle or the OS setting) renders it instantly.
    final reduced = MotionScope.maybeOf(context)?.reducedMotion ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;
    Widget shown = tag;
    if (active && !reduced) {
      shown = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: tag,
      );
    }

    final aligned = Align(alignment: widget.alignment, child: shown);
    final onTap = widget.onTap;
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: aligned,
      );
    }

    return Semantics(
      button: true,
      label: active ? 'Your status: $text' : 'Set a status',
      hint: active ? 'Double tap to edit or clear' : 'Double tap to write one',
      excludeSemantics: true,
      child: Tooltip(
        message: active ? 'Tap to edit your status' : 'Set a status',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(child: aligned),
            ),
          ),
        ),
      ),
    );
  }
}
