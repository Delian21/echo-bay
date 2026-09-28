import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/sketch_kit.dart';
import 'package:go_router/go_router.dart';

import '../design_system/loading_skeletons.dart';
import '../error/failures.dart';
import '../theme/app_theme.dart';
import 'search_hit.dart';
import 'search_repository.dart';

/// Local full-text search over all three modules. On-device only — the
/// page queries [SearchRepository] which reads the FTS5 indexes over the
/// drift cache; no network, no backend.
///
/// Debounced as-you-type search: 250ms quiet period per keystroke, then a
/// single ranked query. Snippets carry FTS5 `[..]` markers which render
/// as highlighted spans.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.searchRepository});

  final SearchRepository searchRepository;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  bool _searching = false;
  List<SearchHit>? _hits;
  Failure? _failure;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    // Keyboard-first: focus lands in the field so typing starts instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _hits = null;
        _failure = null;
        _searching = false;
        _lastQuery = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _lastQuery = query;
    });
    final result = await widget.searchRepository.search(query: query);
    if (!mounted) return;
    // Stale-response guard: a slow earlier query must not overwrite a
    // newer one.
    if (query != _lastQuery) return;
    setState(() {
      _searching = false;
      _failure = result.fold((f) => f, (_) => null);
      _hits = result.fold((_) => null, (h) => h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (q) {
            _debounce?.cancel();
            _runSearch(q.trim());
          },
          decoration: const InputDecoration(
            hintText: 'Search posts and messages',
            filled: false,
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const SketchIcon(
                  kind: SketchIconKind.closeX, size: 20, seed: 19),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_searching) {
      // Shape-matched placeholder: hits render as ListTile rows with a
      // leading avatar, so the skeleton mirrors that row shape.
      return const TileListSkeleton(rows: 5);
    }
    if (_failure != null) {
      return Center(
        child: Text(_failure!.message ?? 'Search unavailable.'),
      );
    }
    final hits = _hits;
    if (hits == null) {
      return const _SearchHint();
    }
    if (hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No matches for "$_lastQuery"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: hits.length,
      itemBuilder: (context, index) => _HitTile(hit: hits[index]),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_search_rounded,
              size: 44, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Search everything on this device.\n'
            'Encrypted messages are searchable locally only.',
            textAlign: TextAlign.center,
            style: golden.enabled
                ? kHandwrittenTextStyle.copyWith(
                    fontSize: 17,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
          ),
        ],
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final (icon, color) = switch (hit.source) {
      SearchSource.squarePost => (
        const Icon(Icons.public_rounded, size: 20),
        accent
      ),
      SearchSource.vaultMessage => (
          const SketchIcon(kind: SketchIconKind.padlock, size: 18, seed: 21),
          secondary
        ),
      SearchSource.groupMessage => (
          const SketchIcon(kind: SketchIconKind.threeHeads, size: 18, seed: 23),
          accent
        ),
    } as (Widget, Color);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: IconTheme.merge(
          data: IconThemeData(color: color),
          child: icon,
        ),
      ),
      title: Text(
        hit.containerTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: _SnippetText(snippet: hit.snippet),
      trailing: Text(
        _sourceLabel(hit.source),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      // Deep link (#8): containerId is the route target (post id for
      // Square, conversation/group id for chats).
      onTap: () => context.go(routeFor(hit)),
    );
  }

  static String _sourceLabel(SearchSource source) => switch (source) {
        SearchSource.squarePost => 'Square',
        SearchSource.vaultMessage => 'Vault',
        SearchSource.groupMessage => 'Hallway',
      };

  /// Route for the hit's container (#8). Square posts land on the feed
  /// (no per-post route while the feed owns its own scroll position);
  /// chat hits open their exact container.
  static String routeFor(SearchHit hit) => switch (hit.source) {
        SearchSource.squarePost => '/square',
        SearchSource.vaultMessage => '/vault/conversation/${hit.containerId}',
        SearchSource.groupMessage => '/nexus/group/${hit.containerId}',
      };
}

/// Renders the FTS5 snippet with `[..]` markers as bold highlighted spans.
class _SnippetText extends StatelessWidget {
  const _SnippetText({required this.snippet});

  final String snippet;

  static const _marker = '[..]';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final highlight = base?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
    );

    final spans = <TextSpan>[];
    var cursor = 0;
    while (true) {
      final start = snippet.indexOf(_marker, cursor);
      if (start < 0) {
        spans.add(TextSpan(text: snippet.substring(cursor)));
        break;
      }
      if (start > cursor) {
        spans.add(TextSpan(text: snippet.substring(cursor, start)));
      }
      // Marker pair: highlight the text between two consecutive markers.
      final end = snippet.indexOf(_marker, start + _marker.length);
      if (end < 0) {
        // Unpaired marker — render as-is and stop.
        spans.add(TextSpan(text: snippet.substring(start)));
        break;
      }
      spans.add(TextSpan(
        text: snippet.substring(start + _marker.length, end),
        style: highlight,
      ));
      cursor = end + _marker.length;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans, style: base),
    );
  }
}
