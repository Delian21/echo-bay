import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../core/attachments/attachment_media_view.dart';
import '../../../core/auth/local_identity.dart';
import '../../../core/chat/message_edit.dart';
import '../../../core/design_system/tear_out_confirm.dart';
import '../../../core/atmosphere/atmosphere_controller.dart';
import '../../../core/design_system/chat_bubble_layout.dart';
import '../../../core/design_system/chat_reply_widgets.dart';
import '../../../core/design_system/ink_chat_composer.dart';
import '../../../core/design_system/message_menu.dart';
import '../../../core/design_system/message_reactions.dart';
import '../../../core/design_system/reaction_pills.dart';
import '../../../core/design_system/swipe_to_reply.dart';
import '../../../core/design_system/loading_skeletons.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/error/failures.dart';
import '../../../core/attachments/post_navigation.dart';
import '../../../core/motion/motion_scope.dart';
import '../../../core/motion/rewind_scope.dart';
import '../../../core/settings/draft_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../injection.dart';
import '../../calls/data/repositories/mock_calls_repository.dart';
import '../../calls/domain/repositories/calls_repository.dart';
import '../../calls/ui/calls_module_view.dart' show placeCallToPeer;
import '../../keepsake/domain/repositories/keepsake_repository.dart';
import '../data/repositories/mock_chat_repository.dart';
import '../domain/entities/message.dart';
import '../domain/entities/reaction.dart';
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

  /// The message being quoted by the draft in the composer, if any.
  Message? _replyTo;

  /// Briefly tints the bubble a jump-to-original landed on.
  String? _highlightedId;
  Timer? _highlightTimer;

  /// One key per rendered row, so a quoted block can ask the list to
  /// bring its original into view. Created lazily and never rebuilt.
  final Map<String, GlobalKey> _rowKeys = {};

  /// "Rune is writing…" — driven by the repository's typing stream when
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

  /// Same contract as [_messages]: one subscription for the page, fed by
  /// a single join over the conversation, not one watcher per bubble.
  late final Stream<Either<Failure, List<Reaction>>> _reactions = widget
      .repository
      .watchConversationReactions(conversationId: widget.conversation.id);

  GlobalKey _rowKey(String id) =>
      _rowKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'msg-$id'));

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
    _highlightTimer?.cancel();
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
    // Atmosphere: soft pen scratch as the note is sent (opt-in,
    // fire-and-forget — a missing sound never blocks a message).
    try {
      unawaited(
          sl<AtmosphereController>().play(AtmosphereSound.penScratch));
    } on Object {
      // DI unavailable (tests): silence is fine.
    }
    final replyToId = _replyTo?.id;
    if (replyToId != null) setState(() => _replyTo = null);
    final result = await widget.repository.sendMessage(
      conversationId: widget.conversation.id,
      body: body,
      replyToMessageId: replyToId,
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
    final replyToId = _replyTo?.id;
    if (replyToId != null) setState(() => _replyTo = null);
    final result = await widget.repository.sendMessage(
      conversationId: widget.conversation.id,
      body: body,
      attachment: attachment,
      replyToMessageId: replyToId,
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
      // One intent at a time: rewriting a message is not also a reply.
      _replyTo = null;
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
  /// at the rewind's midpoint; reduced motion undoes instantly. Nobody
  /// loses a message to a mis-tap: the confirmation comes first.
  Future<void> _confirmDelete(Message message) async {
    final confirmed = await confirmTearOut(
      context,
      title: 'Tear out this message?',
      message: 'It stays in the conversation as a deleted line, but the '
          'words are gone for good.',
    );
    if (!confirmed || !mounted) return;
    RewindScope.rewind(context, () => _delete(message.id));
  }

  Future<void> _react(String messageId, [String reaction = 'heart']) async {
    await widget.repository.toggleReaction(
      messageId: messageId,
      reaction: reaction,
    );
  }

  void _startReply(Message m) {
    setState(() {
      _editingMessageId = null;
      _replyTo = m;
    });
  }

  /// Bring the quoted message into view and flash it. The row may not be
  /// rendered (far-off history), in which case the tap is simply inert
  /// rather than scrolling somewhere wrong.
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

  static Message? _findMessage(List<Message> messages, String? id) {
    if (id == null) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Pin a message to the keepsake wall. The wall stores the reference;
  /// the board card resolves it at render time (and shows a graceful
  /// faded card if the message is later deleted-for-everyone).
  Future<void> _pinToWall(Message m) async {
    // Every failure path reports: a silently swallowed pin looks exactly
    // like a lost keepsake on the wall.
    void reportPinFailure([String? message]) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ??
              "Couldn't pin that one — the wall is out of thumbtacks. "
              'Try again?'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      final wall = sl.isRegistered<KeepsakeRepository>()
          ? sl<KeepsakeRepository>()
          : null;
      if (wall == null) {
        reportPinFailure('Pinning is unavailable right now.');
        return;
      }
      final result = await wall.pinMessage(
        messageId: m.id,
        posX: 0.1 + math.Random().nextDouble() * 0.5,
        posY: 0.1 + math.Random().nextDouble() * 0.5,
      );
      if (!mounted) return;
      result.fold(
        (failure) => reportPinFailure(failure.message),
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pinned to the keepsake wall.'),
            behavior: SnackBarBehavior.floating,
          ),
        ),
      );
    } on Object {
      // DI absent (tests) or the write threw — say so either way.
      reportPinFailure();
    }
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
                style: kHandwrittenTextStyle.copyWith(
                  fontSize: 17,
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
                    return StreamBuilder<Either<Failure, List<Reaction>>>(
                      stream: _reactions,
                      builder: (context, reactionSnapshot) {
                        final reactions = reactionSnapshot.data?.fold(
                              (_) => const <Reaction>[],
                              (rows) => rows,
                            ) ??
                            const <Reaction>[];
                        // Grouped once per emission rather than per bubble:
                        // a long conversation stays O(messages + reactions).
                        final byMessage = <String, List<Reaction>>{};
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
                        final mine = LocalIdentity.owns(m.senderId);
                        final prev = index > 0 ? messages[index - 1] : null;
                        final next = index + 1 < messages.length
                            ? messages[index + 1]
                            : null;
                        // Run boundaries drive the spacing, the timestamp and
                        // the bubble's tail corner; a day change drops a
                        // separator above the first message of the day.
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
                        final quoted =
                            _findMessage(messages, m.replyToMessageId);
                        return Column(
                          key: _rowKey(m.id),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (prev == null ||
                                !isSameChatDay(prev.createdAt, m.createdAt))
                              ChatDaySeparator(
                                  label: chatDayLabel(m.createdAt)),
                            _MessageBubble(
                              message: m,
                              mine: mine,
                              opensRun: opensRun,
                              closesRun: closesRun,
                              peerName: widget.conversation.title,
                              quoted: quoted,
                              highlighted: _highlightedId == m.id,
                              pills: summarizeReactions(
                                (byMessage[m.id] ?? const <Reaction>[])
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
                              onReact: (reaction) => _react(m.id, reaction),
                              // The menu offers Edit only inside the
                              // window; the repository enforces the same
                              // rule, so a stale menu cannot slip past.
                              onEdit: mine &&
                                      !m.isDeleted &&
                                      withinMessageEditWindow(m.createdAt)
                                  ? (id) => _beginEdit(id, m.body)
                                  : null,
                              onDelete: mine && !m.isDeleted
                                  ? () => _confirmDelete(m)
                                  : null,
                              onPinToWall:
                                  m.isDeleted ? null : () => _pinToWall(m),
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
          // "Rune is writing…" — sits above the composer like a real
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
                            'is writing…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
          if (_replyTo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: ReplyBanner(
                senderName: _replyTo!.isMine
                    ? 'You'
                    : widget.conversation.title,
                text: replyExcerpt(
                    _replyTo!.body, _replyTo!.attachment),
                onCancel: () => setState(() => _replyTo = null),
              ),
            ),
          InkChatComposer(
            controller: _composer,
            enabled: !_sending,
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
    required this.mine,
    required this.opensRun,
    required this.closesRun,
    required this.peerName,
    required this.pills,
    required this.onReply,
    this.quoted,
    this.highlighted = false,
    this.onJumpToOriginal,
    this.onEdit,
    this.onDelete,
    this.onReact,
    this.onPinToWall,
  });

  final Message message;
  final bool mine;

  /// First message of this sender's run: opens with a breath of space.
  final bool opensRun;

  /// Last message of the run: carries the timestamp and the tail corner.
  final bool closesRun;

  /// Who "they" are, for quoting their messages back.
  final String peerName;

  /// The message this one quotes, resolved from the loaded page. Null when
  /// the id points at something purged or not loaded yet.
  final Message? quoted;

  /// Tint the bubble for a moment after a jump landed on it.
  final bool highlighted;
  final VoidCallback? onJumpToOriginal;
  final List<ReactionPillData> pills;
  final VoidCallback onReply;
  final ValueChanged<String>? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onReact;

  /// Pin this message to the keepsake wall; null hides the action.
  final VoidCallback? onPinToWall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = this.mine;
    final bodyColor = chatBubbleForeground(context, isMine: mine);
    final metaColor = chatBubbleMetaForeground(context, isMine: mine);

    final bubbleContent = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.replyToMessageId != null) ...[
            QuotedMessageBlock(
              senderName: quoted == null
                  ? 'Message'
                  : (quoted!.isMine ? 'You' : peerName),
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
          if (message.attachment != null) ...[
            AttachmentMediaView(
              attachment: message.attachment!,
              seed: message.id.hashCode & 0x7FFFFFFF,
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
          // Only the last message of a run carries the meta line, so a
          // burst does not repeat the same clock under every bubble.
          if (closesRun) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _clock(message.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: metaColor,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  _StatusTick(status: message.status, onAccent: true),
                ],
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
              ],
            ),
          ],
        ],
      );

    final Widget bubble = ChatBubbleFrame(
      isMine: mine,
      closesRun: closesRun,
      child: bubbleContent,
    );

    // Tombstone: delete-for-everyone renders the placeholder, never the
    // body (which the store blanks anyway). The copy is the app's own
    // — this is a rewind, not a WhatsApp delete — and the mark is the
    // rewind spiral rather than a block sign.
    // Spacing rule: a message that opens a sender's run sits 10px below
    // whoever spoke before it; messages inside the run stack at 2px so a
    // burst reads as one block and a speaker change reads as a breath.
    Widget withRunGap(Widget child) => Padding(
          padding: EdgeInsets.only(
            top: opensRun ? kChatRunGap : kChatRunTightGap,
          ),
          child: child,
        );

    // Tombstone: a deleted message keeps its row (and its place in the
    // conversation, and any reply that points at it) but says only this.
    if (message.isDeleted) {
      return withRunGap(Align(
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
      ));
    }

    // Swipe toward the middle of the screen quotes the bubble; the
    // long-press menu offers the same Reply for anyone who never finds
    // the gesture.
    final interactive = SwipeToReply(
      isMine: mine,
      onReply: onReply,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        onDoubleTap: onReact == null ? null : () => onReact!('heart'),
        child: Semantics(
          button: true,
          label: mine ? 'Your message' : 'Message from $peerName',
          child: BubbleWithReactions(
            bubble: bubble,
            pills: pills,
            isMine: mine,
            onPillTap: (reaction) => onReact?.call(reaction),
          ),
        ),
      ),
    );

    return withRunGap(Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
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
    ));
  }

  Future<void> _showActions(BuildContext context) async {
    final result = await showMessageMenu(
      context,
      canReply: true,
      canEdit: mine && onEdit != null,
      canPin: onPinToWall != null,
      canDelete: mine && onDelete != null,
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
        onEdit?.call(message.id);
      case MessageMenuAction.delete:
        onDelete?.call();
      case MessageMenuAction.pin:
        onPinToWall?.call();
      case null:
        break;
    }
  }

  String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

class _StatusTick extends StatefulWidget {
  const _StatusTick({required this.status, this.onAccent = false});

  final DeliveryStatus status;

  /// True when the tick sits on the filled accent bubble — the status
  /// colors have to come from `onPrimary` there or they vanish.
  final bool onAccent;

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
    final scheme = theme.colorScheme;
    final useInk = GoldenHourExtension.of(context).enabled;
    // Ticks only ever sit on my own bubble, which is now filled with the
    // accent — so their colors come from onPrimary when that is the case.
    final idle =
        widget.onAccent ? scheme.onPrimary : scheme.onPrimaryContainer;
    final read = widget.onAccent ? scheme.onPrimary : scheme.primary;
    final failed = widget.onAccent ? scheme.onPrimary : scheme.error;
    if (!useInk) {
      switch (widget.status) {
        case DeliveryStatus.pending:
          return Icon(Icons.schedule_rounded, size: 15, color: idle);
        case DeliveryStatus.sent:
          return Icon(Icons.done_rounded, size: 16, color: idle);
        case DeliveryStatus.delivered:
          return Icon(Icons.done_all_rounded, size: 16, color: idle);
        case DeliveryStatus.read:
          return Icon(Icons.done_all_rounded, size: 16, color: read);
        case DeliveryStatus.failed:
          return Icon(Icons.error_outline_rounded, size: 16, color: failed);
      }
    }
    final color = switch (widget.status) {
      DeliveryStatus.pending ||
      DeliveryStatus.sent ||
      DeliveryStatus.delivered =>
        idle,
      DeliveryStatus.read => read,
      DeliveryStatus.failed => failed,
    };
    final kind = switch (widget.status) {
      DeliveryStatus.pending => SketchIconKind.clockTick,
      DeliveryStatus.sent => SketchIconKind.singleTick,
      DeliveryStatus.delivered => SketchIconKind.doubleTick,
      DeliveryStatus.read => SketchIconKind.doubleTick,
      DeliveryStatus.failed => SketchIconKind.xHeart,
    };

    // 16px: at 14 the chalk tick read as debris beside the timestamp.
    final tick = SketchIcon(kind: kind, size: 16, color: color, seed: 11);

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

