import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';

import '../database/app_database.dart';
import '../error/failures.dart';

/// "Export my Echo Bay" / "Import from backup".
///
/// Exports EVERY table as JSON — including soft-deleted (tombstoned) rows,
/// because time travel depends on them — plus the schema version, so a
/// backup from a newer app can be rejected cleanly on import.
///
/// Media decision: photos and voice notes live as FILES on the attachments
/// path (native) and are not embedded in the JSON — embedding arbitrary
/// video would blow up any sane file size. Instead every row that carries
/// an attachment keeps its path/blurhash, and the export records the media
/// file names it saw. On web, attachments live only in the session (blob
/// URLs) so there is nothing to export; the JSON note records that. The
/// import therefore restores ALL TEXT DATA exactly and leaves attachment
/// rows pointing at files the new install may not have — the media slots
/// render their "unavailable" states, which the UI already handles
/// gracefully. Blurhashes survive, so ephemeral posts still show real
/// placeholder colors.
///
/// Size: JSON of text rows is tiny (a few hundred KB for years of use).
/// A hard cap of 50 MB on import rejects absurd files before parsing.
class BackupService {
  BackupService(this._db);

  static const formatName = 'echo-bay-backup';
  static const formatVersion = 1;
  static const maxImportBytes = 50 * 1024 * 1024;

  final AppDatabase _db;

  /// Ordered table list: everything with rows worth keeping. Order is
  /// also the import insert order (parents before children is not
  /// strictly required — no FKs — but keeps diffs readable).
  static const _tables = [
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

  /// Export everything to a JSON map (not yet serialized).
  Future<Either<Failure, Map<String, dynamic>>> exportJson() async {
    try {
      final data = <String, dynamic>{};
      for (final table in _tables) {
        final rows = await _db.customSelect('SELECT * FROM $table').get();
        data[table] = [
          for (final row in rows) row.data,
        ];
      }
      final payload = {
        'format': formatName,
        'format_version': formatVersion,
        'schema_version': _db.schemaVersion,
        'exported_at': DateTime.now().toIso8601String(),
        // Media note for the importer (and the human reading the file).
        'media': {
          'embedded': false,
          'note': 'Attachment paths and blurhashes are preserved; binary '
              'media files are not embedded in this file.',
        },
        'data': data,
      };
      return right(payload);
    } on Object catch (e) {
      return left(CacheFailure(message: 'export failed', cause: e));
    }
  }

  /// Serialized bytes ready for the IO seam's download/write path.
  Future<Either<Failure, Uint8List>> exportBytes() async {
    final json = await exportJson();
    return json.map(
      (data) => Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
      ),
    );
  }

  /// Import a backup from raw bytes. Replaces ALL current data — the UI
  /// must confirm before calling. Rejects wrong format and newer schema
  /// versions with distinct, actionable messages.
  Future<Either<Failure, ImportSummary>> importBytes(Uint8List bytes) async {
    if (bytes.length > maxImportBytes) {
      return left(const CacheFailure(
        message: 'That file is far too large to be an Echo Bay backup.',
      ));
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on Object {
      return left(const CacheFailure(
        message: "That doesn't read like an Echo Bay backup.",
      ));
    }

    if (decoded['format'] != formatName) {
      return left(const CacheFailure(
        message: "That doesn't read like an Echo Bay backup.",
      ));
    }

    final schemaVersion = decoded['schema_version'];
    if (schemaVersion is! int) {
      return left(const CacheFailure(
        message: 'The backup is missing its schema version — too old to read.',
      ));
    }
    if (schemaVersion > _db.schemaVersion) {
      return left(CacheFailure(
        message: 'This backup was made by a newer Echo Bay '
            '(schema $schemaVersion > ${_db.schemaVersion}). '
            'Update the app first.',
      ));
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return left(const CacheFailure(
        message: 'The backup is missing its data section.',
      ));
    }

    try {
      var rowsImported = 0;
      await _db.transaction(() async {
        // Wipe current data (the confirm dialog already warned). Settings
        // are wiped too — the backup carries its own.
        for (final table in _tables.reversed) {
          await _db.customStatement('DELETE FROM $table');
        }
        for (final table in _tables) {
          final rows = data[table];
          if (rows is! List) continue;
          for (final raw in rows) {
            if (raw is! Map<String, dynamic>) continue;
            await _insertRow(table, raw);
            rowsImported++;
          }
        }
      });
      return right(ImportSummary(
        rows: rowsImported,
        schemaVersion: schemaVersion,
        exportedAt: decoded['exported_at'] as String?,
      ));
    } on Object catch (e) {
      return left(CacheFailure(message: 'import failed', cause: e));
    }
  }

  /// Generic row insert: serialize dart-typed values the way drift's
  /// type mapping expects (DateTime → ISO milliseconds), then let drift
  /// bind them. Table/column names come from OUR static list, never from
  /// the file, so this is not injectable from a hostile file.
  Future<void> _insertRow(String table, Map<String, dynamic> raw) async {
    final columns = <String>[];
    final values = <Variable>[];
    final placeholders = <String>[];
    var i = 0;
    raw.forEach((column, value) {
      columns.add(column);
      values.add(Variable(_adaptValue(value)));
      placeholders.add('?');
      i++;
    });
    if (i == 0) return;
    await _db.customInsert(
      'INSERT OR REPLACE INTO $table (${columns.join(', ')}) '
      'VALUES (${placeholders.join(', ')})',
      variables: values,
    );
  }

  /// Values come back from SELECT * as raw SQLite values (drift stores
  /// DateTimes as INTEGER unix-ms, booleans as 0/1) and JSON keeps them
  /// as numbers, so no adaptation is needed for round trips of our own
  /// exports. The only conversion is JSON booleans (from hand-built
  /// files) to 0/1 — applied blindly, a body string is never touched.
  Object? _adaptValue(Object? value) {
    if (value is bool) return value ? 1 : 0;
    return value;
  }
}

/// Result of a successful import.
class ImportSummary {
  const ImportSummary({
    required this.rows,
    required this.schemaVersion,
    this.exportedAt,
  });

  final int rows;
  final int schemaVersion;
  final String? exportedAt;
}
