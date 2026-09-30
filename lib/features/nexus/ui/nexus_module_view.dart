import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../core/attachments/attachment.dart';
import '../../../core/attachments/attachment_media_view.dart';
import '../../../core/design_system/ink_chat_composer.dart';
import '../../../core/design_system/loading_skeletons.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/design_system/staggered_entrance.dart';
import '../../../core/error/failures.dart';
import '../../../core/attachments/post_navigation.dart';
import '../../../core/settings/draft_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../injection.dart';
import '../domain/entities/nexus.dart';
import '../domain/repositories/nexus_repository.dart';

/// The Nexus — module shell. Two tabs: broadcast Channels (remote-first
/// cache, Square model) and Groups (local-first outbox, Vault model).
/// Consumes [NexusRepository] streams directly, slice-simple.
class NexusModuleView extends StatefulWidget {
  const NexusModuleView({
    super.key,
    required this.repository,
    this.embedded = false,
    this.deepLinkGroupId,
  });

  final NexusRepository repository;

  /// Wide-shell mode: sits inside the rail body without its own back
  /// chrome; narrow mode pushes from the drawer and gets a leading back.
  final bool embedded;

  /// Deep-link entry (#8): the group the user tapped through to. The
  /// view waits for the groups stream to contain it, then opens it.
  final String? deepLinkGroupId;

  @override
  State<NexusModuleView> createState() => _NexusModuleViewState();
}

class _NexusModuleViewState extends State<NexusModuleView> {
  // Tab selection lives in the DefaultTabController, not here.

