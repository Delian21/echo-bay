import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/attachments/attachment.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/design_system/chat_reply_widgets.dart';
import 'package:echo_bay/core/design_system/message_reactions.dart';
import 'package:echo_bay/core/design_system/swipe_to_reply.dart';
import 'package:echo_bay/features/nexus/data/datasources/nexus_local_datasource.dart';
import 'package:echo_bay/features/nexus/data/repositories/mock_nexus_repository.dart';
import 'package:echo_bay/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:echo_bay/features/vault/data/repositories/mock_chat_repository.dart';

/// Reply-to-message + reactions across the Vault and the Dorms.
///
/// Covers the three things that can quietly break: the v16→v17 migration
/// (existing rows must survive), the reply pointer round-tripping through
/// storage, and the one-reaction-per-person rule on the shared outbox
/// table.
void main() {
  group('v16 -> v17 migration', () {
    test('adds the reply columns and keeps existing rows intact', () async {
      final dir = await Directory.systemTemp.createTemp('echo-migration-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');

      // Build a real v17 database with data, then rewind the schema to
      // v16 by dropping the new columns: reopening must migrate it and
      // keep every row.
      final first = AppDatabase.forTesting(NativeDatabase(file));
      final seed = MockChatRepository(
        localDatasource: DriftVaultLocalDatasource(first),
        localUserId: 'me',
        incomingMessageInterval: const Duration(hours: 1),
        startTicker: false,
      );
      await seed.ensureSeeded();
      final sent = await seed.sendMessage(
          conversationId: 'conv-1', body: 'from before the migration');
      final messageId = sent.fold((f) => throw f, (m) => m.id);
      seed.dispose();

      await first.customStatement(
          'ALTER TABLE messages DROP COLUMN reply_to_message_id;');
      await first.customStatement(
          'ALTER TABLE group_messages DROP COLUMN reply_to_message_id;');
      await first.customStatement('PRAGMA user_version = 16;');
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(second.close);

      for (final table in const ['messages', 'group_messages']) {
        final columns = await second
            .customSelect('PRAGMA table_info($table)')
            .get();
        expect(
          columns.map((r) => r.data['name']),
          contains('reply_to_message_id'),
          reason: '$table gains the nullable column on upgrade',
        );
      }
      expect(second.schemaVersion, greaterThanOrEqualTo(17),
          reason: 'opening migrated the schema forward');

      final rows = await second.select(second.messages).get();
      final old = rows.firstWhere((r) => r.id == messageId);
      expect(old.body, 'from before the migration',
          reason: 'no data moves during the migration');
      expect(old.replyToMessageId, isNull,
          reason: 'messages written before v17 have no reply');
    });
  });

  group('replies', () {
    late AppDatabase db;
    late MockChatRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = MockChatRepository(
        localDatasource: DriftVaultLocalDatasource(db),
        localUserId: 'me',
        incomingMessageInterval: const Duration(hours: 1),
        startTicker: false,
      );
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
    });

    test('a reply stores the quoted id and reads it back', () async {
      await repo.ensureSeeded();
      final original = await repo.sendMessage(
          conversationId: 'conv-1', body: 'dinner at eight?');
      final originalId = original.fold((f) => throw f, (m) => m.id);

      final reply = await repo.sendMessage(
        conversationId: 'conv-1',
        body: 'works for me',
        replyToMessageId: originalId,
      );
      final replyId = reply.fold((f) => throw f, (m) => m.id);

      final messages =
          (await repo.watchMessages(conversationId: 'conv-1').first)
              .fold((f) => throw f, (list) => list);
      final quote = messages.firstWhere((m) => m.id == replyId);
      expect(quote.replyToMessageId, originalId);
    });

    test('a reply to a photo keeps the pointer and quotes as "Photo"',
        () async {
      await repo.ensureSeeded();
      final dir = await Directory.systemTemp.createTemp('echo-photo-');
      addTearDown(() => dir.delete(recursive: true));
      final photo = File('${dir.path}/snap.jpg')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      final sent = await repo.sendMessage(
        conversationId: 'conv-1',
        body: '',
        attachment:
            MessageAttachment(kind: AttachmentKind.photo, path: photo.path),
      );
      final photoMessage = sent.fold((f) => throw f, (m) => m);
      expect(photoMessage.attachment?.kind, AttachmentKind.photo);

      final reply = await repo.sendMessage(
        conversationId: 'conv-1',
        body: 'nice shot',
        replyToMessageId: photoMessage.id,
      );
      final replyId = reply.fold((f) => throw f, (m) => m.id);

      final messages = (await repo.watchMessages(conversationId: 'conv-1').first)
          .fold((f) => throw f, (list) => list);
      final stored = messages.firstWhere((m) => m.id == replyId);
      final target = messages.firstWhere((m) => m.id == stored.replyToMessageId);
      expect(replyExcerpt(target.body, target.attachment), 'Photo');
    });

    test('a reply to a deleted message resolves to no target', () async {
      await repo.ensureSeeded();
      final sent =
          await repo.sendMessage(conversationId: 'conv-1', body: 'oops');
      final originalId = sent.fold((f) => throw f, (m) => m.id);
      await repo.deleteMessage(messageId: originalId);

      final reply = await repo.sendMessage(
        conversationId: 'conv-1',
        body: 'quoting a ghost',
        replyToMessageId: originalId,
      );
      final replyId = reply.fold((f) => throw f, (m) => m.id);

      final messages = (await repo.watchMessages(conversationId: 'conv-1').first)
          .fold((f) => throw f, (list) => list);
      final stored = messages.firstWhere((m) => m.id == replyId);
      expect(stored.replyToMessageId, originalId,
          reason: 'the reply keeps its pointer');
      // The tombstone is still in the list, but flagged deleted: the UI
      // must treat it as unavailable rather than quote a blank body.
      final target = messages.firstWhere((m) => m.id == originalId);
      expect(target.isDeleted, isTrue);
    });

    test('reply excerpts name media instead of rendering an empty quote', () {
      expect(replyExcerpt('', null), 'Message');
      expect(
          replyExcerpt(
              '', const MessageAttachment(kind: AttachmentKind.photo, path: '')),
          'Photo');
      expect(
          replyExcerpt(
              '', const MessageAttachment(kind: AttachmentKind.voice, path: '')),
          'Voice note');
      expect(
          replyExcerpt('a caption',
              const MessageAttachment(kind: AttachmentKind.photo, path: '')),
          'a caption');
    });
  });

  group('reactions', () {
    late AppDatabase db;
    late MockChatRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = MockChatRepository(
        localDatasource: DriftVaultLocalDatasource(db),
        localUserId: 'me',
        incomingMessageInterval: const Duration(hours: 1),
        startTicker: false,
      );
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
    });

    test('one reaction per person: picking another replaces it', () async {
      await repo.ensureSeeded();
      final sent = await repo.sendMessage(conversationId: 'conv-1', body: 'yo');
      final id = sent.fold((f) => throw f, (m) => m.id);
      final local = DriftVaultLocalDatasource(db);

      await repo.toggleReaction(messageId: id, reaction: 'heart');
      expect(await local.reactionsFor(id), hasLength(1));

      await repo.toggleReaction(messageId: id, reaction: 'laugh');
      final rows = await local.reactionsFor(id);
      expect(rows, hasLength(1), reason: 'replaced, not stacked');
      expect(rows.single.reaction, 'laugh');

      // Same emoji again removes it.
      await repo.toggleReaction(messageId: id, reaction: 'laugh');
      expect(await local.reactionsFor(id), isEmpty);
    });

    test('the conversation stream carries reactions to every bubble',
        () async {
      await repo.ensureSeeded();
      final sent = await repo.sendMessage(conversationId: 'conv-1', body: 'hi');
      final id = sent.fold((f) => throw f, (m) => m.id);
      await repo.toggleReaction(messageId: id, reaction: 'heart');

      final reactions = await repo
          .watchConversationReactions(conversationId: 'conv-1')
          .first;
      final rows = reactions.fold((f) => throw f, (list) => list);
      expect(rows.any((r) => r.messageId == id && r.reaction == 'heart'),
          isTrue);
    });

    test('a dorm message collects several people on one pill', () async {
      final nexus = MockNexusRepository(
        localDatasource: DriftNexusLocalDatasource(db),
        startTickers: false,
      );
      addTearDown(nexus.dispose);
      await nexus.ensureSeeded();

      final sent = await nexus.sendGroupMessage(
          groupId: 'grp-core', body: 'ship it?');
      final id = sent.fold((f) => throw f, (m) => m.id);

      await nexus.toggleGroupReaction(messageId: id, reaction: 'heart');
      await DriftNexusLocalDatasource(db).toggleGroupReaction(
        messageId: id,
        userId: 'peer-ada',
        reaction: 'heart',
      );

      final rows = (await nexus
              .watchGroupReactions(groupId: 'grp-core')
              .first)
          .fold((f) => throw f, (list) => list);

      final pills = summarizeReactions(
        rows
            .where((r) => r.messageId == id)
            .map((r) => (userId: r.userId, reaction: r.reaction)),
        localUserId: nexus.localUserId,
      );
      expect(pills, hasLength(1));
      expect(pills.single.count, 2);
      expect(pills.single.mine, isTrue);
    });
  });

  group('swipe gesture', () {
    testWidgets('a peer bubble triggers only when swiped toward the middle',
        (tester) async {
      var replies = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SwipeToReply(
              isMine: false,
              onReply: () => replies++,
              child: const SizedBox(width: 160, height: 48),
            ),
          ),
        ),
      ));

      // Away from the middle: ignored (would be a drag, not a reply).
      await tester.drag(find.byType(SwipeToReply), const Offset(-70, 0));
      await tester.pumpAndSettle();
      expect(replies, 0);

      // Toward the middle, past the threshold.
      await tester.drag(find.byType(SwipeToReply), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(replies, 1);
    });

    testWidgets('a short swipe springs back without replying', (tester) async {
      var replies = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SwipeToReply(
              isMine: true,
              onReply: () => replies++,
              child: const SizedBox(width: 160, height: 48),
            ),
          ),
        ),
      ));

      await tester.drag(find.byType(SwipeToReply), const Offset(-20, 0));
      await tester.pumpAndSettle();
      expect(replies, 0);
    });
  });

  group('quote rendering', () {
    testWidgets('a missing original says so instead of crashing',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: QuotedMessageBlock(
            senderName: 'Rune',
            text: '',
            isMine: false,
            unavailable: true,
          ),
        ),
      ));
      expect(find.text('Original message unavailable'), findsOneWidget);
      expect(find.text('Rune'), findsOneWidget);
    });

    testWidgets('the awaiting-reply banner shows sender, line and a way out',
        (tester) async {
      var cancelled = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReplyBanner(
            senderName: 'Rune',
            text: 'dinner at eight?',
            onCancel: () => cancelled = true,
          ),
        ),
      ));
      expect(find.text('Rune'), findsOneWidget);
      expect(find.text('dinner at eight?'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel reply'));
      expect(cancelled, isTrue);
    });
  });
}
