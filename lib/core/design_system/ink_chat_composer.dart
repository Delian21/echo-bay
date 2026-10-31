import 'package:flutter/material.dart';

import '../attachments/attachment.dart';
import '../attachments/attachment_picker.dart';
import '../theme/app_theme.dart';
import 'sketch_kit.dart';

/// The chat composer: a single "+" attach button, a field that grows to
/// five lines, and a trailing mic that becomes the send plane as soon as
/// there is something to send. Lives in core so the Vault and the
/// Hallway's Dorms share one composer — features may not import features.
///
/// Attach actions (photo / video / voice note) live behind the "+" sheet so
/// the row stays one control wide; the voice-note handler is reachable from
/// both the sheet and the trailing mic. In ink mode the send disc is amber;
/// the bar itself is a plain rounded container with a hairline border (no
/// sketch stroke — a text field should read as a field). Send fires
/// [onSendWithAttachment] when an attachment is pending (text optional — a
/// photo alone is a message), else [onSendText].
class InkChatComposer extends StatefulWidget {
  const InkChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSendText,
    required this.onSendWithAttachment,
    this.editing = false,
    this.onCancelEdit,
    this.hintText = 'Write a message',
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSendText;

  /// Null while editing — attachments don't ride on edits.
  final ValueChanged<MessageAttachment>? onSendWithAttachment;
  final bool editing;
  final VoidCallback? onCancelEdit;
  final String hintText;

  @override
  State<InkChatComposer> createState() => _InkChatComposerState();
}

class _InkChatComposerState extends State<InkChatComposer> {
  final AttachmentPicker _picker = AttachmentPicker();
  MessageAttachment? _pending;
  VoiceRecording? _recording;

  bool get _canSend =>
      widget.enabled &&
      !widget.editing &&
      (_pending != null || widget.controller.text.trim().isNotEmpty);

  Future<void> _attachPhoto() async {
    final a = await _picker.pickPhoto();
    if (!mounted) return;
    if (a == null) {
      // Distinguish cancel from failure is not possible through the
      // picker contract; a null here after a real picker attempt is
      // near-always a cancelled dialog, so stay quiet (no nagging).
      return;
    }
    setState(() => _pending = a);
  }

  Future<void> _attachVideo() async {
    final a = await _picker.pickVideo();
    if (!mounted || a == null) return;
    setState(() => _pending = a);
  }

  Future<void> _recordVoice() async {
    if (_recording != null) return;
    final rec = await _picker.startVoiceRecording();
    if (!mounted) return;
    if (rec == null) {
      // Real failure (not the graceful mic-fallback, which returns a
      // handle): permission denied or recorder broken. Say so.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "The microphone won't answer. Check the app's mic access."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _recording = rec);
  }

  Future<void> _stopRecording({required bool keep}) async {
    final rec = _recording;
    if (rec == null) return;
    setState(() => _recording = null);
    if (!keep) {
      rec.cancel();
      return;
    }
    final a = await rec.stop();
    if (!mounted) return;
    setState(() => _pending = a);
  }

  /// One entry point for every attachment so the bar only needs one
  /// button. Each row hands back to the existing handlers below — the
  /// pick/send paths are untouched.
  Future<void> _openAttachSheet() async {
    if (!widget.enabled) return;
    final action = await showModalBottomSheet<_AttachAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const SketchIcon(
                kind: SketchIconKind.photoFrame,
                size: 22,
              ),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(sheetContext, _AttachAction.photo),
            ),
            ListTile(
              leading: const SketchIcon(
                kind: SketchIconKind.videoCam,
                size: 22,
              ),
              title: const Text('Video'),
              onTap: () => Navigator.pop(sheetContext, _AttachAction.video),
            ),
            ListTile(
              leading: const SketchIcon(
                kind: SketchIconKind.scribbleMic,
                size: 22,
              ),
              title: const Text('Voice note'),
              onTap: () => Navigator.pop(sheetContext, _AttachAction.voice),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _AttachAction.photo:
        await _attachPhoto();
        break;
      case _AttachAction.video:
        await _attachVideo();
        break;
      case _AttachAction.voice:
        await _recordVoice();
        break;
      case null:
        break;
    }
  }



  void _send() {
    final attachment = _pending;
    if (attachment != null) {
      widget.onSendWithAttachment?.call(attachment);
      setState(() => _pending = null);
      return;
    }
    widget.onSendText();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The analog layer reaches the composer: the field becomes a small
    // inked note box (chat restraint — stroke only, no scribbles/paper).
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    final recording = _recording;

    if (recording != null) {
      return _VoiceRecordingBar(
        elapsed: recording.elapsed,
        onSend: () => _stopRecording(keep: true),
        onCancel: () => _stopRecording(keep: false),
      );
    }

    // Attachments are only offered where they can be sent: a fresh
    // message, not an edit.
    final canAttach =
        widget.onSendWithAttachment != null && !widget.editing;
    final hasContent =
        _pending != null || widget.controller.text.trim().isNotEmpty;

    final field = TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      // Grows from one line to five, then scrolls internally.
      minLines: 1,
      maxLines: 5,
      textInputAction: TextInputAction.send,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _send(),
      style: useInk ? theme.textTheme.bodyLarge?.copyWith(height: 1.3) : null,
      // The bar owns the fill and the outline now, so the field is
      // transparent: one surface instead of a box inside a box.
      decoration: InputDecoration(
        hintText: widget.hintText,
        // The placeholder must never wrap, whatever the bar's width.
        hintMaxLines: 1,
        isDense: true,
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      ),
    );

