import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pinned_reference_card.dart' show PinnedReferenceCard;

import '../../../../core/atmosphere/atmosphere_controller.dart';
import '../../../../core/design_system/sketch_kit.dart';
import '../../../../injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/app_database.dart' show KeepsakeKind;
import '../../../../core/motion/rewind_scope.dart';
import '../domain/entities/keepsake_item.dart';
import '../domain/repositories/keepsake_repository.dart';

/// The keepsake wall: a corkboard where pinned Square posts and
/// handwritten notes live. Items drag freely; positions/rotations
/// persist as board-relative fractions so the board survives phone →
/// desktop. A long-press unpins with the rewind animation offering an
/// undo (re-pinning the exact payload).
class KeepsakeBoardPage extends StatefulWidget {
  const KeepsakeBoardPage({super.key, required this.repository});

  final KeepsakeRepository repository;

  static Future<void> show(BuildContext context,
          {required KeepsakeRepository repository}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => KeepsakeBoardPage(repository: repository),
      ));

  @override
  State<KeepsakeBoardPage> createState() => _KeepsakeBoardPageState();
}

class _KeepsakeBoardPageState extends State<KeepsakeBoardPage> {
  Stream<List<KeepsakeItem>>? _stream;
  String? _pendingNoteTarget;

  // Late-final stream discipline (ARCHITECTURE.md §8).
  Stream<List<KeepsakeItem>> get _boardStream =>
      _stream ??= widget.repository
          .watchBoard()
          .map((either) => either.fold((_) => <KeepsakeItem>[], (l) => l));

  Future<void> _persistMove(KeepsakeItem item, Offset fraction,
      double rotation) async {
    await widget.repository.moveItem(
      itemId: item.id,
      posX: fraction.dx,
      posY: fraction.dy,
      rotation: rotation,
    );
  }

