import 'dart:async';

import '../database/app_database.dart';

/// Durable unsent text ("drafts") for every composer in the app: the
/// Square composer, each Vault conversation, each Dorm group, and the
/// comment sheet of each post. Backed by the [Settings] key-value table
/// — one row per composer surface — so a closed or backgrounded app
/// loses nothing.
///
/// Deliberately NOT a content table: drafts never appear in search
/// (FTS5 indexes content tables only), in notifications, or in time
/// travel (every as-of read filters content tables, never settings).
///
/// Debounce lives with the caller (a 500ms [Debouncer] per composer);
/// the store itself is write-through so a save is one upsert.
class DraftStore {
  DraftStore(this._db);

  final AppDatabase _db;

  static const _prefix = 'draft:';

  /// Square composer — one draft for the whole feed.
  static const squareKey = '${_prefix}square_post';

  /// Vault chat composer, per conversation.
  static String vault(String conversationId) => '${_prefix}vault:$conversationId';

  /// Hallway Dorm composer, per group.
  static String dorm(String groupId) => '${_prefix}dorm:$groupId';

  /// Comment composer, per Square post.
  static String comment(String postId) => '${_prefix}comment:$postId';

  /// Reads the draft for [key]; null when none. A read failure returns
  /// null — a missing draft must never block opening a composer.
  Future<String?> read(String key) async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(key)))
          .getSingleOrNull();
      final value = row?.value;
      return (value == null || value.isEmpty) ? null : value;
    } on Object {
      return null;
    }
  }

  /// Upserts the draft. Empty text clears the row. Best-effort: a failed
  /// save loses at most this one keystroke batch, never the app.
  Future<void> write(String key, String text) async {
    try {
      if (text.isEmpty) {
        await (_db.delete(_db.settings)..where((s) => s.key.equals(key)))
            .go();
        return;
      }
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(key: key, value: text),
          );
    } on Object {
      // Swallow: drafts are a convenience, not a contract.
    }
  }

  /// Clears the draft (send or deliberate discard). Same as write('').
  Future<void> clear(String key) => write(key, '');
}

/// Tiny trailing-edge debounce for keystroke saves. One instance per
/// composer; [dispose] cancels any pending save (the composer's own
/// dispose-time flush handles the last state).
class DraftDebouncer {
  DraftDebouncer({this.delay = const Duration(milliseconds: 500)});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending save (composers run their own explicit save on
  /// dispose, so the timer must not double-fire after unmount).
  void flush() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
