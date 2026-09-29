import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/sketch_kit.dart';
import '../theme/app_theme.dart';
import 'time_travel_scope.dart';

/// The time-travel scrubber: a hand-drawn film strip docked at the top
/// of the screen. Drag along the sprocket edge to pick a past date;
/// tap "Return to today" to exit (the shell plays the rewind effect on
/// exit). Rendered while time travel is active — entry lives in the
/// shell's app bar (hourglass glyph).
class TimeTravelScrubber extends StatefulWidget {
  const TimeTravelScrubber({super.key, required this.controller});

  final TimeTravelController controller;

  @override
  State<TimeTravelScrubber> createState() => _TimeTravelScrubberState();
}

class _TimeTravelScrubberState extends State<TimeTravelScrubber> {
  /// Travel window: the app's whole known history, bounded by the first
  /// seeded post (roughly app launch) and now.
  static const _spanDays = 30;

  double _fraction = 1.0;

  DateTime get _now => DateTime.now();

  DateTime _momentFor(double fraction) {
    final moment = _now.subtract(Duration(
      days: (_spanDays * (1 - fraction)).round(),
    ));
    return DateTime(moment.year, moment.month, moment.day);
  }

  @override
  void initState() {
    super.initState();
    final asOf = widget.controller.asOf;
    if (asOf != null) {
      final elapsed = _now.difference(asOf).inDays.clamp(0, _spanDays);
      _fraction = 1.0 - elapsed / _spanDays;
    }
  }

  static const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    return Material(
      color: golden.enabled ? const Color(0xFF221E19) : Colors.black87,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SketchIcon(
                    kind: SketchIconKind.refreshLoop,
                    size: 18,
                    seed: 97,
                    color: Color(0xFFE8E4D8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Looking back at '
                      '${months[_momentFor(_fraction).month - 1]} '
                      '${_momentFor(_fraction).day} — read-only',
                      style: kHandwrittenTextStyle.copyWith(
                        fontSize: 16,
                        color: const Color(0xFFE8E4D8),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.controller.exit(),
                    child: const Text(
                      'Return to today',
                      style: TextStyle(color: Color(0xFFE8E4D8)),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  final box = context.findRenderObject()! as RenderBox;
                  setState(() {
                    _fraction = (_fraction +
                            details.delta.dx / (box.size.width - 32))
                        .clamp(0.0, 1.0);
                  });
                  widget.controller.scrub(_momentFor(_fraction));
                },
                onHorizontalDragEnd: (_) {
                  // Snap the visit to the picked day.
                  widget.controller.scrub(_momentFor(_fraction));
                },
                child: CustomPaint(
                  size: const Size.fromHeight(34),
                  painter: _FilmStripPainter(
                    fraction: _fraction,
                    seed: 97,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hand-drawn film strip: sprocket holes along a wobbly edge, a chalk
/// thumb for the picked day, and faint day ticks across the span.
class _FilmStripPainter extends CustomPainter {
  _FilmStripPainter({required this.fraction, required this.seed});

  final double fraction;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final mid = size.height / 2;

    // The strip: two slightly wavy lines (sketch pass).
    final strip = Paint()
      ..color = const Color(0xFFE8E4D8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final dy in [mid - 12, mid + 12]) {
      final path = Path()..moveTo(0, dy);
      for (var x = 0.0; x <= w; x += 14) {
        final jitter =
            ((math.sin(x * 0.11 + seed) * 2) + ((x ~/ 14) % 3 - 1)) * 0.8;
        path.lineTo(x, dy + jitter);
      }
      canvas.drawPath(path, strip);
    }

    // Sprocket holes.
    final holes = Paint()..color = const Color(0xFFE8E4D8).withValues(alpha: 0.55);
    for (var x = 8.0; x < w - 8; x += 22) {
      canvas.drawCircle(Offset(x, mid - 6), 2.2, holes);
      canvas.drawCircle(Offset(x, mid + 6), 2.2, holes);
    }

    // Day ticks (30 days).
    final ticks = Paint()
      ..color = const Color(0xFFE8E4D8).withValues(alpha: 0.35)
      ..strokeWidth = 1.4;
    for (var i = 0; i <= 30; i++) {
      final x = w * i / 30;
      canvas.drawLine(Offset(x, mid - 10), Offset(x, mid + 10), ticks);
    }

    // The chalk thumb at the picked fraction.
    final thumbX = w * fraction;
    final thumb = Paint()..color = const Color(0xFFF3D27A);
    canvas.drawCircle(Offset(thumbX, mid), 7, thumb);
    final ring = Paint()
      ..color = const Color(0xFFE8E4D8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(thumbX, mid), 10, ring);
  }

  @override
  bool shouldRepaint(_FilmStripPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
