import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'message_reactions.dart';
import 'sketch_kit.dart';

/// Secondary actions a long-press can offer. Kept as an enum (not a
/// string) so adding "Forward" or "Copy" later is a compile-checked
/// change at every call site instead of a silent no-op.
enum MessageMenuAction { reply, edit, pin, delete }

/// What the menu handed back: either a reaction was chosen, or one of the
/// [MessageMenuAction]s.
class MessageMenuResult {
  const MessageMenuResult.reaction(String this.reaction) : action = null;
  const MessageMenuResult.action(MessageMenuAction this.action)
      : reaction = null;

  /// Stored reaction id (see [kMessageReactions]).
  final String? reaction;

  final MessageMenuAction? action;
}

/// Long-press menu: the five reactions, then the actions that apply to
/// this message. Floats above the conversation rather than covering it
/// with a full sheet, because reacting is a glance-and-tap act.
Future<MessageMenuResult?> showMessageMenu(
  BuildContext context, {
  bool canReply = true,
  bool canEdit = false,
  bool canPin = false,
  bool canDelete = false,
}) {
  return showGeneralDialog<MessageMenuResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Message actions',
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: const Duration(milliseconds: 130),
    pageBuilder: (dialogContext, _, __) => SafeArea(
      child: Align(
        alignment: const Alignment(0, 0.55),
        child: _MessageMenuCard(
          canReply: canReply,
          canEdit: canEdit,
          canPin: canPin,
          canDelete: canDelete,
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
        child: child,
      ),
    ),
  );
}

class _MessageMenuCard extends StatelessWidget {
  const _MessageMenuCard({
    required this.canReply,
    required this.canEdit,
    required this.canPin,
    required this.canDelete,
  });

  final bool canReply;
  final bool canEdit;
  final bool canPin;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderPlain),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (final choice in kMessageReactions)
                    Semantics(
                      label: 'React with ${choice.label}',
                      button: true,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: InkResponse(
                          radius: 22,
                          onTap: () => Navigator.of(context)
                              .pop(MessageMenuResult.reaction(choice.id)),
                          child: Center(
                            child: Text(
                              choice.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: context.borderPlain),
            if (canReply)
              _MenuRow(
                icon: const SketchIcon(
                  kind: SketchIconKind.arrowBack,
                  size: 18,
                ),
                label: 'Reply',
                onTap: () => Navigator.of(context)
                    .pop(const MessageMenuResult.action(MessageMenuAction.reply)),
              ),
            if (canEdit)
              _MenuRow(
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: 'Edit message',
                onTap: () => Navigator.of(context)
                    .pop(const MessageMenuResult.action(MessageMenuAction.edit)),
              ),
            if (canPin)
              _MenuRow(
                icon: const Icon(Icons.push_pin_outlined, size: 20),
                label: 'Pin to keepsake wall',
                onTap: () => Navigator.of(context)
                    .pop(const MessageMenuResult.action(MessageMenuAction.pin)),
              ),
            if (canDelete)
              _MenuRow(
                icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                label: 'Delete for everyone',
                labelColor: scheme.error,
                onTap: () => Navigator.of(context).pop(
                    const MessageMenuResult.action(MessageMenuAction.delete)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        // 44dp minimum, same rule as every other tap target here.
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
