
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
import '../domain/entities/post.dart';
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
  Post? editing,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  // The sheet mirrors its field here on every keystroke. Reading this
  // after the sheet closes is synchronous and cannot race the draft's
  // fire-and-forget database write the way a store read does.
  final liveText = ValueNotifier<String>('');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _PostComposer(
      repository: repository,
      authorName: authorName,
      liveText: liveText,
      hint: editing != null
          ? 'Rewrite this page.'
          : prompt != null
              ? prompt.body
              : promptShape == null
                  ? null
                  : promptShapeHint(promptShape),
      prompt: prompt,
      promptRepository: promptRepository,
      editing: editing,
    ),
  );
  // Closed without publishing and with words still in the field: the
  // draft survives, so say so where the person is looking. Cancel and
  // Publish both blank this mirror, so neither keeps a ghost draft.
  final kept = liveText.value.trim().isNotEmpty;
  liveText.dispose();
  if (!context.mounted || !kept) return;
  messenger?.showSnackBar(
    const SnackBar(
      content: Text('Draft saved — pick it up where you left off.'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
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
    this.editing,
    this.liveText,
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

  /// The post being rewritten, or null when composing a new page.
  final Post? editing;

  /// Mirror of the field, for the caller's "draft saved" hint.
  final ValueNotifier<String>? liveText;

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

  /// New posts and edits keep separate drafts: opening the composer to
  /// write something new must never throw away an unsaved rewrite.
  String get _draftKey => widget.editing == null
      ? DraftStore.squareKey
      : DraftStore.squareEdit(widget.editing!.id);

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _controller.text = widget.editing!.body;
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    if (!sl.isRegistered<DraftStore>()) return;
    final text = await sl<DraftStore>().read(_draftKey);
    if (!mounted || text == null) return;
    setState(() {
      _controller.text = text;
      _hasDraft = true;
    });
  }

  void _onCaptionChanged(String text) {
    widget.liveText?.value = text;
    setState(() {});
    if (!sl.isRegistered<DraftStore>()) return;
    _draftSave ??= DraftDebouncer();
    _hasDraft = text.trim().isNotEmpty;
    _draftSave!.run(() {
      sl<DraftStore>().write(_draftKey, text);
    });
  }

  Future<void> _clearDraft() async {
    _draftSave?.dispose();
    _draftSave = null;
    if (!sl.isRegistered<DraftStore>()) return;
    await sl<DraftStore>().clear(_draftKey);
  }

  @override
  void dispose() {
    // Close without publishing: the debounced save likely already ran;
    // if the last keystrokes came inside the window, save now.
    final save = _draftSave;
    if (save != null) {
      save.dispose();
      if (sl.isRegistered<DraftStore>()) {
        // An edit left exactly as it was is not a draft: saving it would
        // put an unchanged copy on the shelf and make "Discard" the only
        // way to get rid of it.
        final unchanged = _isEditing &&
            _controller.text.trim() == widget.editing!.body.trim();
        sl<DraftStore>().write(_draftKey, unchanged ? '' : _controller.text);
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

    final editing = widget.editing;
    final result = editing != null
        ? await widget.repository.editPost(
            postId: editing.id,
            body: _controller.text.trim(),
          )
        : await widget.repository.createPost(
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
        // Peer choreography only for a new page: an edit does not invite
        // a fresh round of comments and notifications.
        if (editing == null) {
          try {
            sl<SocialRepository>()
                .onOwnPostPublished(postId: post.id, body: post.body);
          } on Object {
            // DI unavailable (tests): no peer chatter, post still lands.
          }
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
        if (editing == null && prompt != null && prompts != null) {
          await prompts.recordPosted(
            promptId: prompt.id,
            postId: post.id,
          );
        }
        // Published: the draft has become a post — clear it.
        widget.liveText?.value = '';
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
              _isEditing ? 'Edit post' : 'New post',
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
          if (_isEditing && widget.editing!.hasMedia)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The photo stays as it is — only the words change.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (_media != null && !_isEditing) ...[
            const SizedBox(height: 12),
            // Attached media rides in a wobbly notebook frame — the
            // sketch language follows content everywhere it goes.
            Builder(
              builder: (context) => GoldenHourExtension.of(context).enabled
                  ? SketchBox(
                      seed: _media!.path.hashCode & 0x7FFFFFFF,
                      radius: 8,
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
          // polaroid left in the sun — gone by tomorrow unless kept. The
          // label states the current choice, not just the switch's name.
          // Editing changes words, not lifespan, so the toggle stays out
          // of the edit sheet.
          if (!_isEditing)
            Row(
              children: [
                const SketchIcon(
                  kind: SketchIconKind.clockTick,
                  size: 20,
                  seed: 71,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _ephemeral ? 'Fades in 24h' : 'Stays on your Square',
                  ),
                ),
                Switch.adaptive(
                  value: _ephemeral,
                  onChanged:
                      _sending ? null : (v) => setState(() => _ephemeral = v),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Media attachment: photo + video pickers, desktop-friendly
              // (file dialogs on Windows). Attach without text — the
              // publish gate accepts caption-or-media. Editing never
              // attaches: the media on a page is immutable.
              if (!_isEditing) ...[
                IconButton.filled(
                  tooltip: 'Attach photo',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: _sending ? null : _pickImage,
                  icon: const SketchIcon(
                      kind: SketchIconKind.photoFrame, size: 22, seed: 47),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Attach video',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: _sending ? null : _pickVideo,
                  icon: const SketchIcon(
                      kind: SketchIconKind.videoCam, size: 22, seed: 53),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: _sending
                    ? null
                    : () async {
                        // Deliberate discard: the draft dies here.
                        widget.liveText?.value = '';
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
                    : Text(_isEditing ? 'Save' : 'Publish'),
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
