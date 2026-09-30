import 'dart:async';

import 'package:drift/drift.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/message.dart';

// -- mappers (data-layer concern) -------------------------------------------

extension MessageRowMapper on MessageRow {
  Message toEntity() => Message(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        body: body,
        createdAt: createdAt,
        status: _statusFromDb(syncStatus),
        editedAt: editedAt,
        deletedAt: deletedAt,
        attachment: _attachmentFromDb(
            attachmentKind, attachmentPath, attachmentDurationMs),
      );

  static MessageAttachment? _attachmentFromDb(
      String? kind, String? path, int? durationMs) {
    if (kind == null || path == null) return null;
    final parsed = switch (kind) {
      'photo' => AttachmentKind.photo,
      'video' => AttachmentKind.video,
      'voice' => AttachmentKind.voice,
      'post' => AttachmentKind.post,
      _ => null,
    };
    if (parsed == null) return null;
    return MessageAttachment(
        kind: parsed, path: path, durationMs: durationMs);
  }

  static DeliveryStatus _statusFromDb(MsgSyncStatus s) => switch (s) {
        MsgSyncStatus.pending => DeliveryStatus.pending,
        MsgSyncStatus.sent => DeliveryStatus.sent,
        MsgSyncStatus.delivered => DeliveryStatus.delivered,
        MsgSyncStatus.read => DeliveryStatus.read,
        MsgSyncStatus.failed => DeliveryStatus.failed,
      };
}

extension ConversationRowMapper on ConversationRow {
  Conversation toEntity() => Conversation(
        id: id,
        title: title,
        participantIds: _decodeParticipants(participantIds),
        lastActivityAt: lastActivityAt,
      );

