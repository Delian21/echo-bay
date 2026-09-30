import 'dart:async';

import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../../core/io/platform_io.dart';
import '../entities/post.dart';

/// Renders a [Post] as a polaroid-style PNG on sepia paper: photo (or a
/// chalk placeholder when the post is text-only / media is remote),
/// caption in the handwritten voice, the date pencilled under it, and a
/// subtle "made with Echo Bay" corner mark.
///
/// The card is composed with plain Dart `ui` APIs (paragraphs, picture
/// recording) rather than a widget RepaintBoundary — no build context,
/// no on-screen dependency, deterministic output, and it works from
/// tests and on web identically. No dart:io; the bytes go back to the
/// caller (share sheet on mobile, download on web).
Future<Uint8List> renderPostShareCard(
  Post post, {
  double pixelRatio = 3.0,
}) async {
  const cardWidth = 420.0;
  const padding = 18.0;
  const paper = Color(0xFFF5EFE2); // warm sepia paper
  const ink = Color(0xFF2B2A26); // charcoal ink
  const polaroid = Color(0xFFFDFBF4);

  // Measure the caption first so the picture height fits the content.
  final caption = _paragraph(
    post.body,
    fontSize: 22,
    color: ink,
    maxWidth: cardWidth - padding * 2,
  );
  final captionHeight = caption.height.ceilToDouble();
  final photoHeight = post.hasMedia ? 300.0 : 40.0;
  final cardHeight = padding * 2 +
      photoHeight +
      14 +
      captionHeight +
      12 +
      22 /* date */ +
      8 +
      16 /* mark */;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Paper background.
  canvas.drawRect(
    Offset.zero & Size(cardWidth + 56, cardHeight + 56),
    Paint()..color = paper,
  );

  // Polaroid card with a hand-drawn-feeling charcoal border.
  final cardRect = const Offset(28, 28) & Size(cardWidth, cardHeight);
  final polaroidPaint = Paint()..color = polaroid;
  canvas.drawRect(cardRect, polaroidPaint);
  final border = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round;
  canvas.drawRRect(
    RRect.fromRectAndRadius(cardRect, const Radius.circular(6)),
    border,
  );

  var y = cardRect.top + padding;

  // Media: resolve the actual image through the IO seam (FileImage on
  // native, NetworkImage on web — both are just ImageProviders), with a
  // short timeout so a slow/missing photo degrades to the beige frame
  // instead of hanging the export. canvas.drawImageRect needs a decoded
  // ui.Image; the feed's own rendering has the same provider behind it.
  if (post.hasMedia) {
    final photoRect = Offset(cardRect.left + padding, y) &
        Size(cardWidth - padding * 2, photoHeight - 24);
    canvas.drawRect(photoRect, Paint()..color = const Color(0xFFE7DCC4));
    canvas.drawRect(
      photoRect.deflate(1),
      border..strokeWidth = 1.2,
    );
    final image = await _resolveImage(post.mediaUrl!)
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    if (image != null) {
      // Cover-fit: scale the decoded image to fill the photo rect,
      // centered, like the feed card's BoxFit.cover.
      final src = Rect.fromCenter(
        center: Offset(image.width / 2, image.height / 2),
        width: image.width.toDouble(),
        height: image.height.toDouble(),
      );
      final dst = photoRect;
      final srcFitted = _coverSrcRect(src, dst);
      // Clip so an over-tall photo doesn't bleed past the frame.
      canvas.save();
      canvas.clipRect(photoRect);
      canvas.drawImageRect(image, srcFitted, dst, Paint());
      canvas.restore();
      image.dispose();
    }
    y += photoHeight;
  } else {
    y += 40;
  }

  y += 14;
  // Caption.
  canvas.drawParagraph(
    caption,
    Offset(cardRect.left + padding, y),
  );
  y += captionHeight + 12;

  // Date, pencilled lighter.
  final date = _paragraph(
    '${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}',
    fontSize: 15,
    color: ink.withValues(alpha: 0.65),
    maxWidth: cardWidth - padding * 2,
  );
  canvas.drawParagraph(date, Offset(cardRect.left + padding, y));
  y += 30;

  // The corner mark: small, quiet, handwritten. No logos.
  final mark = _paragraph(
    'made with Echo Bay',
    fontSize: 11,
    color: ink.withValues(alpha: 0.4),
    maxWidth: cardWidth - padding * 2,
    alignRight: true,
    width: cardWidth - padding * 2,
  );
  canvas.drawParagraph(mark, Offset(cardRect.left + padding, cardRect.bottom - 22));

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (cardWidth + 56).toInt(),
    (cardHeight + 56).toInt(),
  );
  final byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

ui.Paragraph _paragraph(
  String text, {
  required double fontSize,
  required Color color,
  required double maxWidth,
  bool alignRight = false,
  double? width,
}) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      fontFamily: 'Caveat',
      fontSize: fontSize,
      textAlign: alignRight ? ui.TextAlign.right : ui.TextAlign.left,
    ),
  )
    ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize))
    ..addText(text);
  final paragraph = builder.build();
  paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
  return paragraph;
}

/// Cover-fit crop: the largest centered sub-rect of [src] with the same
/// aspect ratio as [dst]. Pure geometry — unit-testable without pixels.
Rect _coverSrcRect(Rect src, Rect dst) {
  final srcRatio = src.width / src.height;
  final dstRatio = dst.width / dst.height;
  if (srcRatio > dstRatio) {
    // Source is wider: crop the sides.
    final width = src.height * dstRatio;
    return Rect.fromCenter(
      center: src.center,
      width: width,
      height: src.height,
    );
  }
  // Source is taller: crop top/bottom.
  final height = src.width / dstRatio;
  return Rect.fromCenter(
    center: src.center,
    width: src.width,
    height: height,
  );
}

/// Decodes [url] (network URL or local file path) to a [ui.Image] via
/// the IO seam's provider. Completes with null if the stream errors
/// (missing file, offline, bad URL) — the caller falls back to the
/// placeholder frame.
Future<ui.Image?> _resolveImage(String url) async {
  final provider = platformImageProvider(url);
  final completer = Completer<ui.Image?>();
  final stream = provider.resolve(const ImageConfiguration());
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image);
    },
    onError: (_, __) {
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  stream.addListener(listener);
  try {
    return await completer.future;
  } finally {
    stream.removeListener(listener);
  }
}
