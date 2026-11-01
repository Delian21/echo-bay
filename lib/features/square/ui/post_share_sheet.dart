import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/io/platform_io.dart';
import '../domain/entities/post.dart';
import 'post_share_card.dart';

/// Where a public post can be shared from. The web build knows its own
/// origin at runtime; native builds (and tests) fall back to the
/// published town.
const String _kFallbackOrigin = 'https://echo-bay.netlify.app';

/// The shareable address of [post]: origin + `/square/post/:id`.
String postShareUrl(Post post) {
  final base = Uri.base;
  final origin = (base.scheme == 'http' || base.scheme == 'https')
      ? '${base.scheme}://${base.authority}'
      : _kFallbackOrigin;
  return '$origin/square/post/${Uri.encodeComponent(post.id)}';
}

/// What the card's paper-plane offers. Only public Square posts have this
/// action; Vault conversations, dorm chats and anything private never
/// render the card that carries it.
enum _ShareChoice { image, link }

/// Share entry point for a Square card: a small sheet offering "Save as
/// image" (a 1080 × 1350 polaroid PNG anyone can post) and "Copy link".
Future<void> sharePost(BuildContext context, Post post) async {
  final choice = await showModalBottomSheet<_ShareChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const SketchGlyph(kind: SketchIconKind.photoFrame),
            title: const Text('Save as image'),
            subtitle: const Text('A polaroid card to post anywhere.'),
            onTap: () => Navigator.pop(sheetContext, _ShareChoice.image),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Copy link'),
            subtitle: const Text('A link straight to this square.'),
            onTap: () => Navigator.pop(sheetContext, _ShareChoice.link),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case _ShareChoice.image:
      await _saveAsImage(context, post);
    case _ShareChoice.link:
      await _copyLink(context, post);
    case null:
      return;
  }
}

/// Prepares the card behind a small spinner, then hands the PNG to the
/// browser: the native share sheet where files are shareable, a download
/// where they aren't.
Future<void> _saveAsImage(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);

  // The dialog's own navigator, kept so the spinner can be dismissed from
  // an async callback without holding on to a BuildContext.
  NavigatorState? loadingNavigator;
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      loadingNavigator = Navigator.of(dialogContext);
      return const _PreparingCardDialog();
    },
  ));

  if (!context.mounted) {
    _close(loadingNavigator);
    return;
  }

  final Uint8List bytes;
  try {
    bytes = await renderPostShareCardPng(context, post);
  } on Object {
    _close(loadingNavigator);
    messenger.showSnackBar(const SnackBar(
      content: Text("Couldn't prepare the image, try again"),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }
  _close(loadingNavigator);
  await _handOut(messenger, bytes);
}

Future<void> _copyLink(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: postShareUrl(post)));
  messenger.showSnackBar(const SnackBar(
    content: Text('Link copied.'),
    behavior: SnackBarBehavior.floating,
  ));
}

/// Hands the PNG out. share_plus owns the web behaviour we want: it shares
/// through `navigator.share` when the browser accepts files, and otherwise
/// downloads the PNG as `echo-bay-post.png` (its own download fallback is
/// the `downloadFallbackEnabled` flag). The catch-all below only fires if
/// even that path fails.
Future<void> _handOut(ScaffoldMessengerState messenger, Uint8List bytes) async {
  const fileName = 'echo-bay-post.png';
  try {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'image/png', name: fileName),
      ],
      fileNameOverrides: const [fileName],
      downloadFallbackEnabled: true,
    ));
  } on Object {
    try {
      await writeBytes(fileName, bytes);
      messenger.showSnackBar(const SnackBar(
        content: Text('Card saved to your downloads.'),
        behavior: SnackBarBehavior.floating,
      ));
    } on Object {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't share that one, try again"),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

void _close(NavigatorState? navigator) {
  if (navigator != null && navigator.mounted) navigator.pop();
}

/// The small "making the card" spinner: an in-voice line and a quiet
/// progress ring, over a dimmed sheet.
class _PreparingCardDialog extends StatelessWidget {
  const _PreparingCardDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Making your card…',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
