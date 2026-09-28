import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:superapp/features/vault/data/repositories/mock_chat_repository.dart';

/// #2 lightweight interaction layer: reactions are outbox rows, read
/// state is a per-conversation cursor (Discord/WhatsApp lessons).
void main() {
  late AppDatabase db;
  late MockChatRepository repo;
  const me = 'local-test-user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MockChatRepository(
      localDatasource: DriftVaultLocalDatasource(db),
      localUserId: me,
      incomingMessageInterval: const Duration(seconds: 3600),
      startTicker: false,
    );
  });

  tearDown(() async {
    repo.dispose();
    await db.close();
  });

  Future<String> sendMine(String body) async {
    final result = await repo.sendMessage(conversationId: 'conv-1', body: body);
    return result.fold((f) => throw f, (m) => m.id);
  }

  group('reactions', () {
    test('toggle on creates a pending row; toggle off removes it', () async {
      await repo.ensureSeeded();
      final messageId = await sendMine('react to me');

      final on = await repo.toggleReaction(
          messageId: messageId, reaction: 'heart');
      expect(on.fold((f) => throw f, (v) => v), isTrue);

      final reactions = await DriftVaultLocalDatasource(db)
          .reactionsFor(messageId);
      expect(reactions, hasLength(1));
      expect(reactions.single.userId, me);
      expect(reactions.single.reaction, 'heart');
      expect(reactions.single.syncStatus, ReactionSyncStatus.pending,
          reason: 'reactions queue through the outbox like messages');

      // Toggle off: row removed, no tombstone needed.
      final off = await repo.toggleReaction(
          messageId: messageId, reaction: 'heart');
      expect(off.fold((f) => throw f, (v) => v), isFalse);
      expect(
          await DriftVaultLocalDatasource(db).reactionsFor(messageId),
          isEmpty);
    });

    test('different users react independently', () async {
      await repo.ensureSeeded();
      final messageId = await sendMine('crowd favorite');
      final local = DriftVaultLocalDatasource(db);

      await repo.toggleReaction(messageId: messageId, reaction: 'heart');
      // Peer reaction written directly through the datasource.
      await local.toggleReaction(
        messageId: messageId,
        userId: 'peer-rune',
        reaction: 'heart',
      );

      expect(await local.reactionsFor(messageId), hasLength(2));
    });

    test('reaction on unknown message fails', () async {
      final result = await repo.toggleReaction(
          messageId: 'nope', reaction: 'heart');
      expect(result.isLeft(), isTrue);
    });

    test('syncOutbox marks pending reactions synced', () async {
      await repo.ensureSeeded();
      final messageId = await sendMine('flush me');
      await repo.toggleReaction(messageId: messageId, reaction: 'heart');

      await repo.syncOutbox();

      final rows =
          await DriftVaultLocalDatasource(db).reactionsFor(messageId);
      expect(rows.single.syncStatus, ReactionSyncStatus.synced);
    });
  });

  group('read state', () {
    test('markConversationRead advances the cursor and flips peer to read',
        () async {
      await repo.ensureSeeded();

      // Peer message arrives (inbound = read locally at insert time).
      await DriftVaultLocalDatasource(db).insertMessage(
        MessagesCompanion.insert(
          id: 'peer-in-1',
          conversationId: 'conv-1',
          senderId: 'peer-rune',
          body: 'unread from the peer',
          syncStatus: MsgSyncStatus.delivered,
          createdAt: DateTime.now(),
        ),
      );
      // Re-insert with delivered status to simulate pre-read state.
      await (db.update(db.messages)..where((t) => t.id.equals('peer-in-1')))
          .write(const MessagesCompanion(
        syncStatus: Value(MsgSyncStatus.delivered),
      ));

      final unreadBefore = await repo.unreadCount(conversationId: 'conv-1');
      expect(unreadBefore.fold((f) => throw f, (v) => v), 1);

      await repo.markConversationRead(conversationId: 'conv-1');

      final unreadAfter = await repo.unreadCount(conversationId: 'conv-1');
      expect(unreadAfter.fold((f) => throw f, (v) => v), 0);

      // The peer message flipped delivered -> read via the sync machinery.
      final row = await (db.select(db.messages)
            ..where((t) => t.id.equals('peer-in-1')))
          .getSingle();
      expect(row.syncStatus, MsgSyncStatus.read);

      // Cursor is durable and at the peer message.
      final cursor =
          await DriftVaultLocalDatasource(db).readCursor('conv-1', me);
      expect(cursor, isNotNull);
      expect(cursor!.lastReadMessageId, 'peer-in-1');
    });

    test('own messages never count as unread', () async {
      await repo.ensureSeeded();
      await sendMine('from me');
      // No cursor yet, but own writes are by definition read.
      final unread = await repo.unreadCount(conversationId: 'conv-1');
      expect(unread.fold((f) => throw f, (v) => v), 0);
    });

    test('cursor never moves backwards', () async {
      await repo.ensureSeeded();
      final local = DriftVaultLocalDatasource(db);

      await local.advanceReadCursor(
        conversationId: 'conv-1',
        userId: me,
        messageId: 'm-new',
        at: DateTime.now(),
      );
      final before = await local.readCursor('conv-1', me);

      await local.advanceReadCursor(
        conversationId: 'conv-1',
        userId: me,
        messageId: 'm-old',
        at: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final after = await local.readCursor('conv-1', me);

      expect(after!.lastReadMessageId, before!.lastReadMessageId);
    });
  });
}
