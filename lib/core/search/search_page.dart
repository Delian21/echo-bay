import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/people/person_sheet.dart';
import '../../features/social/domain/entities/peer_directory.dart';
import '../../features/social/domain/entities/social_entities.dart';
import '../design_system/loading_skeletons.dart';
import '../design_system/sketch_kit.dart';
import '../error/failures.dart';
import '../router/app_router.dart';
import '../router/route_push.dart';
import '../settings/app_settings_store.dart';
import '../theme/app_theme.dart';
import 'search_hit.dart';
import 'search_repository.dart';

/// Local full-text search over all three modules. On-device only — the
/// page queries [SearchRepository] which reads the FTS5 indexes over the
/// drift cache; no network, no backend.
///
/// Also resolves people: a typed `@handle` (or a name) offers that
/// person's page above the content hits, so a peer is reachable by
/// typing a handle and not only by tapping one of their posts.
///
/// Debounced as-you-type search (250ms quiet period), results grouped by
/// module (Square / Vault / Hallway boards and dorms), recent searches
/// persisted in the settings KV, and an empty state in the app's voice.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.searchRepository,
    this.settingsStore,
  });

  final SearchRepository searchRepository;

  /// Recents persistence; null disables recents (tests, older callers).
  final AppSettingsStore? settingsStore;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  bool _searching = false;
  List<SearchHit>? _hits;
  List<PeerProfile> _people = const [];
  Failure? _failure;
  String _lastQuery = '';
  List<String> _recents = [];

  static const _maxRecents = 5;

  @override
  void initState() {
    super.initState();
    // Keyboard-first: focus lands in the field so typing starts instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final store = widget.settingsStore;
    if (store == null) return;
    final raw = await store.readString(AppSettingsStore.searchRecentsKey);
    if (!mounted || raw == null) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>).cast<String>();
      setState(() => _recents = list.take(_maxRecents).toList());
    } on Object {
      // Corrupt recents are disposable — start clean.
    }
  }

  Future<void> _rememberQuery(String query) async {
    setState(() {
      _recents
        ..remove(query)
        ..insert(0, query);
      if (_recents.length > _maxRecents) {
        _recents = _recents.sublist(0, _maxRecents);
      }
    });
    final store = widget.settingsStore;
    if (store == null) return;
    await store.writeString(
      AppSettingsStore.searchRecentsKey,
      jsonEncode(_recents),
    );
  }

  Future<void> _clearRecents() async {
    setState(() => _recents = []);
    await widget.settingsStore
        ?.deleteKey(AppSettingsStore.searchRecentsKey);
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
        _people = const [];
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
    // People resolve locally and instantly, independent of the FTS hit.
    final people = PeerDirectory.lookup(query);
    setState(() {
      _searching = false;
      _failure = result.fold((f) => f, (_) => null);
      _hits = result.fold((_) => null, (h) => h);
      _people = people;
    });
    // A finished search with anything to show — content or a person —
    // becomes a recent entry.
    final hits = _hits;
    if ((hits != null && hits.isNotEmpty) || people.isNotEmpty) {
      await _rememberQuery(query);
    }
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
            hintText: 'Search posts, messages, and @people',
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
      if (_recents.isEmpty) return const _SearchHint();
      return _RecentsList(
        recents: _recents,
        onSelected: (q) {
          _controller.text = q;
          _debounce?.cancel();
          _runSearch(q);
        },
        onClear: _clearRecents,
      );
    }
    // A handle that matched someone counts as a result, so the "nothing
    // found" voice never fires over a person the user did find.
    if (hits.isEmpty && _people.isEmpty) {
      // Empty results in the app's voice — nothing found, warmly said.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SketchIcon(
              kind: SketchIconKind.searchGlass,
              size: 40,
              seed: 37,
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing on the boards for "$_lastQuery".',
              textAlign: TextAlign.center,
              style: kHandwrittenTextStyle.copyWith(
                fontSize: 19,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another word or two.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return _GroupedResults(hits: hits, people: _people);
  }
}

