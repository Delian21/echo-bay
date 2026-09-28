import 'package:equatable/equatable.dart';

/// What kind of file rides on an attachment message. Voice notes are
/// recorded in-app; photo/video come from the system picker.
enum AttachmentKind { photo, video, voice }

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

  final AttachmentKind kind;
  final String path;

  /// Voice notes only; null for photo/video.
  final int? durationMs;

  @override
  List<Object?> get props => [kind, path, durationMs];
}
