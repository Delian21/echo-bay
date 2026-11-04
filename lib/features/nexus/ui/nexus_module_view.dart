import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../core/attachments/attachment.dart';
import '../../../core/attachments/attachment_media_view.dart';
import '../../../core/design_system/chat_bubble_layout.dart';
import '../../../core/design_system/chat_reply_widgets.dart';
import '../../../core/design_system/ink_chat_composer.dart';
import '../../../core/design_system/message_menu.dart';
import '../../../core/design_system/message_reactions.dart';
import '../../../core/design_system/reaction_pills.dart';
import '../../../core/design_system/swipe_to_reply.dart';
import '../../../core/design_system/loading_skeletons.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/design_system/staggered_entrance.dart';
import '../../../core/error/failures.dart';
import '../../../core/attachments/post_navigation.dart';
import '../../../core/settings/draft_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/local_identity.dart';
import '../../../core/chat/message_edit.dart';
import '../../../core/design_system/tear_out_confirm.dart';
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
            // A short accent underline under the selected label only:
            // no tab-wide highlight block, no full-width divider line.
            indicatorSize: TabBarIndicatorSize.label,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2.5,
              ),
              insets: const EdgeInsets.symmetric(horizontal: 10),
            ),
            dividerColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
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
                    repository: repository,
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
  const _ChannelTile({
    required this.channel,
    required this.repository,
    required this.onOpen,
  });

  final NexusChannel channel;
  final NexusRepository repository;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // List rows take the plain hairline: the wobbly stroke belongs to feed
    // post cards only.
    final seed = channel.id.hashCode & 0x7FFFFFFF;

    final tileContent = Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.tertiaryContainer,
          // Per-channel chalk glyph: announcements broadcast, the log is
          // written — two megaphones read as the same channel twice.
          child: SketchGlyph(
            kind: _channelGlyph(channel),
            size: 26,
            color: theme.colorScheme.onTertiaryContainer,
            seed: seed ^ 0x2C1,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Measured from the newest real post, not the channel row's
        // seed-time stamp — that one says "now" forever.
        _ChannelActivityTime(
          repository: repository,
          channelId: channel.id,
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
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderPlain), // 1px
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

  /// One glyph per channel, matched on the stable id first and the title
  /// second (custom/named channels still get something sensible).
  SketchIconKind _channelGlyph(NexusChannel channel) {
    final id = channel.id.toLowerCase();
    final title = channel.title.toLowerCase();
    if (id.contains('ann') || title.contains('announce')) {
      return SketchIconKind.megaphone;
    }
    if (id.contains('eng') ||
        title.contains('engineering') ||
        title.contains('log')) {
      // Written record, not a broadcast.
      return SketchIconKind.scribbleLine;
    }
    if (title.contains('design')) return SketchIconKind.plusCircle;
    if (title.contains('random') || title.contains('chat')) {
      return SketchIconKind.jaggedBubble;
    }
    return SketchIconKind.scribbleLine;
  }
}

/// The row's relative time, read from the channel's newest post. No
/// posts (or an empty/failed stream) means no label at all — there is
/// no activity to time. Sub-second freshness stays quiet rather than
/// printing a hard-coded "now".
class _ChannelActivityTime extends StatefulWidget {
  const _ChannelActivityTime({
    required this.repository,
    required this.channelId,
  });

  final NexusRepository repository;
  final String channelId;

  @override
  State<_ChannelActivityTime> createState() => _ChannelActivityTimeState();
}

