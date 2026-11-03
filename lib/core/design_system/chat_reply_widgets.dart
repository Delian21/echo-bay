import 'package:flutter/material.dart';

import '../attachments/attachment.dart';
import 'sketch_kit.dart';

/// One-line preview text for a quoted message.
///
/// Media messages have no body to quote, so they are named instead —
/// calling a photo "" and rendering an empty quote is how reply previews
/// usually break. A caption on a photo still wins over the word "Photo",
/// because that is what the person wrote.
String replyExcerpt(String body, MessageAttachment? attachment) {
  final text = body.trim();
  if (text.isNotEmpty) return text;
  if (attachment == null) return 'Message';
  return switch (attachment.kind) {
    AttachmentKind.photo => 'Photo',
    AttachmentKind.video => 'Video',
    AttachmentKind.voice => 'Voice note',
    AttachmentKind.post => 'Square post',
  };
}

/// The quote block drawn at the top of a bubble that is itself a reply:
/// accent edge, sender, one line of what was said.
class QuotedMessageBlock extends StatelessWidget {
  const QuotedMessageBlock({
    super.key,
    required this.senderName,
    required this.text,
    required this.isMine,
    this.unavailable = false,
    this.onTap,
  });

  final String senderName;
  final String text;

  /// On the accent-filled bubble the quote needs a lighter ink, or it
  /// disappears into the fill.
  final bool isMine;

  /// The original is deleted or not loaded. The block still occupies its
  /// place — a reply with a missing quote reads as broken, a reply that
  /// says so reads as honest.
  final bool unavailable;

  /// Jump to (and flash) the original. Null renders it inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = isMine
        ? scheme.onPrimary.withValues(alpha: 0.9)
        : scheme.onSurfaceVariant;
    final edge = isMine ? scheme.onPrimary : scheme.primary;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        // A tint of the bubble's own foreground, so it works on the cream
        // bubble and on the accent one without a second colour token.
        color: (isMine ? scheme.onPrimary : scheme.onSurface)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: edge, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: edge,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            unavailable ? 'Original message unavailable' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ink,
              fontStyle: unavailable ? FontStyle.italic : null,
            ),
          ),
        ],
      ),
    );

    final labelled = Semantics(
      label: unavailable
          ? 'Replying to $senderName. Original message unavailable.'
          : 'Replying to $senderName: $text',
      button: onTap != null,
      child: content,
    );

    if (onTap == null) return labelled;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: labelled,
      ),
    );
  }
}

/// The slim bar above the composer while a reply is being written: who,
/// one line of what, and a way out.
class ReplyBanner extends StatelessWidget {
  const ReplyBanner({
    super.key,
    required this.senderName,
    required this.text,
    required this.onCancel,
  });

  final String senderName;
  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 44dp touch target, drawn small: the X is a glyph, the tap
          // area is not.
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onCancel,
            icon: const SketchIcon(kind: SketchIconKind.closeX, size: 16),
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ],
      ),
    );
  }
}
