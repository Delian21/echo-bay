import 'package:flutter/material.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/io/platform_io.dart';
import '../../../core/theme/app_theme.dart';
import '../../../injection.dart';
import 'keepsake_stamp.dart';
import '../../square/ui/square_feed_view.dart' show SquareDayViewPage;
import '../../vault/ui/vault_chat_page.dart';
import '../../vault/domain/repositories/chat_repository.dart';
import '../../square/domain/repositories/feed_repository.dart';

/// The body of a keepsake card that references a Square post OR a Vault
/// message (both pin into the same id slot). Resolves the reference at
/// render time and renders the matching mini-card:
///  - post     → polaroid thumbnail (photo or first words)
///  - message  → quote card with the sender + text
///  - gone     → graceful "faded" note (rewound/deleted/purged)
///
/// Tapping opens the item in context (post day view / conversation).
class PinnedReferenceCard extends StatefulWidget {
  const PinnedReferenceCard({
    super.key,
    required this.referenceId,
    required this.pinnedAt,
  });

  final String referenceId;

  /// When this reference was pinned — the stamp's fallback, used when
  /// the moment it points at can no longer be resolved.
  final DateTime pinnedAt;

  @override
  State<PinnedReferenceCard> createState() => _PinnedReferenceCardState();
}

class _PinnedReferenceCardState extends State<PinnedReferenceCard> {
  Future<_Reference?>? _ref;

  @override
  void initState() {
    super.initState();
    _ref = _resolve();
  }

  Future<_Reference?> _resolve() async {
    // Post first (the common case), then message.
    try {
      if (sl.isRegistered<FeedRepository>()) {
        final either = await sl<FeedRepository>().findPostById(
          widget.referenceId,
        );
        final post = either.fold((_) => null, (p) => p);
        if (post != null) {
          return _Reference(
            isPost: true,
            title: post.authorName,
            body: post.body,
            mediaUrl: post.mediaUrl,
            expired: post.expiresAt?.isBefore(DateTime.now()) ?? false,
            deleted: post.deletedAt != null,
            momentAt: post.createdAt,
          );
        }
      }
      if (sl.isRegistered<ChatRepository>()) {
        final message = await sl<ChatRepository>().findMessage(
          widget.referenceId,
        );
        if (message != null && !message.isDeleted) {
          return _Reference(
            isPost: false,
            title: 'a Vault message',
            body: message.body,
            mediaUrl: null,
            expired: false,
            deleted: false,
            momentAt: message.createdAt,
          );
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Reference?>(
      future: _ref,
      builder: (context, snap) {
        final ref = snap.data;
        if (ref == null) {
          return _FadedPin(at: widget.pinnedAt);
        }
        if (ref.deleted || ref.expired) {
          return _FadedPin(
            reason: ref.deleted ? 'This moment was rewound.' : 'It faded.',
            // The moment's own date is unknowable once it is gone — the
            // card dates itself to when it went up on the wall instead.
            at: widget.pinnedAt,
          );
        }
        return _LivePin(reference: ref, referenceId: widget.referenceId);
      },
    );
  }
}

class _Reference {
  const _Reference({
    required this.isPost,
    required this.title,
    required this.body,
    required this.mediaUrl,
    required this.expired,
    required this.deleted,
    required this.momentAt,
  });

  final bool isPost;
  final String title;
  final String body;
  final String? mediaUrl;
  final bool expired;
  final bool deleted;

  /// When the moment itself happened — what the card stamps, as
  /// distinct from when it was pinned to the wall.
  final DateTime momentAt;
}

class _LivePin extends StatelessWidget {
  const _LivePin({required this.reference, required this.referenceId});

  final _Reference reference;
  final String referenceId;

  Future<void> _open(BuildContext context) async {
    if (reference.isPost) {
      final repo = sl<FeedRepository>();
      final either = await repo.findPostById(referenceId);
      final post = either.fold((_) => null, (p) => p);
      if (!context.mounted) return;
      final day = post?.createdAt ?? DateTime.now();
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SquareDayViewPage(repository: repo, day: day),
      ));
      return;
    }
    // Message: open the conversation it lives in.
    final repo = sl<ChatRepository>();
    final message = await repo.findMessage(referenceId);
    if (message == null || !context.mounted) return;
    final conversation = await repo.findConversation(message.conversationId);
    if (conversation == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VaultChatPage(
        repository: repo,
        conversation: conversation,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _open(context),
      // Stack, not a footer: the body clips to three lines, so the date
      // is an overlay pinned to the corner and can never reflow it.
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reference.mediaUrl != null &&
                  reference.mediaUrl!.isNotEmpty)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: double.infinity,
                      child: _isLocal(reference.mediaUrl!)
                          ? Image(
                              image:
                                  platformImageProvider(reference.mediaUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _PinFallbackIcon(),
                            )
                          : Image.network(
                              reference.mediaUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _PinFallbackIcon(),
                            ),
                    ),
                  ),
                )
              else
                const _PinFallbackIcon(),
              const SizedBox(height: 6),
              Text(
                reference.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The card is always cream paper (theme-independent), so its
                // ink is pinned to charcoal — theme colors go chalk in dark
                // mode and vanish on the paper.
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: SketchInk.charcoal,
                ),
              ),
              if (reference.body.isNotEmpty)
                Text(
                  reference.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: kHandwrittenTextStyle.copyWith(
                    fontSize: 13,
                    color: SketchInk.charcoal,
                  ),
                ),
            ],
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: KeepsakeStamp(at: reference.momentAt),
          ),
        ],
      ),
    );
  }

  static bool _isLocal(String url) =>
      !url.startsWith('http://') && !url.startsWith('https://');
}

class _PinFallbackIcon extends StatelessWidget {
  const _PinFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SketchIcon(
        kind: SketchIconKind.photoFrame,
        size: 34,
        seed: 67,
        // Cream card, chalk glyph in dark mode = invisible (see _LivePin).
        color: SketchInk.charcoal,
      ),
    );
  }
}

/// The pinned reference no longer resolves (rewound, deleted, expired,
/// or purged). A small handwritten note in the card's place.
class _FadedPin extends StatelessWidget {
  const _FadedPin({
    required this.at,
    this.reason = 'This moment was rewound.',
  });

  /// The date to stamp: the pin time, since the moment itself is gone.
  final DateTime at;

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SketchIcon(
            kind: SketchIconKind.rewindSpiral,
            size: 22,
            seed: 13,
            color: SketchInk.charcoal,
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: SketchInk.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          // The moment's own date died with it — this card dates itself
          // to when it was pinned instead.
          KeepsakeStamp(at: at),
        ],
      ),
    );
  }
}