class _ChannelActivityTimeState extends State<_ChannelActivityTime> {
  // Late-final stream discipline: watchChannelPosts() hands back a fresh
  // stream per call, so one subscription per row, created once.
  late final Stream<List<ChannelPost>> _posts = widget.repository
      .watchChannelPosts(channelId: widget.channelId)
      .map((either) => either.fold((_) => const <ChannelPost>[], (p) => p));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<ChannelPost>>(
      stream: _posts,
      builder: (context, snapshot) {
        final posts = snapshot.data ?? const <ChannelPost>[];
        // The query orders newest first.
        final label = posts.isEmpty ? null : _timeLabel(posts.first.createdAt);
        if (label == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }

  /// A post inside the last minute reads "now" — the label is measured
  /// from real activity, so that word is now true. A future stamp (clock
  /// skew) still gets nothing: there is no elapsed time to report.
  static String? _timeLabel(DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.isNegative) return null;
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
    // Plain hairline, same as the Board tiles.


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
                if (_timeLabel(group.lastActivityAt) case final label?)
                  Text(
                    label,
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
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderPlain), // 1px
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

  /// Null under a minute: a group whose activity is "right now" gets no
  /// label rather than a hard-coded "now" that never ages.
  String? _timeLabel(DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return null;
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

  /// The message being quoted by the draft in the composer, if any.
  GroupMessage? _replyTo;

  /// The message being rewritten in the composer, if any.
  String? _editingMessageId;

  /// Briefly tints the bubble a jump-to-original landed on.
  String? _highlightedId;
  Timer? _highlightTimer;

  /// One key per rendered row so a quoted block can bring its original
  /// into view. Lazily created, never rebuilt.
  final Map<String, GlobalKey> _rowKeys = {};

  /// Draft autosave, keyed per group — same contract as the Vault chat
  /// page: restore on open, debounced save on change, clear on send.
  DraftDebouncer? _draftSave;
  bool _draftRestored = false;

  String get _draftKey => DraftStore.dorm(widget.group.id);

  void _onDraftChanged(String text) {
    // Same rule as the Vault: an edit in progress never overwrites the
    // conversation's real draft.
    if (_editingMessageId != null) return;
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

  /// One subscription for the whole group, not one watcher per bubble.
  late final Stream<Either<Failure, List<GroupReaction>>> _reactions =
      widget.repository.watchGroupReactions(groupId: widget.group.id);

  GlobalKey _rowKey(String id) =>
      _rowKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'gmsg-$id'));

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
      // Leaving mid-edit must not save the edited body as a new draft.
      if (_editingMessageId == null && sl.isRegistered<DraftStore>()) {
        sl<DraftStore>().write(_draftKey, _composer.text);
      }
    }
    _highlightTimer?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final editingId = _editingMessageId;
    if (editingId != null) {
      await _commitEdit(editingId);
      return;
    }
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    _sending = true;
    _composer.clear();
    unawaited(_clearDraft());
    if (mounted) setState(() {});
    final replyToId = _replyTo?.id;
    if (replyToId != null) setState(() => _replyTo = null);
    final result = await widget.repository.sendGroupMessage(
      groupId: widget.group.id,
      body: body,
      replyToMessageId: replyToId,
    );
    _finishSend(result);
  }

  void _beginEdit(GroupMessage message) {
    setState(() {
      _replyTo = null;
      _editingMessageId = message.id;
      _composer.text = message.body;
    });
  }

