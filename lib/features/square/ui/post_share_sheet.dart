import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/error/failures.dart';
import '../../../core/io/platform_io.dart';
import '../domain/entities/post.dart';
import '../domain/usecases/share_post_as_image.dart';

/// Renders the post to a PNG (SharePostAsImage) and hands it out:
/// system share sheet on mobile, browser download on web. Failures
/// surface as a snackbar in the app's voice — never a stack trace.
Future<void> sharePostAsImage(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  final SharePostAsImage share = SharePostAsImage();
  final result = await share(post);
  result.fold(
    (Failure f) => messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't ink that one. Try again?")),
    ),
    (Uint8List bytes) => _handOut(messenger, post, bytes),
  );
}

Future<void> _handOut(
  ScaffoldMessengerState messenger,
  Post post,
  Uint8List bytes,
) async {
  final fileName =
      'echo-bay-square-${post.createdAt.millisecondsSinceEpoch}.png';
  if (kIsWeb) {
    // Browser: object-URL download through the IO seam's web impl.
    await writeBytes(fileName, bytes);
    return;
  }
  // Native: write through the seam, share the file path.
  final path = await writeBytes(fileName, bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], text: post.body),
  );
  messenger.showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          SketchGlyph(kind: SketchIconKind.paperPlane, size: 16),
          SizedBox(width: 8),
          Text('Card inked and ready to send.'),
        ],
      ),
    ),
  );
}
