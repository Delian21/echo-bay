
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/atmosphere/atmosphere_controller.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/io/platform_io.dart';
import '../../../core/settings/draft_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/prompt/prompt.dart';
import '../../../core/prompt/prompt_repository.dart';
import '../../../injection.dart';
import '../../social/domain/repositories/social_repository.dart';
import '../domain/repositories/feed_repository.dart';

/// Per-shape composer hint, mirroring the Daily Square prompt rotation
/// (drift_prompt_repository). Shared by the composer and the FAB
/// long-press quick actions so both speak the same vocabulary.
String promptShapeHint(String shape) => switch (shape) {
      'photo' => 'One photo of what is in front of you.',
      'sentence' => 'One sentence about today. Just one.',
      'sound' => 'What are you listening to right now?',
      'desk' => 'Show your desk as it actually is.',
      _ => "What's happening on the Square?",
    };

/// Compose-and-publish sheet for the Square. Returns the created post's
/// body when published, null when cancelled/failed (failure surfaces as a
/// snackbar here so callers stay one-liners).
///
/// Daily Square E2E (§6c): pass [prompt] (the active prompt from the
/// notification tap or app-bar entry point) and the sheet pre-seeds the
/// field with the prompt's own copy and, on publish, records the answer
/// so the prompt retires (rule 2 — acted on, never shown again).
Future<void> showPostComposer(
  BuildContext context, {
  required FeedRepository repository,
  required String authorName,
  String? promptShape,
  Prompt? prompt,
  PromptRepository? promptRepository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _PostComposer(
      repository: repository,
      authorName: authorName,
      hint: prompt != null
          ? prompt.body
          : promptShape == null
              ? null
              : promptShapeHint(promptShape),
      prompt: prompt,
      promptRepository: promptRepository,
    ),
  );
}

class _PostComposer extends StatefulWidget {
  const _PostComposer({
    required this.repository,
    required this.authorName,
    this.hint,
    this.prompt,
    this.promptRepository,
  });

  final FeedRepository repository;
  final String authorName;

  /// Prompt-shape hint ('One photo of what is in front of you.') shown
  /// as the field's hint text; null falls back to the generic ask.
  final String? hint;

  /// Active Daily Square prompt, when the composer was opened from the
  /// notification tap or the prompt-aware entry point. Pre-seeds the
  /// field with the prompt copy and retires the prompt on publish.
  final Prompt? prompt;
  final PromptRepository? promptRepository;

  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  /// Draft autosave: the caption survives closing the sheet, the app,
  /// or the tab. Restored once on open; saved debounced on change;
  /// cleared on publish and on the Cancel button.
  DraftDebouncer? _draftSave;
  bool _hasDraft = false;

  /// "Fades in 24h": the post is ephemeral. It disappears from feed and
  /// profile after a day; a keep-it action on the card makes it stay.
  bool _ephemeral = false;

