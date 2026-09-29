import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// The Square — feed cache tables
// ---------------------------------------------------------------------------

/// Cached feed posts. Remote is source of truth while online;
/// this table is the offline cache and the read source for the UI.
@DataClassName('PostRow')
class Posts extends Table {
  TextColumn get id => text()(); // uuid, stable across syncs
  TextColumn get authorId => text()();
  TextColumn get authorName => text()();
  TextColumn get body => text()();
  // Nullable: absent for text-only posts. Local file path when mocked,
  // CDN url once a real backend exists.
  TextColumn get mediaUrl => text().nullable()();

  /// Blurhash of the media (Instagram lesson): travels with the metadata,
  /// decodes synchronously at render time so the drift cache paints a
  /// meaningful placeholder offline, before/behind the full image.
  TextColumn get blurhash => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Soft-delete tombstone (undo window): non-null means the post is
  /// hidden from the feed but still restorable. Purged by the repository
  /// after the window closes.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Ephemeral expiry ("fades in 24h"): non-null means the post is
  /// temporary. Visibility is filtered AT QUERY TIME (expiresAt > now),
  /// so correctness never depends on a background job; the row itself
  /// is purged lazily on app start. Null = keeps forever.
  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Like state, tracked locally so the feed works offline.
/// Sync direction when a backend lands: local -> server.
@DataClassName('PostLikeRow')
class PostLikes extends Table {
  TextColumn get postId => text()();
  TextColumn get userId => text()();
  DateTimeColumn get likedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {postId, userId};
}

// ---------------------------------------------------------------------------
// The Vault — local-first message store (source of truth)
// ---------------------------------------------------------------------------

/// Conversations. For now a single local user talks to seeded peers;
/// the schema already carries participant ids for a real backend later.
@DataClassName('ConversationRow')
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get participantIds => text()(); // JSON array of user ids
  DateTimeColumn get lastActivityAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Messages. LOCAL SOURCE OF TRUTH for the Vault — every message is
/// persisted before it is "sent". Ciphertext columns exist from day one so
/// swapping the mock crypto for real E2EE later changes no schema.
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();

  /// Locally assigned client id; used for dedup and outbox tracking.
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get body => text()();

  /// Encrypted payload. Mock stage: null. Real stage: populated, [body]
  /// holds only a local decryption cache.
  TextColumn get ciphertext => text().nullable()();

  /// Outbox state machine (normative — see ARCHITECTURE.md §5):
  ///   pending   — written locally, awaiting transport
  ///   sent      — handed to (mock) transport
  ///   delivered — transport confirmed receipt by the peer/device
  ///   read      — the peer rendered the message
  ///   failed    — attempts exhausted, retryable
  TextColumn get syncStatus => textEnum<MsgSyncStatus>()();
  DateTimeColumn get createdAt => dateTime()();