    // One trailing action: cancel while editing, the plane once there is
    // something to send, the mic while the field is empty.
    final Widget trailing;
    if (widget.editing) {
      trailing = _InkIconButton(
        tooltip: 'Cancel edit',
        onPressed: widget.onCancelEdit,
        child: const SketchIcon(kind: SketchIconKind.closeX, size: 22),
      );
    } else if (hasContent) {
      trailing = _InkIconButton(
        tooltip: 'Send',
        onPressed: _canSend ? _send : null,
        filled: true,
        child: const SketchIcon(kind: SketchIconKind.paperPlane, size: 22),
      );
    } else {
      trailing = _InkIconButton(
        tooltip: 'Record voice message',
        onPressed: widget.enabled ? _recordVoice : null,
        child: const SketchIcon(kind: SketchIconKind.scribbleMic, size: 22),
      );
    }

    final pendingChip = _pending == null
        ? null
        : _PendingAttachmentChip(
            attachment: _pending!,
            onRemove: () => setState(() => _pending = null),
          );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingChip != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: pendingChip,
                ),
              ),
            Container(
              decoration: _composerBarDecoration(theme),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                // Buttons ride the last line as the field grows.
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (canAttach)
                    _InkIconButton(
                      tooltip: 'Add attachment',
                      onPressed: widget.enabled ? _openAttachSheet : null,
                      child: const SketchIcon(
                          kind: SketchIconKind.plusCircle, size: 22),
                    ),
                  Expanded(child: field),
                  trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the "+" sheet asked for. Each case maps to an existing handler.
enum _AttachAction { photo, video, voice }

/// The composer bar's plain geometry: rounded, hairline outline, no sketch
/// stroke — the field should read as a field, not a notebook box.
BoxDecoration _composerBarDecoration(ThemeData theme) => BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: theme.colorScheme.outline.withValues(alpha: 0.35),
      ),
    );

/// The chip shown above the composer while an attachment is queued.
class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({
    required this.attachment,
    required this.onRemove,
  });

  final MessageAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label) = switch (attachment.kind) {
      AttachmentKind.photo => (
          const SketchIcon(kind: SketchIconKind.photoFrame, size: 16),
          'Photo'
        ),
      AttachmentKind.video => (
          const SketchIcon(kind: SketchIconKind.videoCam, size: 16),
          'Video'
        ),
      AttachmentKind.voice => (
          const SketchIcon(kind: SketchIconKind.scribbleMic, size: 16),
          'Voice note ${(attachment.durationMs! / 1000).toStringAsFixed(0)}s'
        ),
      // Shared posts are composed by the Square's share sheet, never by
      // this composer; the chip case exists only for exhaustiveness.
      AttachmentKind.post => (
          const SketchIcon(kind: SketchIconKind.photoFrame, size: 16),
          'Square post'
        ),
    };
    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 6),
              SketchIcon(
                kind: SketchIconKind.closeX,
                size: 14,
                color: theme.colorScheme.onSecondaryContainer,
                seed: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The composer's voice-recording state: elapsed timer, cancel and send.
class _VoiceRecordingBar extends StatefulWidget {
  const _VoiceRecordingBar({
    required this.elapsed,
    required this.onSend,
    required this.onCancel,
  });

  final Duration elapsed;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  State<_VoiceRecordingBar> createState() => _VoiceRecordingBarState();
}

class _VoiceRecordingBarState extends State<_VoiceRecordingBar> {
  @override
  void initState() {
    super.initState();
    // Poll the stopwatch for the live elapsed display.
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return false;
      setState(() {});
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secs = widget.elapsed.inSeconds;
    final label =
        'Recording… ${(secs ~/ 60)}:${(secs % 60).toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        // Same bar geometry as the idle composer: recording swaps the
        // field for the timer, never the chrome.
        child: Container(
          decoration: _composerBarDecoration(theme),
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          child: Row(
            children: [
              SketchIcon(
                kind: SketchIconKind.scribbleMic,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Discard',
                onPressed: widget.onCancel,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              _InkIconButton(
                tooltip: 'Attach voice note',
                onPressed: widget.onSend,
                filled: true,
                child: const Icon(Icons.check_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Composer icon button at the sketch kit's scale. In ink mode the send
/// disc is amber so the paper plane reads against the sketch background;
/// otherwise standard icon buttons.
class _InkIconButton extends StatelessWidget {
  const _InkIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.filled = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    if (!golden.enabled) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        // 48dp, comfortably past the 44dp touch-target floor.
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: child,
      );
    }
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: filled ? golden.amberAccent : Colors.transparent,
        highlightColor: golden.amberAccent.withValues(alpha: 0.12),
        foregroundColor:
            filled ? theme.colorScheme.onPrimary : SketchInk.of(context),
      ),
      icon: child,
    );
  }
}