  /// Picked local media. One attachment per post (the card renders a
  /// single media slot); re-picking replaces it. Stored as an absolute
  /// file path — the mock cache persists the row, and [FeedCard] paints
  /// local files directly. A real backend swaps this for an upload +
  /// remote URL without touching the UI contract.
  XFile? _media;
  bool _mediaIsVideo = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    if (!sl.isRegistered<DraftStore>()) return;
    final text = await sl<DraftStore>().read(DraftStore.squareKey);
    if (!mounted || text == null) return;
    setState(() {
      _controller.text = text;
      _hasDraft = true;
    });
  }

  void _onCaptionChanged(String text) {
    setState(() {});
    if (!sl.isRegistered<DraftStore>()) return;
    _draftSave ??= DraftDebouncer();
    _hasDraft = text.trim().isNotEmpty;
    _draftSave!.run(() {
      sl<DraftStore>().write(DraftStore.squareKey, text);
    });
  }

  Future<void> _clearDraft() async {
    _draftSave?.dispose();
    _draftSave = null;
    if (!sl.isRegistered<DraftStore>()) return;
    await sl<DraftStore>().clear(DraftStore.squareKey);
  }

  @override
  void dispose() {
    // Close without publishing: the debounced save likely already ran;
    // if the last keystrokes came inside the window, save now.
    final save = _draftSave;
    if (save != null) {
      save.dispose();
      if (sl.isRegistered<DraftStore>()) {
        sl<DraftStore>().write(DraftStore.squareKey, _controller.text);
      }
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
    } on Object catch (e) {
      if (!mounted) return;
      final denied = e.toString().contains('permission') ||
          e.toString().contains('denied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(denied
              ? 'The album stays shut. Grant the app access to your photos '
                  'and try again.'
              : "Couldn't open the album — the pen snapped. Try again?"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (picked == null || !mounted) return;
    setState(() {
      _media = picked;
      _mediaIsVideo = false;
    });
  }

  Future<void> _pickVideo() async {
    final XFile? picked;
    try {
      picked = await _picker.pickVideo(source: ImageSource.gallery);
    } on Object catch (e) {
      if (!mounted) return;
      final denied = e.toString().contains('permission') ||
          e.toString().contains('denied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(denied
              ? 'The album stays shut. Grant the app access to your photos '
                  'and try again.'
              : "Couldn't open the album — the pen snapped. Try again?"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (picked == null || !mounted) return;
    setState(() {
      _media = picked;
      _mediaIsVideo = true;
    });
  }

  void _clearMedia() => setState(() {
        _media = null;
        _mediaIsVideo = false;
      });

  bool get _canPublish => !_sending && (_controller.text.trim().isNotEmpty || _media != null);

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() => _sending = true);

    final result = await widget.repository.createPost(
      body: _controller.text.trim(),
      authorName: widget.authorName,
      mediaUrl: _media?.path,
      ephemeral: _ephemeral,
    );
    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Could not publish'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (post) async {
        // Mock-peer choreography: the Square's regulars may drop a note
        // or a reaction after a realistic delay. Capped and spaced by
        // the social layer — never more than two events per post.
        try {
          sl<SocialRepository>()
              .onOwnPostPublished(postId: post.id, body: post.body);
        } on Object {
          // DI unavailable (tests): no peer chatter, post still lands.
        }
        // Prompt E2E: answering retires the prompt (§6c rule 2). Best
        // effort — a bookkeeping failure never blocks the post.
        // Atmosphere: soft pen scratch as the post lands (opt-in).
        try {
          unawaited(sl<AtmosphereController>()
              .play(AtmosphereSound.penScratch));
        } on Object {
          // DI unavailable (tests): silence is fine.
        }
        final prompt = widget.prompt;
        final prompts = widget.promptRepository;
        if (prompt != null && prompts != null) {
          await prompts.recordPosted(
            promptId: prompt.id,
            postId: post.id,
          );
        }
        // Published: the draft has become a post — clear it.
        await _clearDraft();
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Keyboard inset: the sheet floats above the composer keyboard.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Golden Hour: the composer's title is a handwritten page
          // heading, not a Material label. A restored draft gets a small
          // handwritten "draft" tag — picked up where you left it.
          Builder(builder: (context) {
            final useInk = GoldenHourExtension.of(context).enabled;
            final title = Text(
              'New post',
              style: useInk
                  ? kHandwrittenTextStyle.copyWith(
                      fontSize: 24,
                      color: Theme.of(context).colorScheme.onSurface,
                    )
                  : theme.textTheme.titleMedium,
            );
            if (!_hasDraft) return title;
            return Row(
              children: [
                title,
                const SizedBox(width: 10),
                Text(
                  'draft',
                  style: kHandwrittenTextStyle.copyWith(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            textInputAction: TextInputAction.done,
            onChanged: _onCaptionChanged,
            onSubmitted: (_) => _publish(),
            decoration: InputDecoration(
              hintText: widget.hint ?? "What's happening on the Square?",
            ),
          ),
          if (_media != null) ...[
            const SizedBox(height: 12),
            // Attached media rides in a wobbly notebook frame — the
            // sketch language follows content everywhere it goes.
            Builder(
              builder: (context) => GoldenHourExtension.of(context).enabled
                  ? SketchBox(
                      seed: _media!.path.hashCode & 0x7FFFFFFF,
                      radius: 8,
                      color: SketchInk.of(context),
                      child: _MediaPreview(
                        media: _media!,
                        isVideo: _mediaIsVideo,
                        onRemove: _clearMedia,
                      ),
                    )
                  : _MediaPreview(
                      media: _media!,
                      isVideo: _mediaIsVideo,
                      onRemove: _clearMedia,
                    ),
            ),
          ],
          const SizedBox(height: 8),
          // "Fades in 24h": hand-drawn toggle row. The post prints like a
          // polaroid left in the sun — gone by tomorrow unless kept.
          Row(
            children: [
              const SketchIcon(
                kind: SketchIconKind.clockTick,
                size: 20,
                seed: 71,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Fades in 24h')),
              Switch.adaptive(
                value: _ephemeral,
                onChanged: _sending ? null : (v) => setState(() => _ephemeral = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Media attachment: photo + video pickers, desktop-friendly
              // (file dialogs on Windows). Attach without text — the
              // publish gate accepts caption-or-media.
              IconButton.filledTonal(
                tooltip: 'Attach photo',
                onPressed: _sending ? null : _pickImage,
                icon: const SketchIcon(
                    kind: SketchIconKind.photoFrame, size: 22, seed: 47),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Attach video',
                onPressed: _sending ? null : _pickVideo,
                icon: const SketchIcon(
                    kind: SketchIconKind.videoCam, size: 22, seed: 53),
              ),
              const Spacer(),
              TextButton(
                onPressed: _sending
                    ? null
                    : () async {
                        // Deliberate discard: the draft dies here.
                        await _clearDraft();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _canPublish ? _publish : null,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Attached-media preview inside the composer: photo thumbnail or video
/// icon tile, with a remove affordance. Videos are not thumbnailed here —
/// generating one needs video_player; the badge communicates the type.
class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.media,
    required this.isVideo,
    required this.onRemove,
  });

  final XFile media;
  final bool isVideo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: 160,
            child: isVideo
                ? ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SketchIcon(
                          kind: SketchIconKind.videoCam,
                          size: 32,
                          color: scheme.onSurfaceVariant,
                          seed: 59,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          media.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : Image(
                    image: platformImageProvider(media.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: SketchIcon(
                        kind: SketchIconKind.brokenImage,
                        color: scheme.onSurfaceVariant,
                        seed: 61,
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: scheme.surface.withValues(alpha: 0.85),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child:
                    SketchIcon(
                      kind: SketchIconKind.closeX,
                      size: 18,
                      color: scheme.onSurface,
                      seed: 19,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
