import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The sketch kit — the scratchy ink language from docs/ART_DIRECTION.md.
///
/// Everything here is **deterministic**: every wobble and scribble is
/// seeded from the element's identity (a post id, a slot index), so the
/// feed renders identically on every rebuild and nothing re-randomizes
/// or animates per frame. Scribble fills are authored path sets cached
/// as `ui.Picture`s; wobble amplitudes stay ≤1dp so content inside a
/// sketch box is never disturbed.

/// Deterministic RNG: same seed in, same strokes out, every build.
/// Public so feature-level custom painters (story rings, custom chalk
/// flourishes) share the exact stroke-noise character of the kit.
class SketchRng {
  SketchRng(int seed) : _state = seed == 0 ? 0x9E3779B9 : seed;
  int _state;

  double next() {
    // xorshift32, mapped to 0..1.
    var x = _state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    _state = x & 0x7FFFFFFF;
    if (_state == 0) _state = 1;
    return (_state & 0xFFFFFF) / 0x1000000;
  }
}

/// Internal alias kept short for the kit's own painters.
typedef _Seeded = SketchRng;

/// A clip path of a hand-drawn circle — same wobbly arc language as the
/// kit's chalk circles, but as a [CustomClipper] so avatars and status
/// media clip to an imperfect circle instead of a perfect [ClipOval].
class WobblyCircleClipper extends CustomClipper<Path> {
  const WobblyCircleClipper({this.seed = 5});

  final int seed;

