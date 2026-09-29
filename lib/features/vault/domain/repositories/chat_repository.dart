import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/message.dart';
import '../entities/reaction.dart';

/// Contract for the Vault data layer. Local-first: every mutation lands in
/// the on-device store first; the transport (real or mocked) is an
/// implementation detail behind this interface.
abstract class ChatRepository {
  /// All conversations, newest activity first. Emits on every change.
  Stream<Either<Failure, List<Conversation>>> watchConversations();

  /// Live message stream for one conversation. Cache-backed; re-emits when
  /// rows change, including status transitions (pending → sent →
  /// delivered → read) and tombstone writes.
  Stream<Either<Failure, List<Message>>> watchMessages({
    required String conversationId,
  });

  /// Persist a message locally (status: pending) then hand it to the
  /// transport. In the mock, delivery/read confirmations are simulated
  /// after [deliveryDelay]-spaced steps.
  Future<Either<Failure, Message>> sendMessage({
    required String conversationId,
    required String body,

    /// Optional media. The implementation copies the source file into the
    /// app's attachments directory before persisting (local-first: the
    /// message must outlive the picker session).
    MessageAttachment? attachment,
  });

  /// Edit a message written by the local user. Local-first: the row is
  /// updated immediately (tombstone [editedAt] set), then synced.
  /// Peers' messages cannot be edited.
  Future<Either<Failure, Message>> editMessage({
    required String messageId,
    required String newBody,
  });

  /// Delete-for-everyone: tombstone write (deletedAt set, body blanked),
  /// synced like any other row. The message disappears for all
  /// participants on their next sync — never a hard local delete, so the
  /// offline read path is identical to the online one.
  Future<Either<Failure, Unit>> deleteMessage({required String messageId});

  /// Reactions on one message, all users. Re-emits on toggle.
  Stream<Either<Failure, List<Reaction>>> watchReactions({
    required String messageId,
  });

  /// Toggle the local user's [reaction] on a message. Local-first: the
  /// reaction row is written (or removed) immediately with outbox
  /// status, then synced.
  Future<Either<Failure, bool>> toggleReaction({
    required String messageId,
    required String reaction,
  });

  /// Advance the local user's read cursor for a conversation to now —
  /// the "user looked at the chat" signal that drives delivered→read
  /// transitions and unread badges.
  Future<Either<Failure, Unit>> markConversationRead({
    required String conversationId,
  });

  /// Unread (cursor-not-advanced) incoming messages for a conversation.
  Future<Either<Failure, int>> unreadCount({
    required String conversationId,
  });

  /// Live total unread across all conversations — the shell-level badge
  /// on the Vault nav destination. Emits on every message/cursor change;
  /// opening a conversation (markConversationRead) drives it down.
  Stream<int> watchTotalUnread();

  /// One-shot sync of undelivered (pending/failed) messages — the outbox
  /// flush the background worker would call.
  Future<Either<Failure, Unit>> syncOutbox();

  /// Seed conversations. Mock-only convenience exposed through the
  /// contract while there is no real backend; removed at integration.
  Future<Either<Failure, Unit>> ensureSeeded();
}
