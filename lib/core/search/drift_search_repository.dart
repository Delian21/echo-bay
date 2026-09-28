import 'package:fpdart/fpdart.dart';

import '../database/app_database.dart';
import '../error/failures.dart';
import 'search_hit.dart';
import 'search_repository.dart';

/// Drift-backed [SearchRepository]. Runs the ranked MATCH queries against
/// the FTS5 indexes, then enriches each hit with its container's title
/// and timestamp via the content tables — one results list, three
/// modules, all on-device.
class DriftSearchRepository implements SearchRepository {
  DriftSearchRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Either<Failure, List<SearchHit>>> search({
    required String query,
    int limit = 50,
  }) async {
    try {
      final raw = await _db.searchAllRaw(query, limit: limit);
      if (raw.isEmpty) return right(const []);

      // Enrichment lookups. FTS ids are unique per table, so
      // getSingleOrNull is safe; a missing row (shouldn't happen —
      // triggers keep sync) is skipped rather than failing the search.
      final hits = <SearchHit>[];
      for (final r in raw) {
        switch (r.source) {
          case 'square_post':
            final post = await (_db.select(_db.posts)
                  ..where((t) => t.id.equals(r.id)))
                .getSingleOrNull();
            if (post == null) continue;
            hits.add(SearchHit(
              source: SearchSource.squarePost,
              id: r.id,
              containerId: r.id,
              containerTitle: post.authorName,
              snippet: r.snippet,
              rank: r.rank,
              timestamp: post.createdAt,
            ));
          case 'vault_message':
            final msg = await (_db.select(_db.messages)
                  ..where((t) => t.id.equals(r.id)))
                .getSingleOrNull();
            if (msg == null) continue;
            final conv = await (_db.select(_db.conversations)
                  ..where((t) => t.id.equals(msg.conversationId)))
                .getSingleOrNull();
            hits.add(SearchHit(
              source: SearchSource.vaultMessage,
              id: r.id,
              containerId: msg.conversationId,
              containerTitle: conv?.title ?? 'Conversation',
              snippet: r.snippet,
              rank: r.rank,
              timestamp: msg.createdAt,
            ));
          case 'group_message':
            final msg = await (_db.select(_db.groupMessages)
                  ..where((t) => t.id.equals(r.id)))
                .getSingleOrNull();
            if (msg == null) continue;
            final group = await (_db.select(_db.nexusGroups)
                  ..where((t) => t.id.equals(msg.groupId)))
                .getSingleOrNull();
            hits.add(SearchHit(
              source: SearchSource.groupMessage,
              id: r.id,
              containerId: msg.groupId,
              containerTitle: group?.title ?? 'Group',
              snippet: r.snippet,
              rank: r.rank,
              timestamp: msg.createdAt,
            ));
          default:
            continue; // unknown source: skip, never fail
        }
      }
      return right(hits);
    } on Object catch (e) {
      return left(CacheFailure(message: 'search failed', cause: e));
    }
  }
}
