import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/search/drift_search_repository.dart';
import 'package:superapp/core/search/search_hit.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';

/// Schema v5: FTS5 indexes stay in lockstep with content tables via
/// triggers; blurhash columns exist and round-trip.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('FTS5 search', () {
    test('inserts are indexed by the trigger', () async {
      await db.into(db.posts).insert(PostsCompanion.insert(
            id: 'p1',
            authorId: 'a',
            authorName: 'Kai Meridian',
            body: 'the quick brown fox jumps',
            createdAt: DateTime.now(),
          ));

      final hits = await db.searchAllRaw('fox');
      expect(hits, hasLength(1));
      expect(hits.single.source, 'square_post');
      expect(hits.single.id, 'p1');
      expect(hits.single.snippet, contains('fox'));
    });

    test('updates re-index (edit flow)', () async {
      await db.into(db.messages).insert(MessagesCompanion.insert(
            id: 'm1',
            conversationId: 'c1',
            senderId: 'me',
            body: 'original words here',
            syncStatus: MsgSyncStatus.sent,
            createdAt: DateTime.now(),
          ));

      expect(await db.searchAllRaw('original'), hasLength(1));
      expect(await db.searchAllRaw('corrected'), isEmpty);

      await (db.update(db.messages)..where((t) => t.id.equals('m1')))
          .write(const MessagesCompanion(
        body: Value('corrected words here'),
      ));

      expect(await db.searchAllRaw('corrected'), hasLength(1));
      expect(await db.searchAllRaw('original'), isEmpty);
    });

    test('deletes are removed from the index', () async {
      await db.into(db.messages).insert(MessagesCompanion.insert(
            id: 'm2',
            conversationId: 'c1',
            senderId: 'me',
            body: 'vanishing act message',
            syncStatus: MsgSyncStatus.sent,
            createdAt: DateTime.now(),
          ));
      expect(await db.searchAllRaw('vanishing'), hasLength(1));

      await (db.delete(db.messages)..where((t) => t.id.equals('m2'))).go();
      expect(await db.searchAllRaw('vanishing'), isEmpty);
    });

    test('multi-word queries AND across columns', () async {
      await db.into(db.posts).insert(PostsCompanion.insert(
            id: 'p2',
            authorId: 'a',
            authorName: 'Nova Okafor',
            body: 'offline first architecture holds',
            createdAt: DateTime.now(),
          ));
      await db.into(db.posts).insert(PostsCompanion.insert(
            id: 'p3',
            authorId: 'a',
            authorName: 'Kai Meridian',
            body: 'the river keeps flowing',
            createdAt: DateTime.now(),
          ));

      expect((await db.searchAllRaw('offline river')), isEmpty);
      expect((await db.searchAllRaw('offline architecture')).single.id, 'p2');
      expect((await db.searchAllRaw('river flowing')).single.id, 'p3');
    });

    test('special characters are sanitized, not a syntax error', () async {
      await db.into(db.posts).insert(PostsCompanion.insert(
            id: 'p4',
            authorId: 'a',
            authorName: 'Bo Tamm',
            body: 'quotes " and parens (test) here',
            createdAt: DateTime.now(),
          ));
      // Raw FTS5 syntax in user input must neither throw nor match all.
      final hits = await db.searchAllRaw('" AND * OR');
      expect(hits, isEmpty);
      expect(await db.searchAllRaw('parens'), hasLength(1));
    });

    test('empty/whitespace query returns nothing', () async {
      expect(await db.searchAllRaw(''), isEmpty);
      expect(await db.searchAllRaw('   '), isEmpty);
    });

    test('tombstoned messages stop matching (blanked body)', () async {
      await db.into(db.messages).insert(MessagesCompanion.insert(
            id: 'm3',
            conversationId: 'c1',
            senderId: 'me',
            body: 'secret phrase pineapple',
            syncStatus: MsgSyncStatus.read,
            createdAt: DateTime.now(),
          ));
      expect(await db.searchAllRaw('pineapple'), hasLength(1));

      // Delete-for-everyone blanks the body; the UPDATE trigger re-indexes.
      await (db.update(db.messages)..where((t) => t.id.equals('m3')))
          .write(MessagesCompanion(
        deletedAt: Value(DateTime.now()),
        body: const Value(''),
      ));
      expect(await db.searchAllRaw('pineapple'), isEmpty);
    });
  });

  group('DriftSearchRepository', () {
    late DriftSearchRepository repo;

    setUp(() {
      repo = DriftSearchRepository(db);
    });

    test('searches across all three sources with enrichment', () async {
      await db.into(db.posts).insert(PostsCompanion.insert(
            id: 'post-1',
            authorId: 'a1',
            authorName: 'Kai Meridian',
            body: 'pineapple architecture manifesto',
            createdAt: DateTime(2026, 1, 1),
          ));
      await db.into(db.conversations).insert(ConversationsCompanion.insert(
            id: 'conv-9',
            title: 'Mila Kang',
            participantIds: '["me","peer"]',
            lastActivityAt: DateTime(2026, 1, 2),
          ));
      await db.into(db.messages).insert(MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: 'conv-9',
            senderId: 'peer',
            body: 'the pineapple is a lie',
            syncStatus: MsgSyncStatus.read,
            createdAt: DateTime(2026, 1, 2),
          ));
      await db.into(db.nexusGroups).insert(NexusGroupsCompanion.insert(
            id: 'grp-9',
            title: 'Fruit Critics',
            memberIds: '["me"]',
            lastActivityAt: DateTime(2026, 1, 3),
          ));
      await db.into(db.groupMessages).insert(GroupMessagesCompanion.insert(
            id: 'gmsg-1',
            groupId: 'grp-9',
            senderId: 'peer-ada',
            body: 'pineapple discourse, vol. 2',
            syncStatus: MsgSyncStatus.sent,
            createdAt: DateTime(2026, 1, 3),
          ));

      final result = await repo.search(query: 'pineapple');
      final hits = result.fold((f) => throw f, (h) => h);
      expect(hits, hasLength(3));
      expect(
        hits.map((h) => h.source).toSet(),
        {
          SearchSource.squarePost,
          SearchSource.vaultMessage,
          SearchSource.groupMessage,
        },
      );

      final vault = hits.singleWhere((h) => h.source == SearchSource.vaultMessage);
      expect(vault.containerId, 'conv-9');
      expect(vault.containerTitle, 'Mila Kang');
      expect(vault.snippet, contains('pineapple'));
    });

    test('empty query is an empty success, not a failure', () async {
      final result = await repo.search(query: '   ');
      expect(result.fold((f) => null, (h) => h), isEmpty);
    });
  });

  group('blurhash pipeline', () {
    test('mock writes a decodable hash for every media post', () async {
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final local = DriftSquareLocalDatasource(db2);
      final repo = MockFeedRepository(
        localDatasource: local,
        db: db2,
        seedOnStart: true,
        startTicker: false,
      );
      addTearDown(repo.dispose);
      await repo.watchFeed().first;

      final posts = await local.watchFeed().first;
      final mediaPosts = posts.where((p) => p.hasMedia).toList();
      expect(mediaPosts, isNotEmpty);
      for (final post in mediaPosts) {
        expect(post.blurhash, isNotNull);
        // Every written hash must decode — decode throws on malformed.
        expect(() => BlurHash.decode(post.blurhash!), returnsNormally);
      }
    });

    test('text-only posts carry no hash', () async {
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final local = DriftSquareLocalDatasource(db2);
      final repo = MockFeedRepository(
        localDatasource: local,
        db: db2,
        seedOnStart: false,
        startTicker: false,
      );
      addTearDown(repo.dispose);

      final result = await repo.createPost(body: 'text only');
      final post = result.fold((f) => throw f, (p) => p);
      expect(post.mediaUrl, isNull);
      expect(post.blurhash, isNull);
    });
  });

  group('blurhash columns', () {
    test('post blurhash round-trips', () async {
      await db.into(db.posts).insert(PostsCompanion.insert(
            id: 'p5',
            authorId: 'a',
            authorName: 'Kai',
            body: 'with media',
            mediaUrl: const Value('https://x/img.jpg'),
            blurhash: const Value('LEHV6nWB2yk8pyo0adR*.7kCMdnj'),
            createdAt: DateTime.now(),
          ));
      final row = await (db.select(db.posts)
            ..where((t) => t.id.equals('p5')))
          .getSingle();
      expect(row.blurhash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
    });

    test('null blurhash is the default for text-only posts', () async {
      await db.into(db.posts).insert(PostsCompanion.insert(
            id: 'p6',
            authorId: 'a',
            authorName: 'Kai',
            body: 'text only',
            createdAt: DateTime.now(),
          ));
      final row = await (db.select(db.posts)
            ..where((t) => t.id.equals('p6')))
          .getSingle();
      expect(row.blurhash, isNull);
    });
  });
}