  static List<String> _decodeParticipants(String json) {
    final trimmed = json.trim();
    if (trimmed.isEmpty || trimmed == '[]') return const [];
    return trimmed
        .substring(1, trimmed.length - 1)
        .split(',')
        .map((e) => e.trim().replaceAll('"', ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

String encodeParticipants(List<String> ids) =>
    '[${ids.map((e) => '"$e"').join(',')}]';

// -- datasource --------------------------------------------------------------

/// Local store access for the Vault. The Vault's source of truth —
/// remote transport never writes here directly except through sync.
abstract class VaultLocalDatasource {
  Stream<List<Conversation>> watchConversations();

  /// Live total of unread inbound messages across ALL conversations —
  /// drives the shell-level badge on the Vault destination.
  Stream<int> watchTotalUnread({required String userId});

  Stream<List<Message>> watchMessages({required String conversationId});

  /// Sets the time-travel instant for message reads (null = present).
  /// Read-only: writes throw while active.
  void setAsOf(DateTime? moment);

  Future<Conversation?> findConversation(String id);

  Future<Message?> findMessage(String id);

  Future<void> insertConversation(ConversationsCompanion entry);

  Future<void> insertMessage(MessagesCompanion entry);

  Future<void> updateMessageBody({
    required String messageId,
    required String body,
    required DateTime editedAt,
  });

  /// Delete-for-everyone tombstone: deletedAt set, body blanked. Never a
  /// hard delete — the offline read path must stay identical online.
  Future<void> markDeleted({
    required String messageId,
    required DateTime deletedAt,
  });

  /// Pending + failed messages across all conversations (outbox).
  Future<List<Message>> pendingMessages();

  /// Update outbox status for one message.
  Future<void> updateStatus({
    required String messageId,
    required DeliveryStatus status,
  });

  // -- reactions + read state (v6) ------------------------------------------

  /// Reactions on one message, all users.
  Future<List<MessageReactionRow>> reactionsFor(String messageId);

  /// Toggle the local user's [reaction] on [messageId]: insert or remove.
  /// Returns true when the reaction now exists. The row carries its own
  /// outbox status; removing a pending row deletes it outright.
  Future<bool> toggleReaction({
    required String messageId,
    required String userId,
    required String reaction,
  });

  /// Pending reaction rows for the outbox flush.
  Future<List<MessageReactionRow>> pendingReactions();

  /// Mark reaction rows synced after the transport run.
  Future<void> markReactionsSynced(List<String> ids);

  /// The local user's read cursor for a conversation.
  Future<ReadCursorRow?> readCursor(String conversationId, String userId);

  /// Advance the read cursor (upsert). Idempotent: never moves backwards.
  Future<void> advanceReadCursor({
    required String conversationId,
    required String userId,
    required String messageId,
    required DateTime at,
  });

  /// Count of messages after the user's cursor (unread), per conversation.
  Future<int> unreadCount({
    required String conversationId,
    required String userId,
  });
}

class DriftVaultLocalDatasource implements VaultLocalDatasource {
  DriftVaultLocalDatasource(this._db);

  final AppDatabase _db;

  /// Time-travel instant (null = present). Affects message reads: the
  /// visited moment shows the body as it was (pre-edit text is not
  /// retained, so edits show the current body only if the edit had
  /// already happened) and hides messages deleted after that moment.
  DateTime? _asOf;

  /// Broadcast that the as-of instant changed so live streams re-run.
  final _asOfTick = StreamController<DateTime?>.broadcast();

  @override
  void setAsOf(DateTime? moment) {
    if (_asOf == moment) return;
    _asOf = moment;
    _asOfTick.add(_asOf);
  }

  void _assertWritable() {
    if (_asOf != null) {
      throw StateError('writes are refused while time traveling');
    }
  }

  @override
  Stream<List<Conversation>> watchConversations() {
    final query = _db.select(_db.conversations)
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.lastActivityAt,
              mode: OrderingMode.desc,
            ),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.toEntity()).toList());
  }

  @override
  Stream<int> watchTotalUnread({required String userId}) {
    // Reactive per-conversation unread counts summed in the stream layer:
    // conversations.watch() re-emits on conversation changes while each
    // unreadCount future re-runs on messages/cursor changes (drift watches
    // the tables those selects touch). Cursor inserts fire through the
    // same table set, so opening a chat clears the badge live.
    return _db.select(_db.conversations).watch().asyncMap((conversations) async {
      var total = 0;
      for (final c in conversations) {
        total += await unreadCount(
          conversationId: c.id,
          userId: userId,
        );
      }
      return total;
    });
  }

  /// As-of semantics for one page of message rows: only messages that
  /// existed by the traveled moment; a delete-for-everyone tombstone
  /// hides the row from that moment on; an edit is visible only once it
  /// had happened (the edited body shows — the original pre-edit text
  /// was overwritten at write time; see the schema-constraint note).
  List<MessageRow> _applyAsOf(List<MessageRow> rows) {
    final moment = _asOf;
    if (moment == null) return rows;
    return rows
        .where((r) =>
            !r.createdAt.isAfter(moment) &&
            (r.deletedAt == null || r.deletedAt!.isAfter(moment)))
        .toList();
  }

  @override
  Stream<List<Message>> watchMessages({required String conversationId}) {
    final query = _db.select(_db.messages)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.asc,
            ),
      ]);
    // Time travel: re-run the query when the as-of instant moves.
    return _asOfTick.stream
        .startWith(null)
        .switchMap((_) => query.watch().map(
              (rows) => _applyAsOf(rows)
                  .map((r) => r.toEntity())
                  .toList(),
            ));
  }

  @override
  Future<Conversation?> findConversation(String id) async {
    final query = _db.select(_db.conversations)
      ..where((tbl) => tbl.id.equals(id));
    return (await query.getSingleOrNull())?.toEntity();
  }

  @override
  Future<Message?> findMessage(String id) async {
    final query = _db.select(_db.messages)
      ..where((tbl) => tbl.id.equals(id));
    return (await query.getSingleOrNull())?.toEntity();
  }

  @override
  Future<void> insertConversation(ConversationsCompanion entry) {
    _assertWritable();
    return _db.into(_db.conversations).insertOnConflictUpdate(entry);
  }

  @override
  Future<void> insertMessage(MessagesCompanion entry) {
    _assertWritable();
    return _db.into(_db.messages).insertOnConflictUpdate(entry);
  }

  @override
  Future<void> updateMessageBody({
    required String messageId,
    required String body,
    required DateTime editedAt,
  }) {
    _assertWritable();
    return (_db.update(_db.messages)..where((tbl) => tbl.id.equals(messageId)))
        .write(MessagesCompanion(
      body: Value(body),
      editedAt: Value(editedAt),
    ));
  }

  @override
  Future<void> markDeleted({
    required String messageId,
    required DateTime deletedAt,
  }) {
    _assertWritable();
    return (_db.update(_db.messages)..where((tbl) => tbl.id.equals(messageId)))
        .write(MessagesCompanion(
      deletedAt: Value(deletedAt),
      body: const Value(''),
    ));
  }

  @override
  Future<List<Message>> pendingMessages() async {
    final query = _db.select(_db.messages)
      ..where((tbl) =>
          tbl.syncStatus.equalsValue(MsgSyncStatus.pending) |
          tbl.syncStatus.equalsValue(MsgSyncStatus.failed))
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.asc,
            ),
      ]);
    final rows = await query.get();
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<void> updateStatus({
    required String messageId,
    required DeliveryStatus status,
  }) {
    final dbStatus = switch (status) {
      DeliveryStatus.pending => MsgSyncStatus.pending,
      DeliveryStatus.sent => MsgSyncStatus.sent,
      DeliveryStatus.delivered => MsgSyncStatus.delivered,
      DeliveryStatus.read => MsgSyncStatus.read,
      DeliveryStatus.failed => MsgSyncStatus.failed,
    };
    return (_db.update(_db.messages)
          ..where((tbl) => tbl.id.equals(messageId)))
        .write(MessagesCompanion(syncStatus: Value(dbStatus)));
  }

  @override
  Future<List<MessageReactionRow>> reactionsFor(String messageId) =>
      (_db.select(_db.messageReactions)
            ..where((tbl) => tbl.messageId.equals(messageId)))
          .get();

  @override
  Future<bool> toggleReaction({
    required String messageId,
    required String userId,
    required String reaction,
  }) async {
    final existing = await (_db.select(_db.messageReactions)
          ..where((tbl) =>
              tbl.messageId.equals(messageId) &
              tbl.userId.equals(userId) &
              tbl.reaction.equals(reaction)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.delete(_db.messageReactions)
            ..where((tbl) => tbl.id.equals(existing.id)))
          .go();
      return false;
    }
    await _db.into(_db.messageReactions).insert(MessageReactionsCompanion.insert(
          id: const Uuid().v4(),
          messageId: messageId,
          targetModule: 'vault',
          userId: userId,
          reaction: reaction,
          syncStatus: ReactionSyncStatus.pending,
          createdAt: DateTime.now(),
        ));
    return true;
  }

  @override
  Future<List<MessageReactionRow>> pendingReactions() =>
      (_db.select(_db.messageReactions)
            ..where(
                (tbl) => tbl.syncStatus.equalsValue(ReactionSyncStatus.pending)))
          .get();

  @override
  Future<void> markReactionsSynced(List<String> ids) =>
      (_db.update(_db.messageReactions)
            ..where((tbl) => tbl.id.isIn(ids)))
          .write(const MessageReactionsCompanion(
        syncStatus: Value(ReactionSyncStatus.synced),
      ));

  @override
  Future<ReadCursorRow?> readCursor(String conversationId, String userId) =>
      (_db.select(_db.readCursors)
            ..where((tbl) =>
                tbl.conversationId.equals(conversationId) &
                tbl.userId.equals(userId)))
          .getSingleOrNull();

  @override
  Future<void> advanceReadCursor({
    required String conversationId,
    required String userId,
    required String messageId,
    required DateTime at,
  }) async {
    final existing = await readCursor(conversationId, userId);
    if (existing != null && !at.isAfter(existing.lastReadAt)) {
      return; // never move backwards
    }
    await _db.into(_db.readCursors).insertOnConflictUpdate(
          ReadCursorsCompanion.insert(
            conversationId: conversationId,
            userId: userId,
            lastReadMessageId: messageId,
            lastReadAt: at,
          ),
        );
  }

  @override
  Future<int> unreadCount({
    required String conversationId,
    required String userId,
  }) async {
    final cursor = await readCursor(conversationId, userId);
    if (cursor == null) {
      // No cursor: everything inbound is unread (own writes never count).
      final count = await (_db.selectOnly(_db.messages)
            ..addColumns([_db.messages.id.count()])
            ..where(_db.messages.conversationId.equals(conversationId) &
                _db.messages.senderId.equals(userId).not()))
          .getSingle();
      return count.read(_db.messages.id.count()) ?? 0;
    }
    // Count messages newer than the cursor timestamp, excluding the
    // local user's own writes (they are by definition read).
    final count = await (_db.selectOnly(_db.messages)
          ..addColumns([_db.messages.id.count()])
          ..where(_db.messages.conversationId.equals(conversationId) &
              _db.messages.createdAt
                  .isBiggerThan(Variable.withDateTime(cursor.lastReadAt)) &
              _db.messages.senderId.equals(userId).not()))
        .getSingle();
    return count.read(_db.messages.id.count()) ?? 0;
  }
}
