import 'package:fpdart/fpdart.dart';

import '../../../../core/attachments/attachment.dart';
import '../../../../core/error/failures.dart';
import '../entities/nexus.dart';

/// Contract for the Nexus data layer — one interface, two read/write
/// models composed behind it:
///
///  - **Channels** are 1→many and read-heavy: remote-first, drift is a
///    cache (the Square's model). No local writes except the cache fill.
///  - **Group chats** are many→many and write-heavy: local-first outbox
///    (the Vault's model minus E2EE). Every send persists before any
///    transport attempt.
abstract class NexusRepository {
  // -- channels (remote-first cache) ----------------------------------------

  /// Subscribed channels, most recently active first.
  Stream<Either<Failure, List<NexusChannel>>> watchChannels();

  /// Channel posts, newest first. The cache prunes rows past their
  /// retention window ([ChannelPost.expiresAt]).
  Stream<Either<Failure, List<ChannelPost>>> watchChannelPosts({
    required String channelId,
  });

  /// One-shot refresh from the (mock) remote. Offline: [NetworkFailure].
  Future<Either<Failure, Unit>> refreshChannels();

  // -- groups (local-first outbox) ------------------------------------------

  /// Groups the local user belongs to, newest activity first.
  Stream<Either<Failure, List<NexusGroup>>> watchGroups();

  /// Live message stream for one group. Re-emits when the outbox state
  /// changes or a peer message lands.
  Stream<Either<Failure, List<GroupMessage>>> watchGroupMessages({
    required String groupId,
  });

  /// Persist locally (status: pending) then hand to the transport.
  /// [attachment] is copied into the app's attachments directory before
  /// persisting (local-first: the message outlives the picker session).
  Future<Either<Failure, GroupMessage>> sendGroupMessage({
    required String groupId,
    required String body,
    MessageAttachment? attachment,
  });

  /// Flush pending/failed group messages — the background worker entry.
  Future<Either<Failure, Unit>> syncOutbox();

  // -- membership (first-class sync entity) ---------------------------------

  /// Memberships of one group with their sync state. Emits on every
  /// membership change, including outbox transitions of the ops themselves.
  Stream<Either<Failure, List<GroupMembership>>> watchMembers({
    required String groupId,
  });

  /// Join a group as the local user. Local-first: the membership row is
  /// written immediately as [MembershipSyncStatus.pending] and synced by
  /// the transport; offline joins queue like offline messages.
  Future<Either<Failure, GroupMembership>> joinGroup({
    required String groupId,
  });

  /// Leave a group. Terminal [MembershipSyncStatus.left] locally; the
  /// transport confirms (mock stage: immediate).
  Future<Either<Failure, Unit>> leaveGroup({
    required String groupId,
  });

  /// Change a member's role (owner/admin only — mock stage does not
  /// enforce, real transport will). Queues like any membership op.
  Future<Either<Failure, GroupMembership>> setMemberRole({
    required String groupId,
    required String userId,
    required MemberRole role,
  });

  /// Seed channels + groups. Mock-stage convenience through the contract;
  /// removed at backend integration.
  Future<Either<Failure, Unit>> ensureSeeded();
}
