import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/sketch_kit.dart';
import '../../../../core/people/person_sheet.dart';
import '../../../../core/theme/app_theme.dart';
import '../domain/entities/social_entities.dart';
import '../domain/repositories/social_repository.dart';

/// The notification feed: new comments, reactions, replies from the
/// Square's regulars. Newest first; unread entries carry the ink dot.
/// Tapping navigates to the entry's context and marks the feed read.
/// Copy is plain and warm — no streaks, no counters, no chores.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.repository});

  final SocialRepository repository;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Stream<List<SocialNotification>>? _stream;

  // Late-final stream discipline (ARCHITECTURE.md §8).
  Stream<List<SocialNotification>> get _notificationStream =>
      _stream ??= widget.repository
          .watchNotifications()
          .map((either) =>
              either.fold((_) => <SocialNotification>[], (l) => l));

  @override
  void initState() {
    super.initState();
    // Opening the page is reading it: entries keep their unread ink dot
    // for this visit, then the feed settles as read on the way out.
  }

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: StreamBuilder<List<SocialNotification>>(
        stream: _notificationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <SocialNotification>[];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SketchIcon(
                    kind: SketchIconKind.sunMark,
                    size: 40,
                    seed: 83,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All quiet on the Square.\nNew notes will land here.',
                    textAlign: TextAlign.center,
                    style: golden.enabled
                        ? kHandwrittenTextStyle.copyWith(
                            fontSize: 18,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          )
                        : Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.4),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _NoticeTile(
                notification: item,
                onTap: () async {
                  await widget.repository.markAllRead();
                  if (context.mounted) context.go(item.deepLink);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notification, required this.onTap});

  final SocialNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, verb) = switch (notification.kind) {
      NotificationKind.comment => (Icons.chat_bubble_outline_rounded, 'left a note'),
      NotificationKind.reaction => (Icons.favorite_border_rounded, 'reacted'),
      NotificationKind.reply => (Icons.reply_rounded, 'replied'),
    };
    final personName = notification.peerName;
    return ListTile(
      leading: GestureDetector(
        onTap: () => openPerson(context, name: personName),
        child: CircleAvatar(
          child: Text(personName.characters.first),
        ),
      ),
      title: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            WidgetSpan(
              child: GestureDetector(
                onTap: () => openPerson(context, name: personName),
                child: Text(
                  personName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            TextSpan(text: ' $verb'),
          ],
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: notification.isUnread
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