  bool _deepLinkHandled = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: widget.embedded ? null : IconButton(
            tooltip: 'Back',
            icon: const SketchGlyph(kind: SketchIconKind.arrowBack),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('The Hallway'),
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: 'Refresh channels',
              icon: const SketchGlyph(kind: SketchIconKind.refreshLoop),
              onPressed: () async {
                final result = await widget.repository.refreshChannels();
                if (!mounted) return;
                result.fold(
                  (failure) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(failure.message ?? 'Refresh failed'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  (_) {},
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: SketchGlyph(
                  kind: SketchIconKind.megaphone,
                  seed: 'board'.hashCode & 0x7FFFFFFF,
                ),
                text: 'The Board',
              ),
              Tab(
                icon: SketchGlyph(
                  kind: SketchIconKind.threeHeads,
                  seed: 'dorms'.hashCode & 0x7FFFFFFF,
                ),
                text: 'Dorms',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChannelsTab(repository: widget.repository),
            _GroupsTab(
              repository: widget.repository,
              deepLinkGroupId: widget.deepLinkGroupId,
              onDeepLinkHandled: (group) {
                if (_deepLinkHandled) return;
                _deepLinkHandled = true;
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => NexusGroupChatPage(
                    repository: widget.repository,
                    group: group,
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// -- channels tab -------------------------------------------------------------

/// Bulletin-board header above the channels list — the Nexus's slice of
/// the Golden Hour voice (docs/ART_DIRECTION.md "community bulletin").
/// Handwritten masthead + amber sub-line; hidden entirely when the
/// analog layer is off (decorative, never functional chrome).
class _BulletinBoardHeader extends StatelessWidget {
  const _BulletinBoardHeader();

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    if (!golden.enabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The board is up.',
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 26,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'What the squares are talking about.',
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 15,
              color: golden.amberAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelsTab extends StatelessWidget {
  const _ChannelsTab({required this.repository});

  final NexusRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Either<Failure, List<NexusChannel>>>(
      stream: repository.watchChannels(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TileListSkeleton();
        }
        final either = snapshot.data;
        if (either == null) {
          return const _NexusEmptyState(
            icon: Icons.wifi_off_rounded,
            message: 'Stream dropped. Reconnect to reload.',
          );
        }
        return either.fold(
          (failure) => _NexusEmptyState(
            icon: Icons.cloud_off_rounded,
            message: failure.message ?? 'Hallway unavailable.',
          ),
          (channels) {
            if (channels.isEmpty) {
              return const _NexusEmptyState(
                icon: Icons.campaign_outlined,
                message: 'No channels yet.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              // +1 for the bulletin-board header pinned above the list.
              itemCount: channels.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const _BulletinBoardHeader();
                }
                final c = channels[index - 1];
                return StaggeredEntrance(
                  index: index - 1,
                  child: _ChannelTile(
                    channel: c,
                    onOpen: () {
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => NexusChannelPostsPage(
                          repository: repository,
                          channel: c,
                        ),
                      ));
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.onOpen});

  final NexusChannel channel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Bulletin-board ink (spec §4): wobbly notebook box around each
    // channel tile when the analog layer is on.
    final useInk = GoldenHourExtension.of(context).enabled;
    final seed = channel.id.hashCode & 0x7FFFFFFF;

    final tileContent = Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.tertiaryContainer,
          child: Icon(
            Icons.campaign_rounded,
            color: theme.colorScheme.onTertiaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                channel.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _timeLabel(channel.lastPostAt),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );

    final tile = Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: useInk
            ? SketchBox(
                seed: seed,
                radius: 8,
                strokeWidth: 2,
                color: SketchInk.of(context),
                padding: const EdgeInsets.all(12),
                child: tileContent,
              )
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: tileContent,
              ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: tile,
    );
  }

  String _timeLabel(DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }
}

/// Broadcast posts for one channel. Read-only: channels are 1→many,
/// the local user never writes here.
class NexusChannelPostsPage extends StatelessWidget {
  const NexusChannelPostsPage({
    super.key,
    required this.repository,
    required this.channel,
  });

  final NexusRepository repository;
  final NexusChannel channel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          channel.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<Either<Failure, List<ChannelPost>>>(
        stream: repository.watchChannelPosts(channelId: channel.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TileListSkeleton();
          }
          final either = snapshot.data;
          if (either == null) {
            return const Center(child: Text('Stream dropped.'));
          }
          return either.fold(
            (failure) => Center(
              child: Text(failure.message ?? 'Channel unavailable.'),
            ),
            (posts) {
              if (posts.isEmpty) {
                return const Center(child: Text('No posts yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final p = posts[index];
                  return StaggeredEntrance(
                    index: index,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.tertiaryContainer,
                        child: Text(
                          p.authorName[0].toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(
                        p.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(p.body),
                      trailing: Text(
                        '${p.createdAt.hour.toString().padLeft(2, '0')}:'
                        '${p.createdAt.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// -- groups tab ----------------------------------------------------------------

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({
    required this.repository,
    this.deepLinkGroupId,
    this.onDeepLinkHandled,
  });

  final NexusRepository repository;

  /// Deep-link target (#8): when the stream emits a list containing it,
  /// [onDeepLinkHandled] fires with the group to open.
  final String? deepLinkGroupId;
  final ValueChanged<NexusGroup>? onDeepLinkHandled;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Either<Failure, List<NexusGroup>>>(
      stream: repository.watchGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TileListSkeleton();
        }
        final either = snapshot.data;
        if (either == null) {
          return const _NexusEmptyState(
            icon: Icons.wifi_off_rounded,
            message: 'Stream dropped. Reconnect to reload.',
          );
        }
        return either.fold(
          (failure) => _NexusEmptyState(
            icon: Icons.cloud_off_rounded,
            message: failure.message ?? 'Hallway unavailable.',
          ),
          (groups) {
            // Deep-link resolution: fire once, when the target exists.
            final targetId = deepLinkGroupId;
            if (targetId != null) {
              for (final g in groups) {
                if (g.id == targetId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onDeepLinkHandled?.call(g);
                  });
                  break;
                }
              }
            }
            if (groups.isEmpty) {
              return const _NexusEmptyState(
                icon: Icons.group_outlined,
                message: 'No dorms yet.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final g = groups[index];
                return StaggeredEntrance(
                  index: index,
                  child: _GroupTile(
                    group: g,
                    onOpen: () {
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => NexusGroupChatPage(
                          repository: repository,
                          group: g,
                        ),
                      ));
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.onOpen});

  final NexusGroup group;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = switch (group.myRole) {
      MemberRole.owner => 'Owner',
      MemberRole.admin => 'Admin',
      MemberRole.member => 'Member',
    };
    // Same bulletin-board ink as the Board tiles — the Nexus's second
    // slice of the analog voice.
    final useInk = GoldenHourExtension.of(context).enabled;
    final seed = group.id.hashCode & 0x7FFFFFFF;

    final tileContent = Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: SketchIcon(
                    kind: SketchIconKind.threeHeads,
                    size: 24,
                    color: theme.colorScheme.onPrimaryContainer,
                    seed: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.memberIds.length} members · $roleLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeLabel(group.lastActivityAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );

    final tile = Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: useInk
            ? SketchBox(
                seed: seed,
                radius: 8,
                strokeWidth: 2,
                color: SketchInk.of(context),
                padding: const EdgeInsets.all(12),
                child: tileContent,
              )
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: tileContent,
              ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: tile,
    );
  }

  String _timeLabel(DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }
}

/// Group chat — the Vault's local-first outbox minus E2EE. Sending
/// persists pending, then the mock transport acks.
class NexusGroupChatPage extends StatefulWidget {
  const NexusGroupChatPage({
    super.key,
    required this.repository,
    required this.group,
  });

  final NexusRepository repository;
  final NexusGroup group;

  @override
  State<NexusGroupChatPage> createState() => _NexusGroupChatPageState();
}

class _NexusGroupChatPageState extends State<NexusGroupChatPage> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  /// Draft autosave, keyed per group — same contract as the Vault chat
  /// page: restore on open, debounced save on change, clear on send.
  DraftDebouncer? _draftSave;
  bool _draftRestored = false;

  String get _draftKey => DraftStore.dorm(widget.group.id);

  void _onDraftChanged(String text) {
    if (!sl.isRegistered<DraftStore>()) return;
    _draftSave ??= DraftDebouncer();
    _draftSave!.run(() {
      sl<DraftStore>().write(_draftKey, text);
    });
  }

  Future<void> _clearDraft() async {
    _draftSave?.dispose();
    _draftSave = null;
    if (!sl.isRegistered<DraftStore>()) return;
    await sl<DraftStore>().clear(_draftKey);
  }

  Future<void> _restoreDraft() async {
    if (_draftRestored || !sl.isRegistered<DraftStore>()) return;
    _draftRestored = true;
    final text = await sl<DraftStore>().read(_draftKey);
    if (!mounted || text == null || _composer.text.isNotEmpty) return;
    setState(() => _composer.text = text);
  }

  /// Created once — the StreamBuilder must not re-subscribe on rebuild
  /// (same flash-to-skeleton gotcha as the Vault's chat page).
  late final Stream<Either<Failure, List<GroupMessage>>> _messages =
      widget.repository.watchGroupMessages(groupId: widget.group.id);

  @override
  void initState() {
    super.initState();
    // Draft autosave: one listener for the page's lifetime.
    _composer.addListener(() => _onDraftChanged(_composer.text));
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  @override
  void dispose() {
    // Leave without sending: flush the last state.
    final save = _draftSave;
    if (save != null) {
      save.dispose();
      if (sl.isRegistered<DraftStore>()) {
        sl<DraftStore>().write(_draftKey, _composer.text);
      }
    }
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    _sending = true;
    _composer.clear();
    unawaited(_clearDraft());
    if (mounted) setState(() {});
    final result = await widget.repository.sendGroupMessage(
      groupId: widget.group.id,
      body: body,
    );
    _finishSend(result);
  }

  /// Send with an attachment (text optional — a photo alone is a
  /// message). Same pipeline as the Vault: the repo copies the file
  /// into the attachments dir before persisting.
  Future<void> _sendWithAttachment(MessageAttachment attachment) async {
    if (_sending) return;
    _sending = true;
    final body = _composer.text.trim();
    _composer.clear();
    unawaited(_clearDraft());
    final result = await widget.repository.sendGroupMessage(
      groupId: widget.group.id,
      body: body,
      attachment: attachment,
    );
    _finishSend(result);
  }

  void _finishSend(Either<Failure, GroupMessage> result) {
    if (!mounted) return;
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message ?? 'Send failed')),
        );
      },
      (_) {},
    );
    _sending = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: SketchIcon(
                kind: SketchIconKind.threeHeads,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
                seed: 23,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.group.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<Either<Failure, List<GroupMessage>>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ChatSkeleton();
                }
                final either = snapshot.data;
                if (either == null) {
                  return const Center(child: Text('Message stream unavailable.'));
                }
                return either.fold(
                  (failure) => Center(
                    child: Text(failure.message ?? 'Group unavailable.'),
                  ),
                  (messages) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients) {
                        _scroll.jumpTo(_scroll.position.maxScrollExtent);
                      }
                    });
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'No messages yet.\nSay something first.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        return _GroupBubble(message: m);
                      },
                    );
                  },
                );
              },
            ),
          ),
          InkChatComposer(
            controller: _composer,
            enabled: !_sending,
            seed: widget.group.id.hashCode & 0x7FFFFFFF,
            hintText: 'Message the dorm',
            onSendWithAttachment: _sendWithAttachment,
            onSendText: _send,
          ),
        ],
      ),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  const _GroupBubble({required this.message});

  final GroupMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.isMine;
    // Same notebook restraint as the Vault: wobbly ink stroke when the
    // analog layer is on, Material card otherwise.
    final useInk = GoldenHourExtension.of(context).enabled;
    final seed = message.id.hashCode & 0x7FFFFFFF;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!mine)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message.senderId,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        if (message.attachment != null) ...[
          AttachmentMediaView(
            attachment: message.attachment!,
            seed: seed,
            onOpenSharedPost: (context, postId) =>
                openSquarePost(context, postId),
          ),
          if (message.body.isNotEmpty) const SizedBox(height: 6),
        ],
        if (message.body.isNotEmpty)
          Text(
            message.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mine
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${message.createdAt.hour.toString().padLeft(2, '0')}:'
              '${message.createdAt.minute.toString().padLeft(2, '0')}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: (mine
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant)
                    .withValues(alpha: 0.7),
              ),
            ),
            if (mine) ...[
              const SizedBox(width: 4),
              _OutboxTick(status: message.status),
            ],
          ],
        ),
      ],
    );

    final bubble = useInk
        ? SketchBox(
            seed: seed,
            radius: 6,
            strokeWidth: 2,
            color: SketchInk.of(context),
            fill: mine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: content,
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: mine
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: content,
          );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: mine ? 56 : 0,
          right: mine ? 0 : 56,
        ),
        child: bubble,
      ),
    );
  }
}

