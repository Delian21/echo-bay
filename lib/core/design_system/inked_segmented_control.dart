import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sketch_kit.dart';

/// The app's segmented control: ink-lined cells on paper, the selected one
/// filled solid with the accent. The label rides `onPrimary`, which the
/// theme derives for WCAG contrast — a hatch behind text was unreadable at
/// small sizes and washed out on pale accents.
class InkedSegmentedControl extends StatelessWidget {
  const InkedSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// One cell: its label and an optional chalk glyph.
  final List<({String label, SketchIconKind? icon})> segments;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    final ink = SketchInk.of(context);
    final border = BorderSide(
      color: useInk
          ? ink.withValues(alpha: 0.6)
          : theme.colorScheme.outline.withValues(alpha: 0.4),
      width: useInk ? 1.6 : 1,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.fromBorderSide(border),
        color: theme.colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final (i, segment) in segments.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: segment.label,
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Solid accent fill: the selected cell is a marker
                        // highlight, not a hatch. No texture — the label has
                        // to stay crisp.
                        if (i == selectedIndex)
                          ColoredBox(color: theme.colorScheme.primary),
                        if (i > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: border.width,
                              color: border.color,
                            ),
                          ),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (segment.icon != null) ...[
                                SketchGlyph(
                                  kind: segment.icon!,
                                  size: 18,
                                  color: i == selectedIndex
                                      ? theme.colorScheme.onPrimary
                                      : (useInk
                                          ? theme.colorScheme.onSurface
                                          : theme
                                              .colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                segment.label,
                                style: useInk
                                    ? kHandwrittenTextStyle.copyWith(
                                        fontSize: 18,
                                        color: i == selectedIndex
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface,
                                      )
                                    : theme.textTheme.labelLarge
                                        ?.copyWith(
                                        fontWeight: i == selectedIndex
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: i == selectedIndex
                                            ? theme.colorScheme.onPrimary
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
