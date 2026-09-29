import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../core/design_system/loading_skeletons.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/design_system/staggered_entrance.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/session.dart';
import '../../../core/error/failures.dart';
import '../../../injection.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/entities/post.dart';
import '../domain/repositories/feed_repository.dart';
import 'post_share_sheet.dart';
import 'square_card.dart';
import 'square_post_model.dart';

/// The Square — chronological feed, wired to the real [FeedRepository]
/// (drift cache + mock transport). The repository stream is the single
/// source of truth: likes, inserts and ticker pushes all flow through it.
///
/// Desktop polish: on viewports wider than 640 logical px the feed renders
/// as a centered capped-width column, matching the master-detail rhythm
/// of the Vault at large sizes. Keyboard: Up/Down move card focus,
/// L likes the focused card.
class SquareFeedView extends StatefulWidget {
  const SquareFeedView({super.key, required this.repository});

  final FeedRepository repository;

  /// Author id the keep-it action belongs to. Resolved from the auth
  /// seam when available; tests constructing the view without DI fall
  /// back to the mock's conventional id.
  static Future<String> resolveLocalUserId() async {
    try {
      final session = await sl<AuthRepository>().currentUser();
      final id = session.fold(
        (_) => 'local-user',
        (Session s) => s.userId,
      );
      return id;
    } on Object catch (_) {
      return 'local-user';
    }
  }

  @override
  State<SquareFeedView> createState() => _SquareFeedViewState();
}

class _SquareFeedViewState extends State<SquareFeedView> {
  List<Post> _posts = const [];
  Failure? _failure;
  bool _loading = true;
  bool _refreshing = false;
  Stream<_FeedSnapshot>? _stream;

  /// Per-card like transition guard: optimistic like state is keyed by
  /// post id while the repository write is in flight.
  final Set<String> _pendingLikes = {};

  /// Index of the keyboard-focused card; -1 means nothing focused yet.
  int _focusedIndex = -1;