  @override
  Path getClip(Size size) {
    final rng = SketchRng(seed * 13 + 7);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final path = Path();
    const steps = 40;
    // A slow oval drift (two-lobe sine) plus per-vertex chalk jitter —
    // the circle a hand draws, not a compass.
    for (var i = 0; i <= steps; i++) {
      final a = (2 * math.pi * i) / steps - math.pi / 2;
      final rr = radius -
          0.5 +
          0.9 * math.sin(a * 2 + seed * 0.21) +
          (rng.next() - 0.5) * 1.1;
      final p = Offset(
        center.dx + rr * math.cos(a),
        center.dy + rr * math.sin(a),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WobblyCircleClipper old) => old.seed != seed;
}

// ---------------------------------------------------------------------------
// Ink palette
// ---------------------------------------------------------------------------

/// The ink constants (docs/ART_DIRECTION.md §3). Charcoal, not black —
/// pure #000 kills the pen feel.
class SketchInk {
  const SketchInk._();

  static const charcoal = Color(0xFF2B2A26);
  static const chalk = Color(0xFFE8E4D8);
  static const rewindBlue = Color(0xFF5CE1E6);
  static const graffitiRed = Color(0xFFE0245E);
  static const markerYellow = Color(0xFFF5C518);

  /// Stroke color for the ambient brightness — context-free entry point.
  static Color of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? chalk : charcoal;
}

// ---------------------------------------------------------------------------
// Wobbly border — the notebook box
// ---------------------------------------------------------------------------

/// A container that draws its border as a hand-inked, slightly uneven
/// rounded rectangle. Wobble ≤1dp, deterministic per [seed]. Overlapping
/// second stroke at low alpha when [doubleStroke] — the pen went over
/// the line twice (large containers only).
///
/// The child's layout is untouched: only the painted border wobbles.
class SketchBox extends StatelessWidget {
  const SketchBox({
    super.key,
    required this.child,
    this.seed = 1,
    this.radius = 8,
    this.strokeWidth = 2,
    this.doubleStroke = false,
    this.color,
    this.fill,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final int seed;
  final double radius;
  final double strokeWidth;
  final bool doubleStroke;
  final Color? color;
  final Color? fill;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Two painters, stacked in the right order: the background painter
      // draws the paper fill BEHIND the child, the foreground painter
      // draws the wobbly border ON TOP of the child's edges. A single
      // foreground painter would paint the opaque fill over the content
      // (the blank-card bug).
      painter: fill != null
          ? _SketchFillPainter(
              seed: seed,
              radius: radius,
              fillColor: fill!,
            )
          : null,
      foregroundPainter: _WobblyBorderPainter(
        seed: seed,
        radius: radius,
        strokeWidth: strokeWidth,
        doubleStroke: doubleStroke,
        color: color ?? SketchInk.of(context),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Background painter: the paper fill only. Runs before the child.
class _SketchFillPainter extends CustomPainter {
  _SketchFillPainter({
    required this.seed,
    required this.radius,
    required this.fillColor,
  });

  final int seed;
  final double radius;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = _WobblyBorderPainter(
      seed: seed,
      radius: radius,
      strokeWidth: 0,
      doubleStroke: false,
      color: fillColor,
      fillColor: fillColor,
    );
    painter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _SketchFillPainter old) =>
      old.seed != seed ||
      old.radius != radius ||
      old.fillColor != fillColor;
}

class _WobblyBorderPainter extends CustomPainter {
  _WobblyBorderPainter({
    required this.seed,
    required this.radius,
    required this.strokeWidth,
    required this.doubleStroke,
    required this.color,
    this.fillColor,
  });

  final int seed;
  final double radius;
  final double strokeWidth;
  final bool doubleStroke;
  final Color color;
  final Color? fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    if (fillColor != null) {
      final fillPaint = Paint()..color = fillColor!;
      canvas.drawPath(
        _wobblyRRect(seed: seed, size: size, radius: radius, wobble: 0),
        fillPaint,
      );
    }

    canvas.drawPath(
      _wobblyRRect(seed: seed, size: size, radius: radius, wobble: 1.0),
      paint,
    );

    if (doubleStroke) {
      canvas.drawPath(
        _wobblyRRect(
          seed: seed + 7919,
          size: size,
          radius: radius,
          wobble: 1.2,
        ),
        paint..color = color.withValues(alpha: 0.35),
      );
    }
  }

  /// Rounded rectangle as a polyline of jittered points — the pen's path.
  /// [wobble] scales the per-point deviation (second stroke wobbles a
  /// touch more so the two lines diverge).
  Path _wobblyRRect({
    required int seed,
    required Size size,
    required double radius,
    required double wobble,
  }) {
    final rng = _Seeded(seed);
    final path = Path();
    const step = 9.0; // pen sampling density
    final w = size.width, h = size.height;
    final r = radius.clamp(2.0, math.min(w, h) / 2);

    Offset jitter(double x, double y) {
      final dx = (rng.next() - 0.5) * 2 * wobble;
      final dy = (rng.next() - 0.5) * 2 * wobble;
      return Offset(
        x.clamp(0.0, w) + dx,
        y.clamp(0.0, h) + dy,
      );
    }

    var first = true;
    void lineTo(Offset p) {
      if (first) {
        path.moveTo(p.dx, p.dy);
        first = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    // Top edge, corner arcs sampled as short segments — hand-drawn boxes
    // have slightly flat corners, which is exactly what sampling gives.
    for (var x = r; x < w - r; x += step) {
      lineTo(jitter(x, 0));
    }
    for (var a = -math.pi / 2; a < 0; a += step / r) {
      lineTo(jitter(w - r + r * math.cos(a), r + r * math.sin(a)));
    }
    for (var y = r; y < h - r; y += step) {
      lineTo(jitter(w, y));
    }
    for (var a = 0.0; a < math.pi / 2; a += step / r) {
      lineTo(jitter(w - r + r * math.cos(a), h - r + r * math.sin(a)));
    }
    for (var x = w - r; x > r; x -= step) {
      lineTo(jitter(x, h));
    }
    for (var a = math.pi / 2; a < math.pi; a += step / r) {
      lineTo(jitter(r + r * math.cos(a), h - r + r * math.sin(a)));
    }
    for (var y = h - r; y > r; y -= step) {
      lineTo(jitter(0, y));
    }
    for (var a = math.pi; a < math.pi * 1.5; a += step / r) {
      lineTo(jitter(r + r * math.cos(a), r + r * math.sin(a)));
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _WobblyBorderPainter old) =>
      old.seed != seed ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.doubleStroke != doubleStroke ||
      old.color != color ||
      old.fillColor != fillColor;
}

// ---------------------------------------------------------------------------
// Scribble fill — the selected/active state
// ---------------------------------------------------------------------------

/// Cross-hatch / scribble fill drawn inside [bounds-ish] of the given
/// [sketchPath]. Three authored variants (diagonal hatch, cross-hatch,
/// frantic loop), chosen deterministically by [seed], rendered once per
/// (path, variant, size, color) and cached as a `ui.Picture`.
class ScribbleFill extends StatelessWidget {
  const ScribbleFill({
    super.key,
    required this.sketchPath,
    this.seed = 1,
    this.color = SketchInk.graffitiRed,
    this.opacity = 0.40,
    this.density = 5.0,
  });

  /// Fill region. Reuse the icon's own outline path so the scribble
  /// stays exactly inside the drawn shape.
  final Path sketchPath;
  final int seed;
  final Color color;
  final double opacity;
  final double density;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScribbleFillPainter(
        sketchPath: sketchPath,
        seed: seed,
        color: color.withValues(alpha: opacity),
        density: density,
      ),
    );
  }
}

class _ScribbleFillPainter extends CustomPainter {
  _ScribbleFillPainter({
    required this.sketchPath,
    required this.seed,
    required this.color,
    required this.density,
  });

  final Path sketchPath;
  final int seed;
  final Color color;
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    final picture = _scribblePicture(
      sketchPath: sketchPath,
      seed: seed,
      color: color,
      density: density,
      bounds: size,
    );
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(covariant _ScribbleFillPainter old) =>
      old.seed != seed || old.color != color || old.density != density;
}

/// The three fill variants (docs/ART_DIRECTION.md §1). Authored strokes,
/// clipped to the shape's own path.
ui.Picture _scribblePicture({
  required Path sketchPath,
  required int seed,
  required Color color,
  required double density,
  required Size bounds,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.clipPath(sketchPath);

  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round
    ..color = color;

  final rng = _Seeded(seed);
  final variant = seed % 3;

  switch (variant) {
    case 0: // diagonal hatch with slight angle drift
      for (var d = -bounds.height; d < bounds.width + bounds.height; d += density) {
        final drift = (rng.next() - 0.5) * 2;
        canvas.drawLine(Offset(d + drift, 0), Offset(d - drift, bounds.height), paint);
      }
    case 1: // cross-hatch
      for (var d = -bounds.height; d < bounds.width + bounds.height; d += density) {
        canvas.drawLine(Offset(d, 0), Offset(d + 4, bounds.height), paint);
      }
      for (var d = -bounds.width; d < bounds.width + bounds.height; d += density * 1.4) {
        canvas.drawLine(Offset(d, 0), Offset(d - 4, bounds.height), paint);
      }
    default: // frantic loop — chaotic connected zigzag, the "frantic" one
      var x = 0.0;
      var y = 0.0;
      final loop = Path()..moveTo(0, 0);
      while (y < bounds.height) {
        x = rng.next() * bounds.width;
        y += density * (0.6 + rng.next());
        loop.lineTo(x, y);
      }
      canvas.drawPath(loop, paint);
  }

  return recorder.endRecording();
}

// ---------------------------------------------------------------------------
// The five sketch icons
// ---------------------------------------------------------------------------

/// Which of the hand-inked icons to draw.
enum SketchIconKind {
  scribbleHeart,
  rewindSpiral,
  xHeart,
  jaggedBubble,
  paperPlane,
  playTriangle,
  scribbleMic,
  slateGrid,
  padlock,
  spiralHub,
  handset,
  cog,
  megaphone,
  threeHeads,
  personGlyph,
  searchGlass,
  plusCircle,
  infoMark,
  photoFrame,
  videoCam,
  clockTick,
  singleTick,
  doubleTick,
  refreshLoop,
  plusBubble,
  dialPad,
  arrowDownLeft,
  arrowUpRight,
  arrowMissed,
  speakerWave,
  micOff,
  hangUp,
  arrowBack,
  closeX,
  brokenImage,
  sunMark,
  moonCrescent,
  autoA,
}

/// The five icon set (docs/ART_DIRECTION.md §2), drawn as raw paths with
/// the deterministic wobble. [filled] cross-hatch-fills the shape in
/// [accentColor] — the scribble-fill selection state.
class SketchIcon extends StatelessWidget {
  const SketchIcon({
    super.key,
    required this.kind,
    this.size = 22,
    this.color,
    this.filled = false,
    this.accentColor = SketchInk.graffitiRed,
    this.seed = 1,
  });

  final SketchIconKind kind;
  final double size;
  final Color? color;
  final bool filled;
  final Color accentColor;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final stroke = color ?? SketchInk.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SketchIconPainter(
          kind: kind,
          seed: seed,
          stroke: stroke,
          filled: filled,
          accent: accentColor,
        ),
      ),
    );
  }
}

class _SketchIconPainter extends CustomPainter {
  _SketchIconPainter({
    required this.kind,
    required this.seed,
    required this.stroke,
    required this.filled,
    required this.accent,
  });

  final SketchIconKind kind;
  final int seed;
  final Color stroke;
  final bool filled;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24; // authored in a 24×24 grid
    canvas.scale(s, s);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = stroke;

    final path = _iconPath(kind, seed);
    if (filled) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = accent.withValues(alpha: 0.40);
      final fillPic = _scribblePicture(
        sketchPath: path,
        seed: seed,
        color: accent.withValues(alpha: 0.55),
        density: 3.2,
        bounds: const Size(24, 24),
      );
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPicture(fillPic);
      canvas.restore();
      // Fill hint under the stroke keeps the silhouette solid enough.
      canvas.drawPath(path, fill);
    }

    // Chalk pass: one bold stroke, then a lighter, *differently wobbling*
    // overdraw that drifts off the first — the chalk caught the slate
    // unevenly and the hand went over the gesture again. Two passes of
    // the same path with different jitter read as hand pressure, not as
    // a duplicated vector.
    canvas.drawPath(path, paint);
    canvas.save();
    canvas.translate(0.5, -0.35);
    final ghost = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = stroke.withValues(alpha: 0.38);
    canvas.drawPath(_iconPath(kind, seed * 17 + 101), ghost);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SketchIconPainter old) =>
      old.kind != kind ||
      old.seed != seed ||
      old.stroke != stroke ||
      old.filled != filled ||
      old.accent != accent;
}

/// A chrome-level icon (nav rail, tabs, settings tiles) drawn in the
/// sketch kit. Where [SketchIcon] is the content layer's ink voice
/// gated on the analog layer, chrome navigation should always carry
/// the chalk identity — a chalk app with Material glyphs in the rail
/// reads half-finished — so [SketchGlyph] defaults to always-on and
/// picks chalk-on-dark / charcoal-on-light itself. A theme can still
/// turn it off for accessibility audits.
class SketchGlyph extends StatelessWidget {
  const SketchGlyph({
    super.key,
    required this.kind,
    this.size = 24,
    this.color,
    this.alwaysInk = true,
    this.seed = 7,
  });

