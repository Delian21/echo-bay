import 'package:flutter/material.dart';

import '../../../../core/design_system/sketch_kit.dart';
import '../../../../core/theme/app_theme.dart';

import '../../domain/entities/post.dart';

/// Atomic feed card for The Square. Performance contract:
///  - `const` constructor + final fields: identical inputs skip the rebuild
///    entirely when the parent list uses the same element cache;
///  - [RepaintBoundary] isolates rasterization so one card's animation or
///    image decode never forces the whole viewport to repaint;
///  - no animation, no shadow, no blur — hairline border over elevation
///    keeps the raster cache cheap;
///  - text rendered as-is, zero markdown/parsing on the hot path.
///
/// Takes the pure [Post] entity — never a DTO, never a bloc, never a
/// callback-factory. Interactions flow up through the two callbacks.
class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.post,
    required this.onLike,
    this.onOpen,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- header row: author + timestamp -------------------------
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AccentDerivation.of(
                        scheme.primary,
                        scheme.brightness,
                      ).container,
                      child: Text(
                        _initial(post.authorName),
                        style: text.labelSmall!.copyWith(
                          color: AccentDerivation.of(
                            scheme.primary,
                            scheme.brightness,
                          ).onContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                    ),
                    Text(_compactTime(post.createdAt), style: text.bodySmall),
                  ],
                ),

                const SizedBox(height: 10),

                // -- body ----------------------------------------------------
                Text(
                  post.body,
                  style: text.bodyMedium,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),

                // -- media ---------------------------------------------------
                if (post.mediaUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      // Placeholder until the media pipeline lands;
                      // swap for CachedNetworkImage without touching callers.
                      child: ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: SketchIcon(
                          kind: SketchIconKind.brokenImage,
                          size: 22,
                          seed: 27,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // -- actions -------------------------------------------------
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      _LikeButton(liked: post.isLiked, onLike: onLike),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initial(String name) =>
      name.isEmpty ? '?' : name[0].toUpperCase();

  static String _compactTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}.${dt.month}.';
  }
}

/// Like button kept as a separate widget so only the icon/color swap when
/// like state toggles — the whole card does not rebuild.
class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.onLike});

  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onLike,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      icon: Icon(
        liked ? Icons.favorite : Icons.favorite_border,
        size: 20,
        color: liked ? scheme.error : scheme.onSurfaceVariant,
      ),
    );
  }
}
