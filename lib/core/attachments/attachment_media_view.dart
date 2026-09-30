import 'package:flutter/material.dart';

import '../design_system/sketch_kit.dart';
import '../theme/app_theme.dart';
import '../io/platform_io.dart';
import 'attachment.dart';
import 'attachment_photo_viewer.dart';
import 'shared_post_card.dart';
import 'voice_waveform_chip.dart';

/// Renders a message's attachment inside a chat bubble, in the sketch
/// kit's language: the photo is "taped into the notebook" (wobbly inked
/// frame), video and voice render as small play chips, and a shared
/// Square post renders as a small polaroid card. Lives in core —
/// both the Vault and the Dorms render attachments.
class AttachmentMediaView extends StatelessWidget {
  const AttachmentMediaView({
    super.key,
    required this.attachment,
    this.seed = 1,
    this.onOpenSharedPost,
  });

  final MessageAttachment attachment;

  /// Deterministic wobble seed for the inked frame (message id hash).
  final int seed;

  /// Opens a shared Square post in context (the day view). Null makes
  /// the shared-post card inert (tests).
  final void Function(BuildContext context, String postId)? onOpenSharedPost;

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    switch (attachment.kind) {
      case AttachmentKind.photo:
        // Tap to open full-screen (dark backdrop, pinch/double-tap
        // zoom) — the same contract as every messenger.
        final image = GestureDetector(
          onTap: () => showAttachmentPhotoViewer(context, attachment.path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(useInk ? 4 : 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240, maxHeight: 190),
              child: Image(
                image: platformImageProvider(attachment.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _brokenTile(
                  context,
                  icon: Icons.image_not_supported_outlined,
                  label: 'Photo unavailable',
                ),
              ),
            ),
          ),
        );
        if (!useInk) return image;
        // Taped into the notebook: the wobbly frame doubles as the
        // tape strip — no extra chrome.
        return SketchBox(
          seed: seed,
          radius: 4,
          strokeWidth: 2,
          color: SketchInk.of(context),
          padding: const EdgeInsets.all(4),
          child: image,
        );

      case AttachmentKind.video:
        return _MediaChip(
          seed: seed,
          useInk: useInk,
          icon: const SketchIcon(kind: SketchIconKind.playTriangle, size: 16),
          label: 'Video',
          fallbackIcon: Icons.play_circle_outline_rounded,
        );

      case AttachmentKind.voice:
        // Playable waveform chip: play/pause through the shared player,
        // bars tint amber as the note progresses.
        return VoiceWaveformChip(
          attachment: attachment,
          seed: seed,
        );

      case AttachmentKind.post:
        // A shared Square post: small polaroid card; tap opens the post
        // (the day view). Faded/deleted posts show the graceful card.
        return SharedPostCard(
          postId: attachment.path,
          onOpen: onOpenSharedPost == null
              ? null
              : (context) => onOpenSharedPost!(context, attachment.path),
        );
    }
  }

  Widget _brokenTile(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      height: 120,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Small pill for non-photo media (video poster, voice note). Ink mode
/// draws it as a tiny sketch box; otherwise a soft Material pill. The
/// play affordance is visual for now — real playback lands with the
/// codec stage behind the same attachment path.
class _MediaChip extends StatelessWidget {
  const _MediaChip({
    required this.seed,
    required this.useInk,
    required this.icon,
    required this.label,
    required this.fallbackIcon,
  });

  final int seed;
  final bool useInk;
  final Widget icon;
  final String label;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        useInk
            ? icon
            : Icon(fallbackIcon,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );

    if (!useInk) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: row,
      );
    }

    return SketchBox(
      seed: seed + 13,
      radius: 6,
      strokeWidth: 2,
      color: SketchInk.of(context),
      fill: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: row,
    );
  }
}