  Future<void> _commitEdit(String messageId) async {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    // Clear before dropping the flag: the draft listener ignores writes
    // while an edit is active, so the real draft survives.
    _composer.clear();
    setState(() => _editingMessageId = null);
    final result = await widget.repository.editGroupMessage(
      messageId: messageId,
      newBody: body,
    );
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? "Couldn't save that edit"),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {},
    );
  }

  /// Delete an own group message after the shared confirmation. The row
  /// stays as a tombstone so the conversation keeps its shape.
  Future<void> _confirmDelete(GroupMessage message) async {
    final confirmed = await confirmTearOut(
      context,
      title: 'Tear out this message?',
      message: 'It stays as a deleted line, but the words are gone.',
    );
    if (!confirmed || !mounted) return;
    final result = await widget.repository.deleteGroupMessage(
      messageId: message.id,
    );
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? "Couldn't delete that message"),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {},
    );
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
    final replyToId = _replyTo?.id;
    if (replyToId != null) setState(() => _replyTo = null);
    final result = await widget.repository.sendGroupMessage(
      groupId: widget.group.id,
      body: body,
      attachment: attachment,
      replyToMessageId: replyToId,
    );
    _finishSend(result);
  }

  Future<void> _toggleReaction(String messageId, String reaction) async {
    await widget.repository.toggleGroupReaction(
      messageId: messageId,
      reaction: reaction,
    );
  }

  void _startReply(GroupMessage m) {
    setState(() => _replyTo = m);
  }

  /// Bring the quoted message into view and flash it. A row that is not
  /// currently built simply leaves the tap inert.
  void _jumpToOriginal(String messageId) {
    final ctx = _rowKeys[messageId]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.4,
    );
    _highlightTimer?.cancel();
    setState(() => _highlightedId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  static GroupMessage? _findMessage(List<GroupMessage> messages, String? id) {
    if (id == null) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
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
                    return StreamBuilder<Either<Failure, List<GroupReaction>>>(
                      stream: _reactions,
                      builder: (context, reactionSnapshot) {
                        final reactions = reactionSnapshot.data?.fold(
                              (_) => const <GroupReaction>[],
                              (rows) => rows,
                            ) ??
                            const <GroupReaction>[];
                        final byMessage = <String, List<GroupReaction>>{};
                        for (final r in reactions) {
                          byMessage.putIfAbsent(r.messageId, () => []).add(r);
                        }
                        return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        final prev = index > 0 ? messages[index - 1] : null;
                        final next = index + 1 < messages.length
                            ? messages[index + 1]
                            : null;
                        // Same sender-run rule as the Vault: a message
                        // opens a run when the sender changes (or it's
                        // the oldest), which drives the spacing and the
                        // sender-name line; the run's last message carries
                        // the clock. A day change drops a separator.
                        final opensRun = startsChatRun(
                          senderId: m.senderId,
                          createdAt: m.createdAt,
                          previousSenderId: prev?.senderId,
                          previousCreatedAt: prev?.createdAt,
                        );
                        final closesRun = next == null ||
                            next.senderId != m.senderId ||
                            next.createdAt.difference(m.createdAt) >=
                                kChatRunWindow;
                        return Column(
                          key: _rowKey(m.id),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (prev == null ||
                                !isSameChatDay(prev.createdAt, m.createdAt))
                              ChatDaySeparator(
                                  label: chatDayLabel(m.createdAt)),
                            _GroupBubble(
                              message: m,
                              opensRun: opensRun,
                              closesRun: closesRun,
                              quoted: _findMessage(
                                  messages, m.replyToMessageId),
                              highlighted: _highlightedId == m.id,
                              pills: summarizeReactions(
                                (byMessage[m.id] ?? const <GroupReaction>[])
                                    .map((r) => (
                                          userId: r.userId,
                                          reaction: r.reaction,
                                        )),
                                localUserId: LocalIdentity.id,
                              ),
                              onReply: () => _startReply(m),
                              onJumpToOriginal: m.replyToMessageId == null
                                  ? null
                                  : () => _jumpToOriginal(m.replyToMessageId!),
                              onReact: (reaction) =>
                                  _toggleReaction(m.id, reaction),
                              onEdit: m.isMine &&
                                      !m.isDeleted &&
                                      withinMessageEditWindow(m.createdAt)
                                  ? () => _beginEdit(m)
                                  : null,
                              onDelete: m.isMine && !m.isDeleted
                                  ? () => _confirmDelete(m)
                                  : null,
                            ),
                          ],
                        );
                      },
                    );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_replyTo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: ReplyBanner(
                senderName:
                    _replyTo!.isMine ? 'You' : _replyTo!.senderId,
                text: replyExcerpt(
                    _replyTo!.body, _replyTo!.attachment),
                onCancel: () => setState(() => _replyTo = null),
              ),
            ),
          InkChatComposer(
            controller: _composer,
            enabled: !_sending,
            hintText: 'Message the dorm',
            editing: _editingMessageId != null,
            onCancelEdit: _editingMessageId == null
                ? null
                : () => setState(() {
                      _editingMessageId = null;
                      _composer.clear();
                    }),
            onSendWithAttachment:
                _editingMessageId == null ? _sendWithAttachment : null,
            onSendText: _send,
          ),
        ],
      ),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  const _GroupBubble({
    required this.message,
    required this.opensRun,
    required this.closesRun,
    required this.pills,
    required this.onReply,
    this.quoted,
    this.highlighted = false,
    this.onJumpToOriginal,
    this.onReact,
    this.onEdit,
    this.onDelete,
  });

  final GroupMessage message;

  /// The message this one quotes, resolved from the loaded page. Null when
  /// the original was purged or is not loaded.
  final GroupMessage? quoted;

  /// Tint for a moment after a jump landed here.
  final bool highlighted;
  final VoidCallback? onJumpToOriginal;
  final List<ReactionPillData> pills;
  final VoidCallback onReply;
  final ValueChanged<String>? onReact;

  /// Rewrite / tombstone this message; both null on other people's
  /// messages and outside the edit window (Edit only).
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// True when this message starts a sender's run — it carries the
  /// sender's name and sits below the previous speaker; the rest of
  /// the run stacks tight underneath it.
  final bool opensRun;

  /// True for the run's last message — it carries the clock and the
  /// tail corner.
  final bool closesRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = LocalIdentity.owns(message.senderId);
    final bodyColor = chatBubbleForeground(context, isMine: mine);
    final metaColor = chatBubbleMetaForeground(context, isMine: mine);
    final seed = message.id.hashCode & 0x7FFFFFFF;

    if (message.isDeleted) {
      // Tombstone: keep the row's place in the conversation, say only
      // this, and offer nothing to press.
      return Padding(
        padding: EdgeInsets.only(
          top: opensRun ? kChatRunGap : kChatRunTightGap,
        ),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Semantics(
            label: 'Message deleted',
            child: Text(
              'Message deleted',
              style: theme.textTheme.labelSmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.replyToMessageId != null) ...[
          QuotedMessageBlock(
            senderName: quoted == null
                ? 'Message'
                : (quoted!.isMine ? 'You' : quoted!.senderId),
            text: quoted == null
                ? ''
                : replyExcerpt(quoted!.body, quoted!.attachment),
            isMine: mine,
            // A tombstoned original counts as missing: quoting it would
            // show its blanked-out body as if that were what was said.
            unavailable: quoted == null || quoted!.isDeleted,
            onTap: onJumpToOriginal,
          ),
          const SizedBox(height: 6),
        ],
        if (!mine && opensRun)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message.senderId,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                // Accent identity where it reads, ink where it does not —
                // a pale accent must not turn the name into decoration.
                color: AccentDerivation.higherContrast(
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.primary,
                  theme.colorScheme.onSurface,
                ),
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
              color: bodyColor,
              height: 1.3,
            ),
          ),
        // Only the run's last message carries the clock.
        if (closesRun) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                '${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: metaColor,
                ),
              ),
              // Same "edited" mark as the Vault: small, muted, beside
              // the clock, only when an edit actually happened.
              if (message.isEdited) ...[
                const SizedBox(width: 4),
                Text(
                  'edited',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: metaColor,
                  ),
                ),
              ],
              if (mine) ...[
                const SizedBox(width: 4),
                _OutboxTick(status: message.status, onAccent: true),
              ],
            ],
          ),
        ],
      ],
    );

    final bubble = ChatBubbleFrame(
      isMine: mine,
      closesRun: closesRun,
      child: content,
    );

    final interactive = SwipeToReply(
      isMine: mine,
      onReply: onReply,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        onDoubleTap: onReact == null ? null : () => onReact!('heart'),
        child: Semantics(
          button: true,
          label: mine ? 'Your message' : 'Message from ${message.senderId}',
          child: BubbleWithReactions(
            bubble: bubble,
            pills: pills,
            isMine: mine,
            onPillTap: (reaction) => onReact?.call(reaction),
          ),
        ),
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        // Same rhythm as the Vault: 10px when a speaker changes, 2px
        // inside a burst — a run reads as one block.
        padding: EdgeInsets.only(
          top: opensRun ? kChatRunGap : kChatRunTightGap,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: highlighted
                ? theme.colorScheme.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: interactive,
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final result = await showMessageMenu(
      context,
      canReply: true,
      canEdit: onEdit != null,
      // Pin keeps its reserved slot: the Nexus has no wall handler yet,
      // and a dead action is worse than a missing one.
      canPin: false,
      canDelete: onDelete != null,
    );
    if (result == null) return;
    final reaction = result.reaction;
    if (reaction != null) {
      onReact?.call(reaction);
      return;
    }
    switch (result.action) {
      case MessageMenuAction.reply:
        onReply();
      case MessageMenuAction.edit:
        onEdit?.call();
      case MessageMenuAction.delete:
        onDelete?.call();
      case MessageMenuAction.pin:
      case null:
        break;
    }
  }
}

