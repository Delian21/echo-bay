
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/io/platform_io.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/profile/handles.dart';
import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/theme/app_theme.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../injection.dart';
import '../../keepsake/domain/repositories/keepsake_repository.dart';
import '../../keepsake/ui/keepsake_board_page.dart';
import '../../social/domain/repositories/follow_repository.dart';
import '../../social/ui/circle_window_page.dart';

import '../../square/domain/entities/post.dart';
import '../../square/domain/repositories/feed_repository.dart';

/// Where a profile can be shared from. The web build knows its own
/// origin at runtime; native builds (and tests) fall back to the
/// published town.
const String _kFallbackOrigin = 'https://echo-bay.netlify.app';

/// The full, shareable address for [handle]: origin + `/person/:handle`.
String profileShareUrl(String handle) {
  final base = Uri.base;
  final origin = (base.scheme == 'http' || base.scheme == 'https')
      ? '${base.scheme}://${base.authority}'
      : _kFallbackOrigin;
  return '$origin/person/${Uri.encodeComponent(handle)}';
}

/// Profile — the local user's identity, read-only: avatar, name, handle,
/// bio, the My Circle / My Window counts, and the grid of their own
/// Square posts as polaroid thumbnails. Editing lives on exactly one
/// screen, [ProfileEditPage], reached from the Edit button here.
class ProfilePage extends StatelessWidget {
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

  /// First-run mode: there is no finished profile to look at yet, so
  /// setup embeds the editor itself in the onboarding flow.
  final bool embedInOnboarding;

  @override
  Widget build(BuildContext context) {
    if (embedInOnboarding) {
      return ProfileEditPage(
        profileController: profileController,
        feedRepository: feedRepository,
        embedInOnboarding: true,
      );
    }
    return AnimatedBuilder(
      animation: profileController,
      builder: (context, _) => _ProfileView(
        profile: profileController.profile,
        feedRepository: feedRepository,
        onEdit: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileEditPage(
              profileController: profileController,
              feedRepository: feedRepository,
            ),
          ),
        ),
      ),
    );
  }
}

/// The read-only profile: who you are, who keeps you close, and what
/// you have pinned. One Edit button — the only way into the form.
class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.profile,
    required this.onEdit,
    this.feedRepository,
  });

  final UserProfile profile;
  final FeedRepository? feedRepository;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.displayName.trim().isEmpty
        ? 'You'
        : profile.displayName.trim();
    final bio = profile.bio?.trim() ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Avatar(
                      initials: profile.initials(),
                      avatarPath: profile.avatarPath,
                      accent: profile.accentColor,
                      radius: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      '@${profile.handle}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bio,
                        style: kHandwrittenTextStyle.copyWith(
                          fontSize: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _SectionHeader('People'),
          const _CircleWindowTiles(),
          if (feedRepository != null) ...[
            const _SectionHeader('Pinned squares'),
            // The wall's second front door, right beside the squares it
            // holds, with a live count.
            if (sl.isRegistered<KeepsakeRepository>())
              const _KeepsakeWallTile(),
            _OwnPostsGrid(
              feedRepository: feedRepository!,
              authorName: name,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The profile form — the single edit surface: display name, handle,
/// bio, avatar and the app's accent color. Edits apply live (the theme
/// root cross-fades to the new accent) and persist through the
/// controller's storage seam.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({
    super.key,
    required this.profileController,
    this.feedRepository,
    this.embedInOnboarding = false,
  });

  final ProfileController profileController;

  /// Kept for callers that pass it; the editor itself shows no grid.
  final FeedRepository? feedRepository;

  /// First-run mode: no Scaffold/app-bar — just the form, embedded in
  /// the onboarding flow.
  final bool embedInOnboarding;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profileController.profile.displayName);
  late final TextEditingController _handle =
      TextEditingController(text: widget.profileController.profile.handle);
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
      // Always store a slug: a half-typed handle can never reach a route.
      handle: handleForName(_handle.text),
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
                    const SizedBox(height: 2),
                    Text(
                      '@${handleForName(_handle.text)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
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

          const _SectionHeader('Handle'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _handle,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        prefixText: '@',
                        hintText: 'yourhandle',
                        filled: false,
                        border: InputBorder.none,
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _commit();
                      },
                      onSubmitted: (_) => _commit(),
                    ),
                    _ShareLinkRow(
                      handle: handleForName(_handle.text),
                      valid: isValidHandle(handleForName(_handle.text)),
                    ),
                  ],
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

          const SizedBox(height: 24),
        ],
    );

    if (widget.embedInOnboarding) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        centerTitle: false,
      ),
      body: body,
    );
  }
}

/// The handle's public face: a friendly line and the full link, with a
/// button that puts it on the clipboard. A half-typed handle shows the
/// coaching line instead — there is nothing shareable yet.
class _ShareLinkRow extends StatelessWidget {
  const _ShareLinkRow({required this.handle, required this.valid});

  final String handle;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!valid) {
      return Text(
        'Use at least two letters, numbers or underscores.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final url = profileShareUrl(handle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share this link and people can find you.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                url,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: url));
                messenger.showSnackBar(const SnackBar(
                  content: Text('Link copied.'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Copy link'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Entry to the Keepsake wall from the profile, carrying a live count of
/// everything pinned there (squares and notes alike).
class _KeepsakeWallTile extends StatefulWidget {
  const _KeepsakeWallTile();

  @override
  State<_KeepsakeWallTile> createState() => _KeepsakeWallTileState();
}

class _KeepsakeWallTileState extends State<_KeepsakeWallTile> {
  late final KeepsakeRepository _repository = sl<KeepsakeRepository>();

  // Late-final stream discipline: one subscription, created once.
  late final Stream<int> _count = _repository
      .watchBoard()
      .map((either) => either.fold((_) => -1, (items) => items.length));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: SketchGlyph(
            kind: SketchIconKind.photoFrame,
            color: theme.colorScheme.primary,
          ),
          title: const Text('Keepsake wall'),
          subtitle: StreamBuilder<int>(
            stream: _count,
            builder: (context, snapshot) {
              final count = snapshot.data;
              final label = switch (count) {
                null => 'Open the wall',
                <= 0 => 'Nothing pinned yet',
                1 => '1 thing pinned',
                _ => '$count things pinned',
              };
              return Text(label);
            },
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => KeepsakeBoardPage.show(
            context,
            repository: _repository,
          ),
        ),
      ),
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
    final local = post.mediaUrl != null &&
        !post.mediaUrl!.startsWith('http');
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // Same paper as the feed's prints: a wall of small prints should
          // read as paper, not as UI cards.
          color: const Color(0xFFFBF4E4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.borderPlain), // 1px
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
                color: const Color(0xFF2B2A26), // print ink
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
