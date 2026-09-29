import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/search/drift_search_repository.dart';
import 'package:superapp/core/search/search_hit.dart';
import 'package:superapp/core/settings/app_settings_store.dart';

/// Part B: search matching, module grouping, expired-post exclusion and
/// delete-for-everyone tombstone exclusion. Runs against an in-memory
/// drift database; FTS5 triggers keep the indexes in lockstep.
void main() {
  late AppDatabase db;
  late DriftSearchRepository repo;
  final fixedNow = DateTime(2026, 9, 29, 12);

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      clock: () => fixedNow,
    );
    repo = DriftSearchRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedSquarePost(
    String id,
    String body, {
    DateTime? expiresAt,
    DateTime? deletedAt,
  }) =>
      db.into(db.posts).insert(PostsCompanion.insert(
            id: id,
            authorId: 'a',
            authorName: 'Kai Meridian',
            body: body,
            createdAt: fixedNow.subtract(const Duration(hours: 1)),
            expiresAt: Value(expiresAt),
            deletedAt: Value(deletedAt),
          ));

  Future<void> seedVaultMessage(String id, String body,
          {DateTime? deletedAt}) =>
      db.into(db.messages).insert(MessagesCompanion.insert(
            id: id,
            conversationId: 'c1',
            senderId: 'peer',
            body: body,
            syncStatus: MsgSyncStatus.sent,
            createdAt: fixedNow.subtract(const Duration(hours: 1)),
          )).then((_) async {
        if (deletedAt != null) {
          await (db.update(db.messages)..where((t) => t.id.equals(id)))
              .write(MessagesCompanion(deletedAt: Value(deletedAt)));
        }
      });

  Future<void> seedGroupMessage(String id, String body,
          {DateTime? deletedAt}) =>
      db.into(db.groupMessages).insert(GroupMessagesCompanion.insert(
            id: id,
            groupId: 'g1',
            senderId: 'peer',
            body: body,
            syncStatus: MsgSyncStatus.sent,
            createdAt: fixedNow.subtract(const Duration(hours: 1)),
          )).then((_) async {
        if (deletedAt != null) {
          await (db.update(db.groupMessages)..where((t) => t.id.equals(id)))
              .write(GroupMessagesCompanion(deletedAt: Value(deletedAt)));
        }
      });

  Future<void> seedBoardPost(String id, String body,
          {DateTime? expiresAt}) =>
      db.into(db.channelPosts).insert(ChannelPostsCompanion.insert(
            id: id,
            channelId: 'ch1',
            authorName: 'R. Virtanen',
            body: body,
            createdAt: fixedNow.subtract(const Duration(hours: 1)),
            expiresAt: Value(expiresAt),
          ));

  group('matching', () {
    test('one query matches across all four indexes', () async {
      await seedSquarePost('p1', 'lantern parade tonight');
      await seedVaultMessage('m1', 'did you see the lantern parade?');
      await seedGroupMessage('gm1', 'lantern parade meeting point');
      await seedBoardPost('bp1', 'lantern parade route announcement');

      final hits = (await repo.search(query: 'lantern')).fold(
        (_) => fail('expected right'),
        (h) => h,
      );
      expect(hits, hasLength(4));
      final sources = hits.map((h) => h.source).toSet();
      expect(
        sources,
        {
          SearchSource.squarePost,
          SearchSource.vaultMessage,
          SearchSource.groupMessage,
          SearchSource.boardPost,
        },
      );
    });

    test('tombstoned vault and dorm messages are excluded', () async {
      await seedVaultMessage('m2', 'secret plans for saturday');
      await seedVaultMessage('m3', 'secret plans were cancelled',
          deletedAt: fixedNow);
      await seedGroupMessage('gm2', 'secret santa draw');
      await seedGroupMessage('gm3', 'secret santa postponed',
          deletedAt: fixedNow);
      await seedSquarePost('p5', 'secret spot at the pier');

      final hits = (await repo.search(query: 'secret')).fold(
        (_) => fail('expected right'),
        (h) => h,
      );
      final ids = hits.map((h) => h.id).toSet();
      expect(ids, {'m2', 'gm2', 'p5'});
    });

    test('tombstoned square posts are excluded', () async {
      await seedSquarePost('p6', 'deleted later message body');
      await seedSquarePost(
        'p7',
        'deleted message body here',
        deletedAt: fixedNow,
      );

      final hits = (await repo.search(query: 'deleted')).fold(
        (_) => fail('expected right'),
        (h) => h,
      );
      expect(hits.map((h) => h.id), ['p6']);
    });
  });

  group('grouping', () {
    test('hits land in the right module buckets', () async {
      await seedSquarePost('p2', 'gallery wall photos');
      await seedVaultMessage('m4', 'gallery opening at eight');
      await seedBoardPost('bp2', 'gallery submissions open');

      final hits = (await repo.search(query: 'gallery')).fold(
        (_) => fail('expected right'),
        (h) => h,
      );
      final bySource = {for (final h in hits) h.source: h};
      expect(bySource[SearchSource.squarePost]!.containerTitle,
          'Kai Meridian');
      expect(bySource[SearchSource.vaultMessage]!.containerId, 'c1');
      expect(bySource[SearchSource.boardPost]!.containerId, 'ch1');
    });
  });

  group('expired ephemeral exclusion', () {
    test('expired posts never surface even before the lazy purge',
        () async {
      await seedSquarePost(
        'p3',
        'fading summer picnic recap',
        expiresAt: fixedNow.subtract(const Duration(minutes: 1)),
      );
      await seedSquarePost(
        'p4',
        'fading but still here',
        expiresAt: fixedNow.add(const Duration(hours: 2)),
      );

      final hits = (await repo.search(query: 'fading')).fold(
        (_) => fail('expected right'),
        (h) => h,
      );
      expect(hits.map((h) => h.id), ['p4']);
    });

    test('expired board posts are excluded', () async {
      await seedBoardPost(
        'bp3',
        'expired notice about parking',
        expiresAt: fixedNow.subtract(const Duration(minutes: 2)),
      );
      await seedBoardPost('bp4', 'parking update still current');

      final hits = (await repo.search(query: 'parking')).fold(
        (_) => fail('expected right'),
        (h) => h,
      );
      expect(hits.map((h) => h.id), ['bp4']);
    });
  });

  group('recent searches', () {
    test('settings store round-trips the recents key', () async {
      final store = AppSettingsStore(db);
      expect(await store.readString(AppSettingsStore.searchRecentsKey),
          isNull);

      await store.writeString(
        AppSettingsStore.searchRecentsKey,
        '["lantern","gallery"]',
      );
      expect(await store.readString(AppSettingsStore.searchRecentsKey),
          '["lantern","gallery"]');

      await store.deleteKey(AppSettingsStore.searchRecentsKey);
      expect(await store.readString(AppSettingsStore.searchRecentsKey),
          isNull);
    });
  });
}
