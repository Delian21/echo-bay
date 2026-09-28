import 'package:flutter/material.dart';

import '../attachments/attachment.dart';
import '../attachments/attachment_picker.dart';
import '../theme/app_theme.dart';
import 'sketch_kit.dart';

/// The inked chat composer: attach row (photo / video / voice), pending
/// chip, voice-recording bar and the amber paper-plane send. Lives in
/// core so the Vault and the Hallway's Dorms share one composer —
/// features may not import features.
///
/// In ink mode the field sits inside a small [SketchBox] (stroke only,
/// no scribbles — chat restraint); otherwise plain Material rows. Send
/// fires [onSendWithAttachment] when an attachment is pending (text
/// optional — a photo alone is a message), else [onSendText].
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
    this.seed,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSendText;

  /// Null while editing — attachments don't ride on edits.
  final ValueChanged<MessageAttachment>? onSendWithAttachment;
  final bool editing;
  final VoidCallback? onCancelEdit;
  final String hintText;

  /// Deterministic wobble seed for the inked border. Defaults to a
  /// stable hash of the hint text; pass the conversation id's hash so
  /// each chat's box is its own drawing.
  final int? seed;

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
    if (a == null || !mounted) return;
    setState(() => _pending = a);
  }

  Future<void> _attachVideo() async {
    final a = await _picker.pickVideo();
    if (a == null || !mounted) return;
    setState(() => _pending = a);
  }

  Future<void> _recordVoice() async {
    if (_recording != null) return;
    final rec = await _picker.startVoiceRecording();
    if (rec == null || !mounted) return;
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
        ink: useInk,
        onSend: () => _stopRecording(keep: true),
        onCancel: () => _stopRecording(keep: false),
      );
    }

    final field = TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.send,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _send(),
      style: useInk ? theme.textTheme.bodyLarge?.copyWith(height: 1.3) : null,
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(useInk ? 6 : 24),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final sendButton = widget.editing
        ? _InkIconButton(
            tooltip: 'Cancel edit',
            onPressed: widget.onCancelEdit,
            child: const SketchIcon(kind: SketchIconKind.closeX, size: 22),
          )
        : _InkIconButton(
            tooltip: 'Send',
            onPressed: _canSend ? _send : null,
            filled: true,
            child: const SketchIcon(kind: SketchIconKind.paperPlane, size: 22),
          );

    final attachRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _InkIconButton(
          tooltip: 'Attach photo',
          onPressed: widget.enabled ? _attachPhoto : null,
          child: const SketchIcon(
              kind: SketchIconKind.photoFrame, size: 22),
        ),
        _InkIconButton(
          tooltip: 'Attach video',
          onPressed: widget.enabled ? _attachVideo : null,
          child: const SketchIcon(
              kind: SketchIconKind.videoCam, size: 22),
        ),
        _InkIconButton(
          tooltip: 'Record voice message',
          onPressed: widget.enabled ? _recordVoice : null,
          child: const SketchIcon(
              kind: SketchIconKind.scribbleMic, size: 22),
        ),
      ],
    );

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
            useInk
                ? SketchBox(
                    seed: widget.seed ??
                        widget.hintText.hashCode & 0x7FFFFFFF,
                    radius: 6,
                    strokeWidth: 2,
                    color: SketchInk.of(context),
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                    child: Row(
                      children: [
                        attachRow,
                        Expanded(child: field),
                        const SizedBox(width: 4),
                        sendButton,
                      ],
                    ),
                  )
                : Row(
                    children: [
                      attachRow,
                      Expanded(child: field),
                      const SizedBox(width: 8),
                      sendButton,
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

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
    required this.ink,
    required this.onSend,
    required this.onCancel,
  });

  final Duration elapsed;
  final bool ink;
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
        child: widget.ink
            ? SketchBox(
                seed: 424242,
                radius: 6,
                strokeWidth: 2,
                color: SketchInk.graffitiRed,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    const SketchIcon(
                      kind: SketchIconKind.scribbleMic,
                      size: 20,
                      color: SketchInk.graffitiRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: SketchInk.of(context),
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
              )
            : Row(
                children: [
                  SketchIcon(
                    kind: SketchIconKind.scribbleMic,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label)),
                  IconButton(
                    tooltip: 'Discard',
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  IconButton.filled(
                    tooltip: 'Attach voice note',
                    onPressed: widget.onSend,
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
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
        icon: child,
      );
    }
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: filled ? golden.amberAccent : Colors.transparent,
        highlightColor: golden.amberAccent.withValues(alpha: 0.12),
        foregroundColor:
            filled ? theme.colorScheme.onPrimary : SketchInk.of(context),
      ),
      icon: child,
    );
  }
}
