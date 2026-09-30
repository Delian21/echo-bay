import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/error/failures.dart';
import '../../../core/io/platform_io.dart';
import '../domain/entities/post.dart';
import '../domain/usecases/share_post_as_image.dart';
import 'post_share_destinations.dart';

/// Share entry point for a Square card's paper-plane action: a small
/// sheet offering "save as image" and "send to a chat". Keeping both
/// behind one tap keeps the card's action row uncluttered.
Future<void> sharePost(BuildContext context, Post post) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const SketchGlyph(kind: SketchIconKind.photoFrame),
            title: const Text('Save as image'),
            subtitle: const Text('A polaroid card to keep or send anywhere.'),
            onTap: () => Navigator.pop(sheetContext, 'image'),
          ),
          ListTile(
            leading: const SketchGlyph(kind: SketchIconKind.paperPlane),
            title: const Text('Send to a chat'),
            subtitle: const Text('Into a Vault conversation or a dorm.'),
            onTap: () => Navigator.pop(sheetContext, 'chat'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'image') {
    await sharePostAsImage(context, post);
  } else if (action == 'chat') {
    await showPostShareDestinations(context, post);
  }
}

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
    try {
      await writeBytes(fileName, bytes);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Card inked — check your downloads.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't set that down — try the share again?"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
