import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../injection.dart';
import '../error/failures.dart';
import '../profile/profile_controller.dart';
import '../theme/app_theme.dart';
import '../../features/profile/ui/profile_page.dart';
import '../../features/square/domain/entities/post.dart';
import '../../features/square/domain/repositories/feed_repository.dart';

/// Who a tap refers to. The local user opens their real profile page;
/// everyone else (mock peers, in this stage) opens the person sheet.
enum PersonRefKind { localUser, named }

/// Opens a person from any name/avatar tap. The local user lands on
/// their editable profile; a named person opens the person sheet with
/// their recent Square posts. One entry point so every surface behaves
/// the same.
Future<void> openPerson(
  BuildContext context, {
  required String name,
  PersonRefKind kind = PersonRefKind.named,
}) async {
  if (kind == PersonRefKind.localUser) {
    final controller =
        sl.isRegistered<ProfileController>() ? sl<ProfileController>() : null;
    if (controller == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfilePage(
        profileController: controller,
        feedRepository:
            sl.isRegistered<FeedRepository>() ? sl<FeedRepository>() : null,
      ),
    ));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => PersonSheet(name: name),
  );
}

/// A person at a glance: initials avatar, name, and their recent Square
/// posts. Mock peers have no rich profile yet — the sheet is honest
/// about that with its empty state instead of faking one.
class PersonSheet extends StatefulWidget {
  const PersonSheet({super.key, required this.name});

  final String name;

  @override
  State<PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<PersonSheet> {
  late final Future<List<Post>> _posts = _loadPosts();

  Future<List<Post>> _loadPosts() async {
    if (!sl.isRegistered<FeedRepository>()) return const <Post>[];
    final Either<Failure, List<Post>> result =
        await sl<FeedRepository>().findPostsByAuthor(widget.name);
    // Repo failures degrade to the sheet's empty state.
    return result.fold((_) => const <Post>[], (p) => p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    final initials = widget.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 4),
          CircleAvatar(
            radius: 30,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.name,
            style: useInk
                ? kHandwrittenTextStyle.copyWith(
                    fontSize: 26, color: theme.colorScheme.onSurface)
                : theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            'On the Square',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Post>>(
              future: _posts,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                final posts = snap.data ?? const <Post>[];
                if (posts.isEmpty) {
                  return Padding(
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
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final p = posts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
