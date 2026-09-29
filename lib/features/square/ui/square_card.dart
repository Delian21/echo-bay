import 'dart:math' as math;

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:blurhash_dart/blurhash_extensions.dart';
import 'package:flutter/material.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/io/platform_io.dart';
import '../../../core/motion/motion_scope.dart';
import '../../../core/motion/rewind_scope.dart';
import '../../../core/theme/app_theme.dart';
import 'square_post_model.dart';

/// The Square — feed card. Extracted from the feed view so both the mock
/// slice and the repository-backed feed render identically. Carries the
/// dark-mode polish: story-ring avatar, gradient media scrim, hashtag and
/// mention highlighting, like-pop animation.
///
/// Golden Hour analog layer (docs/ART_DIRECTION.md): media renders in a
/// polaroid frame with a slight per-card rotation, and the loading shimmer
/// is replaced by a "developing" reveal — the image fades in overexposed
/// (bright + low contrast) and settles, like a print coming up.
/// Disable via [GoldenHourExtension.enabled] = false (falls back to the
/// stock flat card).
class SquareFeedCard extends StatelessWidget {
  const SquareFeedCard({
    super.key,
    required this.post,
    required this.onLike,
    this.onComment,
    this.onShare,
    this.onDelete,
    this.onKeep,
  });

  final SquarePost post;
  final VoidCallback onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  /// Delete own post; null hides the affordance. Played through the
  /// rewind effect — removing a post is the purest "undo a moment".
  final VoidCallback? onDelete;

  /// "Keep it": converts an ephemeral post to permanent; null hides
  /// the affordance (only the author's own ephemeral posts offer it).
  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    final deletable = onDelete != null;
    final body = Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.6),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(post: post),
              if (post.hasMedia)
                _CardMedia(
                  mediaUrl: post.mediaUrl!,
                  blurhash: post.blurhash,
                  onLike: onLike,
                  isLiked: post.isLiked,
                ),
              _CardFooter(
                post: post,
                onLike: onLike,
                onComment: onComment,
                onShare: onShare,
                onKeep: onKeep,
              ),
            ],
          ),
        ),
      ),
    );

    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: RewindScope(child: body),
    );

    if (deletable) {
      // Own post: long-press offers "rewind this moment" — the delete
      // rides the signature rewind effect instead of a bare snackbar.
      content = GestureDetector(
        onLongPress: () => _confirmRewindPost(context),
        child: content,
      );
    }

    if (!golden.enabled) {
      return content;
    }

    // Ephemeral posts fade like a print left in the sun: full ink for
    // the first half of their life, then the polaroid washes out toward
    // expiry (floor of 0.2 — a ghost, not an invisible post; the row
    // vanishes entirely once the clock passes the expiry, query-side).
    final fade = post.fadeFactor();
    final opacity = post.expiresAt == null
        ? 1.0
        : (0.2 + 2.0 * fade).clamp(0.2, 1.0);

    // Golden Hour: the card body rides inside a polaroid — warm paper
    // frame, thicker bottom lip, soft print shadow, and a slight
    // per-card tilt. Live-tuned after first render: tilt halved (≤0.6°)
    // so the column reads as a tidy stack of prints, shadow lighter and
    // tighter (a print on a desk, not a poster on a wall).
    final tilt =
        ((post.id.hashCode % 100) / 100 - 0.5) * 2 * _maxTiltRadians;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Transform.rotate(
        angle: tilt,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: golden.polaroidShadow.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SketchBox(
            seed: post.id.hashCode & 0x7FFFFFFF,
            radius: 6,
            strokeWidth: 2,
            color: SketchInk.of(context),
            fill: golden.polaroidPaper,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
            child: Opacity(
              opacity: opacity,
              child: RewindScope(
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Long-press confirmation for deleting own post. Frame it in the
  /// app's voice: rewinding a moment, not "deleting content".
  Future<void> _confirmRewindPost(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rewind this moment?'),
        content: const Text(
          'Your post leaves the Square as if it never happened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rewind'),
          ),
        ],
      ),
    );
    // The card itself never unmounts across the dialog gap (the feed
    // keeps its slot), but the guard keeps the analyzer honest.
    if (confirmed == true && context.mounted) {
      RewindScope.rewind(context, onDelete!);
    }
  }

  static const _maxTiltRadians = 0.6 * math.pi / 180;
}

