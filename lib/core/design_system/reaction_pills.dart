import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'message_reactions.dart';

/// The pill that carries a message's reactions, sitting on the bubble's
/// bottom corner the way a sticker would.
///
/// The bubble itself keeps its own shape: pills are drawn in a [Stack]
/// above it ([BubbleWithReactions]) so a reaction never re-flows the text
/// or changes the bubble's width.
class ReactionPills extends StatelessWidget {
  const ReactionPills({
    super.key,
    required this.pills,
    required this.onPillTap,
  });

  final List<ReactionPillData> pills;

  /// Receives the stored reaction id.
  final ValueChanged<String> onPillTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (final pill in pills)
          _ReactionPill(
            pill: pill,
            onTap: () => onPillTap(pill.reaction),
          ),
      ],
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.pill, required this.onTap});

  final ReactionPillData pill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: '${reactionLabel(pill.reaction)} reaction, '
          '${pill.count == 1 ? '1 person' : '${pill.count} people'}'
          '${pill.mine ? ', including you' : ''}. Tap to toggle.',
      button: true,
      child: ConstrainedBox(
        // 44dp of touch area around a pill that draws at half that: the
        // tap target rule is about fingers, not about how chunky the
        // artwork looks.
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: Material(
            color: pill.mine
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            elevation: 1,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: pill.mine
                        ? scheme.primary
                        : context.borderPlain,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reactionEmoji(pill.reaction),
                      style: const TextStyle(fontSize: 13, height: 1.2),
                    ),
                    if (pill.count > 1) ...[
                      const SizedBox(width: 3),
                      Text(
                        '${pill.count}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pill.mine
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bubble + overlapping pills.
///
/// Reserves 10dp below the bubble whenever pills exist so the pills
/// overlap the bubble without being clipped by the list viewport or
/// colliding with the next message.
class BubbleWithReactions extends StatelessWidget {
  const BubbleWithReactions({
    super.key,
    required this.bubble,
    required this.pills,
    required this.isMine,
    required this.onPillTap,
  });

  final Widget bubble;
  final List<ReactionPillData> pills;
  final bool isMine;
  final ValueChanged<String> onPillTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: pills.isEmpty ? 0 : 16),
          child: bubble,
        ),
        if (pills.isNotEmpty)
          Positioned(
            // Overlaps the bubble's bottom edge, on the sender's side.
            bottom: -10,
            right: isMine ? 6 : null,
            left: isMine ? null : 6,
            child: ReactionPills(pills: pills, onPillTap: onPillTap),
          ),
      ],
    );
  }
}
