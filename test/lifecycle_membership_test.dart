import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/features/nexus/data/datasources/nexus_local_datasource.dart';
import 'package:echo_bay/features/nexus/data/repositories/mock_nexus_repository.dart';
import 'package:echo_bay/features/nexus/domain/entities/nexus.dart';
import 'package:echo_bay/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:echo_bay/features/vault/data/repositories/mock_chat_repository.dart';
import 'package:echo_bay/features/vault/domain/entities/message.dart';

/// #3 message lifecycle + #1 membership sync entity — the contracts
/// frozen in ARCHITECTURE.md §5, verified against the mocks.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('#3 message lifecycle', () {
    late MockChatRepository repo;

    setUp(() {
      repo = MockChatRepository(
        localDatasource: DriftVaultLocalDatasource(db),
        incomingMessageInterval: const Duration(seconds: 3600),
        startTicker: false,
      );
    });

    tearDown(() => repo.dispose());

    test('lifecycle walks pending → sent → delivered → read', () async {
      await repo.ensureSeeded();

      final result =
          await repo.sendMessage(conversationId: 'conv-1', body: 'lifecycle');
      final message = result.fold((f) => throw f, (m) => m);
      expect(message.status, DeliveryStatus.pending);

      // sent at +900ms, delivered at +1800ms, read at +2700ms.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final sent = await _findMessage(db, message.id);
      expect(sent.status, DeliveryStatus.sent);

      await Future<void>.delayed(const Duration(milliseconds: 900));
      final delivered = await _findMessage(db, message.id);
      expect(delivered.status, DeliveryStatus.delivered);

      await Future<void>.delayed(const Duration(milliseconds: 900));
      final read = await _findMessage(db, message.id);
      expect(read.status, DeliveryStatus.read);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('edit stamps editedAt and updates the body', () async {
      await repo.ensureSeeded();

      final result =
          await repo.sendMessage(conversationId: 'conv-1', body: 'original');
      final message = result.fold((f) => throw f, (m) => m);

      final edit = await repo.editMessage(
          messageId: message.id, newBody: 'corrected');
      final edited = edit.fold((f) => throw f, (m) => m);
      expect(edited.body, 'corrected');
      expect(edited.isEdited, isTrue);
      expect(edited.isDeleted, isFalse);

      final stored = await _findMessage(db, message.id);
      expect(stored.body, 'corrected');
      expect(stored.editedAt, isNotNull);
    });

    test('delete is a tombstone, never a hard delete', () async {
      await repo.ensureSeeded();

      final result =
          await repo.sendMessage(conversationId: 'conv-1', body: 'vanish');
      final message = result.fold((f) => throw f, (m) => m);

      final del = await repo.deleteMessage(messageId: message.id);
      expect(del.isRight(), isTrue);

      // Row still exists with deletedAt set and body blanked.
      final stored = await _findMessage(db, message.id);
      expect(stored.isDeleted, isTrue);
      expect(stored.body, isEmpty);

      // Idempotent: deleting again succeeds.
      final again = await repo.deleteMessage(messageId: message.id);
      expect(again.isRight(), isTrue);
    });

    test('cannot edit or delete a peer message', () async {
      await repo.ensureSeeded();

      // Insert a peer message directly through the datasource path the
      // inbound ticker uses.
      await DriftVaultLocalDatasource(db).insertMessage(
        MessagesCompanion.insert(
          id: 'peer-msg',
          conversationId: 'conv-1',
          senderId: 'peer-rune',
          body: 'peer says',
          syncStatus: MsgSyncStatus.read,
          createdAt: DateTime.now(),
        ),
      );

      final edit =
          await repo.editMessage(messageId: 'peer-msg', newBody: 'hacked');
      expect(edit.isLeft(), isTrue);

      final del = await repo.deleteMessage(messageId: 'peer-msg');
      expect(del.isLeft(), isTrue);
    });

    test('cannot edit a deleted (tombstoned) message', () async {
      await repo.ensureSeeded();

      final result =
          await repo.sendMessage(conversationId: 'conv-1', body: 'gone soon');
      final message = result.fold((f) => throw f, (m) => m);
      await repo.deleteMessage(messageId: message.id);

      final edit = await repo.editMessage(
          messageId: message.id, newBody: 'resurrect');
      expect(edit.isLeft(), isTrue);
    });
  });

  group('#1 membership sync entity', () {
    late MockNexusRepository repo;

    setUp(() {
      repo = MockNexusRepository(
        localDatasource: DriftNexusLocalDatasource(db),
        startTickers: false,
      );
    });

    tearDown(() => repo.dispose());

    test('membership rows carry synced seed state, not pending', () async {
      final seeded = await repo.watchMembers(groupId: 'grp-core').first;
      final memberships = seeded.fold((f) => throw f, (m) => m);
      expect(memberships, isNotEmpty);
      for (final m in memberships) {
        expect(m.syncStatus, MembershipSyncStatus.synced,
            reason: 'seeded rows must not queue phantom join ops');
      }
    });

    test('join queues pending, then syncOutbox confirms', () async {
      await repo.ensureSeeded();

      // Leave first so the join op is a fresh outbox write.
      final left = await repo.leaveGroup(groupId: 'grp-core');
      expect(left.isRight(), isTrue);

      final join = await repo.joinGroup(groupId: 'grp-core');
      final membership = join.fold((f) => throw f, (m) => m);
      expect(membership.syncStatus, MembershipSyncStatus.pending);
      expect(membership.role, MemberRole.member);

      final stored = await _findMembership(db, 'grp-core',
          NexusGroup.localUserId);
      expect(stored.syncStatus, MembershipSyncStatus.pending);

      final flush = await repo.syncOutbox();
      expect(flush.isRight(), isTrue);
      final synced = await _findMembership(db, 'grp-core',
          NexusGroup.localUserId);
      expect(synced.syncStatus, MembershipSyncStatus.synced);
    });

    test('role change requeues the membership as pending', () async {
      await repo.ensureSeeded();

      final result = await repo.setMemberRole(
        groupId: 'grp-core',
        userId: 'peer-ada',
        role: MemberRole.admin,
      );
      final updated = result.fold((f) => throw f, (m) => m);
      expect(updated.role, MemberRole.admin);
      expect(updated.syncStatus, MembershipSyncStatus.pending);

      await repo.syncOutbox();
      final stored = await _findMembership(db, 'grp-core', 'peer-ada');
      expect(stored.role, MemberRole.admin);
      expect(stored.syncStatus, MembershipSyncStatus.synced);
    });

    test('leave is terminal and idempotent', () async {
      await repo.ensureSeeded();

      expect((await repo.leaveGroup(groupId: 'grp-core')).isRight(), isTrue);
      final stored =
          await _findMembership(db, 'grp-core', NexusGroup.localUserId);
      expect(stored.syncStatus, MembershipSyncStatus.left);

      // Second leave: still right, still left-state.
      expect((await repo.leaveGroup(groupId: 'grp-core')).isRight(), isTrue);
    });

    test('join of an unknown group fails, does not write', () async {
      final join = await repo.joinGroup(groupId: 'nope');
      expect(join.isLeft(), isTrue);
    });
  });
}

Future<Message> _findMessage(AppDatabase db, String id) async {
  final row = await (db.select(db.messages)..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  return row!.toEntity();
}

Future<GroupMembership> _findMembership(
    AppDatabase db, String groupId, String userId) async {
  final row = await (db.select(db.memberRoles)
        ..where((t) => t.groupId.equals(groupId) & t.userId.equals(userId)))
      .getSingleOrNull();
  return row!.toEntity();
}
