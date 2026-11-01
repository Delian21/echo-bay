import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;

import '../../../core/design_system/polaroid_frame.dart';
import '../../../core/io/platform_io.dart';
import '../../../core/profile/handles.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/entities/post.dart';

/// The exported image is composed at this logical size and captured at
/// [kShareCardPixelRatio]× — 360 × 3 = exactly 1080 px wide, 450 × 3 =
/// 1350 px tall, the 4:5 portrait frame stories and WhatsApp expect.
const double kShareCardWidth = 360;
const double kShareCardHeight = 450;
const double kShareCardPixelRatio = 3;

/// A share card could not be prepared: the photo never decoded, the
/// canvas was tainted by a cross-origin image, or the capture failed.
/// The UI turns this into one plain-language line, never a stack trace.
class ShareCardException implements Exception {
  const ShareCardException(this.cause);

  final Object? cause;

  @override
  String toString() => 'ShareCardException($cause)';
}

/// The printable card: a cream page carrying the post's polaroid (or, for
/// a text-only post, a handwritten note card), the author's name and
/// @handle, and the Echo Bay footer.
///
/// Deliberately theme-independent — the same light-paper print comes out
/// whichever theme the app is in, so a shared image never depends on the
/// sender's settings. Fixed size: the exporter captures it 1:1.
class PostShareCard extends StatelessWidget {
  const PostShareCard({super.key, required this.post, this.image});

  final Post post;

  /// Overrides the post's own media provider — for previews and tests that
  /// hand over bytes they already hold. Null uses [platformImageProvider].
  final ImageProvider? image;

  /// Warm cream page (light-theme paper tones, by design in both themes).
  static const Color paper = Color(0xFFF6EEE0);

  /// Slightly lighter card stock for the text-only note.
  static const Color cardStock = Color(0xFFFCF7EC);

  /// Charcoal ink, matching the polaroid's caption ink.
  static const Color ink = Color(0xFF2B2A26);

  /// The app's default golden-hour accent, used for the date stamp.
  static const Color accent = Color(0xFFD98324);

  static const String site = 'echo-bay.netlify.app';

  String get _handle => handleForName(post.authorName);

  String get _semanticLabel {
    final caption = post.body.trim();
    return caption.isEmpty
        ? 'Share card by ${post.authorName}'
        : 'Share card by ${post.authorName}: $caption';
  }

  @override
  Widget build(BuildContext context) {
    // A light theme is supplied explicitly so the polaroid's date stamp and
    // shadow do not inherit the running app's dark-mode treatment.
    return Theme(
      data: buildGoldenHourLightTheme(accent),
      child: SizedBox(
        width: kShareCardWidth,
        height: kShareCardHeight,
        child: Semantics(
          container: true,
          image: true,
          label: _semanticLabel,
          child: ColoredBox(
            color: paper,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      // scaleDown, never up: a long caption shrinks the
                      // print a touch instead of pushing the footer off.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: post.hasMedia ? _print() : _note(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 20,
                      height: 1.2,
                      color: ink,
                    ),
                  ),
                  Text(
                    '@$_handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 13,
                      height: 1.3,
                      color: ink.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Echo Bay',
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 15,
                      height: 1.25,
                      color: accent,
                    ),
                  ),
                  const Text(
                    site,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      letterSpacing: 0.2,
                      color: Color(0x992B2A26),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Photo post: the same print the feed shows, with room for four lines of
  /// pencilled caption before it ellipsizes.
  Widget _print() => PolaroidFrame(
        image: image ?? platformImageProvider(post.mediaUrl!),
        caption: post.body,
        date: post.createdAt,
        author: post.authorName,
        width: 190,
        aspectRatio: 4 / 5,
        maxCaptionLines: 4,
        seed: post.id.hashCode,
      );

  /// Text-only post: the words become the picture — a large handwritten
  /// note on a sheet of card stock, capped at four lines.
  Widget _note() => Transform.rotate(
        angle: 0.012, // ~0.7°, the same "placed by hand" language
        child: Container(
          width: 250,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: cardStock,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                post.body.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: kHandwrittenTextStyle.copyWith(
                  fontSize: 24,
                  height: 1.25,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _stamp(post.createdAt),
                  style: kHandwrittenTextStyle.copyWith(
                    fontSize: 13,
                    color: accent.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _stamp(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}';
}

/// Renders [post] to PNG bytes for sharing, at exactly 1080 × 1350.
///
/// 1. The bundled handwriting face is loaded, so the card never captures a
///    fallback font.
/// 2. A photo post's image is fully resolved and decoded into the image
///    cache, so the capture never shows a loading well.
/// 3. [PostShareCard] is mounted offscreen (in an overlay, far to the left,
///    invisible to the user) inside a [RepaintBoundary].
/// 4. That boundary is rasterised at [kShareCardPixelRatio] and encoded as
///    PNG.
///
/// Throws [ShareCardException] when any of those steps fails — including a
/// cross-origin photo the browser refuses to let us paint into an image.
Future<Uint8List> renderPostShareCardPng(BuildContext context, Post post) async {
  // Resolved up front: everything after this point is asynchronous, and
  // the card only needs somewhere to paint, not the context again.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    throw const ShareCardException('no overlay to render the card in');
  }

  await _ensureHandwritingLoaded();

  if (post.hasMedia) {
    await _precachePhoto(platformImageProvider(post.mediaUrl!));
  }

  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -2000,
      top: 0,
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: key,
            child: PostShareCard(post: post),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // Two frames: one to lay out and paint the card, one to be sure the
    // photo and text have made it into the layer tree.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw const ShareCardException('share card did not mount');
    }
    return await captureBoundaryAsPng(boundary);
  } finally {
    entry.remove();
  }
}

/// Rasterises an already-painted [RenderRepaintBoundary] at the export
/// scale and returns PNG bytes. Split out so it can be exercised without
/// the overlay plumbing.
Future<Uint8List> captureBoundaryAsPng(
  RenderRepaintBoundary boundary, {
  double pixelRatio = kShareCardPixelRatio,
}) async {
  ui.Image? image;
  try {
    image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const ShareCardException('PNG encoding returned no bytes');
    }
    return data.buffer.asUint8List();
  } on ShareCardException {
    rethrow;
  } on Object catch (e) {
    // A tainted canvas (cross-origin photo) lands here on web.
    throw ShareCardException(e);
  } finally {
    image?.dispose();
  }
}

/// Loads the bundled Caveat face into the font collection so the capture
/// uses it rather than the fallback. A second registration of an already
/// loaded family is harmless; a failure just means text falls back.
Future<void> _ensureHandwritingLoaded() async {
  try {
    final loader = FontLoader('Caveat')
      ..addFont(rootBundle.load('assets/fonts/Caveat-Variable.ttf'));
    await loader.load();
  } on Object {
    // Already registered (the normal case once the UI has drawn) — the
    // capture is still correct.
  }
}

/// Resolves and decodes a photo into the image cache, throwing
/// [ShareCardException] when the bytes never arrive (offline, 404,
/// cross-origin) so the caller can refuse to export a broken card.
Future<void> _precachePhoto(ImageProvider provider) {
  final completer = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete();
    },
    onError: (error, stack) {
      if (!completer.isCompleted) {
        completer.completeError(ShareCardException(error));
      }
    },
  );
  stream.addListener(listener);
  return completer.future
      .timeout(const Duration(seconds: 10),
          onTimeout: () => throw const ShareCardException('photo timed out'))
      .whenComplete(() => stream.removeListener(listener));
}