// -- header -------------------------------------------------------------------

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.post});

  final SquarePost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          _StoryRingAvatar(url: post.userAvatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              post.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            post.timeAgo,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Avatar with the "unread story" ring — redrawn as pencil shading in
/// the sketch language: a hand-drawn graphite ring (wobbly, uneven,
/// double-passed, slight tilt) instead of the Instagram gradient. When
/// the analog layer is off, the original gradient ring renders.
class _StoryRingAvatar extends StatelessWidget {
  const _StoryRingAvatar({required this.url});

  final String url;

  static const _ringGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFFFEDA75), // warm gold
      Color(0xFFFA7E1E), // orange
      Color(0xFFD62976), // magenta
      Color(0xFF962FBF), // violet
    ],
  );

  @override
  Widget build(BuildContext context) {
    const gapPadding = EdgeInsets.all(2); // gap between ring and image
    final gapDecoration = BoxDecoration(
      shape: BoxShape.circle,
      color: Theme.of(context).colorScheme.surface,
    );

    if (GoldenHourExtension.of(context).enabled) {
      // Pencil-shaded ring: the painter draws the graphite ring in the
      // outer margin of the box; the avatar sits centered inside.
      return CustomPaint(
        painter: const _PencilStoryRingPainter(seed: 79),
        child: Container(
          margin: const EdgeInsets.all(3.5),
          padding: gapPadding,
          decoration: gapDecoration,
          child: _SafeAvatar(url: url),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2.5), // ring thickness
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: _ringGradient,
      ),
      child: Container(
        padding: gapPadding,
        decoration: gapDecoration,
        child: _SafeAvatar(url: url),
      ),
    );
  }
}

/// The pencil-shaded story ring: two wobbly graphite loops with a
/// hatched shading pass on the lower-left arc — the ring a 4B pencil
/// leaves on paper, not a gradient. Deterministic per seed.
class _PencilStoryRingPainter extends CustomPainter {
  const _PencilStoryRingPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = SketchRng(seed);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2.5;

    // Two overdrawn loops: graphite pressure varies along the stroke.
    for (var pass = 0; pass < 2; pass++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pass == 0 ? 2.0 : 1.1
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3B3835)
            .withValues(alpha: pass == 0 ? 0.75 : 0.30);

      final path = Path();
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final a = (2 * math.pi * i) / steps - math.pi / 2;
        final rr = radius +
            (rng.next() - 0.5) * 1.6 +
            0.7 * math.sin(a * 2 + seed * 0.13); // slow breathing oval
        final ox = (rng.next() - 0.5) * 0.8;
        final p = Offset(
          center.dx + rr * math.cos(a) + ox,
          center.dy + rr * math.sin(a) + (pass - 0.5) * 0.9,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    // Shading hatch on the lower-left arc — where the pencil rested.
    final shade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF3B3835).withValues(alpha: 0.28);
    for (var i = 0; i < 10; i++) {
      final a = math.pi * 0.55 + (math.pi * 0.5) * (i / 10);
      final r1 = radius + 0.5 + (rng.next() - 0.5);
      final r2 = radius + 3.4 + (rng.next() - 0.5);
      canvas.drawLine(
        Offset(center.dx + r1 * math.cos(a), center.dy + r1 * math.sin(a)),
        Offset(center.dx + r2 * math.cos(a), center.dy + r2 * math.sin(a)),
        shade,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PencilStoryRingPainter old) =>
      old.seed != seed;
}

class _SafeAvatar extends StatelessWidget {
  const _SafeAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final useInk = GoldenHourExtension.of(context).enabled;
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipPath(
        // Ink mode: clip to a hand-drawn circle — a compass-perfect oval
        // reads synthetic against everything else on the page.
        clipper: useInk ? const WobblyCircleClipper(seed: 79) : null,
        child: Image.network(
          url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
          errorBuilder: (_, __, ___) => SketchIcon(
            kind: SketchIconKind.personGlyph,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            seed: 73,
          ),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// -- media + double-tap heart ---------------------------------------------------

/// Local file paths (composer attachments) vs remote URLs (mock
/// transport). Heuristic: a Windows drive prefix or POSIX root is a file.
bool _isLocalPath(String url) {
  final lower = url.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return false;
  }
  return url.startsWith('/') ||
      RegExp(r'^[a-z]:[\\/]').hasMatch(lower);
}

/// Video extension check for the badge — attachment or future remote
/// media both land here.
bool _isVideoPath(String url) {
  final dot = url.lastIndexOf('.');
  if (dot < 0) return false;
  const videoExts = {'.mp4', '.mov', '.webm', '.avi', '.mkv', '.m4v'};
  return videoExts.contains(url.substring(dot).toLowerCase());
}

/// Locally-attached media tile: photo from disk, or a video poster tile
/// (play badge over a dim gradient) — playback needs video_player, which
/// is not in the dependency set yet; the badge communicates the type
/// instead of a broken image.
class _LocalMediaTile extends StatelessWidget {
  const _LocalMediaTile({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (_isVideoPath(path)) {
      final scheme = Theme.of(context).colorScheme;
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.smart_display_outlined,
                size: 56, color: scheme.onSurfaceVariant),
            // Play affordance centered on the poster.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0x99000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  size: 40, color: Colors.white),
            ),
          ],
        ),
      );
    }
    return Image(
      image: platformImageProvider(path),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => const _MediaUnavailableStatic(),
    );
  }
}

