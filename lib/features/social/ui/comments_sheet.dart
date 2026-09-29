import 'package:flutter/material.dart';

import '../../../../core/design_system/sketch_kit.dart';
import '../../../../core/theme/app_theme.dart';
import '../domain/entities/social_entities.dart';
import '../domain/repositories/social_repository.dart';

/// Comments under one Square post: an inked note list plus a composer
/// styled like the app's note box. Opens as a bottom sheet from the
/// card's speech-bubble action.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.repository,
    required this.postId,
  });

  final SocialRepository repository;
  final String postId;

  /// Opens the sheet; safe to call from anywhere with the DI-resolved
  /// repository.
  static Future<void> show(
    BuildContext context, {
    required SocialRepository repository,
    required String postId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(repository: repository, postId: postId),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  Stream<List<PostComment>>? _stream;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Late-final stream discipline (ARCHITECTURE.md §8): one stream per
  // sheet, not per build.
  Stream<List<PostComment>> get _commentsStream =>
      _stream ??= widget.repository
          .watchComments(widget.postId)
          .map((either) => either.fold((_) => <PostComment>[], (l) => l));

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    _controller.clear();
    await widget.repository.addComment(postId: widget.postId, body: body);
  }

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'Notes on this square',
                style: golden.enabled
                    ? kHandwrittenTextStyle.copyWith(fontSize: 22)
                    : Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: StreamBuilder<List<PostComment>>(
                stream: _commentsStream,
                builder: (context, snapshot) {
                  final comments = snapshot.data ?? const <PostComment>[];
                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No notes yet. Leave the first one.',
                        style: kHandwrittenTextStyle.copyWith(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) =>
                        _CommentBubble(comment: comments[index]),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                // The inked note box: sketch border, handwritten input.
                child: SketchBox(
                  seed: 61,
                  radius: 10,
                  color: SketchInk.of(context),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: kHandwrittenTextStyle.copyWith(fontSize: 18),
                          decoration: const InputDecoration(
                            hintText: 'Write a note…',
                            border: InputBorder.none,
                            filled: false,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Pin note',
                        icon: const SketchIcon(
                          kind: SketchIconKind.paperPlane,
                          size: 20,
                          seed: 29,
                        ),
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment});

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment:
            comment.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: SketchBox(
          seed: comment.id.hashCode & 0x7FFFFFFF,
          radius: 10,
          color: SketchInk.of(context),
          fill: comment.isMine
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  comment.body,
                  style: golden.enabled
                      ? kHandwrittenTextStyle.copyWith(fontSize: 17)
                      : theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