/// Outbox status tick for group messages. Same visual language as the
/// Vault's StatusTick, but Nexus-owned (no cross-feature import).
class _OutboxTick extends StatelessWidget {
  const _OutboxTick({required this.status, this.onAccent = false});

  final OutboxStatus status;

  /// True on the filled accent bubble: the tick must use onPrimary to
  /// stay visible.
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final useInk = GoldenHourExtension.of(context).enabled;
    // The tick only sits on my own bubble, which is accent-filled now.
    final idle = onAccent ? scheme.onPrimary : scheme.onPrimaryContainer;
    final failed = onAccent ? scheme.onPrimary : scheme.error;
    if (!useInk) {
      switch (status) {
        case OutboxStatus.pending:
          return Icon(Icons.schedule_rounded, size: 15, color: idle);
        case OutboxStatus.sent:
          return Icon(Icons.done_all_rounded, size: 16, color: idle);
        case OutboxStatus.failed:
          return Icon(Icons.error_outline_rounded, size: 16, color: failed);
      }
    }
    final color = switch (status) {
      OutboxStatus.pending ||
      OutboxStatus.sent =>
        idle,
      OutboxStatus.failed => failed,
    };
    final kind = switch (status) {
      OutboxStatus.pending => SketchIconKind.clockTick,
      OutboxStatus.sent => SketchIconKind.doubleTick,
      OutboxStatus.failed => SketchIconKind.xHeart,
    };
    // 16px, matching the Vault's tick — at 14 it read as debris.
    return SketchIcon(kind: kind, size: 16, color: color, seed: 11);
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
