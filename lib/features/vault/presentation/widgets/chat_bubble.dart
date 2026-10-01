import 'package:flutter/material.dart';

import '../../../../core/auth/local_identity.dart';
import '../../../../core/design_system/sketch_kit.dart';

import '../../../../core/design_system/status_tick.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/message.dart';

/// Mapping from the data-layer sync status to the presentation enum.
/// Kept here, in presentation, so the domain never imports UI vocabulary.
ChatStatus chatStatusFrom(Message m) => switch (m.status) {
      DeliveryStatus.pending => ChatStatus.pending,
      DeliveryStatus.sent => ChatStatus.sent,
      DeliveryStatus.delivered => ChatStatus.delivered,
      DeliveryStatus.read => ChatStatus.read,
      DeliveryStatus.failed => ChatStatus.failed,
    };

/// Encrypted chat bubble for The Vault.
///
/// Performance contract mirrors [FeedCard]:
///  - `const` constructor, all fields final, no implicit animations;
///  - [RepaintBoundary] per bubble so scrolling never repaints the whole
///    conversation view;
///  - layout is a simple Row/Column — no slivers, no intrinsics;
///  - status tick is its own widget so a delivered→read change rebuilds
///    only the 16px icon, not the bubble text.
///
/// Trust affordance: the `encrypted` flag renders the lock glyph. When the
/// real E2EE lands in `vault/security/`, the bubble does not change — the
/// flag is computed upstream where ciphertext presence is known.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.encrypted = true,
  });

  final Message message;
  final bool encrypted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isMine = LocalIdentity.owns(message.senderId);

    final bubbleColor = isMine
        ? scheme.primary.withValues(alpha: 0.16)
        : scheme.surfaceContainerHighest;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.widthOf(context) * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.senderId, // peer display name once contacts exist
                style: text.labelSmall!.copyWith(
                  color: scheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            message.body,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (encrypted) ...[
                SketchIcon(
                  kind: SketchIconKind.padlock,
                  size: 11,
                  color: AppThemeExtension.of(context).encrypted,
                  seed: 71,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                _hhmm(message.createdAt),
                style: text.labelSmall,
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                StatusTick(status: chatStatusFrom(message)),
              ],
            ],
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: isMine ? 48 : 4,
            right: isMine ? 4 : 48,
            top: 2,
            bottom: 2,
          ),
          child: bubble,
        ),
      ),
    );
  }

  static String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
