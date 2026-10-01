
import 'package:flutter/material.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/io/platform_io.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/theme/app_theme.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../injection.dart';
import '../../social/domain/repositories/follow_repository.dart';
import '../../social/ui/circle_window_page.dart';

import '../../square/domain/entities/post.dart';
import '../../square/domain/repositories/feed_repository.dart';

/// Profile — view and edit the local user's identity: display name,
/// bio, avatar, and the app's accent color, plus the grid of the user's
/// own Square posts as polaroid thumbnails. Edits apply live (the theme
/// root cross-fades to the new accent) and persist through the
/// controller's storage seam.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profileController,
    this.feedRepository,
    this.embedInOnboarding = false,
  });

  final ProfileController profileController;

  /// Own-post grid source. Null (older callers / standalone tests) hides
  /// the grid section entirely rather than showing a fake empty state.
  final FeedRepository? feedRepository;

  /// First-run mode: no Scaffold/app-bar, no own-posts grid, no padding —
  /// just the identity editor, embedded in the onboarding flow.
  final bool embedInOnboarding;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profileController.profile.displayName);
  late final TextEditingController _bio =
      TextEditingController(text: widget.profileController.profile.bio ?? '');
  late String? _avatarPath = widget.profileController.profile.avatarPath;
  late Color _accent = widget.profileController.profile.accentColor;

  final ImagePicker _picker = ImagePicker();
  bool _picking = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    widget.profileController.update(UserProfile(
      displayName:
          _name.text.trim().isEmpty ? 'You' : _name.text.trim(),
      bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      avatarPath: _avatarPath,
      accentColor: _accent,
    ));
  }

  Future<void> _pickAvatar() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return; // user cancelled
      setState(() => _avatarPath = picked.path);
      _commit();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the image picker')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _clearAvatar() {
    setState(() => _avatarPath = null);
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Embedded (first-run setup): shrink-wrap to content and let the
    // host's scroll view own the physics — a full ListView inside a
    // CustomScrollView sliver gets unbounded height and paints nothing.
    final body = ListView(
      shrinkWrap: widget.embedInOnboarding,
      physics: widget.embedInOnboarding
          ? const NeverScrollableScrollPhysics()
          : null,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
          // -- identity preview ------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Avatar(
                      initials: _PreviewProfile.from(_name.text).initials(),
                      avatarPath: _avatarPath,
                      accent: _accent,
                      radius: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _name.text.trim().isEmpty ? 'You' : _name.text.trim(),
                      style: theme.textTheme.headlineSmall,
                    ),
                    // The bio renders in the handwritten voice (Caveat),
                    // like a note pencilled under a yearbook photo. Empty
                    // shows a quiet invitation, never a blank gap.
                    const SizedBox(height: 4),
                    Text(
                      _bio.text.trim().isEmpty
                          ? 'write a line about yourself…'
                          : _bio.text.trim(),
                      style: kHandwrittenTextStyle.copyWith(
                        fontSize: 18,
                        color: _bio.text.trim().isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.55)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // -- editable fields -------------------------------------------
          if (!widget.embedInOnboarding) ...[
            const _SectionHeader('My Circle'),
            const _CircleWindowTiles(),
          ],
          const _SectionHeader('Display name'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                    filled: false,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _commit();
                  },
                  onSubmitted: (_) => _commit(),
                ),
              ),
            ),
          ),

          const _SectionHeader('Bio'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _bio,
                  maxLines: 2,
                  maxLength: 120,
                  style: kHandwrittenTextStyle.copyWith(fontSize: 19),
                  decoration: const InputDecoration(
                    hintText: 'One line, in ink…',
                    filled: false,
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _commit();
                  },
                  onSubmitted: (_) => _commit(),
                ),
              ),
            ),
          ),

          const _SectionHeader('Profile picture'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      // Raw tap target: give screen readers a name and
                      // button role (the avatar itself is just initials).
                      child: Semantics(
                        button: true,
                        label: 'Change profile picture',
                        child: _Avatar(
                          initials:
                              _PreviewProfile.from(_name.text).initials(),
                          avatarPath: _avatarPath,
                          accent: _accent,
                          radius: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _picking
                            ? 'Opening picker…'
                            : _avatarPath == null
                                ? 'No picture — tap the avatar to choose one from your files'
                                : 'Picture set from a local file',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _picking ? null : _pickAvatar,
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: const Text('Choose file'),
                    ),
                    if (_avatarPath != null)
                      IconButton(
                        tooltip: 'Use initials avatar',
                        onPressed: _clearAvatar,
                        icon: Semantics(
                          label: 'Use initials avatar',
                          excludeSemantics: true,
                          child: const SketchIcon(
                              kind: SketchIconKind.closeX, size: 18, seed: 19),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const _SectionHeader('Accent color'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final color in kAccentPalette)
                          _AccentSwatch(
                            color: color,
                            selected:
                                color.toARGB32() == _accent.toARGB32(),
                            onTap: () {
                              setState(() => _accent = color);
                              _commit();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ContainerPreview(accent: _accent),
                  ],
                ),
              ),
            ),
          ),

          // -- own posts grid --------------------------------------------
          if (!widget.embedInOnboarding && widget.feedRepository != null) ...[
            const _SectionHeader('Pinned squares'),
            _OwnPostsGrid(
              feedRepository: widget.feedRepository!,
              authorName: _name.text.trim().isEmpty
                  ? 'You'
                  : _name.text.trim(),
            ),
          ],

          const SizedBox(height: 24),
        ],
    );

    if (widget.embedInOnboarding) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
      ),
      body: body,
    );
  }
}