/// Results grouped by module: people first (a typed @handle is the most
/// specific thing the user can ask for), then Square posts, Vault
/// messages, and Hallway boards and dorms — each section with a
/// handwritten heading.
class _GroupedResults extends StatelessWidget {
  const _GroupedResults({required this.hits, this.people = const []});

  final List<SearchHit> hits;

  /// Peers matching the query, best match first.
  final List<PeerProfile> people;

  @override
  Widget build(BuildContext context) {
    final sections = <(String, List<Widget>)>[
      if (people.isNotEmpty)
        ('PEOPLE', [for (final p in people) _PersonTile(peer: p)]),
      (
        'SQUARE POSTS',
        [
          for (final h in hits.where((h) => h.source == SearchSource.squarePost))
            _HitTile(hit: h, showSourceBadge: false),
        ]
      ),
      (
        'VAULT MESSAGES',
        [
          for (final h
              in hits.where((h) => h.source == SearchSource.vaultMessage))
            _HitTile(hit: h, showSourceBadge: false),
        ]
      ),
      (
        'HALLWAY',
        [
          for (final h in hits.where((h) =>
              h.source == SearchSource.boardPost ||
              h.source == SearchSource.groupMessage))
            _HitTile(hit: h, showSourceBadge: true),
        ]
      ),
    ].where((s) => s.$2.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (title, rows) in sections) ...[
          _SectionHeading(title: title),
          ...rows,
        ],
      ],
    );
  }
}

/// A person as a search result: initials, name, and the @handle that
/// makes the row addressable. Tapping opens their page — pushed, so the
/// search stays behind and Back returns to these results.
class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.peer});

  final PeerProfile peer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final handle = PeerDirectory.handleFor(peer.name);
    final initials = peer.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.15),
        child: Text(
          initials,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
      title: Text(
        peer.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '@$handle',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        'Person',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => pushDestination(
        context,
        AppRoutes.person(handle),
        fallback: () => PersonRoutePage(handle: handle),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        title,
        style: golden.enabled
            ? kHandwrittenTextStyle.copyWith(
                fontSize: 15,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
      ),
    );
  }
}

/// Recent searches, persisted in the settings KV. Tapping re-runs; the
/// eraser clears the whole list.
class _RecentsList extends StatelessWidget {
  const _RecentsList({
    required this.recents,
    required this.onSelected,
    required this.onClear,
  });

  final List<String> recents;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'RECENT SEARCHES',
                      style: kHandwrittenTextStyle.copyWith(
                        fontSize: 15,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear recent searches',
                    icon: const SketchIcon(
                      kind: SketchIconKind.closeX,
                      size: 18,
                      seed: 19,
                    ),
                    onPressed: onClear,
                  ),
                ],
              ),
            ),
            for (final q in recents)
              ListTile(
                leading: const SketchIcon(
                  kind: SketchIconKind.searchGlass,
                  size: 20,
                  seed: 37,
                ),
                title: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => onSelected(q),
              ),
          ],
        ),
      ),
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
            'Jump straight to someone with their @handle.',
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
  const _HitTile({required this.hit, this.showSourceBadge = true});

  final SearchHit hit;

  /// In grouped lists the section already names the module, but inside
  /// the mixed Hallway section boards and dorms still disambiguate.
  final bool showSourceBadge;

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
      SearchSource.boardPost => (
          const SketchIcon(kind: SketchIconKind.megaphone, size: 18, seed: 27),
          accent
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
      // Square, conversation/group/channel id for the rest).
      onTap: () => context.go(routeFor(hit)),
    );
  }

  static String _sourceLabel(SearchSource source) => switch (source) {
        SearchSource.squarePost => 'Square',
        SearchSource.vaultMessage => 'Vault',
        SearchSource.boardPost => 'Board',
        SearchSource.groupMessage => 'Dorm',
      };

  /// Route for the hit's container (#8). Square posts land on the feed
  /// (no per-post route while the feed owns its own scroll position);
  /// chat hits open their exact container.
  static String routeFor(SearchHit hit) => switch (hit.source) {
        SearchSource.squarePost => '/square',
        SearchSource.vaultMessage => '/vault/conversation/${hit.containerId}',
        SearchSource.boardPost => '/nexus',
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
