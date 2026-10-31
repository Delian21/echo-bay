import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sketch_kit.dart';

/// Delivery lifecycle for a Vault message. Presentation-only mirror of the
/// domain/data sync status; mapping lives in the presentation layer.
enum ChatStatus { pending, sent, delivered, read, failed }

/// Delivery status drawn in the sketch language: the chalk clock, one
/// pen check, two overlapping checks (accent when read), or a scratched
/// X for failure. Falls back to Material icons when the analog layer is
/// off (the stock A/B theme keeps its original look).
class StatusTick extends StatelessWidget {
  const StatusTick({
    super.key,
    required this.status,
    this.size = 16,
    this.onAccent = false,
  });

  final ChatStatus status;
  final double size;

  /// The tick is drawn on an accent-filled bubble (my own messages), so its
  /// colors come from `onPrimary` instead of the neutral-bubble tokens.
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppThemeExtension.of(context);
    final useInk = GoldenHourExtension.of(context).enabled;

    final idle = onAccent ? scheme.onPrimary : scheme.onSurfaceVariant;
    final read = onAccent ? scheme.onPrimary : tokens.readAccent;
    final failed = onAccent ? scheme.onPrimary : scheme.error;

    if (!useInk) {
      final (icon, color) = switch (status) {
        ChatStatus.pending || ChatStatus.sent => (
            Icons.schedule_outlined,
            idle
          ),
        ChatStatus.delivered => (Icons.done_all, idle),
        ChatStatus.read => (Icons.done_all, read),
        ChatStatus.failed => (Icons.error_outline, failed),
      };
      return Icon(icon, size: size, color: color);
    }

    final color = switch (status) {
      ChatStatus.pending ||
      ChatStatus.sent ||
      ChatStatus.delivered =>
        idle,
      ChatStatus.read => read,
      ChatStatus.failed => failed,
    };
    final kind = switch (status) {
      ChatStatus.pending => SketchIconKind.clockTick,
      ChatStatus.sent => SketchIconKind.singleTick,
      ChatStatus.delivered => SketchIconKind.doubleTick,
      ChatStatus.read => SketchIconKind.doubleTick,
      ChatStatus.failed => SketchIconKind.xHeart,
    };

    return SketchIcon(kind: kind, size: size, color: color, seed: 11);
  }
}
