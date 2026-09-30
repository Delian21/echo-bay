import 'package:flutter/material.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/motion/motion_scope.dart';
import 'post_composer.dart' show promptShapeHint;

/// Shipped hybrid bottom bar (nav decision, replaced the sliding pill
/// bar): Material 3 [BottomAppBar] with a docked circular compose FAB in
/// the notch, two destinations left, two right. The FAB is the visual
/// anchor — "an app organized around posting" — while the bar itself is
/// stock M3 (tokens, touch targets, a11y for free).
///
/// Active destination is signaled by color alone — primary-tinted icon
/// + label, no highlight shape behind it (the sliding pill was removed:
/// it never stayed visually centered and read as noise). A subtle
/// animated weight/color transition is the only motion left.
///
/// Settings is intentionally absent: it lives in the Square app bar on
/// mobile. The wide/rail layout is unaffected.
class FabBottomBar extends StatelessWidget {
  const FabBottomBar({
    super.key,
    required this.modules,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCompose,
    this.showNotch = true,
    this.badgedIndexes = const {},
  });

  /// Exactly four destinations: two docked left of the FAB, two right.
  /// Destinations draw chalk glyphs, not Material icons — the bar is
  /// app chrome, and chrome carries the sketch identity.
  final List<(String, SketchIconKind)> modules;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Indexes currently showing the unread scribble-dot (e.g. the Vault
  /// when unread messages exist). Anti-chore rule: the dot must clear
  /// the moment the module opens — a permanent badge is a chore machine.
  final Set<int> badgedIndexes;

  /// Compose action — the shell wires this to the '/square/compose'
  /// deep link so it lands on the Square with the composer open and back
  /// returns to the originating module.
  final VoidCallback onCompose;

  /// True: classic M3 notch cutout. False: flat-docked FAB (subtler).
  final bool showNotch;

  static const _barHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    assert(modules.length == 4, 'hybrid bar expects exactly 4 destinations');
    final scheme = Theme.of(context).colorScheme;
    final reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;
    final tintDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 200);

    // Reserve the center gap for the docked FAB (FAB is 56dp; 64 gives
    // the notch breathing room without starving the label columns).
    const gapWidth = 64.0;

    Widget destination(int index) {
      final (label, kind) = modules[index];
      final selected = index == selectedIndex;
      final badged = badgedIndexes.contains(index) && !selected;
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(index),
          child: SizedBox(
            height: _barHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: tintDuration,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: SketchGlyph(
                    kind: kind,
                    key: ValueKey(selected),
                    size: 24,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    // The tile's Text label carries the semantics; the
                    // glyph would double-speak the destination name.
                    excludeFromSemantics: true,
                  ),
                ),
                // Unread scribble-dot: a pen-drawn filled blob, not a
                // Material badge pill — chrome carries the sketch identity.
                SizedBox(
                  height: 5,
                  child: badged
                      ? const CustomPaint(
                          size: Size(6, 5), painter: UnreadScribbleDot())
                      : null,
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: tintDuration,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.clip),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BottomAppBar(
      key: const ValueKey('fab-bottom-bar'),
      shape: showNotch ? const CircularNotchedRectangle() : null,
      notchMargin: showNotch ? 6 : 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        height: _barHeight,
        child: Row(
          children: [
            for (var i = 0; i < 2; i++) destination(i),
            const SizedBox(width: gapWidth),
            for (var i = 2; i < 4; i++) destination(i),
          ],
        ),
      ),
    );
  }
}

/// The unread dot: a small hand-pressed blob of Graffiti Red ink —
/// slightly irregular, denser at one edge, like a pen pressed to paper.
/// Shared by the bottom-bar destinations and the desktop rail.
class UnreadScribbleDot extends CustomPainter {
  const UnreadScribbleDot();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFE0245E)
      ..style = PaintingStyle.fill;
    // The blob: a wobbly filled circle plus a denser core, so it reads
    // as ink soaking into paper rather than a vector badge.
    final blob = Path()
      ..addOval(Rect.fromCenter(
        center: c,
        width: size.width * 0.9,
        height: size.height * 1.05,
      ));
    canvas.drawPath(blob, paint);
    canvas.drawCircle(
      c.translate(-0.4, 0.3),
      size.width * 0.22,
      paint..color = const Color(0xFFB01A4B),
    );
  }

  @override
  bool shouldRepaint(covariant UnreadScribbleDot oldDelegate) => false;
}

/// Compose FAB for the hybrid bar. Kept beside [FabBottomBar] so the
/// pair is one decision: a scaffold uses
/// [FloatingActionButtonLocation.centerDocked] with this FAB and
/// [FabBottomBar] together.
///
/// Long-press opens quick actions keyed by Daily Square prompt shape
/// (photo / sentence / sound — the three interactive shapes of the
/// seeded rotation; 'desk' has no distinct compose affordance). Each
/// action opens the composer with the shape's own hint, so a prompt
/// tap and a FAB quick action land on the same invitation.
class ComposeFab extends StatelessWidget {
  const ComposeFab({super.key, required this.onPressed, this.onQuickAction});

  final VoidCallback onPressed;

  /// Long-press quick action, invoked with the prompt shape
  /// ('photo' | 'sentence' | 'sound'). Null disables the quick menu.
  final ValueChanged<String>? onQuickAction;

  /// (shape, icon, label) — labels mirror the prompt shape names.
  /// The 4th entry is not a prompt shape: 'timetravel' is a plain
  /// action token the shell interprets (opens the scrubber).
  static const _quickActions = [
    ('photo', Icons.photo_outlined, 'Photo'),
    ('sentence', Icons.short_text_rounded, 'Sentence'),
    ('sound', Icons.music_note_outlined, 'Sound'),
    ('timetravel', Icons.history_rounded, 'Time travel'),
  ];

  Future<void> _showQuickActions(BuildContext context) async {
    final shape = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (shape, icon, label) in _quickActions)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                // Same copy as the prompt body for that shape — one
                // vocabulary across notification, FAB, and composer.
                // The time-travel token isn't a prompt shape and has
                // no composer copy.
                subtitle: shape == 'timetravel'
                    ? const Text('Flip through the sketchbook\'s past days.')
                    : Text(promptShapeHint(shape)),
                onTap: () => Navigator.of(sheetContext).pop(shape),
              ),
          ],
        ),
      ),
    );
    if (shape != null) onQuickAction?.call(shape);
  }

  @override
  Widget build(BuildContext context) {
    // This Flutter SDK's FloatingActionButton no longer takes onLongPress
    // (RawMaterialButton still does), so the long-press lives on a
    // wrapping GestureDetector: taps are won by the FAB's own recognizer,
    // long-presses fall through to this one.
    return GestureDetector(
      onLongPress:
          onQuickAction == null ? null : () => _showQuickActions(context),
      child: Tooltip(
        // triggerMode.manual: this SDK's FAB has no onLongPress, and the
        // default long-press tooltip would steal the long-press gesture
        // from the quick-action detector above. The message still reaches
        // screen readers via semantics.
        triggerMode: TooltipTriggerMode.manual,
        message: 'New post',
        child: FloatingActionButton(
          onPressed: onPressed,
          elevation: 2,
          child: const SketchIcon(
              kind: SketchIconKind.plusCircle, size: 26, seed: 67),
        ),
      ),
    );
  }
}
