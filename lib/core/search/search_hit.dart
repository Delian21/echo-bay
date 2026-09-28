import 'package:equatable/equatable.dart';

/// Which index a search hit came from. Mirrors the three FTS5 tables.
enum SearchSource { squarePost, vaultMessage, groupMessage }

/// One local search result. The snippet carries FTS5's `[..]` highlight
/// markers around the matched terms; the UI renders them (or strips
/// them). Enrichment (`containerTitle`) lets one results list span all
/// three modules without the UI re-querying each repository.
class SearchHit extends Equatable {
  const SearchHit({
    required this.source,
    required this.id,
    required this.containerId,
    required this.containerTitle,
    required this.snippet,
    required this.rank,
    this.timestamp,
  });

  final SearchSource source;
  final String id;

  /// Where the hit lives: post id for the Square (same as [id]),
  /// conversation id for Vault messages, group id for group messages —
  /// the deep-link target once go_router lands.
  final String containerId;

  /// Human label of the container: author name (Square), conversation
  /// title (Vault), group title (Nexus).
  final String containerTitle;

  /// Context fragment around the match with `[..]` highlight markers.
  final String snippet;

  /// bm25 score — lower is better.
  final double rank;

  /// Best-known time of the underlying row, for results sorting in the UI.
  final DateTime? timestamp;

  @override
  List<Object?> get props =>
      [source, id, containerId, containerTitle, snippet, rank, timestamp];
}