  /// The local user's id — gates the keep-it action to the author's own
  /// ephemeral posts. Resolved once from the auth seam.
  String _localUserId = 'local-user';

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    SquareFeedView.resolveLocalUserId().then((id) {
      if (mounted) setState(() => _localUserId = id);
    });
    _stream = widget.repository.watchFeed().map(
          (either) => _FeedSnapshot(posts: either.fold((f) => null, (l) => l), failure: either.fold((f) => f, (_) => null)),
        );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(Post post) async {
    if (_pendingLikes.contains(post.id)) return;
    _pendingLikes.add(post.id);
    // Optimistic flip; the repository write lands in the same frame the
    // stream re-emits, so the flicker window is one build.
    final result = await widget.repository.toggleLike(postId: post.id);
    if (!mounted) return;
    _pendingLikes.remove(post.id);
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Like failed')),
      ),
      (_) {},
    );
  }

  /// "Keep it": converts an ephemeral post to permanent. Only offered
  /// on the local user's own ephemeral posts (the button is null
  /// otherwise). The stream re-emits; the timer strip disappears.
  Future<void> _keepPost(Post post) async {
    final result = await widget.repository.keepPost(postId: post.id);
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Could not keep it'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {},
    );
  }

  /// Delete own post — the action behind the card's "rewind this
  /// moment" long-press. The repository rejects foreign posts; the
  /// failure surfaces as a snackbar. Success shows a rewind-styled
  /// confirmation with a real undo (re-inserts the exact post) for a
  /// few seconds — undoing the undo, in the app's voice.
  Future<void> _deletePost(Post post) async {
    final result = await widget.repository.deletePost(postId: post.id);
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Rewind failed'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) => _showRewindSnackbar(post),
    );
  }

  void _showRewindSnackbar(Post post) {
    final golden = GoldenHourExtension.of(context);
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: golden.enabled
              ? scheme.primary.withValues(alpha: 0.14)
              : null,
          content: Row(
            children: [
              // The rewind spiral (sketch kit §2) is the app-wide undo
              // mark; the Material replay glyph remains for the stock
              // theme. Slightly larger: the spiral reads denser.
              if (golden.enabled)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SketchIcon(
                    kind: SketchIconKind.rewindSpiral,
                    size: 22,
                    color: golden.amberAccent,
                    seed: 7,
                  ),
                )
              else
                Icon(Icons.replay_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
              if (!golden.enabled) const SizedBox(width: 10),
              Text(
                'Moment rewound.',
                style: golden.enabled
                    ? kHandwrittenTextStyle.copyWith(
                        fontSize: 17, color: scheme.onSurface)
                    : null,
              ),
            ],
          ),
          // True undo: the post lives in a soft-delete tombstone for
          // [FeedRepository undo window] seconds; 'Put it back' clears
          // the tombstone and the exact post (id, timestamp, likes)
          // returns to the feed.
          action: SnackBarAction(
            label: 'Put it back',
            onPressed: () async {
              final result = await widget.repository.restorePost(
                postId: post.id,
              );
              if (!mounted) return;
              result.fold(
                (failure) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        failure.message ?? 'Too late to put it back.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
                (_) {},
              );
            },
          ),
        ),
      );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final result = await widget.repository.refreshFeed();
    if (!mounted) return;
    setState(() => _refreshing = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Refresh failed'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {},
    );
  }

  /// Arrow-key navigation: focus moves one card at a time and the list
  /// scrolls just enough to keep the focused card in view. Estimated
  /// card height keeps the math layout-free; the clamp guards the edges.
  void _moveFocus(int delta) {
    if (_posts.isEmpty) return;
    final next = (_focusedIndex + delta).clamp(0, _posts.length - 1);
    if (next == _focusedIndex) return;
    setState(() => _focusedIndex = next);

    if (!_scroll.hasClients) return;
    const estimatedCardHeight = 420.0;
    final viewport = _scroll.position.viewportDimension;
    final target = (next * estimatedCardHeight - viewport * 0.4).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _likeFocused() {
    if (_focusedIndex < 0 || _focusedIndex >= _posts.length) return;
    _toggleLike(_posts[_focusedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_FeedSnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          _posts = data.posts ?? _posts;
          _failure = data.failure;
        }
        _loading = _loading && _posts.isEmpty && _failure == null;

        if (_loading) {
          return const FeedSkeleton();
        }
        if (_failure != null && _posts.isEmpty) {
          return _FeedErrorState(
            failure: _failure!,
            onRetry: () => setState(() {
              _stream = widget.repository.watchFeed().map(
                    (either) => _FeedSnapshot(
                      posts:
                          either.fold((f) => null, (l) => l),
                      failure: either.fold((f) => f, (_) => null),
                    ),
                  );
              _loading = true;
              _failure = null;
            }),
          );
        }

        final keyboard = CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _moveFocus(1),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _moveFocus(-1),
            const SingleActivator(LogicalKeyboardKey.keyL): _likeFocused,
          },
          child: Focus(
            autofocus: true,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildList(),
            ),
          ),
        );

        // Desktop polish: cap and center the feed column on wide windows.
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: keyboard,
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      // +1 for the journal-invitation header pinned above the feed.
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _posts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _JournalHeader(repository: widget.repository);
        }
        final postIndex = index - 1;
        final focused = postIndex == _focusedIndex;
        return StaggeredEntrance(
          index: postIndex,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.fromBorderSide(
                BorderSide(
                  color: focused
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: SquareFeedCard(
              post: _toModel(_posts[postIndex]),
              onLike: () => _toggleLike(_posts[postIndex]),
              onDelete: () => _deletePost(_posts[postIndex]),
              onShare: () => sharePostAsImage(context, _posts[postIndex]),
              onKeep: _posts[postIndex].authorId == _localUserId &&
                      _posts[postIndex].expiresAt != null
                  ? () => _keepPost(_posts[postIndex])
                  : null,
            ),
          ),
        );
      },
    );
  }

  /// Domain entity -> presentation model. The UI speaks [SquarePost]; the
  /// mapping is intentionally trivial and local.
  SquarePost _toModel(Post p) => SquarePost(
        id: p.id,
        username: p.authorName,
        // Unsplash face crop — pravatar has no CORS header and is
        // blocked on web; images.unsplash.com sends Access-Control-Allow-Origin: *.
        userAvatarUrl:
            'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=150&h=150&fit=crop&crop=faces&q=80',
        timestamp: p.createdAt,
        caption: p.body,
        mediaUrl: p.mediaUrl,
        blurhash: p.blurhash,
        likesCount: p.likesCount,
        isLiked: p.isLiked,
        expiresAt: p.expiresAt,
      );
}