class _MediaUnavailableStatic extends StatelessWidget {
  const _MediaUnavailableStatic();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
    );
  }
}

class _CardMedia extends StatefulWidget {
  const _CardMedia({
    required this.mediaUrl,
    required this.onLike,
    required this.isLiked,
    this.blurhash,
  });

  final String mediaUrl;
  final VoidCallback onLike;

  /// Current like state, read when the double-tap burst plays: a like
  /// double-tap inks the burst heart scribble-filled in red.
  final bool isLiked;

  /// Blurhash placeholder: decoded synchronously and painted behind the
  /// network image while it loads (or while offline) — the media slot
  /// never shows an empty gray block when a hash exists.
  final String? blurhash;

  @override
  State<_CardMedia> createState() => _CardMediaState();
}

class _CardMediaState extends State<_CardMedia> with TickerProviderStateMixin {
  late final AnimationController _burst;
  late final AnimationController _shimmer;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  /// Incremented on retry so the Image gets a fresh provider key —
  /// without this, a failed stream would never re-attempt the download.
  int _imageAttempt = 0;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _develop = AnimationController(
      vsync: this,
      // Live-tuned: 900ms read as sluggish on the feed; 550ms keeps the
      // developing feel without delaying the photo.
      duration: const Duration(milliseconds: 550),
    );
    final curve = CurvedAnimation(parent: _burst, curve: Curves.easeOutBack);
    _scale = Tween(begin: 0.0, end: 1.0).animate(curve);
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _burst,
        curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
      ),
    );
    // "Developing" curve: starts overexposed and settles to natural —
    // fast rise out of the wash, long tail as the print fixes.
    _developCurve = CurvedAnimation(parent: _develop, curve: Curves.easeOutCubic);
  }

  late final AnimationController _develop;
  late final Animation<double> _developCurve;

  void _handleDoubleTap() {
    _burst
      ..reset()
      ..forward();
    widget.onLike();
  }

  void _retryImage() {
    setState(() => _imageAttempt++);
  }

  @override
  void dispose() {
    _burst.dispose();
    _shimmer.dispose();
    _develop.dispose();
    super.dispose();
  }

  /// Guards the one-shot develop animation: it plays when the image's
  /// first real frame arrives, never on subsequent rebuilds (like taps,
  /// focus changes would otherwise replay the wash).
  bool _developStarted = false;

  void _startDevelopOnce() {
    if (_developStarted) return;
    _developStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _develop.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    final reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;
    final developing = golden.enabled && !reduced;
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Blurhash underlay: painted whenever a hash exists, visible
            // while the image loads and permanently when offline (the
            // error state keeps it instead of the gray fallback).
            if (widget.blurhash != null)
              Positioned.fill(
                child: _BlurhashPlaceholder(hash: widget.blurhash!),
              ),
            Positioned.fill(
              // Local paths (composer-attached files) render from disk;
              // everything else is the mock transport's remote URLs. A
              // path with a drive/root separator is a local file on every
              // platform this project targets.
              child: _isLocalPath(widget.mediaUrl)
                  ? _LocalMediaTile(path: widget.mediaUrl)
                  : Image.network(
                      key: ValueKey(
                          'media-$_imageAttempt-${widget.mediaUrl}'),
                      widget.mediaUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      frameBuilder: (context, child, frame, wasSync) {
                        if (wasSync) return child;
                        if (!developing) {
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 250),
                            child: child,
                          );
                        }
                        // Golden Hour "developing print": the first
                        // frame of the image rides the develop animation
                        // — overexposed wash that fixes into the photo.
                        if (frame != null) _startDevelopOnce();
                        return AnimatedBuilder(
                          animation: _developCurve,
                          builder: (context, currentChild) {
                            final t = _developCurve.value;
                            // Cross-fade from the blurhash underlay to
                            // the photo while it "develops".
                            return Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: currentChild,
                            );
                          },
                          child: child,
                        );
                      },
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return widget.blurhash != null
                            ? const SizedBox.expand() // hash shows through
                            : _MediaShimmer(shimmer: _shimmer);
                      },
                      errorBuilder: (_, __, ___) => widget.blurhash != null
                          // Offline with a hash: keep the placeholder visible.
                          ? const SizedBox.expand()
                          : _MediaUnavailable(
                              shimmer: _shimmer,
                              onRetry: _retryImage,
                            ),
                    ),
            ),
            // Bottom gradient scrim: keeps overlaid text legible on bright
            // media and grounds the card in dark mode.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    stops: [0.0, 0.35],
                    colors: [
                      Color(0x66000000), // 40% black at the bottom edge
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
            // "Developing" overexposure wash: a warm white that starts
            // nearly opaque (the print just out of the chemistry) and
            // fades away as the image fixes. Only during the develop
            // window; invisible (and non-animating) at reduced motion.
            if (developing)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _developCurve,
                    builder: (context, _) {
                      final t = _developCurve.value;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(
                                const Color(0xF2FAF3E4),
                                const Color(0x00FAF3E4),
                                t,
                              )!,
                              Color.lerp(
                                const Color(0xE6FAF3E4),
                                const Color(0x00FAF3E4),
                                t,
                              )!,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Double-tap heart burst — the chalk scribbleHeart, not a
            // Material glyph. Warm chalk ink over the photo (dark-mode
            // ink colour reads on both light and dark images); when the
            // post ends up liked, the heart renders scribble-filled in
            // Graffiti Red per the scribble-fill rule (ART_DIRECTION §1).
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) {
                  if (_burst.isDismissed) return const SizedBox.shrink();
                  final liked = widget.isLiked;
                  return Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: SketchIcon(
                        kind: SketchIconKind.scribbleHeart,
                        size: 96,
                        seed: 41,
                        color: liked
                            ? const Color(0xFFE0245E)
                            : const Color(0xFFE8E4D8),
                        filled: liked,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- footer: caption + actions ---------------------------------------------------

class _CardFooter extends StatefulWidget {
  const _CardFooter({
    required this.post,
    required this.onLike,
    this.onComment,
    this.onShare,
    this.onKeep,
  });

  final SquarePost post;
  final VoidCallback onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  /// "Keep it" — makes an ephemeral post permanent. Null hides it.
  final VoidCallback? onKeep;

  @override
  State<_CardFooter> createState() => _CardFooterState();
}

class _CardFooterState extends State<_CardFooter> {
  SquarePost get post => widget.post;
  VoidCallback get onLike => widget.onLike;

  /// True between tapping unlike and the stream re-emitting the unliked
  /// state — the window where the X-scratched heart shows (the rewind
  /// moment). Cleared in didUpdateWidget once the un-like lands.
  bool _unliking = false;

  @override
  void didUpdateWidget(_CardFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!post.isLiked && _unliking) {
      setState(() => _unliking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    // Ink prototype (docs/ART_DIRECTION.md §2): when the analog layer is
    // on, the action row draws with the five sketch icons instead of
    // Material glyphs. Seed per post so each card's strokes are unique
    // but stable.
    final seed = post.id.hashCode & 0x7FFFFFFF;
    final useInk = golden.enabled;

    Widget likeButton() {
      // Three states (spec §2): resting = rough heart outline; liked =
      // cross-hatch scribble fill in Graffiti Red; un-liking = the
      // graffiti X scratched through the heart while the rewind effect
      // plays, falling back to the plain outline once it lands.
      final SketchIconKind kind;
      final bool filled;
      if (post.isLiked) {
        kind = SketchIconKind.scribbleHeart;
        filled = true;
      } else if (_unliking) {
        kind = SketchIconKind.xHeart;
        filled = false;
      } else {
        kind = SketchIconKind.scribbleHeart;
        filled = false;
      }
      final icon = SketchIcon(
        kind: kind,
        filled: filled,
        accentColor: SketchInk.graffitiRed,
        seed: seed,
      );
      Widget button = IconButton(
        onPressed: () {
          if (post.isLiked) {
            // Un-liking is *undoing* — the X-scratch shows for the
            // rewind moment, then the plain heart returns.
            setState(() => _unliking = true);
            RewindScope.rewind(context, onLike);
          } else {
            onLike();
          }
        },
        icon: AnimatedScale(
          scale: post.isLiked ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: icon,
        ),
        visualDensity: VisualDensity.compact,
        splashRadius: 22,
      );
      button = Tooltip(
        message: post.isLiked ? 'Rewind like' : 'Like',
        child: button,
      );
      return button;
    }

    Widget sketchAction({
      required SketchIconKind kind,
      required String tooltip,
      required VoidCallback onTap,
    }) =>
        Tooltip(
          message: tooltip,
          child: IconButton(
            onPressed: onTap,
            icon: SketchIcon(kind: kind, seed: seed + kind.index),
            visualDensity: VisualDensity.compact,
            splashRadius: 22,
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (useInk)
                likeButton()
              else
                _ActionIcon(
                  icon: post.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: post.isLiked ? const Color(0xFFE0245E) : null,
                  tooltip: post.isLiked ? 'Rewind like' : 'Like',
                  onTap: () {
                    if (post.isLiked) {
                      RewindScope.rewind(context, onLike);
                    } else {
                      onLike();
                    }
                  },
                  scaleFrom: post.isLiked ? 1.12 : 1.0,
                ),
              const SizedBox(width: 6),
              Text(
                post.likesLabel,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              if (useInk)
                sketchAction(
                  kind: SketchIconKind.jaggedBubble,
                  tooltip: 'Comment',
                  onTap: widget.onComment ?? () {},
                )
              else
                _ActionIcon(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Comment',
                  onTap: widget.onComment ?? () {},
                ),
              const Spacer(),
              if (useInk)
                sketchAction(
                  kind: SketchIconKind.paperPlane,
                  tooltip: 'Share',
                  onTap: widget.onShare ?? () {},
                )
              else
                _ActionIcon(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share',
                  onTap: widget.onShare ?? () {},
                ),
            ],
          ),
          if (post.expiresAt != null) ...[
            const SizedBox(height: 4),
            // Hand-drawn timer strip: a clock-tick mark and a written
            // verdict. Keeps fading copy in the app's voice.
            Row(
              children: [
                const SketchIcon(
                  kind: SketchIconKind.clockTick,
                  size: 16,
                  seed: 71,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    post.isExpired
                        ? 'Its time is up — it fades away.'
                        : 'Fades in ${_timeLeft(post)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                if (widget.onKeep != null)
                  Tooltip(
                    message: 'Keep it — this one stays',
                    child: InkWell(
                      onTap: widget.onKeep,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        child: Text(
                          'keep it',
                          style: kHandwrittenTextStyle.copyWith(
                            fontSize: 15,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: RichText(
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35, color: theme.colorScheme.onSurface),
                children: _buildCaptionSpans(theme, post),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact time-left for the ephemeral strip: "38m", "19h".
String _timeLeft(SquarePost post) {
  final expiry = post.expiresAt!;
  final delta = expiry
      .difference(post.clock?.call() ?? DateTime.now());
  if (delta.isNegative) return '0m';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24) return '${delta.inHours}h';
  return '${delta.inDays}d';
}

/// Caption spans with #hashtags and @mentions highlighted. Dark-mode
/// tuned accent: light periwinkle reads on near-black without vibrating.
List<InlineSpan> _buildCaptionSpans(ThemeData theme, SquarePost post) {
  final base = theme.textTheme.bodyMedium
      ?.copyWith(height: 1.35, color: theme.colorScheme.onSurface);
  final accentStyle = base?.copyWith(
    color: const Color(0xFF9DA9FF),
    fontWeight: FontWeight.w700,
  );

  final pattern = RegExp(r'([#@][\w.]+)');
  final spans = <InlineSpan>[
    TextSpan(
        text: post.username,
        style: base?.copyWith(fontWeight: FontWeight.w800)),
    const TextSpan(text: '  '),
  ];

  var cursor = 0;
  for (final match in pattern.allMatches(post.caption)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: post.caption.substring(cursor, match.start)));
    }
    spans.add(TextSpan(text: match.group(0), style: accentStyle));
    cursor = match.end;
  }
  if (cursor < post.caption.length) {
    spans.add(TextSpan(text: post.caption.substring(cursor)));
  }
  return spans;
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.onTap,
    this.color,
    this.tooltip,
    this.scaleFrom = 1.0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    Widget button = IconButton(
      onPressed: onTap,
      icon: AnimatedScale(
        scale: scaleFrom,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Icon(icon, size: 22, color: color),
      ),
      visualDensity: VisualDensity.compact,
      splashRadius: 22,
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

// -- media state widgets -------------------------------------------------------

/// Synchronous blurhash decode + paint. No async image loading — the
/// hash string becomes pixel colors in one frame, which is the entire
/// point: the cache renders meaningful media offline with zero latency.
///
/// Paints a diagonal gradient sampled from the hash's four corners —
/// a faithful (and cheap) approximation of the decoded image for the
/// placeholder's job: set the mood until real pixels arrive.
class _BlurhashPlaceholder extends StatelessWidget {
  const _BlurhashPlaceholder({required this.hash});

  final String hash;

  static Color _toFlutterColor(ColorTriplet linear) {
    final rgb = linear.toRgb();
    int clamp(double v) => v.round().clamp(0, 255);
    return Color.fromARGB(255, clamp(rgb.r), clamp(rgb.g), clamp(rgb.b));
  }

  @override
  Widget build(BuildContext context) {
    try {
      final decoded = BlurHash.decode(hash);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _toFlutterColor(decoded.linearRgbAt(0.0, 0.0)),
              _toFlutterColor(decoded.linearRgbAt(1.0, 0.0)),
              _toFlutterColor(decoded.linearRgbAt(0.0, 1.0)),
              _toFlutterColor(decoded.linearRgbAt(1.0, 1.0)),
            ],
            stops: const [0.0, 0.33, 0.66, 1.0],
          ),
        ),
      );
    } on Object {
      // Malformed hash (never expected): flat neutral fallback.
      return ColoredBox(color: Colors.grey.shade800);
    }
  }
}

/// Shimmer-style loading block: flat dark-gray surface with a subtle
/// diagonal sheen sweeping across. Dependency-free shimmer feel.
class _MediaShimmer extends StatefulWidget {
  const _MediaShimmer({required AnimationController shimmer})
      : _shimmer = shimmer;

  final AnimationController _shimmer;

  @override
  State<_MediaShimmer> createState() => _MediaShimmerState();
}

class _MediaShimmerState extends State<_MediaShimmer> {
  @override
  void initState() {
    super.initState();
    widget._shimmer.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MediaShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._shimmer != widget._shimmer) {
      oldWidget._shimmer.stop();
      widget._shimmer.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    // Don't dispose — the controller is owned by _CardMediaState and
    // reused across loading/error cycles.
    widget._shimmer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget._shimmer,
      builder: (context, _) {
        final t = widget._shimmer.value;
        return Container(
          color: const Color(0xFF232326),
          alignment: Alignment.center,
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-1.0 - 2 * t, -0.4),
              end: Alignment(1.0 + 2 * t, 0.4),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x14FFFFFF), // 8% white sheen
                Color(0x00FFFFFF),
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds),
            child: Container(color: const Color(0xFF232326)),
          ),
        );
      },
    );
  }
}

/// Error fallback for failed/404 media: clean dark-gray block with a
/// stylized icon and label. Never shows the default broken-asset glyph.
class _MediaUnavailable extends StatefulWidget {
  const _MediaUnavailable({
    required AnimationController shimmer,
    required this.onRetry,
  })  : _shimmer = shimmer;

  final AnimationController _shimmer;
  final VoidCallback onRetry;

  @override
  State<_MediaUnavailable> createState() => _MediaUnavailableState();
}

class _MediaUnavailableState extends State<_MediaUnavailable> {
  @override
  void initState() {
    super.initState();
    widget._shimmer
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    widget._shimmer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C1F),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 44,
            color: Colors.white.withValues(alpha: 0.28),
          ),
          const SizedBox(height: 8),
          Text(
            'Media unavailable',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(height: 10),
          ActionChip(
            avatar: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.55),
            ),
            label: Text(
              'Tap to retry',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            onPressed: widget.onRetry,
          ),
        ],
      ),
    );
  }
}