  /// Tombstones (Telegram/WhatsApp model): edits and delete-for-everyone
  /// are terminal states synced like any other row, never hard deletes —
  /// the offline read path must stay identical to the online one.
  DateTimeColumn get editedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Attachment (schema v9/v10). Kind + local file path; [attachmentPath]
  /// points into the app's attachments directory (copied on send so the
  /// picker's temp file can't vanish under us). [attachmentDurationMs]
  /// carries voice-note length (null for photo/video). Null = text-only.
  TextColumn get attachmentKind => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();
  IntColumn get attachmentDurationMs =>
      integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

enum MsgSyncStatus { pending, sent, delivered, read, failed }

// ---------------------------------------------------------------------------
// The Nexus — channels (remote-first cache) + groups (local-first outbox)
// ---------------------------------------------------------------------------

/// Broadcast channels. CACHE ONLY — the remote is the source of truth;
/// rows here mirror the server exactly like the Square's posts table.
@DataClassName('NexusChannelRow')
class NexusChannels extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  DateTimeColumn get lastPostAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Channel posts with retention + blurhash (same media pattern as
/// [Posts]). [expiresAt] is null for keep-forever;
/// the datasource filters expired rows from every read.
@DataClassName('ChannelPostRow')
class ChannelPosts extends Table {
  TextColumn get id => text()();
  TextColumn get channelId => text()();
  TextColumn get authorName => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  TextColumn get blurhash => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Nexus groups. Local source of truth for group chat, same posture as
/// the Vault's conversations minus E2EE. Roles live in [MemberRoles].
@DataClassName('NexusGroupRow')
class NexusGroups extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get memberIds => text()(); // JSON array of user ids
  DateTimeColumn get lastActivityAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-user role inside a group (owner/admin/member). One row per
/// (group, user); the local user's row drives [NexusGroup.myRole].
///
/// Membership is a sync entity (Reddit/Discord lesson): join/leave/role
/// changes are outbox-style writes with their own sync state, not UI
/// checkboxes. The mock stage queues them as pending; the real transport
/// flushes them like messages.
@DataClassName('MemberRoleRow')
class MemberRoles extends Table {
  TextColumn get groupId => text()();
  TextColumn get userId => text()();
  TextColumn get role => textEnum<NexusMemberRole>()();

  /// Outbox state for the membership operation that produced this row
  /// (join, leave, role change). Kept on the role row itself — one row
  /// per (group, user) carries both state and its sync status.
  TextColumn get syncStatus => textEnum<MemberSyncStatus>()();

  /// When the local user issued the membership operation.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {groupId, userId};
}

/// Storage-side role enum. Domain maps it to [MemberRole] at the mapper
/// edge so the domain layer keeps zero drift vocabulary.
enum NexusMemberRole { owner, admin, member }

/// Storage-side sync state for membership operations. Domain maps it to
/// its own [MembershipSyncStatus] at the mapper edge (same name pattern
/// as NexusMemberRole ↔ MemberRole). Terminal [left] is its own value,
/// distinct from a message's failure: a failed join is retryable by the
/// user, not by a background worker.
enum MemberSyncStatus { pending, synced, failed, left }

// ---------------------------------------------------------------------------
// Reactions + read state (Discord lesson): lightweight interaction is a
// sync problem, not a UI problem. Reactions are outbox rows exactly like
// messages; read state is a per-user, per-conversation cursor.
// ---------------------------------------------------------------------------

/// One reaction on one message. Outbox semantics: the row is written
/// locally first (pending), then synced; [syncStatus] tracks that.
@DataClassName('MessageReactionRow')
class MessageReactions extends Table {
  TextColumn get id => text()();

  /// Target message: a Vault message or a Nexus group message.
  TextColumn get messageId => text()();

  /// Which module owns the target (vault | nexus_group) so the sync
  /// layer can route the row without reverse-engineering ids.
  TextColumn get targetModule => text()();
  TextColumn get userId => text()();

  /// Emoji shortcode ('heart', 'laugh', ...) — presentation maps to glyph.
  TextColumn get reaction => text()();
  TextColumn get syncStatus => textEnum<ReactionSyncStatus>()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

enum ReactionSyncStatus { pending, synced, failed }

// ---------------------------------------------------------------------------
// Social (comments + peer notifications) — schema v13
// ---------------------------------------------------------------------------

/// Comments on Square posts. Local-first: the author's own comment is
/// persisted before anything else happens; mock peers append via the
/// social engine. [authorId] distinguishes 'local-user' from peers.
@DataClassName('PostCommentRow')
class PostComments extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get postId => text()();
  TextColumn get authorId => text()();
  TextColumn get authorName => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notification feed: new comments, reactions, replies — all generated
/// locally in the mock stage. [readAt] non-null = read; unread count is
/// a live query. [deepLink] is a go_router location ('/square',
/// '/vault/conversation/:id', '/nexus/group/:id').
@DataClassName('SocialNotificationRow')
class SocialNotifications extends Table {
  TextColumn get id => text()(); // uuid

  /// 'comment' | 'reaction' | 'reply'
  TextColumn get kind => textEnum<NotificationKind>()();
  TextColumn get peerName => text()();
  TextColumn get body => text()();
  TextColumn get deepLink => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get readAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kind of social notification.
enum NotificationKind { comment, reaction, reply }

// ---------------------------------------------------------------------------
// Keepsake wall — schema v13
// ---------------------------------------------------------------------------

/// One pinned item on the corkboard: a Square post pinned by id, or a
/// freehand note. Position/rotation are board-relative fractions
/// (0..1) — the board scales to phone and desktop without re-layout.
@DataClassName('KeepsakeItemRow')
class KeepsakeItems extends Table {
  TextColumn get id => text()(); // uuid

  /// 'post' | 'note'
  TextColumn get kind => textEnum<KeepsakeKind>()();

  /// Square post id when [kind] == post; null for freehand notes.
  TextColumn get postId => text().nullable()();

  /// Note text when [kind] == note; null for pinned posts.
  TextColumn get noteText => text().nullable()();

  /// Board-relative anchor of the item's top-left corner.
  RealColumn get posX => real()();
  RealColumn get posY => real()();

  /// Tilt in radians (kept small — a thumbtacked print, not a kite).
  RealColumn get rotation => real()();

  /// Second item this one is strung to (hand-inked wobbly string), or
  /// null. One outgoing string per item keeps the board tidy.
  TextColumn get strungTo => text().nullable()();
  DateTimeColumn get pinnedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kind of keepsake item.
enum KeepsakeKind { post, note }

// ---------------------------------------------------------------------------
// The Daily Square (§6c): a recurring, guilt-free posting prompt. The
// schedule and rotation are user-owned; nothing here can shame or gate.
// ---------------------------------------------------------------------------

/// A prompt definition — one entry in the rotation.
@DataClassName('PromptRow')
class Prompts extends Table {
  TextColumn get id => text()();

  /// Which shape of ask this is: photo | sentence | sound | desk ...
  TextColumn get shape => text()();

  /// The prompt's copy ('Show your desk right now.'). Named [body] —
  /// `text` collides with drift's column-builder method.
  TextColumn get body => text()();

  /// Order in the rotation; the active prompt is the next unposted one.
  IntColumn get rotationIndex => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The user's prompt preferences: window, pause state. One row, keyed.
@DataClassName('PromptPrefsRow')
class PromptPrefs extends Table {
  TextColumn get userId => text()();

  /// Hour of day the user's window opens (0-23). User-picked — never
  /// a random interrupt (§6c rule 1).
  IntColumn get windowHour => integer()();

  /// Opt-in flag and pause: false or paused = no prompt fires (§6c rule 5).
  BoolColumn get optedIn => boolean().withDefault(const Constant(false))();
  DateTimeColumn get pausedUntil => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Which prompts the user has acted on. A prompt seen is a prompt
/// retired — no streaks, no completion pressure (§6c rule 2).
@DataClassName('PromptActionRow')
class PromptActions extends Table {
  TextColumn get promptId => text()();
  TextColumn get userId => text()();
  TextColumn get action => text()(); // posted | dismissed
  DateTimeColumn get actedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {promptId, userId};
}

/// Per-user, per-conversation read cursor (WhatsApp model): the id of
/// the last message the user has seen plus when. One row per
/// (conversation, user); upserted on read.
@DataClassName('ReadCursorRow')
class ReadCursors extends Table {
  TextColumn get conversationId => text()();
  TextColumn get userId => text()();
  TextColumn get lastReadMessageId => text()();
  DateTimeColumn get lastReadAt => dateTime()();

  @override
  Set<Column> get primaryKey => {conversationId, userId};
}

/// Group messages with the same outbox state machine as the Vault.
@DataClassName('GroupMessageRow')
class GroupMessages extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get senderId => text()();
  TextColumn get body => text()();
  TextColumn get syncStatus => textEnum<MsgSyncStatus>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get editedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get blurhash => text().nullable()();

  /// Attachment (schema v9/v10), same contract as [Messages].
  TextColumn get attachmentKind => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();
  IntColumn get attachmentDurationMs =>
      integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Local full-text search (FTS5) — the local-first differentiator (Signal
// searches on device because the server never sees plaintext).
//
// Drift's table DSL cannot express FTS5 virtual tables, so the indexes are
// created and queried through raw SQL (see [_ftsStatements] on
// [AppDatabase]). Standalone FTS5 tables keyed by id strings, kept in
// lockstep by AFTER INSERT/UPDATE/DELETE triggers — the write path never
// changes and no repository touches the index directly.
//
//   posts_fts(id, body, author_name)        <- posts
//   messages_fts(id, body)                  <- messages (Vault; indexes the
//                                              decrypted-at-rest body only)
//   group_messages_fts(id, body)            <- group_messages (Nexus)
//
// ---------------------------------------------------------------------------

/// Durable app preferences (theme mode now, anything key-shaped later).
/// One row per setting key; values are strings so the schema never
/// migrates for a new preference type.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  Posts,
  PostLikes,
  Conversations,
  Messages,
  NexusChannels,
  ChannelPosts,
  NexusGroups,
  GroupMessages,
  MemberRoles,
  MessageReactions,
  ReadCursors,
  Prompts,
  PromptPrefs,
  PromptActions,
  PostComments,
  SocialNotifications,
  KeepsakeItems,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  /// Injectable clock for query-time expiry checks (search, purge).
  /// Production uses wall time; tests pin a fixed instant.
  AppDatabase({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(_openConnection());

  /// In-memory instance for tests. Wraps the executor in a
  /// [DatabaseConnection] with `closeStreamsSynchronously: true` — drift
  /// keeps stream-key cleanup one event-loop tick after the last listener
  /// detaches, which trips flutter_test's pending-timer invariant. Drift
  /// documents this exact flag for such test setups.
  AppDatabase.forTesting(QueryExecutor e, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(DatabaseConnection(e, closeStreamsSynchronously: true));

  final DateTime Function() _clock;

  DateTime clock() => _clock();

  @override
  int get schemaVersion => 13;

  /// Backfills an FTS5 index from its content table. Used by the v5
  /// migration so existing rows become searchable immediately.
  static String _ftsBackfill({
    required String ftsTable,
    required String contentTable,
    required String columns,
  }) =>
      'INSERT INTO $ftsTable($columns) '
      'SELECT $columns FROM $contentTable';

  /// Virtual tables + sync triggers for one content table. Standalone
  /// FTS5 (not external-content): simpler, and the row count is bounded
  /// by chat/feed volume in the mock stage.
  ///
  /// Removal uses plain `DELETE ... WHERE rowid` (the FTS5
  /// `INSERT ... VALUES('delete', ...)` command form only works on
  /// external-content/contentless tables). The id column is unique per
  /// content table, so a subquery on it selects exactly one rowid.
  static List<String> _ftsStatements({
    required String ftsTable,
    required String contentTable,
    required String columns,
  }) {
    final newVals = columns.split(', ').map((c) => 'new.$c').join(', ');
    final idCol = columns.split(', ').first;
    final idEqualsOld = '$idCol = old.$idCol';
    return [
      'CREATE VIRTUAL TABLE IF NOT EXISTS $ftsTable '
          'USING fts5($columns)',
      // INSERT: index the new row.
      'CREATE TRIGGER IF NOT EXISTS "${ftsTable}_ai" '
          'AFTER INSERT ON "$contentTable" BEGIN '
          'INSERT INTO $ftsTable($columns) VALUES ($newVals); '
          'END',
      // DELETE: drop the row from the index (tombstones blank the body
      // via UPDATE, so deleted messages stop matching on their own).
      'CREATE TRIGGER IF NOT EXISTS "${ftsTable}_ad" '
          'AFTER DELETE ON "$contentTable" BEGIN '
          'DELETE FROM $ftsTable WHERE $idEqualsOld; '
          'END',
      // UPDATE: re-index the row.
      'CREATE TRIGGER IF NOT EXISTS "${ftsTable}_au" '
          'AFTER UPDATE OF $columns ON "$contentTable" BEGIN '
          'DELETE FROM $ftsTable WHERE $idEqualsOld; '
          'INSERT INTO $ftsTable($columns) VALUES ($newVals); '
          'END',
    ];
  }

  /// All FTS5 DDL. Idempotent (IF NOT EXISTS) so onCreate and the v5
  /// upgrade share it.
  static List<String> get _ftsSchema => [
        ..._ftsStatements(
          ftsTable: 'posts_fts',
          contentTable: 'posts',
          columns: 'id, body, author_name',
        ),
        ..._ftsStatements(
          ftsTable: 'messages_fts',
          contentTable: 'messages',
          columns: 'id, body',
        ),
        ..._ftsStatements(
          ftsTable: 'group_messages_fts',
          contentTable: 'group_messages',
          columns: 'id, body',
        ),
        ..._ftsStatements(
          ftsTable: 'channel_posts_fts',
          contentTable: 'channel_posts',
          columns: 'id, body, author_name',
        ),
      ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final stmt in _ftsSchema) {
            await customStatement(stmt);
          }
        },
        onUpgrade: (m, from, to) async {
          // Idempotence rule: every step must tolerate having already been
          // applied. A migration that throws midway leaves user_version at
          // the old value, so the next launch re-enters onUpgrade and re-runs
          // every step — each one must survive that.
          Future<void> addColumnIfMissing(
            String table,
            String column,
            String decl,
          ) async {
            final existing = await customSelect(
              'PRAGMA table_info($table)',
              variables: const [],
              readsFrom: const {},
            ).get();
            final names = existing.map((r) => r.data['name']).toSet();
            if (!names.contains(column)) {
              await customStatement(
                'ALTER TABLE $table ADD COLUMN $column $decl;',
              );
            }
          }

          // v1 -> v2: Nexus tables added. Nothing shipped on v1, so a
          // simple create of the new tables is safe and lossless.
          if (from < 2) {
            await m.createTable(nexusChannels);
            await m.createTable(channelPosts);
            await m.createTable(nexusGroups);
            await m.createTable(groupMessages);
            await m.createTable(memberRoles);
          }
          // v2 -> v3: settings key-value store (theme persistence).
          if (from < 3) {
            await m.createTable(settings);
          }
          // v3 -> v4: extended message lifecycle (delivered/read + edit/
          // delete tombstones) and membership sync state. Columns only —
          // no data moves, no renames.
          if (from < 4) {
            // All via raw SQL so NOT NULL columns can carry a constant
            // DEFAULT (SQLite forbids ADD COLUMN of NOT NULL without one).
            // Declarations mirror what drift generates for these columns.
            await addColumnIfMissing('messages', 'edited_at', 'INTEGER NULL');
            await addColumnIfMissing('messages', 'deleted_at', 'INTEGER NULL');
            await addColumnIfMissing(
              'group_messages', 'edited_at', 'INTEGER NULL',
            );
            await addColumnIfMissing(
              'group_messages', 'deleted_at', 'INTEGER NULL',
            );
            // 'pending' is the MemberSyncStatus outbox seed; 0 is the drift
            // epoch storage for DateTime (int mode).
            await addColumnIfMissing(
              'member_roles',
              'sync_status',
              "TEXT NOT NULL DEFAULT 'pending'",
            );
            await addColumnIfMissing(
              'member_roles',
              'updated_at',
              'INTEGER NOT NULL DEFAULT 0',
            );
          }
          // v4 -> v5: FTS5 search indexes (created + backfilled) and the
          // blurhash media-placeholder columns.
          if (from < 5) {
            for (final stmt in _ftsSchema) {
              await customStatement(stmt);
            }
            await customStatement(_ftsBackfill(
              ftsTable: 'posts_fts',
              contentTable: 'posts',
              columns: 'id, body, author_name',
            ));
            await customStatement(_ftsBackfill(
              ftsTable: 'messages_fts',
              contentTable: 'messages',
              columns: 'id, body',
            ));
            await customStatement(_ftsBackfill(
              ftsTable: 'group_messages_fts',
              contentTable: 'group_messages',
              columns: 'id, body',
            ));
            await m.addColumn(posts, posts.blurhash);
            await m.addColumn(channelPosts, channelPosts.blurhash);
            await m.addColumn(groupMessages, groupMessages.blurhash);
          }
          // v5 -> v6: reactions (outbox rows) + read cursors.
          if (from < 6) {
            await m.createTable(messageReactions);
            await m.createTable(readCursors);
          }
          // v6 -> v7: Daily Square prompts, prefs, actions.
          if (from < 7) {
            await m.createTable(prompts);
            await m.createTable(promptPrefs);
            await m.createTable(promptActions);
          }
          // v7 -> v8: post soft-delete tombstone (10s undo window).
          if (from < 8) {
            await addColumnIfMissing('posts', 'deleted_at', 'INTEGER NULL');
          }
          // v8 -> v9: message attachments (kind + local path). Idempotent
          // like every step: column-presence checked before adding.
          if (from < 9) {
            await addColumnIfMissing(
              'messages', 'attachment_kind', 'TEXT NULL',
            );
            await addColumnIfMissing(
              'messages', 'attachment_path', 'TEXT NULL',
            );
            await addColumnIfMissing(
              'group_messages', 'attachment_kind', 'TEXT NULL',
            );
            await addColumnIfMissing(
              'group_messages', 'attachment_path', 'TEXT NULL',
            );
          }
          // v9 -> v10: attachment duration (voice notes render their
          // length from the store, not memory).
          if (from < 10) {
            await addColumnIfMissing(
              'messages', 'attachment_duration_ms', 'INTEGER NULL',
            );
            await addColumnIfMissing(
              'group_messages', 'attachment_duration_ms', 'INTEGER NULL',
            );
          }
          // v10 -> v11: ephemeral posts ("fades in 24h"). Visibility is
          // a query-time filter on the new column; the purge is lazy.
          if (from < 11) {
            await addColumnIfMissing('posts', 'expires_at', 'INTEGER NULL');
          }
          // v11 -> v12: Hallway board posts join the search index (the
          // dorm groups were indexed since v5; the boards were missed).
          // Idempotent DDL + backfill, same as the v5 pattern.
          if (from < 12) {
            for (final stmt in _ftsSchema) {
              await customStatement(stmt);
            }
            await customStatement(_ftsBackfill(
              ftsTable: 'channel_posts_fts',
              contentTable: 'channel_posts',
              columns: 'id, body, author_name',
            ));
          }
          // v12 -> v13: social layer (post comments, peer notifications)
          // and the keepsake wall. All-new tables — no data moves.
          if (from < 13) {
            await m.createTable(postComments);
            await m.createTable(socialNotifications);
            await m.createTable(keepsakeItems);
          }
        },
      );

  /// Hard-deletes expired ephemeral posts and their likes. Lazy cleanup
  /// for the "fades in 24h" feature: rows survive until this runs (app
  /// start), but visibility never depends on it — every read filters
  /// expired rows at query time. The posts_fts AFTER DELETE trigger
  /// keeps the search index in sync automatically. Returns rows purged.
  Future<int> purgeExpiredPosts(DateTime now) async {
    Expression<bool> expiredExpr(DateTime t) =>
        posts.expiresAt.isNotNull() & posts.expiresAt.isSmallerOrEqualValue(t);
    final expired =
        await (select(posts)..where((tbl) => expiredExpr(now)))
            .map((r) => r.id)
            .get();
    if (expired.isEmpty) return 0;
    final deleted = await (delete(posts)..where((tbl) => expiredExpr(now))).go();
    await (delete(postLikes)..where((tbl) => tbl.postId.isIn(expired))).go();
    return deleted;
  }


  /// Sanitized FTS5 MATCH term: strips syntax characters so user input
  /// cannot break (or widen) the query, then quote-wraps each word as an
  /// implicit AND. Empty input returns null — callers skip the query.
  static String? _ftsMatchTerm(String query) {
    final words = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    return words.map((w) => '"$w"').join(' ');
  }

  /// One search hit: table, id, ranked relevance, and a context snippet
  /// with the match highlighted by FTS5's [..] markers.
  Future<List<FtsHitRow>> searchAllRaw(String query, {int limit = 50}) async {
    final term = _ftsMatchTerm(query);
    if (term == null) return const [];

    Future<List<FtsHitRow>> searchOne(
      String ftsTable,
      String source, {
      String extraWhere = '',
      List<Variable> extraVars = const [],
    }) async {
      final selectCols = <String>[
        "'$source' AS source",
        'id',
        "snippet($ftsTable, 1, '[..]', '[..]', '…', 12) AS snippet_text",
        'bm25($ftsTable) AS rank_value',
      ];
      final variables = <Variable>[Variable(term), ...extraVars, Variable(limit)];
      final rows = await customSelect(
        'SELECT ${selectCols.join(', ')} '
        'FROM $ftsTable WHERE $ftsTable MATCH ? $extraWhere '
        'ORDER BY rank_value LIMIT ?',
        variables: variables,
        readsFrom: {},
      ).get();
      return rows
          .map((r) => FtsHitRow(
                source: r.read<String>('source'),
                id: r.read<String>('id'),
                snippet: r.read<String>('snippet_text'),
                rank: r.read<double>('rank_value'),
              ))
          .toList();
    }

    // Expiry is a query-time filter: expired ephemeral posts must not
    // surface in search even before the lazy purge runs. The NOT EXISTS
    // subquery re-checks the content table at search time.
    const notExpiredPosts =
        'AND NOT EXISTS (SELECT 1 FROM posts p WHERE p.id = posts_fts.id '
        'AND p.expires_at IS NOT NULL AND p.expires_at <= ?)';

    final results = <FtsHitRow>[];
    results.addAll(await searchOne(
      'posts_fts',
      'square_post',
      extraWhere: notExpiredPosts,
      extraVars: [Variable(clock())],
    ));
    results.addAll(await searchOne('messages_fts', 'vault_message'));
    results.addAll(await searchOne('group_messages_fts', 'group_message'));
    results.addAll(await searchOne('channel_posts_fts', 'board_post'));
    results.sort((a, b) => a.rank.compareTo(b.rank));
    return results.take(limit).toList();
  }
}

/// Raw search hit as returned by [AppDatabase.searchAllRaw]. The data
/// layer maps these onto domain [SearchHit]s with entity enrichment.
class FtsHitRow {
  const FtsHitRow({
    required this.source,
    required this.id,
    required this.snippet,
    required this.rank,
  });

  /// Which index matched: square_post | vault_message | group_message.
  final String source;
  final String id;

  /// Context fragment around the match with [..] highlight markers.
  final String snippet;

  /// bm25 score — lower is better; sorted before returning.
  final double rank;
}

/// Platform-appropriate database connection via drift_flutter: on native
/// platforms a background-isolate SQLite file in the documents directory
/// (unchanged behavior); on the web, drift's WasmDatabase backed by
/// sqlite3.wasm + drift_worker.js served from `web/` (IndexedDB / OPFS
/// storage) — Netlify deploys get real local persistence in the browser.
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'echo_bay',
    native: DriftNativeOptions(
      // Same file the manual LazyDatabase opened before (renamed from
      // superapp.sqlite — a fresh file; old dev databases are disposable).
      databasePath: () async => 'echo_bay.sqlite',
    ),
    // Web: the wasm module + worker served from web/ (fetched from the
    // drift & sqlite3.dart releases, versions matching pubspec.lock).
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