/// Journal day-view: every post from one date, opened by tapping the
/// date in the feed header. A finished page of the journal — same card
/// vocabulary as the feed, one-shot load instead of a live stream.
class SquareDayViewPage extends StatelessWidget {
  const SquareDayViewPage({
    super.key,
    required this.repository,
    required this.day,
  });

  final FeedRepository repository;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final dateLine =
        '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';

    return Scaffold(
      appBar: AppBar(title: Text(dateLine)),
      body: FutureBuilder<Either<Failure, List<Post>>>(
        future: repository.postsOnDay(day),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const FeedSkeleton(cards: 2);
          }
          final either = snapshot.data;
          if (either == null) {
            return const Center(
              child: Text('Could not load this day.'),
            );
          }
          return either.fold(
            (failure) => Center(
              child: Text(failure.message ?? 'This day is unavailable.'),
            ),
            (posts) {
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 44,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nothing was written this day.',
                        style: kHandwrittenTextStyle.copyWith(
                          fontSize: 20,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final p = posts[index];
                      return SquareFeedCard(
                        post: SquarePost(
                          id: p.id,
                          username: p.authorName,
                          userAvatarUrl:
                              'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=150&h=150&fit=crop&crop=faces&q=80',
                          timestamp: p.createdAt,
                          caption: p.body,
                          mediaUrl: p.mediaUrl,
                          blurhash: p.blurhash,
                          likesCount: p.likesCount,
                          isLiked: p.isLiked,
                          expiresAt: p.expiresAt,
                        ),
                        onLike: () {},
                        onShare: () => sharePostAsImage(context, p),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Journal-invitation header at the top of the feed. Golden Hour voice:
/// a handwritten line inviting a small moment, with today's date —
/// reads like the first page of a day, not a growth-hacked hero banner.
/// Renders only when the analog layer is on; stock theme gets nothing
/// (the header is decorative, and functional text stays in Roboto).
class _JournalHeader extends StatelessWidget {
  const _JournalHeader({required this.repository});

  final FeedRepository repository;

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    if (!golden.enabled) return const SizedBox.shrink();

    final now = DateTime.now();
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final dateLine =
        '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _invitationFor(now.hour),
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 26,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SquareDayViewPage(
                  repository: repository,
                  day: now,
                ),
              ));
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateLine,
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 16,
                      color: golden.amberAccent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: golden.amberAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Time-of-day invitation — one small ask, never a demand.
  String _invitationFor(int hour) {
    if (hour < 5) return 'Still up? Capture the quiet.';
    if (hour < 12) return 'Good morning. What did you notice?';
    if (hour < 17) return 'Afternoon pages. What caught your eye?';
    if (hour < 22) return 'Evening pages. How did today look?';
    return 'Late pages. One small thing before sleep.';
  }
}

/// Stream frame: posts or a failure, never both.
class _FeedSnapshot {
  const _FeedSnapshot({required this.posts, required this.failure});
  final List<Post>? posts;
  final Failure? failure;
}

class _FeedErrorState extends StatelessWidget {
  const _FeedErrorState({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 44, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            failure.message ?? 'Feed unavailable.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
