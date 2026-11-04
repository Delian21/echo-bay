import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/chat/message_edit.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/settings/draft_store.dart';
import 'package:echo_bay/core/theme/app_theme.dart';
import 'package:echo_bay/features/nexus/data/datasources/nexus_local_datasource.dart';
import 'package:echo_bay/features/nexus/data/repositories/mock_nexus_repository.dart';
import 'package:echo_bay/features/social/data/repositories/drift_social_repository.dart';
import 'package:echo_bay/features/square/data/datasources/square_local_datasource.dart';
import 'package:echo_bay/features/square/data/repositories/mock_feed_repository.dart';
import 'package:echo_bay/features/square/domain/entities/post.dart';
import 'package:echo_bay/features/square/ui/post_composer.dart';
import 'package:echo_bay/features/square/ui/square_card.dart';
import 'package:echo_bay/features/square/ui/square_post_model.dart';
import 'package:echo_bay/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:echo_bay/features/vault/data/repositories/mock_chat_repository.dart';
import 'package:echo_bay/injection.dart';

/// Edit + delete for posts, comments and messages, plus drafts.
///
/// The important cases are the ones the previous delete path got wrong:
/// content written before the auth seam (authorId `local-user`) must stay
/// deletable, a tombstoned post must stay gone after a restart, and the
/// long-press must survive the Golden Hour card shell.
void main() {
  group('v17 -> v18 migration', () {
    test('adds posts.edited_at and keeps existing posts', () async {
      final dir = await Directory.systemTemp.createTemp('echo-v18-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');

      final first = AppDatabase.forTesting(NativeDatabase(file));
      final local = DriftSquareLocalDatasource(first);
      final repo = MockFeedRepository(
        localDatasource: local,
        db: first,
        seedOnStart: false,
        startTicker: false,
      );
      final created = await repo.createPost(
          body: 'written before the migration', authorName: 'You');
      final postId = created.fold((f) => throw f, (p) => p.id);
      repo.dispose();

      await first.customStatement('ALTER TABLE posts DROP COLUMN edited_at;');
      await first.customStatement('PRAGMA user_version = 17;');
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(second.close);
      expect(second.schemaVersion, 18);

      final columns =
          await second.customSelect('PRAGMA table_info(posts)').get();
      expect(columns.map((r) => r.data['name']), contains('edited_at'));

      final rows = await second.select(second.posts).get();
      final old = rows.firstWhere((r) => r.id == postId);
      expect(old.body, 'written before the migration');
      expect(old.editedAt, isNull, reason: 'old posts were never edited');
    });
  });

  group('posts', () {
    late AppDatabase db;
    late MockFeedRepository repo;
    late DriftSquareLocalDatasource local;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = DriftSquareLocalDatasource(db);
      repo = MockFeedRepository(
        localDatasource: local,
        db: db,
        localUserId: 'session-u',
        seedOnStart: false,
        startTicker: false,
      );
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
    });

    Future<Post> create(String body) async {
      final result = await repo.createPost(body: body, authorName: 'You');
      return result.fold((f) => throw f, (p) => p);
    }

    test('editing stamps editedAt and rewrites the body everywhere', () async {
      final post = await create('first draft');
      final edited = await repo.editPost(postId: post.id, body: 'second thought');
      final updated = edited.fold((f) => throw f, (p) => p);
      expect(updated.body, 'second thought');
      expect(updated.editedAt, isNotNull);

      final feed = (await repo.watchFeed().first)
          .fold((f) => throw f, (list) => list);
      final stored = feed.firstWhere((p) => p.id == post.id);
      expect(stored.body, 'second thought');
      expect(stored.editedAt, isNotNull);
    });

    test("someone else's post cannot be edited or deleted", () async {
      final foreign = Post(
        id: 'peer-post',
        authorId: 'peer-rune',
        authorName: 'Rune',
        body: 'not yours',
        createdAt: DateTime.now(),
      );
      await local.insertPost(PostsCompanion.insert(
        id: foreign.id,
        authorId: foreign.authorId,
        authorName: foreign.authorName,
        body: foreign.body,
        createdAt: foreign.createdAt,
      ));
      expect((await repo.editPost(postId: foreign.id, body: 'hijack')).isLeft(),
          isTrue);
      expect((await repo.deletePost(postId: foreign.id)).isLeft(), isTrue);
    });

    test('legacy local-user rows stay deletable after the auth seam',
        () async {
      // Rows written before LocalIdentity existed carry 'local-user' even
      // though the repository now runs with a session id. The app showed
      // them as mine and then refused to delete them — the reported bug.
      await local.insertPost(PostsCompanion.insert(
        id: 'legacy-post',
        authorId: 'local-user',
        authorName: 'You',
        body: 'from an older build',
        createdAt: DateTime.now(),
      ));
      final result = await repo.deletePost(postId: 'legacy-post');
      expect(result.isRight(), isTrue);
      final feed = (await repo.watchFeed().first)
          .fold((f) => throw f, (list) => list);
      expect(feed.any((p) => p.id == 'legacy-post'), isFalse);
    });

    test('deleting a post takes its comments and wall pin with it', () async {
      final post = await create('has notes');
      await db.into(db.postComments).insert(PostCommentsCompanion.insert(
            id: 'c1',
            postId: post.id,
            authorId: 'peer-rune',
            authorName: 'Rune',
            body: 'a note',
            createdAt: DateTime.now(),
          ));
      await db.into(db.keepsakeItems).insert(KeepsakeItemsCompanion.insert(
            id: 'k1',
            kind: KeepsakeKind.post,
            postId: Value(post.id),
            posX: 0.2,
            posY: 0.3,
            rotation: 0.0,
            pinnedAt: DateTime.now(),
          ));

      expect((await repo.deletePost(postId: post.id)).isRight(), isTrue);

      final comments = await db.select(db.postComments).get();
      expect(comments.where((c) => c.postId == post.id), isEmpty);
      final pin = await (db.select(db.keepsakeItems)
            ..where((k) => k.id.equals('k1')))
          .getSingle();
      expect(pin.unpinnedAt, isNotNull);
    });

    test('a deleted post stays gone after reopening the database', () async {
      final dir = await Directory.systemTemp.createTemp('echo-restart-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');

      final first = AppDatabase.forTesting(NativeDatabase(file));
      final firstRepo = MockFeedRepository(
        localDatasource: DriftSquareLocalDatasource(first),
        db: first,
        localUserId: 'session-u',
        seedOnStart: false,
        startTicker: false,
      );
      final created = await firstRepo.createPost(
          body: 'temporary page', authorName: 'You');
      final id = created.fold((f) => throw f, (p) => p.id);
      await firstRepo.deletePost(postId: id);
      firstRepo.dispose();
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(second.close);
      final secondRepo = MockFeedRepository(
        localDatasource: DriftSquareLocalDatasource(second),
        db: second,
        localUserId: 'session-u',
        seedOnStart: false,
        startTicker: false,
      );
      addTearDown(secondRepo.dispose);
      final feed = (await secondRepo.watchFeed().first)
          .fold((f) => throw f, (list) => list);
      expect(feed.any((p) => p.id == id), isFalse,
          reason: 'the tombstone survives a restart');
    });

    test('own comments can be removed, foreign ones refused', () async {
      final social = DriftSocialRepository(db, localUserId: 'session-u');
      final post = await create('notes here');
      final mine = await social.addComment(
          postId: post.id, body: 'my note');
      final mineId = mine.fold((f) => throw f, (c) => c.id);
      await db.into(db.postComments).insert(PostCommentsCompanion.insert(
            id: 'peer-note',
            postId: post.id,
            authorId: 'peer-rune',
            authorName: 'Rune',
            body: 'their note',
            createdAt: DateTime.now(),
          ));

      expect((await social.deleteComment(commentId: mineId)).isRight(), isTrue);
      expect(
          (await social.deleteComment(commentId: 'peer-note')).isLeft(), isTrue);
      final comments = (await social.watchComments(post.id).first)
          .fold((f) => throw f, (list) => list);
      expect(comments.map((c) => c.id), ['peer-note']);
    });
  });

  group('message edit window', () {
    final created = DateTime(2026, 11, 3, 12);
    test('exactly 15 minutes is already too late', () {
      expect(withinMessageEditWindow(created, now: created), isTrue);
      expect(
          withinMessageEditWindow(created,
              now: created.add(const Duration(minutes: 14, seconds: 59))),
          isTrue);
      expect(
          withinMessageEditWindow(created,
              now: created.add(kMessageEditWindow)),
          isFalse);
      expect(
          withinMessageEditWindow(created,
              now: created.add(const Duration(minutes: 20))),
          isFalse);
    });

    test('the repository enforces the same window', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = MockChatRepository(
        localDatasource: DriftVaultLocalDatasource(db),
        localUserId: 'session-u',
        incomingMessageInterval: const Duration(hours: 1),
        startTicker: false,
      );
      addTearDown(repo.dispose);
      await repo.ensureSeeded();

      final sent = await repo.sendMessage(conversationId: 'conv-1', body: 'hi');
      final freshId = sent.fold((f) => throw f, (m) => m.id);
      expect((await repo.editMessage(messageId: freshId, newBody: 'hello'))
          .isRight(), isTrue);

      await DriftVaultLocalDatasource(db).insertMessage(
        MessagesCompanion.insert(
          id: 'stale',
          conversationId: 'conv-1',
          senderId: 'session-u',
          body: 'old ink',
          syncStatus: MsgSyncStatus.sent,
          createdAt: DateTime.now().subtract(const Duration(minutes: 16)),
        ),
      );
      expect(
          (await repo.editMessage(messageId: 'stale', newBody: 'too late'))
              .isLeft(),
          isTrue);
    });

    test('legacy local-user messages stay deletable and editable', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = MockChatRepository(
        localDatasource: DriftVaultLocalDatasource(db),
        localUserId: 'session-u',
        incomingMessageInterval: const Duration(hours: 1),
        startTicker: false,
      );
      addTearDown(repo.dispose);
      final local = DriftVaultLocalDatasource(db);
      await local.insertMessage(MessagesCompanion.insert(
        id: 'legacy-msg',
        conversationId: 'conv-1',
        senderId: 'local-user',
        body: 'older build',
        syncStatus: MsgSyncStatus.sent,
        createdAt: DateTime.now(),
      ));

      expect((await repo.editMessage(messageId: 'legacy-msg', newBody: 'fixed'))
          .isRight(), isTrue);
      expect((await repo.deleteMessage(messageId: 'legacy-msg')).isRight(),
          isTrue);
      final row = await local.findMessage('legacy-msg');
      expect(row?.isDeleted, isTrue);
      expect(row?.body, isEmpty,
          reason: 'the tombstone keeps the row but drops the words');
    });
  });

  group('dorm messages', () {
    late AppDatabase db;
    late MockNexusRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = MockNexusRepository(
        localDatasource: DriftNexusLocalDatasource(db),
        localUserId: 'session-u',
        startTickers: false,
      );
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
    });

    test('edit and delete work and land in the stream', () async {
      await repo.ensureSeeded();
      final sent = await repo.sendGroupMessage(
          groupId: 'grp-core', body: 'first');
      final id = sent.fold((f) => throw f, (m) => m.id);

      expect(
          (await repo.editGroupMessage(messageId: id, newBody: 'second'))
              .isRight(),
          isTrue);
      var messages = (await repo.watchGroupMessages(groupId: 'grp-core').first)
          .fold((f) => throw f, (list) => list);
      var stored = messages.firstWhere((m) => m.id == id);
      expect(stored.body, 'second');
      expect(stored.editedAt, isNotNull);

      expect((await repo.deleteGroupMessage(messageId: id)).isRight(), isTrue);
      messages = (await repo.watchGroupMessages(groupId: 'grp-core').first)
          .fold((f) => throw f, (list) => list);
      stored = messages.firstWhere((m) => m.id == id);
      expect(stored.isDeleted, isTrue);
      expect(stored.body, isEmpty);
    });
  });

  group('drafts', () {
    test('are per surface, survive and clear', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DraftStore(db);

      await store.write(DraftStore.vault('conv-1'), 'for Rune');
      await store.write(DraftStore.vault('conv-2'), 'for someone else');

      expect(await store.read(DraftStore.vault('conv-1')), 'for Rune');
      expect(await store.read(DraftStore.vault('conv-2')), 'for someone else');
      expect(await store.read(DraftStore.squareKey), isNull);

      await store.clear(DraftStore.vault('conv-1'));
      expect(await store.read(DraftStore.vault('conv-1')), isNull);
      expect(await store.read(DraftStore.vault('conv-2')), 'for someone else',
          reason: 'clearing one conversation leaves the others alone');
    });

    testWidgets('the compose sheet saves, announces and restores a draft',
        (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await sl.reset();
      sl.registerSingleton<DraftStore>(DraftStore(db));
      addTearDown(sl.reset);
      expect(sl.isRegistered<DraftStore>(), isTrue,
          reason: 'the composer reads its drafts from DI');

      final local = DriftSquareLocalDatasource(db);
      final repo = MockFeedRepository(
        localDatasource: local,
        db: db,
        seedOnStart: false,
        startTicker: false,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPostComposer(
                context,
                repository: repo,
                authorName: 'You',
              ),
              child: const Text('compose'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('compose'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'half a thought');

      // Close the sheet without publishing.
      Navigator.of(tester.element(find.byType(TextField))).pop();
      await tester.pumpAndSettle();
      expect(find.textContaining('Draft saved'), findsOneWidget);
      // The write itself is fire-and-forget in the sheet's dispose: let it
      // land before reading the store.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(await sl<DraftStore>().read(DraftStore.squareKey), 'half a thought');

      // Reopen: the words come back.
      await tester.tap(find.text('compose'));
      await tester.pumpAndSettle();
      expect(find.text('half a thought'), findsOneWidget);

      // Explicit discard kills it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await sl<DraftStore>().read(DraftStore.squareKey), isNull);
    });
  });

  group('post card affordances', () {
    final post = SquarePost(
      id: 'p1',
      username: 'You',
      userAvatarUrl: '',
      timestamp: DateTime.now(),
      caption: 'a page',
      likesCount: 0,
      isLiked: false,
      editedAt: DateTime.now(),
    );

    testWidgets('own post shows a menu with Edit and Delete', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: SquareFeedCard(
            post: post,
            onLike: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ));
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      expect(find.text('· edited'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('foreign post shows no menu', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: SquareFeedCard(post: post, onLike: () {})),
      ));
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('long-press delete works in the Golden Hour shell',
        (tester) async {
      // Regression: the Golden Hour branch rebuilt the card from `body`
      // and dropped the long-press wrapper, so deleting an own post did
      // nothing in the app's default theme.
      var deleted = 0;
      await tester.pumpWidget(MaterialApp(
        theme: buildGoldenHourLightTheme(),
        home: Scaffold(
          body: SquareFeedCard(
            post: post,
            onLike: () {},
            onDelete: () => deleted++,
          ),
        ),
      ));
      await tester.longPress(find.byType(SquareFeedCard));
      await tester.pump(const Duration(milliseconds: 50));
      expect(deleted, 1);
    });

    testWidgets('the own-post menu renders in the dark shell too',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildGoldenHourDarkTheme(),
        home: Scaffold(
          body: SquareFeedCard(
            post: post,
            onLike: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });
}
