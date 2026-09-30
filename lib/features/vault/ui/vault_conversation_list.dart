import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../core/design_system/breakpoints.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/design_system/loading_skeletons.dart';
import '../../../core/design_system/staggered_entrance.dart';
import '../../../core/error/failures.dart';
import '../../../core/motion/motion_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/entities/message.dart';
import '../domain/repositories/chat_repository.dart';
import 'vault_chat_page.dart';

/// The Vault — conversation list. Consumes the mock [ChatRepository]
/// stream directly (StreamBuilder, slice-simple); a bloc replaces this at
/// integration without touching the widgets below.
///
/// Master-detail: when [embedded] (desktop shell, wide window) the list
/// renders as a side pane with the chat pane next to it; on narrow
/// screens tapping a tile pushes [VaultChatPage] full-screen instead.
class VaultConversationList extends StatefulWidget {
  const VaultConversationList({
    super.key,
    required this.repository,
    this.embedded = false,
    this.deepLinkConversationId,
  });

  final ChatRepository repository;

  /// Wide-shell mode: master-detail panes inside the rail body.
  final bool embedded;

  /// Deep-link entry (#8): the conversation the user tapped through to
  /// (notification payload or search hit). Preselected on first match.
  final String? deepLinkConversationId;

  @override
  State<VaultConversationList> createState() => _VaultConversationListState();
}

class _VaultConversationListState extends State<VaultConversationList> {
  Conversation? _selected;
  bool _deepLinkHandled = false;

  /// Created once — re-subscribing on every rebuild (e.g. after the
  /// setState in master-detail selection) would reset the StreamBuilder
  /// to waiting and flash the empty state.
  late final Stream<Either<Failure, List<Conversation>>> _conversations =
      widget.repository.watchConversations();

  /// Whether the chat pane renders beside the list (true master-detail)
  /// or taps push [VaultChatPage] full-screen. Embedded is necessary but
  /// not sufficient: a narrow window in the wide shell (small desktop
  /// window, split view) must degrade to full-page list + push, or the
  /// detail pane becomes an unusable sliver. Mirrors the shell's 600 px
  /// breakpoint.
  bool get _masterDetail =>
      widget.embedded && MediaQuery.sizeOf(context).width >= AppBreakpoints.wide;