  Future<void> _unpin(KeepsakeItem item) async {
    final result = await widget.repository.unpin(itemId: item.id);
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? "Couldn't unpin that one."),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {},
    );
    // Undo rides the rewind effect: re-pin the exact payload on tap.
    RewindScope.rewind(context, () async {
      final result = item.kind == KeepsakeKind.post
          ? await widget.repository.pinPost(
              postId: item.postId!,
              posX: item.posX,
              posY: item.posY,
              rotation: item.rotation,
            )
          : await widget.repository.addNote(
              noteText: item.noteText ?? '',
              posX: item.posX,
              posY: item.posY,
            );
      if (!mounted) return;
      result.fold(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                failure.message ?? "Couldn't put it back — try again?"),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        (_) {},
      );
    });
  }

  /// Pin a handwritten note, with the same page-settle atmosphere as a
  /// pinned post.
  Future<void> _addNote() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pin a note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: kHandwrittenTextStyle.copyWith(fontSize: 19),
          decoration: const InputDecoration(
            hintText: 'Scratch it down…',
          ),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Pin'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    final result = await widget.repository.addNote(
      noteText: text,
      posX: 0.1 + math.Random().nextDouble() * 0.5,
      posY: 0.1 + math.Random().nextDouble() * 0.5,
    );
    if (!mounted) return;
    // Atmosphere: page settling on the wall (opt-in, best-effort).
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              failure.message ?? "Couldn't pin that note. Try again?"),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {
        try {
          unawaited(
              sl<AtmosphereController>().play(AtmosphereSound.pageTurn));
        } on Object {
          // DI unavailable (tests): silence is fine.
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keepsake wall'),
        actions: [
          IconButton(
            tooltip: 'Pin a note',
            icon: const SketchIcon(
              kind: SketchIconKind.plusCircle,
              size: 22,
              seed: 43,
            ),
            onPressed: _addNote,
          ),
        ],
      ),
      body: StreamBuilder<List<KeepsakeItem>>(
        stream: _boardStream,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <KeepsakeItem>[];
          return Stack(
            children: [
              // Corkboard ground.
              Positioned.fill(
                child: ColoredBox(
                  color: golden.enabled
                      ? const Color(0xFFD9B98A)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              // Hand-inked strings first (under the items).
              ..._buildStrings(items),
              // The pinned items.
              for (final item in items)
                _KeepsakeCard(
                  item: item,
                  repository: widget.repository,
                  onMoved: _persistMove,
                  onLongPress: () => _unpin(item),
                  onStringDrag: (targetId) => widget.repository.stringItems(
                    fromItemId: item.id,
                    toItemId: targetId,
                  ),
                  stringModeActive: _pendingNoteTarget != null,
                  onStringHandleTapped: () => setState(() =>
                      _pendingNoteTarget =
                          _pendingNoteTarget == item.id ? null : item.id),
                  highlightStringTarget: _pendingNoteTarget != null &&
                      _pendingNoteTarget != item.id,
                ),
              if (items.isEmpty)
                Center(
                  child: Text(
                    'The wall is bare.\nPin a square or scratch a note.',
                    textAlign: TextAlign.center,
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 19,
                      height: 1.4,
                      color: Colors.brown.shade700,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// One wobbly ink line per strung pair (a -> strungTo), drawn in
  /// board coordinates via the LayoutBuilder fractions.
  List<Widget> _buildStrings(List<KeepsakeItem> items) {
    final byId = {for (final i in items) i.id: i};
    final strings = <Widget>[];
    for (final item in items) {
      final target = item.strungTo == null ? null : byId[item.strungTo!];
      if (target == null) continue;
      strings.add(
        Positioned.fill(
          child: CustomPaint(
            painter: _WobblyStringPainter(from: item, to: target),
          ),
        ),
      );
    }
    return strings;
  }
}

/// A draggable, slightly rotated keepsake card. Drag deltas are
/// converted to board fractions on release and persisted.
class _KeepsakeCard extends StatefulWidget {
  const _KeepsakeCard({
    required this.item,
    required this.repository,
    required this.onMoved,
    required this.onLongPress,
    required this.onStringDrag,
    required this.stringModeActive,
    required this.onStringHandleTapped,
    required this.highlightStringTarget,
  });

  final KeepsakeItem item;
  final KeepsakeRepository repository;
  final Future<void> Function(KeepsakeItem, Offset, double) onMoved;
  final VoidCallback onLongPress;
  final ValueChanged<String> onStringDrag;
  final bool stringModeActive;
  final VoidCallback onStringHandleTapped;
  final bool highlightStringTarget;

  @override
  State<_KeepsakeCard> createState() => _KeepsakeCardState();
}

class _KeepsakeCardState extends State<_KeepsakeCard> {
  Offset? _dragFractionDelta;
  double _dragRotationDelta = 0;

  static const _cardWidthFraction = 0.30;
  static const _cardHeightFraction = 0.24;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return LayoutBuilder(builder: (context, constraints) {
      final boardSize = constraints.biggest;
      final baseLeft = item.posX * boardSize.width;
      final baseTop = item.posY * boardSize.height;
      final dx = _dragFractionDelta?.dx ?? 0;
      final dy = _dragFractionDelta?.dy ?? 0;

      final card = SketchBox(
        seed: item.id.hashCode & 0x7FFFFFFF,
        radius: 6,
        strokeWidth: 2,
        color: SketchInk.of(context),
        fill: Colors.amber.shade50,
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: boardSize.width * _cardWidthFraction,
          height: boardSize.height * _cardHeightFraction,
          child: item.kind == KeepsakeKind.post
              ? PinnedReferenceCard(referenceId: item.postId ?? '')
              : Text(
                  item.noteText ?? '',
                  style: kHandwrittenTextStyle.copyWith(fontSize: 17),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      );

      return Positioned(
        left: baseLeft + dx,
        top: baseTop + dy,
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          onPanStart: (_) {
            _dragFractionDelta = Offset.zero;
            _dragRotationDelta = 0;
          },
          onPanUpdate: (details) {
            setState(() {
              _dragFractionDelta =
                  (_dragFractionDelta ?? Offset.zero) + details.delta;
              // Tilt slightly with horizontal travel — feels pinned.
              _dragRotationDelta = dx / 400;
            });
          },
          onPanEnd: (_) async {
            final board = boardSize;
            final newX = ((baseLeft + dx) / board.width).clamp(0.0, 0.95);
            final newY = ((baseTop + dy) / board.height).clamp(0.0, 0.95);
            _dragFractionDelta = null;
            final rotation = item.rotation + _dragRotationDelta;
            _dragRotationDelta = 0;
            setState(() {});
            await widget.onMoved(item, Offset(newX, newY), rotation);
          },
          child: Transform.rotate(
            angle: item.rotation + _dragRotationDelta,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                // String handle: small thumbtack dot; tap one item then
                // another to string them together.
                Positioned(
                  right: -6,
                  top: -6,
                  child: GestureDetector(
                    onTap: widget.stringModeActive
                        ? (widget.highlightStringTarget
                            ? () {
                                widget.onStringDrag(widget.item.id);
                                widget.onStringHandleTapped();
                              }
                            : null)
                        : widget.onStringHandleTapped,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.highlightStringTarget
                            ? Colors.red.shade700
                            : Colors.brown.shade400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Hand-inked wobbly string between two pinned items. Draws a 2-pass
/// jittered line in board-fraction coordinates (reusing the sketch ink
/// vocabulary, per-point seeded so it is stable across rebuilds).
class _WobblyStringPainter extends CustomPainter {
  _WobblyStringPainter({required this.from, required this.to});

  final KeepsakeItem from;
  final KeepsakeItem to;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(
      (from.posX + 0.15) * size.width,
      (from.posY + 0.05) * size.height,
    );
    final b = Offset(
      (to.posX + 0.15) * size.width,
      (to.posY + 0.05) * size.height,
    );

    final paint = Paint()
      ..color = const Color(0xFF6B4A2B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(a.dx, a.dy);
    const segments = 12;
    for (var i = 1; i <= segments; i++) {
      final t = i / segments;
      final base = Offset.lerp(a, b, t)!;
      // Stable per-segment jitter from the two ids.
      final seed = (from.id.hashCode ^ to.id.hashCode ^ (i * 31)) & 0xFF;
      final jitter = ((seed / 255) - 0.5) * 6.0;
      path.lineTo(base.dx + jitter, base.dy + jitter * 0.5);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WobblyStringPainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}
