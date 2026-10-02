import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../features/social/domain/entities/social_entities.dart';
import '../../features/social/domain/repositories/follow_repository.dart';
import '../../injection.dart';
import '../error/failures.dart';
import '../profile/handles.dart';
import '../profile/profile_controller.dart';
import '../router/app_router.dart';
import '../router/route_push.dart';
import '../theme/app_theme.dart';
import '../../features/profile/ui/profile_page.dart';
import '../../features/square/domain/entities/post.dart';
import '../../features/square/domain/repositories/feed_repository.dart';

/// Who a tap refers to. The local user opens their real profile page;
/// everyone else (mock peers, in this stage) opens their person page.
enum PersonRefKind { localUser, named }

/// Opens a person from any name/avatar tap. Every surface routes the same
/// way: the local user lands on their editable profile, a named person on
/// `/person/:handle` with their recent Square posts.
Future<void> openPerson(
  BuildContext context, {
  required String name,
  PersonRefKind kind = PersonRefKind.named,
}) async {
  if (kind == PersonRefKind.localUser) {
    final controller =
        sl.isRegistered<ProfileController>() ? sl<ProfileController>() : null;
    if (controller == null) return;
    await pushDestination(
      context,
      AppRoutes.profile,
      fallback: () => ProfilePage(
        profileController: controller,
        feedRepository:
            sl.isRegistered<FeedRepository>() ? sl<FeedRepository>() : null,
      ),
    );
    return;
  }
  // The route carries the handle (addressable, shareable); `extra`
  // carries the exact author name, so a name the slug cannot round-trip
  // ("J.P. Aurelio") still reads correctly in the app.
  final handle = handleForName(name);
  await pushDestination(
    context,
    AppRoutes.person(handle),
    extra: name,
    fallback: () => PersonRoutePage(handle: handle, name: name),
  );
}

/// A peer's page — the `/person/:handle` destination. Initials avatar,
/// name, their handle, a line of bio in their own voice, the Keep close /
/// Drift apart button, and their recent Square posts. Vocabulary is fixed
/// app-wide: "Keep close", "Drift apart", "Keeping close".
///
/// [name] is the exact author name when the tap came from inside the app
/// (it rides in as the route's `extra`). A cold deep link has none and
/// falls back to the inverse of the slug.
class PersonRoutePage extends StatelessWidget {
  const PersonRoutePage({super.key, required this.handle, this.name});

  final String handle;

  /// The person's exact display name, when the caller already knows it.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final person = (name == null || name!.isEmpty)
        ? nameForHandle(handle)
        : name!;
    return Scaffold(
      appBar: AppBar(title: Text(person)),
      body: _PersonPageBody(name: person, handle: handle),
    );
  }
}

class _PersonPageBody extends StatefulWidget {
  const _PersonPageBody({required this.name, required this.handle});

  final String name;
  final String handle;

  @override
  State<_PersonPageBody> createState() => _PersonPageBodyState();
}

class _PersonPageBodyState extends State<_PersonPageBody> {
  /// Created once, never in build — the stream-rebind gotcha (see
  /// ARCHITECTURE.md §8): watchPeerProfile returns a fresh stream per
  /// call, so rebuilding would restart the follow state every frame.
  late final Stream<Either<Failure, PeerProfile>>? _peerStream =
      sl.isRegistered<FollowRepository>()
          ? sl<FollowRepository>().watchPeerProfile(widget.name)
          : null;

  late final Future<List<Post>> _posts = _loadPosts();

  Future<List<Post>> _loadPosts() async {
    if (!sl.isRegistered<FeedRepository>()) return const <Post>[];
    final Either<Failure, List<Post>> result =
        await sl<FeedRepository>().findPostsByAuthor(widget.name);
    // Repo failures degrade to the page's empty state.
    return result.fold((_) => const <Post>[], (p) => p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useInk = GoldenHourExtension.of(context).enabled;
    final initials = widget.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

    return FutureBuilder<List<Post>>(
      future: _posts,
      builder: (context, snap) {
        final posts = snap.data ?? const <Post>[];
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            // -- identity ---------------------------------------------------
            Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AccentDerivation.of(
                  theme.colorScheme.primary,
                  theme.brightness,
                ).container,
                child: Text(
                  initials,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AccentDerivation.of(
                      theme.colorScheme.primary,
                      theme.brightness,
                    ).onContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.name,
              textAlign: TextAlign.center,
              style: useInk
                  ? kHandwrittenTextStyle.copyWith(
                      fontSize: 26, color: theme.colorScheme.onSurface)
                  : theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              '@${widget.handle}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'On the Square',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            StreamBuilder<Either<Failure, PeerProfile>>(
              stream: _peerStream,
              builder: (context, peerSnap) {
                final String? bioText =
                    peerSnap.data?.fold((_) => null, (p) => p.bio);
                if (bioText == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    bioText,
                    textAlign: TextAlign.center,
                    style: useInk
                        ? kHandwrittenTextStyle.copyWith(
                            fontSize: 15, height: 1.35)
                        : theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Center(child: _KeepCloseButton(name: widget.name)),
            const SizedBox(height: 16),

            // -- their squares ------------------------------------------------
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (posts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No squares from ${widget.name} yet —\ntheir page fills as they post.',
                  textAlign: TextAlign.center,
                  style: useInk
                      ? kHandwrittenTextStyle.copyWith(
                          fontSize: 17,
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
              )
            else
              for (final p in posts)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.createdAt.day}.${p.createdAt.month}.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: useInk
                                ? kHandwrittenTextStyle.copyWith(fontSize: 16)
                                : theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// The follow button on a peer's page. Three honest states: "Keep close"
/// (not following), "Keeping close" (following, filled), and "Drift apart"
/// (the action while following). Drifting apart asks nothing, confirms
/// nothing, announces nothing — the button just returns to "Keep close".
class _KeepCloseButton extends StatefulWidget {
  const _KeepCloseButton({required this.name});

  final String name;

  @override
  State<_KeepCloseButton> createState() => _KeepCloseButtonState();
}

class _KeepCloseButtonState extends State<_KeepCloseButton> {
  bool _busy = false;

  Future<void> _toggle(bool following) async {
    if (_busy || !sl.isRegistered<FollowRepository>()) return;
    setState(() => _busy = true);
    final repo = sl<FollowRepository>();
    final result = following
        ? await repo.driftApart(widget.name)
        : await repo.keepClose(widget.name);
    result.fold((_) {}, (_) {});
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Either<Failure, PeerFollow?>>(
      stream: sl.isRegistered<FollowRepository>()
          ? sl<FollowRepository>().watchRelationship(widget.name)
          : null,
      builder: (context, snap) {
        final following =
            snap.data?.fold((_) => false, (f) => f != null) ?? false;
        // Accent-safe pairing: the raw accent as a foreground on the
        // tonal fill is unreadable for several accents (green on amber).
        // The derivation guarantees a contrast-tested pair instead.
        final derivation = AccentDerivation.of(
          Theme.of(context).colorScheme.primary,
          Theme.of(context).brightness,
        );
        return Semantics(
          label: following ? 'Keeping close' : 'Keep close',
          button: true,
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _toggle(following),
            icon: Icon(following
                ? Icons.favorite_rounded
                : Icons.person_add_alt_1_rounded),
            label: Text(following ? 'Keeping close' : 'Keep close'),
            style: FilledButton.styleFrom(
              backgroundColor: derivation.container,
              foregroundColor: derivation.onContainer,
            ),
          ),
        );
      },
    );
  }
}