  void _openConversation(BuildContext context, Conversation c) {
    if (!_masterDetail) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => VaultChatPage(
          repository: widget.repository,
          conversation: c,
        ),
      ));
      return;
    }
    setState(() => _selected = c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Vault'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'New conversation',
            icon: const SketchGlyph(kind: SketchIconKind.plusBubble),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<Either<Failure, List<Conversation>>>(
        stream: _conversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TileListSkeleton();
          }
          final either = snapshot.data;
          if (either == null) {
            return const _VaultEmptyState(
              icon: Icons.wifi_off_rounded,
              message: 'Stream dropped. Reconnect to reload.',
            );
          }
          return either.fold(
            (failure) => _VaultEmptyState(
              icon: Icons.lock_outline_rounded,
              message: failure.message ?? 'Vault unavailable.',
            ),
            (List<Conversation> conversations) {
              // Deep-link resolution (#8): fire once, when the target
              // conversation exists in the stream.
              final targetId = widget.deepLinkConversationId;
              if (targetId != null && !_deepLinkHandled) {
                for (final c in conversations) {
                  if (c.id == targetId) {
                    _deepLinkHandled = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _openConversation(context, c);
                    });
                    break;
                  }
                }
              }
              if (conversations.isEmpty) {
                return const _VaultEmptyState(
                  icon: Icons.forum_outlined,
                  message: 'No conversations yet.',
                );
              }

              final listPane = _ConversationListPane(
                repository: widget.repository,
                conversations: conversations,
                selectedId: _selected?.id,
                onSelect: (c) => _openConversation(context, c),
              );

              if (!widget.embedded || !_masterDetail) return listPane;

              // Master-detail: list pane + chat pane side by side,
              // Telegram proportions — the list stays roughly a third of
              // the shell body, the open chat owns the rest. Fixed 320 px
              // starved the chat pane on scaled desktop windows (the
              // "squished Vault" bug): the list now scales with the
              // window, clamped so it never dwarfs or vanishes.
              final listWidth =
                  (MediaQuery.sizeOf(context).width * 0.34)
                      .clamp(280.0, 420.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: listWidth,
                    child: listPane,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    // AnimatedSwitcher cross-fades the detail pane on
                    // selection change (empty state <-> chat, chat <->
                    // chat), replacing the old instant swap. Keyed on the
                    // conversation id so a re-select animates too.
                    // Reduced motion: duration zero = instant swap.
                    child: AnimatedSwitcher(
                      duration: MotionScope.maybeOf(context)?.reducedMotion ?? false
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: animation.drive(
                            Tween<Offset>(
                              begin: const Offset(0.02, 0),
                              end: Offset.zero,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: _selected == null
                          ? const _VaultEmptyState(
                              key: ValueKey('empty'),
                              icon: Icons.lock_outline_rounded,
                              message: 'Select a conversation.',
                            )
                          : VaultChatPage(
                              key: ValueKey(_selected!.id),
                              repository: widget.repository,
                              conversation: _selected!,
                            ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationListPane extends StatelessWidget {
  const _ConversationListPane({
    required this.repository,
    required this.conversations,
    required this.selectedId,
    required this.onSelect,
  });

  final ChatRepository repository;
  final List<Conversation> conversations;
  final String? selectedId;
  final ValueChanged<Conversation> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final c = conversations[index];
        return StaggeredEntrance(
          index: index,
          child: _ConversationTile(
            repository: repository,
            conversation: c,
            selected: c.id == selectedId,
            onTap: () => onSelect(c),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.repository,
    required this.conversation,
    required this.onTap,
    this.selected = false,
  });

  final ChatRepository repository;
  final Conversation conversation;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = conversation.title
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    // Bulletin-board ink (spec §4): same wobbly notebook box as the
    // Hallway's tiles, seeded from the conversation id so each tile is
    // its own drawing.
    final useInk = GoldenHourExtension.of(context).enabled;
    final seed = conversation.id.hashCode & 0x7FFFFFFF;

    final tileContent = Row(
              children: [
                // Lock-badge avatar — the Vault marks every conversation.
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        initials,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: SketchIcon(
                          kind: SketchIconKind.padlock,
                          size: 12,
                          color: theme.colorScheme.primary,
                          seed: 75,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Private · local-first · tap to open',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeLabel(conversation.lastActivityAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                _UnreadBadge(repository: repository, conversation: conversation),
              ],
            );

    final tile = Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: useInk
            ? SketchBox(
                seed: seed,
                radius: 8,
                strokeWidth: 2,
                doubleStroke: selected,
                color: selected
                    ? theme.colorScheme.primary
                    : SketchInk.of(context),
                padding: const EdgeInsets.all(12),
                child: tileContent,
              )
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.6)
                        : theme.colorScheme.outlineVariant
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

/// Unread count from the read cursor (#2 WhatsApp model): cursor-derived,
/// own writes excluded. Zero renders nothing — no badge, no pressure.
/// Refreshes on conversation-activity change (each new message emits).
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.repository, required this.conversation});

  final ChatRepository repository;
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Either<Failure, List<Message>>>(
      stream: repository.watchMessages(conversationId: conversation.id),
      builder: (context, _) {
        return FutureBuilder<Either<Failure, int>>(
          future: repository.unreadCount(conversationId: conversation.id),
          builder: (context, snap) {
            final count = snap.data?.fold((f) => 0, (v) => v) ?? 0;
            if (count <= 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VaultEmptyState extends StatelessWidget {
  const _VaultEmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