  final SketchIconKind kind;
  final double size;
  final Color? color;

  /// False: fall back to nothing drawn (caller should render a Material
  /// alternative) when the analog layer is off.
  final bool alwaysInk;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    if (!golden.enabled && !alwaysInk) return const SizedBox.shrink();
    return SketchIcon(
      kind: kind,
      size: size,
      color: color ?? SketchInk.of(context),
      seed: seed,
    );
  }
}

/// Authored icon outlines in a 24×24 grid, with deterministic jitter.
/// Chalk-on-slate roughness: every vertex drifts hard (0.9–1.6 units of
/// 24 — a pencil line doesn't hit its mark), and control points wobble
/// independently of endpoints so curves sag like real hand pressure.
Path _iconPath(SketchIconKind kind, int seed) {
  final rng = _Seeded(seed * 31 + kind.index);
  final path = Path();

  Offset j(double x, double y, [double wobble = 1.0]) => Offset(
        x + (rng.next() - 0.5) * 2 * wobble,
        y + (rng.next() - 0.5) * 2 * wobble,
      );

  void moveTo(Offset p) => path.moveTo(p.dx, p.dy);
  void lineTo(Offset p) => path.lineTo(p.dx, p.dy);
  void cubicTo(Offset a, Offset b, Offset c) =>
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);

  /// Wobbly four-sided rect used by the grid tile + padlock body.
  void rect(Offset a, Offset b) {
    moveTo(a);
    lineTo(Offset(b.dx, a.dy));
    lineTo(b);
    lineTo(Offset(a.dx, b.dy));
    path.close();
  }

  /// Wobbly circle as jittered arc segments — a compass the hand
  /// slipped on.
  void circle(Offset c, double radius) {
    const steps = 28;
    moveTo(j(c.dx + radius, c.dy, 0.7));
    for (var i = 1; i <= steps; i++) {
      final a = (2 * math.pi * i) / steps;
      lineTo(j(
        c.dx + radius * math.cos(a),
        c.dy + radius * math.sin(a),
        0.7,
      ));
    }
  }

  switch (kind) {
    case SketchIconKind.scribbleHeart:
    case SketchIconKind.xHeart:
      // Rough heart: two lobes meeting at a point, all points jittered.
      // Control points sag twice as hard as anchors — a soft chalk lobe.
      Offset soft(double x, double y) => j(x, y, 2.1);
      moveTo(j(12, 21));
      cubicTo(soft(6, 18), soft(2, 14), j(2, 10.5));
      cubicTo(soft(2, 6.5), soft(7, 3), j(12, 6.5));
      cubicTo(soft(17, 3), soft(22, 6.5), j(22, 10.5));
      cubicTo(soft(22, 14), soft(18, 18), j(12, 21));
      path.close();
      if (kind == SketchIconKind.xHeart) {
        // Aggressive pen X scratched through — two overlapping strokes.
        moveTo(j(5, 5, 1.2));
        lineTo(j(19, 19, 1.2));
        moveTo(j(19, 5, 1.2));
        lineTo(j(5, 19, 1.2));
      }
    case SketchIconKind.rewindSpiral:
      // Continuous messy loop, center outward: the arc radii grow with
      // jittered deltas, one unbroken pen stroke. The loop gaps on
      // purpose — the spiral doesn't close on itself cleanly.
      const turns = 3;
      const steps = 64;
      var radius = 1.5;
      var angle = 0.0;
      moveTo(j(12 + radius, 12, 0.5));
      for (var i = 0; i < turns * steps; i++) {
        angle += (2 * math.pi) / steps;
        radius += 10.0 / (turns * steps);
        lineTo(j(
          12 + radius * math.cos(angle),
          12 + radius * math.sin(angle),
          0.85,
        ));
      }
    case SketchIconKind.jaggedBubble:
      // Comic-book bubble: sharp corners, uneven tail.
      moveTo(j(3, 4, 1.2));
      lineTo(j(21, 3, 1.3));
      lineTo(j(21.5, 14, 1.3));
      lineTo(j(9, 14, 1.1));
      lineTo(j(5, 20, 1.3)); // tail
      lineTo(j(8, 14, 1.0));
      lineTo(j(3, 15, 1.3));
      path.close();
    case SketchIconKind.paperPlane:
      // Simplified fold-line sketch.
      moveTo(j(2, 12, 1.1));
      lineTo(j(22, 3, 1.2));
      lineTo(j(14, 21, 1.2));
      lineTo(j(10, 14, 1.0));
      lineTo(j(2, 12)); // base fold
      path.close();
      // Inner fold lines (unclosed strokes).
      moveTo(j(10, 14, 0.9));
      lineTo(j(22, 3, 1.1));
    case SketchIconKind.playTriangle:
      // YouTube-style rounded play mark: a chunky triangle that misses
      // its corners, drawn twice by the chalk pass.
      moveTo(j(8, 5.5, 1.1));
      lineTo(j(18.5, 11, 1.2));
      lineTo(j(18.5, 13, 1.1));
      lineTo(j(8, 18.5, 1.2));
      lineTo(j(7.2, 12, 0.9));
      path.close();
    case SketchIconKind.scribbleMic:
      // Hand-drawn mic: capsule head, open stand legs, wobbly base line.
      moveTo(j(9, 4, 1.0));
      cubicTo(j(9, 3, 1.2), j(15, 3, 1.2), j(15, 4, 1.0));
      lineTo(j(15, 11, 1.1));
      cubicTo(j(15, 13.5, 1.2), j(9, 13.5, 1.2), j(9, 11, 1.0));
      path.close();
      // Stand: hook down and around.
      moveTo(j(6.5, 10, 1.0));
      cubicTo(j(6.5, 16, 1.2), j(17.5, 16, 1.2), j(17.5, 10, 1.0));
      moveTo(j(12, 16.5, 0.8));
      lineTo(j(12, 19.5, 1.0));
      moveTo(j(8.5, 20.5, 1.0));
      lineTo(j(15.5, 20.5, 1.0));
    case SketchIconKind.slateGrid:
      // The Square: four chalk tiles, none quite the same size.
      rect(j(4, 4, 1.1), j(10.5, 10.5, 1.2));
      rect(j(13.5, 4.5, 1.2), j(20, 10, 1.1));
      rect(j(4.5, 13.5, 1.2), j(10, 20, 1.1));
      rect(j(13, 13, 1.1), j(19.5, 19.5, 1.2));
    case SketchIconKind.padlock:
      // The Vault: shackle loop + chalk body with a keyhole cross.
      moveTo(j(7.5, 11, 1.0));
      lineTo(j(7.5, 8.5, 1.2));
      cubicTo(j(7.5, 4.5, 1.2), j(16.5, 4.5, 1.2), j(16.5, 8.5, 1.0));
      lineTo(j(16.5, 11, 1.1));
      rect(j(5, 11, 1.2), j(19, 20, 1.2));
      moveTo(j(12, 14.5, 0.7));
      lineTo(j(12, 17.5, 0.8));
    case SketchIconKind.spiralHub:
      // The Hallway: a corridor drawn in perspective — outer doorframe
      // converging to a smaller inner frame at the far end, the way a
      // hallway gets sketched in a journal. Deliberately architectural
      // (a place you walk through), not a network hub.
      // Outer frame.
      rect(j(3, 3.5, 1.2), j(21, 20.5, 1.2));
      // Perspective rails: corners of the outer frame to the inner one.
      moveTo(j(3, 3.5, 0.9));
      lineTo(j(8, 8.5, 1.0));
      moveTo(j(21, 3.5, 0.9));
      lineTo(j(16, 8.5, 1.0));
      moveTo(j(21, 20.5, 0.9));
      lineTo(j(16, 15, 1.0));
      moveTo(j(3, 20.5, 0.9));
      lineTo(j(8, 15, 1.0));
      // Inner frame — the far end of the corridor, slightly off-center
      // (the corridor never runs perfectly true).
      rect(j(8, 8.5, 1.0), j(16, 15, 1.0));
      // Door handle on the inner frame, a small chalk tick.
      moveTo(j(14.3, 12, 0.5));
      lineTo(j(14.3, 13.2, 0.5));
    case SketchIconKind.handset:
      // The Landline: chunky old handset, receiver + mouthpiece blobs.
      moveTo(j(4.5, 8, 1.1));
      cubicTo(j(4, 5.5, 1.2), j(7, 4, 1.1), j(9, 5, 1.0));
      lineTo(j(10.5, 9.5, 1.0));
      cubicTo(j(8, 11.5, 1.0), j(12.5, 16, 1.1), j(14.5, 13.5, 1.0));
      lineTo(j(19, 15, 1.1));
      cubicTo(j(20, 17, 1.2), j(18.5, 20, 1.1), j(16, 19.5, 1.0));
      cubicTo(j(9, 18, 1.3), j(6, 15, 1.2), j(4.5, 8, 1.1));
    case SketchIconKind.cog:
      // Settings: eight blunt teeth around a wobbly ring, off-center
      // the way a compass-drawn circle never is.
      const teeth = 8;
      for (var t = 0; t < teeth; t++) {
        final a0 = (2 * math.pi * t) / teeth - 0.22;
        final a1 = (2 * math.pi * t) / teeth + 0.22;
        moveTo(j(12 + 9.5 * math.cos(a0), 12 + 9.5 * math.sin(a0), 0.7));
        lineTo(j(12 + 12.2 * math.cos(a0), 12 + 12.2 * math.sin(a0), 0.8));
        lineTo(j(12 + 12.2 * math.cos(a1), 12 + 12.2 * math.sin(a1), 0.8));
        lineTo(j(12 + 9.5 * math.cos(a1), 12 + 9.5 * math.sin(a1), 0.7));
      }
      // Body ring, drawn as jittered arc segments so it breathes.
      const ringSteps = 40;
      moveTo(j(12 + 9.5, 12, 0.6));
      for (var i = 1; i <= ringSteps; i++) {
        final a = (2 * math.pi * i) / ringSteps;
        lineTo(j(12 + 9.5 * math.cos(a), 12 + 9.5 * math.sin(a), 0.6));
      }
    case SketchIconKind.megaphone:
      // The Board: hand-drawn bullhorn with sound strokes.
      moveTo(j(4, 10, 1.0));
      lineTo(j(13, 5.5, 1.1));
      lineTo(j(13, 17.5, 1.1));
      lineTo(j(4, 13.5, 1.0));
      path.close();
      moveTo(j(13, 7.5, 0.9));
      lineTo(j(18, 5, 1.1));
      lineTo(j(18, 18, 1.1));
      lineTo(j(13, 15.5, 0.9));
      moveTo(j(6, 14, 0.9));
      lineTo(j(7, 19.5, 1.0));
      lineTo(j(10, 19, 1.0));
      lineTo(j(9.2, 15.5, 0.9));
      moveTo(j(20.5, 9, 0.8));
      lineTo(j(22, 7.5, 0.9));
      moveTo(j(21, 12, 0.8));
      lineTo(j(22.5, 12, 0.9));
      moveTo(j(20.5, 15, 0.8));
      lineTo(j(22, 16.5, 0.9));
    case SketchIconKind.threeHeads:
      // Dorms: three chalk circle heads over a shared bench line.
      circle(j(6, 8, 1.0), 2.6);
      circle(j(18, 8, 1.0), 2.6);
      circle(j(12, 6.5, 1.0), 2.8);
      moveTo(j(2.5, 17, 1.0));
      cubicTo(j(4, 13.5, 1.2), j(8, 13.5, 1.1), j(9.5, 17, 1.0));
      moveTo(j(14.5, 17, 1.0));
      cubicTo(j(16, 13.5, 1.2), j(20, 13.5, 1.1), j(21.5, 17, 1.0));
      moveTo(j(7.5, 19.5, 1.0));
      cubicTo(j(9, 15, 1.2), j(15, 15, 1.2), j(16.5, 19.5, 1.0));
    case SketchIconKind.personGlyph:
      // Profile: head loop + shoulder arc.
      circle(j(12, 7.5, 1.0), 3.4);
      moveTo(j(4.5, 20, 1.0));
      cubicTo(j(6, 13.5, 1.2), j(18, 13.5, 1.2), j(19.5, 20, 1.0));
    case SketchIconKind.searchGlass:
      // Search: wobbly loop + handle.
      circle(j(10.5, 10.5, 1.0), 6.2);
      moveTo(j(15.5, 15.5, 0.9));
      lineTo(j(20.5, 20.5, 1.0));
    case SketchIconKind.plusCircle:
      // New post: circle + scratched plus, arms uneven.
      circle(j(12, 12, 1.0), 9.2);
      moveTo(j(12, 7.5, 0.9));
      lineTo(j(12, 16.5, 0.9));
      moveTo(j(7.5, 12, 0.9));
      lineTo(j(16.5, 12, 0.9));
    case SketchIconKind.infoMark:
      // About: circle, dot, stem — the "i" drawn twice by the chalk pass.
      circle(j(12, 12, 1.0), 9.2);
      moveTo(j(12, 6.5, 0.6));
      lineTo(j(12, 7.2, 0.6));
      moveTo(j(12, 10.5, 0.7));
      lineTo(j(12, 17, 0.8));
    case SketchIconKind.photoFrame:
      // Attach photo: chalk frame with mountain + sun, postcard-style.
      rect(j(3.5, 5, 1.1), j(20.5, 19, 1.1));
      moveTo(j(6.5, 15.5, 0.9));
      lineTo(j(10.5, 10, 1.0));
      lineTo(j(13.5, 13.5, 0.9));
      lineTo(j(16, 11, 1.0));
      lineTo(j(18.5, 15.5, 0.9));
      moveTo(j(15.5, 8.8, 0.5));
      lineTo(j(15.6, 8.9, 0.5));
    case SketchIconKind.videoCam:
      // Attach video: camera body + wobbly lens wedge.
      rect(j(3.5, 7, 1.1), j(14.5, 17, 1.1));
      moveTo(j(14.5, 10.5, 0.9));
      lineTo(j(20.5, 7.5, 1.0));
      lineTo(j(20.5, 16.5, 1.0));
      lineTo(j(14.5, 13.5, 0.9));
    case SketchIconKind.clockTick:
      // Pending status: the clock face, hands at a lazy angle.
      circle(j(12, 12, 0.9), 8.8);
      moveTo(j(12, 12, 0.5));
      lineTo(j(12, 7.5, 0.6));
      moveTo(j(12, 12, 0.5));
      lineTo(j(15.2, 13.8, 0.6));
    case SketchIconKind.singleTick:
      // Sent status: one pen check.
      moveTo(j(5, 13, 0.9));
      cubicTo(j(8, 15.5, 1.0), j(9.5, 17.5, 1.0), j(10.5, 18, 0.8));
      moveTo(j(10.5, 18, 0.8));
      cubicTo(j(13, 12.5, 1.0), j(17, 7.5, 1.0), j(19.5, 5, 0.9));
    case SketchIconKind.doubleTick:
      // Delivered/read: the two overlapping checks.
      moveTo(j(2.5, 13, 0.8));
      cubicTo(j(5, 15, 0.9), j(6.5, 17, 0.9), j(7.5, 17.5, 0.8));
      moveTo(j(7.5, 17.5, 0.8));
      cubicTo(j(9.5, 12.5, 0.9), j(12.5, 8.5, 0.9), j(14.5, 6, 0.8));
      moveTo(j(8.5, 13.5, 0.8));
      cubicTo(j(11, 15.5, 0.9), j(12.5, 17, 0.9), j(13.5, 17.5, 0.8));
      moveTo(j(13.5, 17.5, 0.8));
      cubicTo(j(15.5, 12.5, 0.9), j(18.5, 8.5, 0.9), j(21, 6, 0.8));
    case SketchIconKind.refreshLoop:
      // Refresh: open circle with a chalk arrowhead — the hand drew the
      // loop and couldn't quite close it.
      moveTo(j(19.2, 7.5, 0.8));
      for (var i = 1; i <= 22; i++) {
        final a = -math.pi * 0.65 + (2 * math.pi * 0.82) * i / 22;
        lineTo(j(12 + 8.5 * math.cos(a), 12 + 8.5 * math.sin(a), 0.8));
      }
      moveTo(j(19.2, 7.5, 0.7));
      lineTo(j(20.8, 11.2, 0.8));
      moveTo(j(19.2, 7.5, 0.7));
      lineTo(j(15.4, 7.2, 0.8));
    case SketchIconKind.plusBubble:
      // New conversation: speech bubble with a scratched plus.
      rect(j(3.5, 4.5, 1.1), j(20.5, 15.5, 1.1));
      moveTo(j(8, 15.5, 0.9));
      lineTo(j(7, 20, 1.0));
      lineTo(j(12.5, 15.5, 0.9));
      moveTo(j(12, 7, 0.8));
      lineTo(j(12, 13, 0.8));
      moveTo(j(9, 10, 0.8));
      lineTo(j(15, 10, 0.8));
    case SketchIconKind.dialPad:
      // Landline dialpad: nine chalk dots, none perfectly round.
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          circle(j(6 + c * 6, 6 + r * 6, 0.8), 1.15);
        }
      }
    case SketchIconKind.arrowDownLeft:
      // Incoming call: chalk arrow into the corner.
      moveTo(j(17.5, 6.5, 0.9));
      lineTo(j(7, 17, 1.0));
      moveTo(j(7, 17, 0.9));
      lineTo(j(7, 10.5, 0.8));
      moveTo(j(7, 17, 0.9));
      lineTo(j(13.5, 17, 0.8));
    case SketchIconKind.arrowUpRight:
      // Outgoing call: chalk arrow out of the corner.
      moveTo(j(6.5, 17.5, 0.9));
      lineTo(j(17, 7, 1.0));
      moveTo(j(17, 7, 0.9));
      lineTo(j(17, 13.5, 0.8));
      moveTo(j(17, 7, 0.9));
      lineTo(j(10.5, 7, 0.8));
    case SketchIconKind.arrowMissed:
      // Missed call: incoming arrow with a scratched slash through it.
      moveTo(j(17.5, 8.5, 0.9));
      lineTo(j(7, 19, 1.0));
      moveTo(j(7, 19, 0.9));
      lineTo(j(7, 12.5, 0.8));
      moveTo(j(7, 19, 0.9));
      lineTo(j(13.5, 19, 0.8));
      moveTo(j(5.5, 4.5, 0.9));
      lineTo(j(18.5, 17.5, 1.0));
    case SketchIconKind.speakerWave:
      // Speaker: chalk horn + two sound arcs.
      moveTo(j(4, 9.5, 0.9));
      lineTo(j(8.5, 9.5, 0.8));
      lineTo(j(14, 5, 1.0));
      lineTo(j(14, 19, 1.0));
      lineTo(j(8.5, 14.5, 0.8));
      lineTo(j(4, 14.5, 0.9));
      path.close();
      moveTo(j(17, 9, 0.8));
      cubicTo(j(18.5, 10.5, 0.9), j(18.5, 13.5, 0.9), j(17, 15, 0.8));
      moveTo(j(19.5, 6.5, 0.8));
      cubicTo(j(22, 9, 0.9), j(22, 15, 0.9), j(19.5, 17.5, 0.8));
    case SketchIconKind.micOff:
      // Mute: the mic with a slash through it.
      moveTo(j(9, 4, 1.0));
      cubicTo(j(9, 3, 1.2), j(15, 3, 1.2), j(15, 4, 1.0));
      lineTo(j(15, 11, 1.1));
      cubicTo(j(15, 13.5, 1.2), j(9, 13.5, 1.2), j(9, 11, 1.0));
      path.close();
      moveTo(j(6.5, 10, 1.0));
      cubicTo(j(6.5, 16, 1.2), j(17.5, 16, 1.2), j(17.5, 10, 1.0));
      moveTo(j(12, 16.5, 0.8));
      lineTo(j(12, 19.5, 1.0));
      moveTo(j(8.5, 20.5, 1.0));
      lineTo(j(15.5, 20.5, 1.0));
      moveTo(j(5, 4, 0.9));
      lineTo(j(19, 19.5, 1.0));
    case SketchIconKind.hangUp:
      // End call: the handset laid down across a chalk cross.
      moveTo(j(4.5, 14, 1.0));
      cubicTo(j(8, 9.5, 1.3), j(16, 9.5, 1.3), j(19.5, 14, 1.0));
      cubicTo(j(20.5, 15.2, 1.1), j(19, 16.8, 1.0), j(17.6, 16, 0.9));
      cubicTo(j(14.5, 13.8, 1.1), j(9.5, 13.8, 1.1), j(6.4, 16, 0.9));
      cubicTo(j(5, 16.8, 1.0), j(3.5, 15.2, 1.0), j(4.5, 14, 1.0));
      moveTo(j(8.5, 18.5, 0.9));
      lineTo(j(15.5, 18.5, 1.0));
    case SketchIconKind.arrowBack:
      // Back: chalk arrow pointing left, uneven head.
      moveTo(j(19, 12, 0.9));
      lineTo(j(5, 12, 1.0));
      moveTo(j(5, 12, 0.9));
      lineTo(j(11, 6, 1.0));
      moveTo(j(5, 12, 0.9));
      lineTo(j(11, 18, 1.0));
    case SketchIconKind.closeX:
      // Close: the pen X, scratched slightly past its corners.
      moveTo(j(5.5, 5.5, 1.0));
      lineTo(j(18.5, 18.5, 1.1));
      moveTo(j(18.5, 5.5, 1.0));
      lineTo(j(5.5, 18.5, 1.1));
    case SketchIconKind.brokenImage:
      // Failed image: frame with a torn diagonal + sun.
      rect(j(3.5, 5, 1.1), j(20.5, 19, 1.1));
      moveTo(j(3.5, 5, 0.9));
      lineTo(j(9, 11, 0.8));
      lineTo(j(7, 13, 0.8));
      lineTo(j(14, 19, 0.8));
      moveTo(j(15.5, 8.8, 0.5));
      lineTo(j(15.6, 8.9, 0.5));
    case SketchIconKind.sunMark:
      // Light mode: wobbly disc + hand-drawn rays of uneven length.
      circle(j(12, 12, 0.9), 4.4);
      for (var i = 0; i < 8; i++) {
        final a = (2 * math.pi * i) / 8;
        final inner = 6.6 + rng.next() * 0.6;
        final outer = 9.6 + rng.next() * 1.4;
        moveTo(j(12 + inner * math.cos(a), 12 + inner * math.sin(a), 0.6));
        lineTo(j(12 + outer * math.cos(a), 12 + outer * math.sin(a), 0.7));
      }
    case SketchIconKind.moonCrescent:
      // Dark mode: crescent from two offset arcs.
      moveTo(j(14.5, 4.5, 1.0));
      cubicTo(j(8, 6, 1.2), j(7, 17, 1.2), j(14.5, 19.5, 1.0));
      cubicTo(j(18, 15, 1.2), j(18, 9, 1.1), j(14.5, 4.5, 1.0));
      path.close();
    case SketchIconKind.autoA:
      // System mode: circle with a chalk A — the theme follows the OS.
      circle(j(12, 12, 0.9), 9.0);
      moveTo(j(8.5, 16.5, 0.8));
      lineTo(j(12, 7, 0.9));
      lineTo(j(15.5, 16.5, 0.8));
      moveTo(j(9.8, 13.5, 0.6));
      lineTo(j(14.2, 13.5, 0.6));
  }
  return path;
}