/// The local user's own Square posts as small polaroid thumbnails.
/// Loading paints the shared skeleton; empty shows the in-voice
/// "nothing pinned yet" note. Thumbnails open the post's day view (the
/// existing post surface) — no new post-detail page invented here.
class _OwnPostsGrid extends StatelessWidget {
  const _OwnPostsGrid({
    required this.feedRepository,
    required this.authorName,
  });

  final FeedRepository feedRepository;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    // Late-final stream discipline: watchFeed() returns a fresh stream
    // per call, so the stream must be created once per author, not per
    // build (see the stream-rebind gotcha in ARCHITECTURE.md §8).
    final stream = feedRepository.watchFeed();
    return StreamBuilder<Either<dynamic, List<Post>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final posts = (snapshot.data?.fold((_) => null, (p) => p)) ??
            const <Post>[];
        final mine = posts.where((p) => p.authorName == authorName).toList();
        if (mine.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
            child: Text(
              'Nothing pinned yet. Your squares will gather here.',
              style: kHandwrittenTextStyle.copyWith(
                fontSize: 17,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82, // polaroid: taller than wide
            ),
            itemCount: mine.length,
            itemBuilder: (context, index) => _PolaroidThumb(
              post: mine[index],
              onTap: () {
                final day = mine[index].createdAt;
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => _ProfileDayLoader(
                    feedRepository: feedRepository,
                    day: day,
                  ),
                ));
              },
            ),
          ),
        );
      },
    );
  }
}

/// Loads the day the tapped post belongs to and opens the existing
/// SquareDayViewPage for it — "opens the existing post view" without
/// inventing a new detail surface.
class _ProfileDayLoader extends StatelessWidget {
  const _ProfileDayLoader({required this.feedRepository, required this.day});

