import 'package:equatable/equatable.dart';

import '../../../../core/attachments/attachment.dart';

/// Outbox state machine for Nexus group messages. Mirrors the Vault's
/// DeliveryStatus semantics but is deliberately a separate type: feature
/// modules do not import each other, and the Nexus is not E2EE so its
/// transport story will diverge.
enum OutboxStatus { pending, sent, failed }

/// Sync state for a membership operation (join, leave, role change).
/// Membership is a first-class sync entity, not a UI checkbox: every
/// mutation queues as [pending] and is flushed by the transport like any
/// other outbox row. [left] is terminal — the local row records the
/// departure until the server confirms.
enum MembershipSyncStatus { pending, synced, failed, left }

/// Role of a member inside a Nexus group (Telegram model).
enum MemberRole { owner, admin, member }

/// Pure domain entity for a broadcast channel. Remote-first read model —
/// the cache mirrors the server; the UI never writes to channels.
class NexusChannel extends Equatable {
  const NexusChannel({
    required this.id,
    required this.title,
    required this.description,
    required this.lastPostAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime lastPostAt;

  @override
  List<Object?> get props => [id, title, description, lastPostAt];
}

/// One broadcast post inside a channel. [expiresAt] carries the retention
/// policy from day one: null = keep forever; otherwise the cache prunes
/// the row once the clock passes it.
class ChannelPost extends Equatable {
  const ChannelPost({
    required this.id,
    required this.channelId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String channelId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final DateTime? expiresAt;

  bool get hasMedia => false; // text-only for the mock stage

  @override
  List<Object?> get props =>
      [id, channelId, authorName, body, createdAt, expiresAt];
}

/// A group chat. Many→many, write-heavy — the Vault's outbox model
/// without E2EE. [myRole] is the local user's role in this group.
class NexusGroup extends Equatable {
  /// Stable id for the local user until real auth exists.
  static const localUserId = 'local-user';

  const NexusGroup({
    required this.id,
    required this.title,
    required this.memberIds,
    required this.myRole,
    required this.lastActivityAt,
  });

  final String id;
  final String title;
  final List<String> memberIds;
  final MemberRole myRole;
  final DateTime lastActivityAt;

  @override
  List<Object?> get props =>
      [id, title, memberIds, myRole, lastActivityAt];
}

/// Membership of one user in one group, with its own sync state.
/// The interesting unit of a community app is the membership, not the
/// content row (Reddit/Discord lesson) — joins, leaves and role changes
/// are sync operations that can fail and retry, exactly like messages.
class GroupMembership extends Equatable {
  const GroupMembership({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.syncStatus,
    required this.updatedAt,
  });

  final String groupId;
  final String userId;
  final MemberRole role;
  final MembershipSyncStatus syncStatus;

  /// When the local user issued the current membership operation.
  final DateTime updatedAt;

  bool get isPending => syncStatus == MembershipSyncStatus.pending;

  GroupMembership copyWith({
    MemberRole? role,
    MembershipSyncStatus? syncStatus,
    DateTime? updatedAt,
  }) =>
      GroupMembership(
        groupId: groupId,
        userId: userId,
        role: role ?? this.role,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props =>
      [groupId, userId, role, syncStatus, updatedAt];
}

/// One group chat message with outbox state and edit/delete tombstones
/// (same lifecycle as the Vault minus the E2EE vocabulary).
class GroupMessage extends Equatable {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.status,
    this.editedAt,
    this.deletedAt,
    this.attachment,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final OutboxStatus status;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  /// Null for plain text messages (same contract as the Vault's
  /// [MessageAttachment] — vault entity reused across features is
  /// forbidden by the dependency rule, so this mirrors its shape).
  final MessageAttachment? attachment;

  bool get isMine => senderId == NexusGroup.localUserId;
  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;

  GroupMessage copyWith({OutboxStatus? status}) => GroupMessage(
        id: id,
        groupId: groupId,
        senderId: senderId,
        body: body,
        createdAt: createdAt,
        status: status ?? this.status,
        editedAt: editedAt,
        deletedAt: deletedAt,
      );

  @override
  List<Object?> get props =>
      [id, groupId, senderId, body, createdAt, status, editedAt, deletedAt];
}
