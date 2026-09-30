import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/backup/backup_service.dart';
import 'package:echo_bay/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late BackupService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BackupService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('export carries format, schema version, and tombstoned rows', () async {
    // A post, a tombstoned post (soft-deleted), and a like — the
    // tombstone MUST be in the export: time travel depends on it.
    await db.into(db.posts).insert(PostsCompanion.insert(
          id: 'p1',
          authorId: 'a',
          authorName: 'You',
          body: 'kept',
          createdAt: DateTime(2026, 1, 1),
        ));
    await db.into(db.posts).insert(PostsCompanion.insert(
          id: 'p2',
          authorId: 'a',
          authorName: 'You',
          body: 'deleted but kept for time travel',
          createdAt: DateTime(2026, 1, 2),
          deletedAt: Value(DateTime(2026, 1, 3)),
        ));
    await db.into(db.postLikes).insert(PostLikesCompanion.insert(
          postId: 'p1',
          userId: 'u',
          likedAt: DateTime(2026, 1, 1),
        ));

    final result = await service.exportBytes();
    expect(result.isRight(), isTrue);

    final bytes = result.fold((_) => Uint8List(0), (b) => b);
    final payload = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;

    expect(payload['format'], BackupService.formatName);
    expect(payload['schema_version'], db.schemaVersion);
    final data = payload['data'] as Map<String, dynamic>;

    // Tombstoned row survives the export — this is the whole point.
    final posts = data['posts'] as List;
    expect(posts, hasLength(2));
    final deleted = posts.singleWhere((p) => p['id'] == 'p2');
    expect(deleted['deleted_at'], isNotNull);
    expect((data['post_likes'] as List), hasLength(1));
  });

  test('round trip: export then import into an empty database yields '
      'identical data', () async {
    // -- populate a source database with rows across several tables ----
    await db.into(db.posts).insert(PostsCompanion.insert(
          id: 'p1',
          authorId: 'a',
          authorName: 'Kai',
          body: 'a square post with an #anchor',
          createdAt: DateTime(2026, 3, 4, 9, 30),
          expiresAt: Value(DateTime(2026, 3, 5, 9, 30)),
        ));
    await db.into(db.messages).insert(MessagesCompanion.insert(
          id: 'm1',
          conversationId: 'c1',
          senderId: 'peer',
          body: 'vault message',
          syncStatus: MsgSyncStatus.read,
          createdAt: DateTime(2026, 3, 4, 10),
          deletedAt: Value(DateTime(2026, 3, 4, 11)),
        ));
    await db.into(db.keepsakeItems).insert(KeepsakeItemsCompanion.insert(
          id: 'k1',
          kind: KeepsakeKind.note,
          noteText: const Value('a note'),
          posX: 0.25,
          posY: 0.4,
          rotation: 0.03,
          pinnedAt: DateTime(2026, 3, 4),
          unpinnedAt: Value(DateTime(2026, 3, 5)),
        ));
    await db.into(db.postComments).insert(PostCommentsCompanion.insert(
          id: 'cm1',
          postId: 'p1',
          authorId: 'peer',
          authorName: 'Rune',
          body: 'a comment',
          createdAt: DateTime(2026, 3, 4, 12),
        ));
    await db.into(db.settings).insert(
          SettingsCompanion.insert(key: 'profile_name', value: 'You'),
        );

    // -- export ---------------------------------------------------------
    final export = await service.exportBytes();
    final sourceBytes = export.fold((_) => Uint8List(0), (b) => b);

    // -- import into a SECOND database that holds different data -------
    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db2.close);
    final target = BackupService(db2);
    // Existing data must be wiped by the import.
    await db2.into(db2.posts).insert(PostsCompanion.insert(
          id: 'old',
          authorId: 'x',
          authorName: 'Old',
          body: 'to be replaced',
          createdAt: DateTime(2025, 1, 1),
        ));

    final import = await target.importBytes(sourceBytes);
    expect(import.isRight(), isTrue);
    final summary = import.fold((_) => null, (s) => s)!;
    expect(summary.schemaVersion, db.schemaVersion);
    expect(summary.rows, greaterThan(0));

    // -- compare every table row-for-row --------------------------------
    final snap1 = await _snapshot(db);
    final snap2 = await _snapshot(db2);
    expect(snap2, equals(snap1));
  });

  test('import rejects a newer schema with a clear message', () async {
    final payload = <String, dynamic>{
      'format': BackupService.formatName,
      'format_version': BackupService.formatVersion,
      'schema_version': db.schemaVersion + 5,
      'data': const <String, dynamic>{},
    };
    final bytes = Uint8List.fromList(utf8.encode(json.encode(payload)));

    final result = await service.importBytes(bytes);
    expect(result.isLeft(), isTrue);
    final failure = result.fold((f) => f, (_) => null)!;
    expect(failure.message, contains('newer Echo Bay'));
    expect(failure.message, contains('${db.schemaVersion + 5}'));
  });

  test('import rejects non-echo-bay files and malformed JSON', () async {
    const foreignPayload = <String, dynamic>{
      'format': 'other-app',
      'data': <String, dynamic>{},
    };
    final notOurs = Uint8List.fromList(utf8.encode(json.encode(foreignPayload)));
    expect((await service.importBytes(notOurs)).isLeft(), isTrue);

    final garbage = Uint8List.fromList(utf8.encode('{not json'));
    expect((await service.importBytes(garbage)).isLeft(), isTrue);
  });
}

/// Raw table dump used for byte-level round-trip comparison. Rows are
/// compared as maps so column order does not matter; every user table
/// is included.
Future<Map<String, Set<String>>> _snapshot(AppDatabase db) async {
  const tables = [
    'posts',
    'post_likes',
    'conversations',
    'messages',
    'nexus_channels',
    'channel_posts',
    'nexus_groups',
    'group_messages',
    'member_roles',
    'message_reactions',
    'read_cursors',
    'prompts',
    'prompt_prefs',
    'prompt_actions',
    'post_comments',
    'social_notifications',
    'keepsake_items',
    'settings',
  ];
  final snap = <String, Set<String>>{};
  for (final t in tables) {
    final rows = await db.customSelect('SELECT * FROM $t').get();
    snap[t] = {
      for (final r in rows) json.encode(r.data),
    };
  }
  return snap;
}
