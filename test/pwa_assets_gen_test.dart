import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color, Size;
import 'package:flutter_test/flutter_test.dart';

/// PWA asset generator: renders the Echo Bay cover mark (hand-inked
/// sketchbook over sepia paper) at every manifest size, plus maskable
/// variants with a 20% safe zone, the favicon, and two install-dialog
/// screenshots. Run: `flutter test test/pwa_assets_gen_test.dart`.
///
/// Art direction: sepia paper (#F5EFE2), charcoal ink (#2B2A26), golden
/// amber spine (#D98324). A closed sketchbook, slightly wobbly border,
/// stitched spine, three journal lines, and a bay ripple under it — the
/// "echo" — readable at 192px and recognizable at 32px.
void main() {
  test('generate PWA icons, favicon, and install screenshots', () async {
    Future<void> writePng(ui.Image image, String path) async {
      final data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      file.createSync(recursive: true);
      file.writeAsBytesSync(data!.buffer.asUint8List());
      // ignore: avoid_print
      print('WROTE $path (${data.buffer.lengthInBytes} bytes)');
    }

    // -- plain icons: paper square, art centered -------------------------
    for (final size in [192, 512]) {
      final image = await _render(_paperSquarePainter, size);
      await writePng(image, 'web/icons/Icon-$size.png');
    }

    // -- maskable: full-bleed paper, art inside the 80% safe zone --------
    for (final size in [192, 512]) {
      final image = await _render(_maskablePainter, size);
      await writePng(image, 'web/icons/Icon-maskable-$size.png');
    }

    // -- favicon ----------------------------------------------------------
    final favicon = await _render(_paperSquarePainter, 32);
    await writePng(favicon, 'web/favicon.png');

    // -- install-dialog screenshots: stylized brand cards -----------------
    final narrow = await _render(_narrowScreenshotPainter, 1080, height: 1920);
    await writePng(narrow, 'web/screenshots/echo-bay-narrow.png');
    final wide = await _render(_wideScreenshotPainter, 1920, height: 1080);
    await writePng(wide, 'web/screenshots/echo-bay-wide.png');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

typedef _IconPainter = void Function(_IconCanvas canvas);

Future<ui.Image> _render(
  _IconPainter painter,
  int size, {
  int height = 0,
}) async {
  final h = height == 0 ? size : height;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final c = _IconCanvas(canvas, Size(size.toDouble(), h.toDouble()));
  painter(c);
  final picture = recorder.endRecording();
  return picture.toImage(size, h);
}

// -- palette ----------------------------------------------------------------

const _paper = Color(0xFFF5EFE2);
const _paperDeep = Color(0xFFEDE4D0);
const _ink = Color(0xFF2B2A26);
const _amber = Color(0xFFD98324);

// -- the mark: a closed sketchbook with a stitched spine and a bay ripple ----

void _drawMark(_IconCanvas c, {required double scale}) {
  final s = scale;

  // Bay ripple first (sits under the book, the "echo").
  final wave = ui.Paint()
    ..color = _ink.withValues(alpha: 0.55)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 9 * s
    ..strokeCap = ui.StrokeCap.round;
  for (final (i, r) in const [(0, 120.0), (1, 170.0)]) {
    final path = ui.Path();
    final baseY = 830 * s + i * 46 * s;
    path.moveTo(512 * s - r * s, baseY);
    for (var x = -r; x <= r; x += 8) {
      path.lineTo(
        512 * s + x * s,
        baseY + math.sin(x / r * math.pi * 2) * 8 * s,
      );
    }
    c.canvas.drawPath(path, wave);
  }

  // Cover: a big wobbly rounded rect, three passes of ink for weight.
  final cover = ui.RRect.fromRectAndRadius(
    ui.Rect.fromLTWH(232 * s, 190 * s, 560 * s, 560 * s),
    ui.Radius.circular(36 * s),
  );
  final border = ui.Paint()
    ..color = _ink
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 16 * s
    ..strokeJoin = ui.StrokeJoin.round;
  final borderSoft = ui.Paint()
    ..color = _ink.withValues(alpha: 0.55)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 9 * s
    ..strokeJoin = ui.StrokeJoin.round;
  c.canvas.drawRRect(cover, ui.Paint()..color = _paperDeep);
  c.canvas.drawRRect(cover, border);
  final wobble = cover.deflate(7 * s).shift(ui.Offset(3 * s, -3 * s));
  c.canvas.drawRRect(wobble, borderSoft);

  // Spine: amber band on the left with stitch dashes.
  final spine = ui.RRect.fromRectAndRadius(
    ui.Rect.fromLTWH(232 * s, 190 * s, 118 * s, 560 * s),
    ui.Radius.circular(36 * s),
  );
  c.canvas.drawRRect(spine, ui.Paint()..color = _amber);
  c.canvas.drawRRect(spine, borderSoft);
  final stitch = ui.Paint()
    ..color = _paper
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 8 * s
    ..strokeCap = ui.StrokeCap.round;
  for (var y = 0; y < 5; y++) {
    final sy = 300 * s + y * 84 * s;
    c.canvas.drawLine(
      ui.Offset(291 * s, sy),
      ui.Offset(291 * s, sy + 34 * s),
      stitch,
    );
  }

  // Journal lines on the cover's right side — the page that waits.
  final line = ui.Paint()
    ..color = _ink.withValues(alpha: 0.8)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 13 * s
    ..strokeCap = ui.StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    final ly = 400 * s + i * 92 * s;
    final w = (i == 1 ? 300.0 : 250.0) * s;
    c.canvas.drawLine(
      ui.Offset(400 * s, ly),
      ui.Offset(400 * s + w, ly + 4 * s),
      line,
    );
  }
}

// -- painters ----------------------------------------------------------------

void _paperSquarePainter(_IconCanvas c) {
  c.canvas.drawRect(ui.Offset.zero & c.size, ui.Paint()..color = _paper);
  // A few paper flecks so it isn't a flat field.
  final rng = math.Random(11);
  final fleck = ui.Paint()..color = _ink.withValues(alpha: 0.05);
  for (var i = 0; i < 40; i++) {
    c.canvas.drawCircle(
      ui.Offset(rng.nextDouble() * c.size.width, rng.nextDouble() * c.size.height),
      1 + rng.nextDouble() * 2,
      fleck,
    );
  }
  _drawMark(c, scale: c.size.width / 1024);
}

void _maskablePainter(_IconCanvas c) {
  // Full-bleed paper; the mark shrinks into the center 80% safe zone so
  // Android's circular mask can't clip it.
  c.canvas.drawRect(ui.Offset.zero & c.size, ui.Paint()..color = _paper);
  final rng = math.Random(11);
  final fleck = ui.Paint()..color = _ink.withValues(alpha: 0.05);
  for (var i = 0; i < 40; i++) {
    c.canvas.drawCircle(
      ui.Offset(rng.nextDouble() * c.size.width, rng.nextDouble() * c.size.height),
      1 + rng.nextDouble() * 2,
      fleck,
    );
  }
  c.canvas.save();
  final s = c.size.width;
  c.canvas.translate(s / 2, s / 2);
  c.canvas.scale(0.78);
  c.canvas.translate(-s / 2, -s / 2);
  _drawMark(c, scale: s / 1024);
  c.canvas.restore();
}

void _narrowScreenshotPainter(_IconCanvas c) {
  final w = c.size.width;
  final h = c.size.height;
  c.canvas.drawRect(ui.Offset.zero & c.size, ui.Paint()..color = _paper);
  // Header: "Echo Bay" handwritten voice (ink strokes stand in for the
  // Caveat glyph — the generator runs outside the font bundle).
  final title = ui.Paint()
    ..color = _ink
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 22.0
    ..strokeCap = ui.StrokeCap.round;
  final t = ui.Path();
  _inkWord(t, ui.Offset(w * 0.12, h * 0.13), w * 0.42, 3);
  c.canvas.drawPath(t, title);
  final sub = ui.Paint()
    ..color = _ink.withValues(alpha: 0.5)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 10.0
    ..strokeCap = ui.StrokeCap.round;
  final st = ui.Path();
  _inkWord(st, ui.Offset(w * 0.12, h * 0.18), w * 0.3, 2);
  c.canvas.drawPath(st, sub);

  // A polaroid post card.
  final card = ui.RRect.fromRectAndRadius(
    ui.Rect.fromLTWH(w * 0.1, h * 0.24, w * 0.8, h * 0.5),
    const ui.Radius.circular(28),
  );
  c.canvas.drawRRect(card, ui.Paint()..color = const Color(0xFFFDFBF4));
  final border = ui.Paint()
    ..color = _ink
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 10.0;
  c.canvas.drawRRect(card, border);
  final photo = ui.Rect.fromLTWH(
      w * 0.15, h * 0.27, w * 0.7, h * 0.3);
  c.canvas.drawRect(photo, ui.Paint()..color = const Color(0xFFE7DCC4));
  // Sun-and-hills sketch inside the photo frame.
  final art = ui.Paint()
    ..color = _amber
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 9.0;
  c.canvas.drawCircle(
      ui.Offset(photo.left + photo.width * 0.7, photo.top + photo.height * 0.35),
      photo.width * 0.09, art);
  final hills = ui.Paint()
    ..color = _ink.withValues(alpha: 0.7)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 9.0
    ..strokeCap = ui.StrokeCap.round;
  final hill = ui.Path()
    ..moveTo(photo.left + 8, photo.bottom - 12)
    ..quadraticBezierTo(
      photo.left + photo.width * 0.35, photo.top + photo.height * 0.45,
      photo.left + photo.width * 0.55, photo.bottom - 12);
  c.canvas.drawPath(hill, hills);
  // Caption lines.
  for (final (i, cw) in const [(0, 0.6), (1, 0.42)]) {
    c.canvas.drawLine(
      ui.Offset(w * 0.15, h * 0.62 + i * 46),
      ui.Offset(w * (0.15 + cw), h * 0.62 + i * 46 + 6),
      hills..strokeWidth = 8.0,
    );
  }

  // Bottom: bay ripple + "made with Echo Bay" line.
  final wave = ui.Paint()
    ..color = _amber
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 12.0
    ..strokeCap = ui.StrokeCap.round;
  final wpath = ui.Path();
  _wave(wpath, ui.Offset(w * 0.5, h * 0.86), w * 0.16);
  c.canvas.drawPath(wpath, wave);
}

void _wideScreenshotPainter(_IconCanvas c) {
  final w = c.size.width;
  final h = c.size.height;
  c.canvas.drawRect(ui.Offset.zero & c.size, ui.Paint()..color = _paper);
  // Big cover mark on the left.
  c.canvas.save();
  c.canvas.translate(w * 0.06, h * 0.08);
  c.canvas.scale((h * 0.84) / 1024);
  _drawMark(_IconCanvas(c.canvas, const ui.Size(1024, 1024)), scale: 1.0);
  c.canvas.restore();
  // Wordmark lines on the right.
  final title = ui.Paint()
    ..color = _ink
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 26.0
    ..strokeCap = ui.StrokeCap.round;
  final t = ui.Path();
  _inkWord(t, ui.Offset(w * 0.52, h * 0.34), w * 0.34, 3);
  c.canvas.drawPath(t, title);
  final sub = ui.Paint()
    ..color = _ink.withValues(alpha: 0.5)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 12.0
    ..strokeCap = ui.StrokeCap.round;
  for (final (i, len) in const [(0, 0.24), (1, 0.18)]) {
    c.canvas.drawLine(
      ui.Offset(w * 0.52, h * 0.46 + i * 54),
      ui.Offset(w * (0.52 + len), h * 0.46 + i * 54 + 5),
      sub,
    );
  }
  final wave = ui.Paint()
    ..color = _amber
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 14.0
    ..strokeCap = ui.StrokeCap.round;
  final wpath = ui.Path();
  _wave(wpath, ui.Offset(w * 0.62, h * 0.68), w * 0.07);
  c.canvas.drawPath(wpath, wave);
}

// -- helpers: handwriting stand-ins -------------------------------------------

/// Draws [rounds] overlapping slightly-jittered strokes between p0 and
/// p1 — reads as ink handwriting at small sizes without font loading.
void _inkWord(ui.Path path, ui.Offset start, double width, int rounds) {
  final rng = math.Random(width.toInt());
  for (var r = 0; r < rounds; r++) {
    final y = start.dy + r * 10.0 - 10.0;
    path.moveTo(start.dx, y);
    final segments = 5;
    for (var i = 1; i <= segments; i++) {
      final t = i / segments;
      path.lineTo(
        start.dx + width * t + (rng.nextDouble() - 0.5) * 6,
        y + (rng.nextDouble() - 0.5) * 10,
      );
    }
  }
}

void _wave(ui.Path path, ui.Offset center, double radius) {
  path.moveTo(center.dx - radius, center.dy);
  for (var x = -radius; x <= radius; x += 6) {
    path.lineTo(center.dx + x, center.dy + math.sin(x / radius * math.pi * 2) * radius * 0.12);
  }
}

/// Thin wrapper so painters share one canvas + size without globals.
class _IconCanvas {
  _IconCanvas(this.canvas, this.size);
  final ui.Canvas canvas;
  final ui.Size size;
}
