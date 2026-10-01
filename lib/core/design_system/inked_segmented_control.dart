import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sketch_kit.dart';

/// The app's hand-inked segmented control: wobbly cells on paper, the
/// selected one cross-hatched like a few pencil passes that never quite
/// fill the space. Hatch carries the selection, so the label stays
/// ink-on-paper and readable whatever the accent.
class InkedSegmentedControl extends StatelessWidget {
  const InkedSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
    this.seed = 7,
  });

  /// One cell: its label and an optional chalk glyph.
  final List<({String label, SketchIconKind? icon})> segments;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int seed;

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
                        // The hatch sits behind the label: the selected
                        // cell reads as shaded paper, not a solid block.
                        if (i == selectedIndex)
                          LayoutBuilder(
                            builder: (context, constraints) => ScribbleFill(
                              sketchPath: Path()
                                ..addRRect(RRect.fromRectAndRadius(
                                  Offset.zero &
                                      Size(constraints.maxWidth,
                                          constraints.maxHeight),
                                  const Radius.circular(10),
                                )),
                              seed: seed + i,
                              color: theme.colorScheme.primary,
                              opacity: 0.55,
                              density: ScribbleFill.adaptiveDensity(
                                Size(constraints.maxWidth,
                                    constraints.maxHeight),
                              ),
                            ),
                          ),
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
                                  color: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                segment.label,
                                style: useInk
                                    ? kHandwrittenTextStyle.copyWith(
                                        fontSize: 18,
                                        color: theme.colorScheme.onSurface,
                                      )
                                    : theme.textTheme.labelLarge
                                        ?.copyWith(
                                        fontWeight: i == selectedIndex
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: i == selectedIndex
                                            ? theme.colorScheme.onSurface
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
