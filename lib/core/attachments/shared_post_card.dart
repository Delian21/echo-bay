import 'package:flutter/material.dart';

import '../../injection.dart';
import '../design_system/sketch_kit.dart';
import '../io/platform_io.dart';
import '../theme/app_theme.dart';
import '../database/app_database.dart' show AppDatabase;

/// A shared Square post rendered as a small polaroid card inside a chat
/// bubble (Vault or Dorm). Tapping opens the post's day view.
///
/// Dependency-rule note: this widget lives in core and reads the post
/// through the [AppDatabase] directly (the same local-first read the
/// Square's repository performs). No feature-to-feature import: the
/// Vault and Hallway render the card without knowing the Square exists.
///
/// Deleted/expired posts render a graceful "faded" placeholder — a
/// shared moment that has been rewound or faded away is remembered,
/// not shown as a broken image.
class SharedPostCard extends StatefulWidget {
  const SharedPostCard({super.key, required this.postId, this.onOpen});

  final String postId;

  /// Opens the post in context. The chat page supplies navigation;
  /// null (tests) makes the card inert.
  final void Function(BuildContext context)? onOpen;

  @override
  State<SharedPostCard> createState() => _SharedPostCardState();
}

class _SharedPostCardState extends State<SharedPostCard> {
  Future<Map<String, Object?>?>? _post;

  @override
  void initState() {
    super.initState();
    _post = _load();
  }

  Future<Map<String, Object?>?> _load() async {
    final db = _resolveDb();
    if (db == null) return null;
    final query = db.select(db.posts)
      ..where((t) => t.id.equals(widget.postId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return <String, Object?>{
      'body': row.body,
      'author_name': row.authorName,
      'media_url': row.mediaUrl,
      'expires_at': row.expiresAt,
    };
  }

  AppDatabase? _resolveDb() {
    try {
      return sl.isRegistered<AppDatabase>() ? sl<AppDatabase>() : null;
    } on Object {
      return null; // tests / DI-less: renders the unavailable state
    }
  }

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, Object?>?>(
      future: _post,
      builder: (context, snap) {
        final row = snap.data;

        // Faded / missing: the post was rewound or its time is up. The
        // card remembers it was something shared — a gentle placeholder,
        // not a broken image.
        if (row == null) {
          return _FadedCard(useInk: useInk, reason: 'This moment was rewound.');
        }
        final expiresAt = row['expires_at'] as DateTime?;
        if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
          return _FadedCard(useInk: useInk, reason: 'It faded with the day.');
        }

        final body = (row['body'] as String?) ?? '';
        final mediaUrl = row['media_url'] as String?;
        final authorName = (row['author_name'] as String?) ?? '';

        final card = Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onOpen == null ? null : () => widget.onOpen!(context),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const SketchIcon(
                          kind: SketchIconKind.photoFrame,
                          size: 13,
                          seed: 41,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          'from the Square',
                          style: useInk
                              ? kHandwrittenTextStyle.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (mediaUrl != null && mediaUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 96,
                          width: double.infinity,
                          child: _isLocal(mediaUrl)
                              ? Image(
                                  image: platformImageProvider(mediaUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const _Dimmed(),
                                )
                              : Image.network(
                                  mediaUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const _Dimmed(),
                                ),
                        ),
                      ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: useInk
                            ? kHandwrittenTextStyle.copyWith(fontSize: 14)
                            : theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

        if (!useInk) return card;
        return SketchBox(
          seed: widget.postId.hashCode & 0x7FFFFFFF,
          radius: 6,
          strokeWidth: 2,
          color: SketchInk.of(context),
          padding: const EdgeInsets.all(2),
          child: card,
        );
      },
    );
  }

  static bool _isLocal(String url) =>
      !url.startsWith('http://') && !url.startsWith('https://');
}

class _Dimmed extends StatelessWidget {
  const _Dimmed();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SketchIcon(
          kind: SketchIconKind.brokenImage,
          size: 22,
          seed: 47,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The shared post is gone (rewound) or faded (ephemeral expiry). A
/// small handwritten note — the memory is acknowledged, not broken.
class _FadedCard extends StatelessWidget {
  const _FadedCard({required this.useInk, required this.reason});

  final bool useInk;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SketchIcon(
            kind: SketchIconKind.rewindSpiral,
            size: 18,
            seed: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: useInk
                  ? kHandwrittenTextStyle.copyWith(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