/// Outbox status tick for group messages. Same visual language as the
/// Vault's StatusTick, but Nexus-owned (no cross-feature import).
class _OutboxTick extends StatelessWidget {
  const _OutboxTick({required this.status});

  final OutboxStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useInk = GoldenHourExtension.of(context).enabled;
    if (!useInk) {
      switch (status) {
        case OutboxStatus.pending:
          return Icon(Icons.schedule_rounded,
              size: 13,
              color:
                  theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7));
        case OutboxStatus.sent:
          return Icon(Icons.done_all_rounded,
              size: 14,
              color:
                  theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9));
        case OutboxStatus.failed:
          return Icon(Icons.error_outline_rounded,
              size: 14, color: theme.colorScheme.error);
      }
    }
    final color = switch (status) {
      OutboxStatus.pending ||
      OutboxStatus.sent =>
        theme.colorScheme.onPrimaryContainer,
      OutboxStatus.failed => theme.colorScheme.error,
    };
    final kind = switch (status) {
      OutboxStatus.pending => SketchIconKind.clockTick,
      OutboxStatus.sent => SketchIconKind.doubleTick,
      OutboxStatus.failed => SketchIconKind.xHeart,
    };
    return SketchIcon(kind: kind, size: 14, color: color, seed: 11);
  }
}

class _NexusEmptyState extends StatelessWidget {
  const _NexusEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: golden.enabled
                ? kHandwrittenTextStyle.copyWith(
                    fontSize: 19,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