  final FeedRepository feedRepository;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(day.year, day.month, day.day);
    return FutureBuilder<Either<dynamic, List<Post>>>(
      future: feedRepository.postsOnDay(start),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final posts =
            snapshot.data?.fold((_) => <Post>[], (p) => p) ?? const <Post>[];
        return Scaffold(
          appBar: AppBar(title: const Text('That day')),
          body: posts.isEmpty
              ? Center(
                  child: Text(
                    'Nothing was written this day.\nThe page stays blank.',
                    textAlign: TextAlign.center,
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 18,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final p in posts)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.body,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                              const SizedBox(height: 8),
                              Text(
                                '${p.likesCount} likes',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// A small polaroid thumbnail: media on top, caption strip below. Local
/// files render from disk; remote media falls back to the caption-only
/// frame (no network fetch in a 100dp tile).
class _PolaroidThumb extends StatelessWidget {
  const _PolaroidThumb({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = post.mediaUrl != null &&
        !post.mediaUrl!.startsWith('http');
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: post.hasMedia && local
                    ? Image(
                        image: platformImageProvider(post.mediaUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SketchGlyph(
                            kind: SketchIconKind.photoFrame, size: 28),
                      )
                    : const ColoredBox(
                        color: Color(0x1414181F),
                        child: Center(
                          child: SketchGlyph(
                              kind: SketchIconKind.photoFrame, size: 28),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kHandwrittenTextStyle.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.avatarPath,
    required this.accent,
    required this.radius,
  });

  final String initials;
  final String? avatarPath;
  final Color accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,                        backgroundImage:
                            platformImageProvider(avatarPath!),
        onBackgroundImageError: (_, __) {},
      );
    }
    final derivation =
        AccentDerivation.of(accent, Theme.of(context).brightness);
    return CircleAvatar(
      radius: radius,
      backgroundColor: derivation.container,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w800,
          color: derivation.onContainer,
        ),
      ),
    );
  }
}

/// Live preview of the in-editor values (the controller holds only the
/// committed profile).
class _PreviewProfile extends UserProfile {
  const _PreviewProfile(String displayName) : super(displayName: displayName);

  factory _PreviewProfile.from(String name) =>
      _PreviewProfile(name.trim().isEmpty ? 'You' : name.trim());
}

/// My Circle / My Window entry tiles with live counts, shown on the
/// local user's profile. Vocabulary is fixed: "My Circle" (who keeps me
/// close), "My Window" (who I keep close).
class _CircleWindowTiles extends StatelessWidget {
  const _CircleWindowTiles();

  Stream<int> _count(BuildContext context, {required bool circle}) {
    if (!sl.isRegistered<FollowRepository>()) return const Stream.empty();
    final repo = sl<FollowRepository>();
    final stream = circle ? repo.watchCircle() : repo.watchWindow();
    return stream
        .map((either) => either.fold((_) => -1, (l) => l.length));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            StreamBuilder<int?>(
              stream: _count(context, circle: true),
              builder: (context, snap) => ListTile(
                leading: SketchGlyph(
                  kind: SketchIconKind.scribbleHeart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('My Circle'),
                subtitle: const Text('People who keep you close'),
                trailing: snap.data != null && snap.data! >= 0
                    ? Text('${snap.data}',
                        style: Theme.of(context).textTheme.titleMedium)
                    : null,
                onTap: () => Navigator.of(context)
                    .push<void>(MaterialPageRoute<void>(
                  builder: (_) => const CircleWindowPage(initiallyCircle: true),
                )),
              ),
            ),
            const Divider(height: 1),
            StreamBuilder<int?>(
              stream: _count(context, circle: false),
              builder: (context, snap) => ListTile(
                leading: SketchGlyph(
                  kind: SketchIconKind.windowFrame,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('My Window'),
                subtitle: const Text('People you keep close'),
                trailing: snap.data != null && snap.data! >= 0
                    ? Text('${snap.data}',
                        style: Theme.of(context).textTheme.titleMedium)
                    : null,
                onTap: () => Navigator.of(context)
                    .push<void>(MaterialPageRoute<void>(
                  builder: (_) =>
                      const CircleWindowPage(initiallyCircle: false),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: selected
            ? Icon(Icons.check_rounded,
                color: AccentDerivation.of(color, Theme.of(context).brightness)
                    .onPrimary)
            : null,
      ),
    );
  }
}

/// Shows the auto-derived container family for the current accent —
/// what a chip/avatar background built on the accent will look like,
/// with its contrast-verified foreground.
class _ContainerPreview extends StatelessWidget {
  const _ContainerPreview({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final d = AccentDerivation.of(accent, brightness);
    return Row(
      children: [
        Expanded(
          child: _PreviewChip(
            label: 'primary',
            background: d.primary,
            foreground: d.onPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PreviewChip(
            label: 'container',
            background: d.container,
            foreground: d.onContainer,
          ),
        ),
      ],
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Min-height (not fixed) so the label survives large text scales;
      // identical 40dp at default scale.
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
