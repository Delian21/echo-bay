import 'package:flutter/material.dart';

import '../motion/motion_scope.dart';
import '../theme/app_theme.dart' show kHandwrittenTextStyle;

/// A physical-looking print: cream paper, a photo inset with even borders,
/// a thicker bottom lip carrying a handwritten caption, and a stamped date.
///
/// It knows nothing about feeds or posts — it takes an [ImageProvider], some
/// caption text and a [DateTime], so a share-image builder can hand it the
/// same three things. Sizing is up to the caller ([width] or the incoming
/// constraints); the photo keeps its [aspectRatio] and every state (loading,
/// failed) fills that same box, so the frame never jumps.
class PolaroidFrame extends StatefulWidget {
  const PolaroidFrame({
    super.key,
    required this.image,
    required this.caption,
    required this.date,
    this.width,
    this.aspectRatio = 1.0,
    this.maxCaptionLines = 2,
    this.author,
    this.semanticLabel,
    this.onTap,
    this.onDoubleTap,
    this.seed,
  });

  /// What to print. Any provider works: network, file, memory.
  final ImageProvider image;

  /// The line pencilled under the photo. Empty still reserves the strip.
  final String caption;

  /// The date stamped in the bottom-right corner — `Oct 30`.
  final DateTime date;

  /// Fixed print width; null fills the constraints it is given.
  final double? width;

  /// Photo crop. Square by default; 4/5 gives a slightly taller print.
  final double aspectRatio;

  /// How many pencilled lines fit before the caption ellipsizes. The feed
  /// keeps two; a share card has room for a little more.
  final int maxCaptionLines;

  /// Whose print it is, used only for the screen-reader label.
  final String? author;

  /// Overrides the generated accessibility label entirely.
  final String? semanticLabel;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  /// Stable tilt source (a post id, a message id). Same seed, same angle;
  /// null falls back to the image's own identity.
  final int? seed;

  @override
  State<PolaroidFrame> createState() => _PolaroidFrameState();
}

class _PolaroidFrameState extends State<PolaroidFrame> {
  /// Tap-to-expand: a long caption grows in place instead of ellipsizing.
  bool _expanded = false;

  static const Color _paper = Color(0xFFFBF4E4);
  static const Color _ink = Color(0xFF2B2A26);
  // Soft neutral gray: an unexposed patch of print while the photo loads.
  static const Color _photoWell = Color(0xFFD9D7D2);

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _stamp => '${_months[widget.date.month - 1]} ${widget.date.day}';

  /// Stable ±1° tilt. A physical print never sits perfectly straight.
  double get _angle {
    final seed = widget.seed ?? widget.image.hashCode;
    final step = (seed.abs() % 201) - 100; // -100..100
    return step / 100 * (3.141592653589793 / 180);
  }

  String get _label {
    if (widget.semanticLabel case final custom?) return custom;
    final buffer = StringBuffer('Photo');
    if (widget.author case final author? when author.trim().isNotEmpty) {
      buffer.write(' by ${author.trim()}');
    }
    final caption = widget.caption.trim();
    if (caption.isNotEmpty) buffer.write(': $caption');
    buffer.write('. $_stamp');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final angle = reduced ? 0.0 : _angle;

    final print = Container(
      width: widget.width,
      // Even hairline border on top/left/right; the bottom lip is three
      // times as deep, like a real print waiting for a caption.
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 30),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.38 : 0.12),
            blurRadius: dark ? 14 : 8,
            offset: Offset(0, dark ? 6 : 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: widget.onDoubleTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                // The well is always painted, so the frame holds its size
                // while the image loads or after it fails.
                child: ColoredBox(
                  color: _photoWell,
                  child: Image(
                    image: widget.image,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, wasSync) {
                      if (wasSync) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: child,
                      );
                    },
                    errorBuilder: (context, _, __) => Center(
                      child: Text(
                        "couldn't load",
                        style: kHandwrittenTextStyle.copyWith(
                          fontSize: 14,
                          color: _ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.caption.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _Caption(
              text: widget.caption.trim(),
              maxLines: widget.maxCaptionLines,
              expanded: _expanded,
              // Expansion belongs to the caption only; the photo keeps its
              // own tap target. Short captions are not taps at all.
              onTap: () => setState(() => _expanded = !_expanded),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _stamp,
              style: kHandwrittenTextStyle.copyWith(
                fontSize: 13,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: _label,
      button: widget.onTap != null,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Transform.rotate(angle: angle, child: print),
    );
  }
}

/// The pencilled line under the photo. Two lines ellipsize; only a caption
/// that actually overflows becomes tappable, and tapping grows it in place.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.text,
    required this.maxLines,
    required this.expanded,
    required this.onTap,
  });

  final String text;
  final int maxLines;
  final bool expanded;
  final VoidCallback onTap;

  static final TextStyle _style = kHandwrittenTextStyle.copyWith(
    fontSize: 17,
    height: 1.25,
    color: const Color(0xFF2B2A26),
  );

  @override
  Widget build(BuildContext context) {
    final body = Text(
      text,
      maxLines: expanded ? null : maxLines,
      overflow: expanded ? null : TextOverflow.ellipsis,
      style: _style,
    );
    if (expanded) return body;

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: _style),
          maxLines: maxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        if (!overflows) return body;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: body,
        );
      },
    );
  }
}
