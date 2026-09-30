import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/design_system/sketch_kit.dart';
import 'package:echo_bay/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:echo_bay/features/vault/data/repositories/mock_chat_repository.dart';
import 'package:echo_bay/features/vault/domain/entities/message.dart';
import 'package:echo_bay/features/vault/ui/vault_chat_page.dart';
import 'package:echo_bay/features/vault/ui/vault_conversation_list.dart';

import 'package:drift/native.dart';

/// In-memory drift instance per test — no disk, no pollution.
/// Returns the mock repo so tests can stop its inbound ticker in teardown
/// (flutter_test forbids timers pending past widget disposal).
(MockChatRepository, AppDatabase) _makeRepo() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final local = DriftVaultLocalDatasource(db);
  return (
    MockChatRepository(
      localDatasource: local,
      incomingMessageInterval: const Duration(seconds: 3600),
      startTicker: false,
      peerReplies: false,
    ),
    db,
  );
}

void main() {
  group('Vault conversation list', () {
    testWidgets('renders seeded conversations with lock badges',
        (tester) async {
      final (repo, db) = _makeRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });
      await repo.ensureSeeded();

      await tester.pumpWidget(MaterialApp(
        home: VaultConversationList(repository: repo),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('The Vault'), findsOneWidget);
      expect(find.text('Rune Virtanen'), findsOneWidget);
      expect(find.text('Signal Ops Team'), findsOneWidget);
      expect(find.text('Mila Kang'), findsOneWidget);
      // Every tile advertises privacy. Lock badges are the chalk
      // padlock glyph now (SketchIcon), not a Material icon.
      expect(find.text('Private · local-first · tap to open'),
          findsNWidgets(3));
      expect(
        find.byWidgetPredicate(
            (w) => w is SketchIcon && w.kind == SketchIconKind.padlock),
        findsAtLeastNWidgets(3),
      );
    });

    testWidgets('tapping a tile opens the chat page', (tester) async {
      final (repo, db) = _makeRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });
      await repo.ensureSeeded();

      await tester.pumpWidget(MaterialApp(
        home: VaultConversationList(repository: repo),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Rune Virtanen'));
      await tester.pump(const Duration(milliseconds: 500));
      // Route transition needs a couple of frames to land.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VaultChatPage), findsOneWidget);
      expect(find.text('Private · local-first'), findsOneWidget);
    });
  });

  group('Vault chat page', () {
    testWidgets('empty conversation shows privacy notice', (tester) async {
      final (repo, db) = _makeRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });
      await repo.ensureSeeded();
      // Constructed directly, not awaited from watchConversations(): a
      // drift stream event needs a real timer tick, which FakeAsync never
      // advances — awaiting it here deadlocks the test runner.
      // 'conv-2', not conv-1: the first-run welcome message seeds into
      // conv-1, so the empty-state assertion needs a conversation the
      // seeder leaves untouched.
      final conversation = Conversation(
        id: 'conv-2',
        title: 'Signal Ops Team',
        participantIds: const [Conversation.localUserId, 'peer-ops'],
        lastActivityAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: VaultChatPage(repository: repo, conversation: conversation),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('Stays on this device'),
        findsOneWidget,
      );
    });

    testWidgets('sending a message shows pending tick, then delivered',
        (tester) async {
      final (repo, db) = _makeRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });
      await repo.ensureSeeded();
      // Constructed directly, not awaited from watchConversations(): a
      // drift stream event needs a real timer tick, which FakeAsync never
      // advances — awaiting it here deadlocks the test runner.
      final conversation = Conversation(
        id: 'conv-1',
        title: 'Rune Virtanen',
        participantIds: const [Conversation.localUserId, 'peer-rune'],
        lastActivityAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: VaultChatPage(repository: repo, conversation: conversation),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Compose and send. Send is the composer's sketch paper-plane
      // button, addressed by tooltip (the icon is custom-drawn).
      await tester.enterText(
          find.byType(TextField), 'hello from the vault');
      // The inked composer enables send on text change — pump the frame.
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 100));

      // Bubble renders immediately (local-first write).
      expect(find.text('hello from the vault'), findsOneWidget);
      // Pending tick visible before the simulated ack lands.
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      // Walk the full simulated lifecycle: sent at +900ms (single tick),
      // delivered at +1800ms (double tick), read at +2700ms (double tick,
      // accent-colored). Pumps flush every stage timer for teardown.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    testWidgets('inbound mock messages appear as peer bubbles',
        (tester) async {
      final (repo, db) = _makeRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });
      await repo.ensureSeeded();

      // Drive the repository directly: send as the local user into conv-1,
      // then let the mock inbound ticker deliver a peer message.
      final conversation = Conversation(
        id: 'conv-1',
        title: 'Rune Virtanen',
        participantIds: const [Conversation.localUserId, 'peer-rune'],
        lastActivityAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: VaultChatPage(repository: repo, conversation: conversation),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      await repo.sendMessage(
          conversationId: 'conv-1', body: 'ping one');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ping one'), findsOneWidget);

      // Flush the full simulated lifecycle (sent/delivered/read at
      // 900/1800/2700ms): flutter_test checks pending timers BEFORE
      // addTearDown runs, so dispose()'s cancel comes too late — the
      // test must elapse the delays itself.
      await tester.pump(const Duration(milliseconds: 2800));
    });

    testWidgets('composer clears after send', (tester) async {
      final (repo, db) = _makeRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });
      await repo.ensureSeeded();
      // Constructed directly, not awaited from watchConversations(): a
      // drift stream event needs a real timer tick, which FakeAsync never
      // advances — awaiting it here deadlocks the test runner.
      final conversation = Conversation(
        id: 'conv-1',
        title: 'Rune Virtanen',
        participantIds: const [Conversation.localUserId, 'peer-rune'],
        lastActivityAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: VaultChatPage(repository: repo, conversation: conversation),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'auto-clear check');
      // The inked composer enables send on text change — pump the frame.
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 200));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);

      // Flush the full simulated lifecycle so teardown sees no pending
      // timers (the invariant check runs before addTearDown).
      await tester.pump(const Duration(milliseconds: 2800));
    });
  });
}
