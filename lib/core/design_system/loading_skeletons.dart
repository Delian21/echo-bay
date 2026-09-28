import 'package:flutter/material.dart';

import '../motion/motion_scope.dart';

/// Shared loading skeletons — shape-matched placeholders that pulse
/// gently while a stream's first frame is in flight, replacing the old
/// centered spinners. A skeleton previews the layout it stands in for,
/// so content "arrives" instead of "appears" (no layout jump).
///
/// All skeletons respect [MotionScope] reduced motion: the pulse is
/// disabled and the blocks render at rest opacity.
///
/// Building blocks:
///  - [SkeletonBox] — one pulsing rounded block.
///  - [FeedSkeleton] — Square feed card placeholders.
///  - [TileListSkeleton] — Vault/Calls/Nexus tile placeholders.
///  - [ChatSkeleton] — alternating message-bubble placeholders.

/// One rounded, softly pulsing block. The single primitive every
/// skeleton below is composed from.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  /// Null width = fill available space (inside Row/Column children).
  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;
    if (reduced) {
      if (_pulse.isAnimating) _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Square feed: N card-shaped skeletons (avatar row, two text lines,
/// tall media block) inside the feed's capped column.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.cards = 3, this.maxWidth = 640});

  final int cards;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (var i = 0; i < cards; i++)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _FeedCardSkeleton(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedCardSkeleton extends StatelessWidget {
  const _FeedCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 40, height: 40, radius: 20),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 120, height: 12),
                  SizedBox(height: 6),
                  SkeletonBox(width: 64, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 14),
          SkeletonBox(width: double.infinity, height: 12),
          SizedBox(height: 8),
          SkeletonBox(width: 220, height: 12),
          SizedBox(height: 14),
          // Media block mirrors the card's ~4:3 media area.
          SkeletonBox(
            width: double.infinity,
            height: 200,
            radius: 14,
          ),
        ],
      ),
    );
  }
}

/// Tile lists (Vault conversations, Calls recents, Nexus channels and
/// groups): avatar circle + title/subtitle lines, per row.
class TileListSkeleton extends StatelessWidget {
  const TileListSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                const SkeletonBox(width: 48, height: 48, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160.0 + 40 * (i % 3), height: 13),
                      const SizedBox(height: 8),
                      const SkeletonBox(width: 200, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Chat panes (Vault chat, Nexus group chat): alternating left/right
/// bubble blocks of varied width, bottom-anchored like the real list.
class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key, this.bubbles = 6});

  final int bubbles;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      children: [
        for (var i = 0; i < bubbles; i++)
          Align(
            alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
            child: SkeletonBox(
              width: 120.0 + 60 * (i % 3),
              height: 36,
              radius: 18,
            ),
          ),
      ],
    );
  }
}
