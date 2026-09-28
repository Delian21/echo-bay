import 'package:equatable/equatable.dart';

import '../../../../core/attachments/attachment.dart';

export '../../../../core/attachments/attachment.dart';

/// Normative message sync lifecycle (ARCHITECTURE.md §5):
/// pending → sent → delivered → read, with failed as the retryable
/// error state. Edits and deletes are terminal tombstones carried by
/// [Message.editedAt] / [Message.deletedAt], not by this enum — a
/// deleted message is still a delivered message.
enum DeliveryStatus { pending, sent, delivered, read, failed }

/// Pure domain message. The Vault is local-first: this entity is what the
/// UI renders; persistence details stay in the data layer.
class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.status,
    this.editedAt,
    this.deletedAt,
    this.attachment,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DeliveryStatus status;

  /// Tombstones. Non-null [deletedAt] means delete-for-everyone: the body
  /// is stale and the UI must render the placeholder, never the text.
  /// [editedAt] marks an edit; [body] already holds the edited text.
  final DateTime? editedAt;
  final DateTime? deletedAt;

  /// Null for plain text messages.
  final MessageAttachment? attachment;

  /// Authorship check. NOTE: with the auth seam, callers that have a
  /// session pass it explicitly; the fallback keeps the pre-auth constant
  /// for mock-seeded rows. Do not add new comparisons against
  /// [Conversation.localUserId] — repositories own this decision via
  /// their injected `localUserId`.
  bool get isMine => senderId == Conversation.localUserId;
  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;

  Message copyWith({
    DeliveryStatus? status,
    String? body,
    DateTime? editedAt,
    DateTime? deletedAt,
    bool clearDeleted = false,
    MessageAttachment? attachment,
  }) =>
      Message(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        body: body ?? this.body,
        createdAt: createdAt,
        status: status ?? this.status,
        editedAt: editedAt ?? this.editedAt,
        deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
        attachment: attachment ?? this.attachment,
      );

  @override
  List<Object?> get props => [
        id, conversationId, senderId, body, createdAt, status, editedAt, deletedAt, attachment,
      ];
}

class Conversation extends Equatable {
  /// Stable id for the local user until real auth exists.
  static const localUserId = 'local-user';

  const Conversation({
    required this.id,
    required this.title,
    required this.participantIds,
    required this.lastActivityAt,
  });

  final String id;
  final String title;
  final List<String> participantIds;
  final DateTime lastActivityAt;

  @override
  List<Object?> get props => [id, title, participantIds, lastActivityAt];
}
