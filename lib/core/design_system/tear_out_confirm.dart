import 'package:flutter/material.dart';

/// The one confirmation every destructive action in the app uses.
///
/// Same voice everywhere — a page being torn out of the sketchbook, not a
/// record being deleted — and the same two buttons, so nobody has to read
/// a differently-worded dialog on each surface. Returns true when the
/// person chose [tearOutLabel].
Future<bool> confirmTearOut(
  BuildContext context, {
  String title = 'Tear out this page?',
  String message = "This can't be undone.",
  String tearOutLabel = 'Tear it out',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tearOutLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
