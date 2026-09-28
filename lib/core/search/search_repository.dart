import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';
import 'search_hit.dart';

/// Contract for local full-text search across all three modules' content
/// (Square posts, Vault messages, Nexus group messages).
///
/// Local-first differentiator: search runs entirely on device over the
/// drift cache — for the Vault that means the decrypted-at-rest body, so
/// plaintext never leaves the device (the Signal posture). A real backend
/// never needs to see a query.
///
/// Implementation notes: backed by FTS5 indexes kept in lockstep with the
/// content tables by database triggers (schema v5) — repositories never
/// touch the index directly, they just write content rows as usual.
abstract class SearchRepository {
  /// One-shot search across all content. Empty query returns an empty
  /// list, never a failure. Rank-ordered (bm25), newest-first as a
  /// tiebreak within equal relevance.
  Future<Either<Failure, List<SearchHit>>> search({
    required String query,
    int limit,
  });
}
