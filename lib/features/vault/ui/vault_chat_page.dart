import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../core/attachments/attachment_media_view.dart';
import '../../../core/design_system/ink_chat_composer.dart';
import '../../../core/design_system/loading_skeletons.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/error/failures.dart';
import '../../../core/motion/motion_scope.dart';
import '../../../core/motion/rewind_scope.dart';
import '../../../core/settings/draft_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../injection.dart';
import '../../calls/data/repositories/mock_calls_repository.dart';
import '../../calls/domain/repositories/calls_repository.dart';
import '../../calls/ui/calls_module_view.dart' show placeCallToPeer;
import '../data/repositories/mock_chat_repository.dart';
import '../domain/entities/message.dart';
import '../domain/repositories/chat_repository.dart';

/// The Vault — chat page. Renders the live [ChatRepository.watchMessages]
/// stream; sending goes through [ChatRepository.sendMessage] which
/// persists locally first (pending) and simulates delivery (sent).
class VaultChatPage extends StatefulWidget {
  const VaultChatPage({
    super.key,
    required this.repository,
    required this.conversation,
  });

  final ChatRepository repository;
  final Conversation conversation;

  @override
  State<VaultChatPage> createState() => _VaultChatPageState();
}

class _VaultChatPageState extends State<VaultChatPage> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _editingMessageId;

  /// "Rune is typing…" — driven by the repository's typing stream when
  /// it provides one (the mock does; a real transport would push typing
  /// receipts over the wire).
  StreamSubscription<(String, bool)>? _typingSub;
  bool _peerTyping = false;

  /// Created once — the StreamBuilder must not re-subscribe on rebuild.
  /// watchMessages() returns a fresh stream per call, so rebuilding with
  /// a new one (e.g. the typing-indicator setState) resets the snapshot
  /// to waiting and flashes the whole chat to a skeleton.
  late final Stream<Either<Failure, List<Message>>> _messages =
      widget.repository.watchMessages(conversationId: widget.conversation.id);

  @override
  void initState() {
    super.initState();
    // Draft autosave: one listener for the page's lifetime — the
    // controller has no onChanged of its own.
    _composer.addListener(() => _onDraftChanged(_composer.text));
    final mock = widget.repository;
    if (mock is MockChatRepository) {
      _typingSub = mock.watchTyping.listen((event) {
        final (conversationId, typing) = event;
        if (!mounted) return;
        if (conversationId != widget.conversation.id) return;
        setState(() => _peerTyping = typing);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  /// Draft autosave, keyed per conversation. Restored on open (first
  /// stream emission), saved debounced on change, cleared on send. The
  /// draft lives in the settings KV table — invisible to search,
  /// notifications, and time travel by construction.
  DraftDebouncer? _draftSave;
  bool _draftRestored = false;

  String get _draftKey => DraftStore.vault(widget.conversation.id);

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

  @override
  void dispose() {
    // Leave without sending: flush the last state (the debounced save
    // may still be inside its window).
    final save = _draftSave;
    if (save != null) {
      save.dispose();
      if (sl.isRegistered<DraftStore>()) {
        sl<DraftStore>().write(_draftKey, _composer.text);
      }
    }
    _typingSub?.cancel();
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
    final result = await widget.repository.sendMessage(
      conversationId: widget.conversation.id,
      body: body,
    );
    _finishSend(result);
  }

  /// Send with an attachment (text optional — a photo alone is a
  /// message). Bubbles carry the media; the repo copies the file into
  /// the attachments dir before persisting.
  Future<void> _sendWithAttachment(MessageAttachment attachment) async {
    if (_sending) return;
    _sending = true;
    final body = _composer.text.trim();
    _composer.clear();
    unawaited(_clearDraft());
    final result = await widget.repository.sendMessage(
      conversationId: widget.conversation.id,
      body: body,
      attachment: attachment,
    );
    _finishSend(result);
  }

  void _finishSend(Either<Failure, Message> result) {
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

  void _beginEdit(String messageId, String currentBody) {
    setState(() {
      _editingMessageId = messageId;
      _composer.text = currentBody;
    });
  }

  Future<void> _commitEdit() async {
    final id = _editingMessageId;
    final body = _composer.text.trim();
    if (id == null || body.isEmpty) return;
    setState(() {
      _editingMessageId = null;
      _composer.clear();
    });
    await widget.repository.editMessage(messageId: id, newBody: body);
  }

  Future<void> _delete(String messageId) async {
    await widget.repository.deleteMessage(messageId: messageId);
  }

  /// Unsend via the signature rewind effect — deleting for everyone is
  /// the Vault's own "take it back" moment. The tombstone write fires
  /// at the rewind's midpoint; reduced motion undoes instantly.
  void _rewindDelete(String messageId) {
    RewindScope.rewind(context, () => _delete(messageId));
  }

  Future<void> _react(String messageId) async {
    await widget.repository.toggleReaction(
      messageId: messageId,
      reaction: 'heart',
    );
  }

  /// Landline mock call flow, launched from the conversation header.
  /// The chat repository seam doesn't know calls, so the calls repository
  /// is resolved through DI (registered with the shell's mock stack).
  void _placeCall({required bool video}) {
    final CallsRepository calls = sl.isRegistered<CallsRepository>()
        ? sl<CallsRepository>()
        : MockCallsRepository();
    placeCallToPeer(
      context,
      repository: calls,
      peerName: widget.conversation.title,
      peerAvatarUrl: '',
      video: video,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Opening the conversation is the read signal (WhatsApp model): the
    // peer's delivered messages flip to read through the sync machinery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.repository.markConversationRead(
          conversationId: widget.conversation.id);
    });
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                widget.conversation.title
                    .split(' ')
                    .where((w) => w.isNotEmpty)
                    .map((w) => w[0].toUpperCase())
                    .take(2)
                    .join(),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Row(
                    children: [
                      SketchIcon(
                        kind: SketchIconKind.padlock,
                        size: 12,
                        color: theme.colorScheme.primary,
                        seed: 75,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Private · local-first',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Call actions live in the conversation (the convention the
            // Landline-as-island was missing): voice and video, both
            // chalk glyphs. They launch the Landline's shared mock call
            // flow and land in its log — calls belong to the person
            // you're talking to.
            IconButton(
              tooltip: 'Voice call',
              icon: SketchGlyph(
                kind: SketchIconKind.handset,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _placeCall(video: false),
            ),
            IconButton(
              tooltip: 'Video call',
              icon: SketchGlyph(
                kind: SketchIconKind.videoCam,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _placeCall(video: true),
            ),
          ],
        ),
      ),
      body: RewindScope(
        child: Column(
        children: [
          Expanded(
            child: StreamBuilder<Either<Failure, List<Message>>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ChatSkeleton();
                }
                final either = snapshot.data;
                if (either == null) {
                  return const Center(
                    child: Text('Message stream unavailable.'),
                  );
                }
                return either.fold(
                  (failure) => Center(
                    child: Text(failure.message ?? 'Vault unavailable.'),
                  ),
                  (messages) {
                    // Keep the newest message in view as it arrives.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients) {
                        _scroll.jumpTo(
                            _scroll.position.maxScrollExtent);
                      }
                    });
                    if (messages.isEmpty) {
                      return const _ChatEmptyState();
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        return _MessageBubble(
                          message: m,
                          showTail: index == 0 ||
                              messages[index - 1].senderId != m.senderId,
                          onEdit: m.isMine && !m.isDeleted
                              ? (id) => _beginEdit(id, m.body)
                              : null,
                          onDelete: m.isMine && !m.isDeleted
                              ? () => _rewindDelete(m.id)
                              : null,
                          onReact: () => _react(m.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // "Rune is typing…" — sits above the composer like a real
          // messenger; vanishes when the reply lands.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _peerTyping
                ? Align(
                    key: const ValueKey('typing'),
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                      child: Text(
                        '${widget.conversation.title.split(' ').first} '
                            'is typing…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
          InkChatComposer(
            controller: _composer,
            enabled: !_sending,
            seed: widget.conversation.id.hashCode & 0x7FFFFFFF,
            onSendWithAttachment: _editingMessageId == null
                ? _sendWithAttachment
                : null,
            onSendText: _editingMessageId == null ? _send : _commitEdit,
            editing: _editingMessageId != null,
            onCancelEdit: _editingMessageId == null
                ? null
                : () => setState(() => _editingMessageId = null),
          ),
        ],
        ),
      ),
    );
  }
}

// -- bubbles ------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showTail,
    this.onEdit,
    this.onDelete,
    this.onReact,
  });

  final Message message;
  final bool showTail;
  final ValueChanged<String>? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.isMine;
    // Restrained ink (spec §4): the Vault gets the wobbly border stroke
    // but no scribble fills, no paper — a notebook that takes secrets
    // seriously. Gate on the analog layer.
    final useInk = GoldenHourExtension.of(context).enabled;

    final bubbleContent = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.attachment != null) ...[
            AttachmentMediaView(
              attachment: message.attachment!,
              seed: message.id.hashCode & 0x7FFFFFFF,
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
                _clock(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: (mine
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant)
                      .withValues(alpha: 0.7),
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                _StatusTick(status: message.status),
              ],
              if (message.isEdited) ...[
                const SizedBox(width: 4),
                Text(
                  'edited',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: (mine
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant)
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ],
      );

    // Ink mode: wobbly notebook box instead of the smooth container.
    final Widget bubble = useInk
        ? Container(
            margin: EdgeInsets.only(
              top: 3,
              bottom: 3,
              left: mine ? 56 : 0,
              right: mine ? 0 : 56,
            ),
            child: SketchBox(
              seed: message.id.hashCode & 0x7FFFFFFF,
              radius: 6,
              strokeWidth: 2,
              color: SketchInk.of(context),
              fill: mine
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: bubbleContent,
            ),
          )
        : Container(
            margin: EdgeInsets.only(
              top: 3,
              bottom: 3,
              left: mine ? 56 : 0,
              right: mine ? 0 : 56,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: mine
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(mine || !showTail ? 16 : 4),
                topRight: Radius.circular(mine && showTail ? 4 : 16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
            ),
            child: bubbleContent,
          );

    // Tombstone: delete-for-everyone renders the placeholder, never the
    // body (which the store blanks anyway) — Telegram/WhatsApp pattern.
    if (message.isDeleted) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            top: 3,
            bottom: 3,
            left: mine ? 56 : 0,
            right: mine ? 0 : 56,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded,
                  size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                mine ? 'You deleted this message' : 'Message deleted',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final actionable = mine && onEdit != null && !message.isDeleted;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: actionable ? () => _showActions(context) : null,
        onDoubleTap: message.isDeleted ? null : onReact,
        child: bubble,
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit message'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: Text('Delete for everyone',
                  style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.error)),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') onEdit?.call(message.id);
    if (action == 'delete') onDelete?.call();
  }

  String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

class _StatusTick extends StatefulWidget {
  const _StatusTick({required this.status});

  final DeliveryStatus status;

  @override
  State<_StatusTick> createState() => _StatusTickState();
}

class _StatusTickState extends State<_StatusTick> {
  @override
  void didUpdateWidget(_StatusTick old) {
    super.didUpdateWidget(old);
    // The read moment: the tick just flipped delivered → read. One light
    // haptic tick — felt, not heard. Fires only on the transition, never
    // on ordinary rebuilds (the read state re-emits with every stream
    // snapshot).
    if (old.status != DeliveryStatus.read &&
        widget.status == DeliveryStatus.read) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useInk = GoldenHourExtension.of(context).enabled;
    if (!useInk) {
      switch (widget.status) {
        case DeliveryStatus.pending:
          return Icon(Icons.schedule_rounded,
              size: 13,
              color:
                  theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7));
        case DeliveryStatus.sent:
          return Icon(Icons.done_rounded,
              size: 14,
              color:
                  theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9));
        case DeliveryStatus.delivered:
          return Icon(Icons.done_all_rounded,
              size: 14,
              color:
                  theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9));
        case DeliveryStatus.read:
          return Icon(Icons.done_all_rounded,
              size: 14, color: theme.colorScheme.primary);
        case DeliveryStatus.failed:
          return Icon(Icons.error_outline_rounded,
              size: 14, color: theme.colorScheme.error);
      }
    }
    final color = switch (widget.status) {
      DeliveryStatus.pending ||
      DeliveryStatus.sent ||
      DeliveryStatus.delivered =>
        theme.colorScheme.onPrimaryContainer,
      DeliveryStatus.read => theme.colorScheme.primary,
      DeliveryStatus.failed => theme.colorScheme.error,
    };
    final kind = switch (widget.status) {
      DeliveryStatus.pending => SketchIconKind.clockTick,
      DeliveryStatus.sent => SketchIconKind.singleTick,
      DeliveryStatus.delivered => SketchIconKind.doubleTick,
      DeliveryStatus.read => SketchIconKind.doubleTick,
      DeliveryStatus.failed => SketchIconKind.xHeart,
    };

    final tick = SketchIcon(kind: kind, size: 14, color: color, seed: 11);

    // The read flip plays once per transition (TweenAnimationBuilder
    // re-animates only when its end value changes): a sketchy pen-press
    // — overshoot scale with a small rock, settling into the accent
    // color. Reduced motion: straight to 1.
    final reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;
    if (widget.status != DeliveryStatus.read) return tick;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0.4, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 340),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.rotate(
        angle: (1 - t) * -0.35,
        child: Transform.scale(scale: t, child: child),
      ),
      child: tick,
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SketchIcon(
            kind: SketchIconKind.padlock,
            size: 44,
            color: theme.colorScheme.onSurfaceVariant,
            seed: 77,
          ),
          const SizedBox(height: 12),
          Text(
            'Stays on this device.\nSay something first.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

