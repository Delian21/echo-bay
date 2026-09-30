import 'package:equatable/equatable.dart';

/// What kind of file rides on an attachment message. Voice notes are
/// recorded in-app; photo/video come from the system picker; [post] is
/// a shared Square post — [path] then carries the POST ID, not a file
/// path, and the bubble renders a small polaroid card for it.
enum AttachmentKind { photo, video, voice, post }

/// A message's attached media. Local-first: [path] is a file path inside
/// the app's attachments directory (the picker's temp file is copied on
/// send so it survives past the picker session). Lives in `core/` because
/// both the Vault and the Hallway's Dorms attach media and feature
/// modules may not import each other.
class MessageAttachment extends Equatable {
  const MessageAttachment({
    required this.kind,
    required this.path,
    this.durationMs,
  });

  /// Shared-Square-post constructor: [path] carries the post id. Kept
  /// here (not a widget) so the domain layer can express sharing without
  /// importing the Square's UI.
  const MessageAttachment.sharedPost(String postId)
      : kind = AttachmentKind.post,
        path = postId,
        durationMs = null;

  final AttachmentKind kind;
  final String path;

  /// Voice notes only; null for photo/video.
  final int? durationMs;

  /// The shared post id when [kind] == post, else null.
  String? get sharedPostId =>
      kind == AttachmentKind.post ? path : null;

  @override
  List<Object?> get props => [kind, path, durationMs];
}
