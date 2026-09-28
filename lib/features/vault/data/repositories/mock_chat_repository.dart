import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fpdart/fpdart.dart';

import '../../../../core/io/platform_io.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/reaction.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/vault_local_datasource.dart';

/// Mock implementation of [ChatRepository].
///
/// Simulates a live secure-messaging backend:
///  - seeds conversations on first use;
///  - outgoing messages persist locally as [DeliveryStatus.pending], then
///    a timer chain walks them sent → delivered → read (simulated acks,
///    spaced by [deliveryDelay]);
///  - a [Stream.periodic] "server ticker" delivers inbound messages from a
///    peer into random conversations — exactly the path a real WebSocket
///    push would take (transport -> repository -> local store -> stream);
///  - edits and delete-for-everyone are local-first tombstone writes;
///  - all reads hit the local store. No message lives only in memory.
class MockChatRepository implements ChatRepository {
  MockChatRepository({
    required VaultLocalDatasource localDatasource,
    this.localUserId = 'local-user',
    Duration incomingMessageInterval = const Duration(seconds: 15),
    this.deliveryDelay = const Duration(milliseconds: 900),
    bool simulateDeliveryFailures = false,
    bool startTicker = true,
    bool peerReplies = true,
  })  : _local = localDatasource,
        _incomingMessageInterval = incomingMessageInterval,
        _simulateDeliveryFailures = simulateDeliveryFailures,
        _peerReplies = peerReplies {
    // Opt-in: the periodic inbound timer trips flutter_test's
    // pending-timer invariant (teardowns run after the check), so tests
    // disable it.
    if (startTicker) {
      _startTicker();
    }
  }

  final VaultLocalDatasource _local;

  /// The local session's opaque id, injected from the auth seam.
  final String localUserId;
  final Duration _incomingMessageInterval;
  final Duration deliveryDelay;
  final bool _simulateDeliveryFailures;

  /// Peer persona replies after a send (tests disable: the reply chain
  /// runs on multi-second timers that trip flutter_test's pending-timer
  /// invariant, same family as [startTicker]).
  final bool _peerReplies;
  final _uuid = const Uuid();
  final _random = Random(42); // deterministic for reproducible demos

  Timer? _ticker;

  /// In-flight simulated-delivery timers, tracked so [dispose] can cancel
  /// them. Without this, a message sent near teardown leaves a pending
  /// `Future.delayed` that trips flutter_test's timer invariant and hangs
  /// the test runner.
  final Set<Timer> _deliveryTimers = {};

  bool _seeded = false;
  int _tickCount = 0;

  static const _seedConversations = [
    (id: 'conv-1', title: 'Rune Virtanen', peer: 'peer-rune'),
    (id: 'conv-2', title: 'Signal Ops Team', peer: 'peer-ops'),
    (id: 'conv-3', title: 'Mila Kang', peer: 'peer-mila'),
  ];

  /// Peer personas — the Vault feels inhabited because replies are in
  /// character: each peer has a voice, vocabulary, and rhythm. Lines
  /// cover greetings, acknowledgements, questions, and filler so a
  /// reply is chosen by what you said and who you said it to.
  static const _personas = <String, _PeerPersona>{
    'peer-rune': _PeerPersona(
      typingSecondsPerWord: 0.9,
      replyDelayRange: (1.5, 4.0),
      greetings: [
        'yo',
        'hej — you caught me between things',
        'hey. was just thinking about this actually',
      ],
      acknowledgements: [
        'makes sense',
        'got it. that tracks.',
        'fair. noted.',
        'ok that is actually a good point',
      ],
      questions: [
        'how long has that been going on?',
        'did you check it offline first?',
        'which layer is that in — cache or wire?',
      ],
      filler: [
        'the north side of the city flooded again. whole block smelled like wet cable.',
        'i keep a paper notebook now. no battery, no sync, no lie.',
        'found a rolls of undeveloped film in a drawer. taking them in saturday.',
        'call me when you are off. voices beat typing for this stuff.',
      ],
    ),
    'peer-mila': _PeerPersona(
      typingSecondsPerWord: 0.6,
      replyDelayRange: (1.0, 3.0),
      greetings: [
        'hey hey!',
        'oh good, you are online',
        'hi! perfect timing',
      ],
      acknowledgements: [
        'yes!! exactly that',
        'ooooh okay now I get it',
        'love that. keep going',
        'same here honestly',
      ],
      questions: [
        'can I see a photo of it?',
        'when did you start noticing that?',
        'wait is this the thing you mentioned last week?',
      ],
      filler: [
        'the light through my window right now is unreal. very golden hour.',
        'started a sketchbook again. first page is terrible and I love it.',
        'made coffee, forgot to drink it, found it cold an hour later. a lifestyle.',
        'sending you a voice note later, too much for typing',
      ],
    ),
    'peer-ops': _PeerPersona(
      typingSecondsPerWord: 0.5,
      replyDelayRange: (2.0, 6.0),
      greetings: [
        'ack.',
        'ops channel synced.',
        'copy.',
      ],
      acknowledgements: [
        'logged.',
        'understood. no action needed on our side.',
        'confirmed. rotating keys anyway.',
      ],
      questions: [
        'state your current build id when convenient.',
        'is this reproducible or a one-off?',
        'do we need to schedule a window for this?',
      ],
      filler: [
        'weekly integrity sweep: all channels green. two stale cursors reaped.',
        'reminder: retention window on channel_posts is 30d. nothing personal, just hygiene.',
        'backup rotation completed. verify your local restore path once this month.',
      ],
    ),
  };

  _PeerPersona? _personaFor(String conversationId) {
    final conv = _seedConversations.firstWhereOrNull(
      (c) => c.id == conversationId,
    );
    return conv == null ? null : _personas[conv.peer];
  }

  String? _peerOf(String conversationId) {
    final conv = _seedConversations.firstWhereOrNull(
      (c) => c.id == conversationId,
    );
    return conv?.peer;
  }

  // -- ChatRepository -------------------------------------------------------

  @override
  Future<Either<Failure, Unit>> ensureSeeded() async {
    if (_seeded) return right(unit);
    final now = DateTime.now();
    for (final c in _seedConversations) {
      final existing = await _local.findConversation(c.id);
      if (existing == null) {
        await _local.insertConversation(ConversationsCompanion.insert(
          id: c.id,
          title: c.title,
          participantIds: encodeParticipants(
              [localUserId, c.peer]),
          lastActivityAt: now,
        ));
      }
    }
    _seeded = true;
    return right(unit);
  }

  @override
  Stream<Either<Failure, List<Conversation>>> watchConversations() async* {
    await ensureSeeded();
    yield* _local
        .watchConversations()
        .map((list) => Right<Failure, List<Conversation>>(list));
  }

  @override
  Stream<Either<Failure, List<Message>>> watchMessages(
      {required String conversationId}) async* {
    await ensureSeeded();
    yield* _local
        .watchMessages(conversationId: conversationId)
        .map((list) => Right<Failure, List<Message>>(list));
  }

  @override
  Future<Either<Failure, Message>> sendMessage({
    required String conversationId,
    required String body,
    MessageAttachment? attachment,
  }) async {
    try {
      final conversation = await _local.findConversation(conversationId);
      if (conversation == null) {
        return left(const NotFoundFailure(message: 'conversation not found'));
      }

      // Local-first attachments: copy the picked/recorded file into the
      // app's attachments directory before persisting, so the message
      // outlives the picker session's temp file.
      final stored = attachment == null ? null : await _storeAttachment(attachment);

      final message = Message(
        id: _uuid.v4(),
        conversationId: conversationId,
        senderId: localUserId,
        body: body,
        createdAt: DateTime.now(),
        status: DeliveryStatus.pending,
        attachment: stored,
      );

      // LOCAL-FIRST: persist before any transport attempt.
      await _local.insertMessage(MessagesCompanion.insert(
        id: message.id,
        conversationId: message.conversationId,
        senderId: message.senderId,
        body: message.body,
        ciphertext: const Value(null), // real E2EE fills this later
        syncStatus: MsgSyncStatus.pending,
        createdAt: message.createdAt,
        attachmentKind: Value(stored?.kind.name),
        attachmentPath: Value(stored?.path),
        attachmentDurationMs: Value(stored?.durationMs),
      ));
      await _touchConversation(conversationId, message.createdAt);

      // Simulated transport: pending → sent → delivered → read.
      _simulateLifecycle(message.id);

      // The peer answers — that is what makes the Vault feel inhabited.
      // Fires after the message reads (peer "saw" it), types for a
      // word-count-proportional stretch, then sends in character.
      if (_peerReplies) {
        _schedulePeerReply(conversationId, body);
      }

      return right(message);
    } catch (e) {
      return left(CacheFailure(message: 'sendMessage failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Message>> editMessage({
    required String messageId,
    required String newBody,
  }) async {
    try {
      final message = await _local.findMessage(messageId);
      if (message == null) {
        return left(const NotFoundFailure(message: 'message not found'));
      }
      if (message.senderId != localUserId) {
        return left(const UnauthorizedFailure(
            message: 'only your own messages can be edited'));
      }
      if (message.isDeleted) {
        return left(const ConflictFailure(
            message: 'cannot edit a deleted message'));
      }

      // LOCAL-FIRST tombstone write: body updated, editedAt stamped, then
      // synced by the transport (simulated here as an immediate ack).
      final editedAt = DateTime.now();
      await _local.updateMessageBody(
        messageId: messageId,
        body: newBody,
        editedAt: editedAt,
      );
      return right(message.copyWith(body: newBody, editedAt: editedAt));
    } catch (e) {
      return left(CacheFailure(message: 'editMessage failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteMessage({
    required String messageId,
  }) async {
    try {
      final message = await _local.findMessage(messageId);
      if (message == null) {
        return left(const NotFoundFailure(message: 'message not found'));
      }
      if (message.senderId != localUserId) {
        return left(const UnauthorizedFailure(
            message: 'only your own messages can be deleted'));
      }
      if (message.isDeleted) return right(unit); // idempotent

      await _local.markDeleted(
        messageId: messageId,
        deletedAt: DateTime.now(),
      );
      return right(unit);
    } catch (e) {
      return left(CacheFailure(message: 'deleteMessage failed', cause: e));
    }
  }

  // -- reactions + read state (v6) ------------------------------------------

  @override
  Stream<Either<Failure, List<Reaction>>> watchReactions(
      {required String messageId}) async* {
    // Re-fetch on every toggle: reactions live in their own table, so a
    // stream query needs a row there — a simple re-read on demand keeps
    // the mock honest without a watchable join.
    var last = <Reaction>[];
    while (true) {
      final rows = await _local.reactionsFor(messageId);
      final current = rows
          .map((r) => Reaction(
                id: r.id,
                messageId: r.messageId,
                userId: r.userId,
                reaction: r.reaction,
              ))
          .toList();
      if (current.toString() != last.toString()) {
        last = current;
        yield Right<Failure, List<Reaction>>(current);
      } else if (last.isEmpty) {
        yield Right<Failure, List<Reaction>>(current);
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleReaction({
    required String messageId,
    required String reaction,
  }) async {
    try {
      final message = await _local.findMessage(messageId);
      if (message == null) {
        return left(const NotFoundFailure(message: 'message not found'));
      }
      final nowActive = await _local.toggleReaction(
        messageId: messageId,
        userId: localUserId,
        reaction: reaction,
      );
      return right(nowActive);
    } catch (e) {
      return left(CacheFailure(message: 'toggleReaction failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> markConversationRead(
      {required String conversationId}) async {
    try {
      // Cursor lands on the newest message in the conversation.
      final messages = await _local.watchMessages(conversationId: conversationId).first;
      if (messages.isEmpty) return right(unit);
      final newest = messages.last;
      await _local.advanceReadCursor(
        conversationId: conversationId,
        userId: localUserId,
        messageId: newest.id,
        at: DateTime.now(),
      );
      // Discord's lesson in action: the peer's messages flip to "read"
      // through the same sync machinery, not a UI flag.
      for (final m in messages) {
        if (m.senderId != localUserId && m.status != DeliveryStatus.read) {
          await _local.updateStatus(
              messageId: m.id, status: DeliveryStatus.read);
        }
      }
      return right(unit);
    } catch (e) {
      return left(
          CacheFailure(message: 'markConversationRead failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, int>> unreadCount(
      {required String conversationId}) async {
    try {
      final count = await _local.unreadCount(
        conversationId: conversationId,
        userId: localUserId,
      );
      return right(count);
    } catch (e) {
      return left(CacheFailure(message: 'unreadCount failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> syncOutbox() async {
    try {
      final pending = await _local.pendingMessages();
      for (final m in pending) {
        await _local.updateStatus(
            messageId: m.id, status: DeliveryStatus.sent);
        _simulateLifecycle(m.id);
      }
      // Reactions flush through the same outbox discipline.
      final pendingReactions = await _local.pendingReactions();
      if (pendingReactions.isNotEmpty) {
        await _local.markReactionsSynced(
            pendingReactions.map((r) => r.id).toList());
      }
      return right(unit);
    } catch (e) {
      return left(CacheFailure(message: 'syncOutbox failed', cause: e));
    }
  }

  // -- Inhabited peers -------------------------------------------------------

  /// In-flight reply timers, cancelled on dispose like the delivery
  /// chain. Without this, a sent message near teardown hangs tests.
  final Set<Timer> _replyTimers = {};

  /// Typing indicator seam: the UI watches this stream to show "Rune is
  /// typing…". Emits (conversationId, true/false). Kept as a broadcast
  /// stream so any open chat page can listen.
  final _typingController =
      StreamController<(String, bool)>.broadcast();
  Stream<(String, bool)> get watchTyping => _typingController.stream;

  void _schedulePeerReply(String conversationId, String incomingBody) {
    final persona = _personaFor(conversationId);
    final peer = _peerOf(conversationId);
    if (persona == null || peer == null) return;

    // 1) The peer reads your message after the delivery chain lands.
    late final Timer readTimer;
    readTimer = Timer(deliveryDelay * 3 + const Duration(milliseconds: 400), () {
      _replyTimers.remove(readTimer);
      if (!_online) return;

      // 2) Typing… for as long as the reply would take to write, capped
      // — a long filler line shouldn't pin the indicator for 13s.
      final reply = persona.pickReply(incomingBody, _random);
      final typingMs = (
              reply.split(' ').length * persona.typingSecondsPerWord)
          .clamp(0.8, 4.0) * 1000;
      _typingController.add((conversationId, true));

      late final Timer sendTimer;
      sendTimer = Timer(
        Duration(milliseconds: typingMs.round()),
      () {
          _replyTimers.remove(sendTimer);
          _typingController.add((conversationId, false));
          if (!_online) return;
          _deliverPeerMessage(conversationId, peer, reply);
        },
      );
      _replyTimers.add(sendTimer);
    });
    _replyTimers.add(readTimer);
  }

  /// Copy an attachment's source file into the app support directory
  /// (`attachments/<uuid>.<ext>`). Returns the stored form pointing at
  /// the durable copy. Missing source files fail the send (local-first:
  /// better to error than persist a dead path). On the web the IO seam
  /// no-ops the copy and returns a session-only path — the message and
  /// its metadata still persist through the database.
  Future<MessageAttachment> _storeAttachment(MessageAttachment a) async {
    if (!await fileExists(a.path)) {
      throw StateError('attachment source missing: ${a.path}');
    }
    final dirPath = await _attachmentsDir();
    final ext = a.path.contains('.') ? a.path.split('.').last : 'bin';
    final dest = joinPath(dirPath, '${_uuid.v4()}.$ext');
    await fileCopy(a.path, dest);
    return MessageAttachment(
      kind: a.kind,
      path: dest,
      durationMs: a.durationMs,
    );
  }

  Future<String> _attachmentsDir() async {
    // No path_provider dependency in the mock stack: store in a
    // `.attachments` folder under the working directory (desktop mock
    // stage; the real transport swaps in path_provider later).
    return dirEnsure(joinPath(currentDirPath, '.attachments'));
  }

  Future<void> _deliverPeerMessage(
    String conversationId,
    String peer,
    String body,
  ) async {
    try {
      final now = DateTime.now();
      await _local.insertMessage(MessagesCompanion.insert(
        id: _uuid.v4(),
        conversationId: conversationId,
        senderId: peer,
        body: body,
        ciphertext: const Value(null),
        syncStatus: MsgSyncStatus.read,
        createdAt: now,
      ));
      await _touchConversation(conversationId, now);
    } on Object {
      // Simulation only.
    }
  }

  // -- Fake network simulation ----------------------------------------------

  bool _online = true;

  /// Toggle the simulated network. Offline: ticker stops and simulated
  /// deliveries fail, so messages pile up pending — the outbox path.
  void setOnline(bool online) {
    _online = online;
    online ? _startTicker() : _ticker?.cancel();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_incomingMessageInterval, (_) {
      _tickCount++;
      _deliverInbound();
    });
  }

  /// Walk one message through the full simulated lifecycle:
  /// pending → sent → delivered → read, one [deliveryDelay] apart. Each
  /// stage is a tracked timer so dispose() can cancel the whole chain.
  void _simulateLifecycle(String messageId) {
    void stage(Duration after, DeliveryStatus status) {
      late final Timer timer;
      timer = Timer(after, () {
        _deliveryTimers.remove(timer);
        _advanceStatus(messageId, status);
      });
      _deliveryTimers.add(timer);
    }

    if (_simulateDeliveryFailures && _random.nextDouble() < 0.25) {
      // Flaky network: the message dies at the first transport stage.
      stage(deliveryDelay, DeliveryStatus.failed);
      return;
    }
    stage(deliveryDelay, DeliveryStatus.sent);
    stage(deliveryDelay * 2, DeliveryStatus.delivered);
    stage(deliveryDelay * 3, DeliveryStatus.read);
  }

  Future<void> _advanceStatus(
      String messageId, DeliveryStatus status) async {
    try {
      await _local.updateStatus(messageId: messageId, status: status);
    } on Object {
      // Simulation only; real transport errors map to Failures at the edge.
    }
  }

  Future<void> _deliverInbound() async {
    if (!_online) return;
    final conversations = await _local.watchConversations().first;
    if (conversations.isEmpty) return;

    final target = conversations[_random.nextInt(conversations.length)];
    final peer = target.participantIds
        .where((p) => p != localUserId)
        .firstOrNull;
    if (peer == null) return;

    final now = DateTime.now();
    await _local.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      conversationId: target.id,
      senderId: peer,
      body: _inboundBody(_tickCount),
      ciphertext: const Value(null),
      syncStatus: MsgSyncStatus.read, // inbound: the peer has it locally
      createdAt: now,
    ));
    await _touchConversation(target.id, now);
  }

  Future<void> _touchConversation(String id, DateTime at) async {
    final c = await _local.findConversation(id);
    if (c == null) return;
    await _local.insertConversation(ConversationsCompanion.insert(
      id: c.id,
      title: c.title,
      participantIds: encodeParticipants(c.participantIds),
      lastActivityAt: at,
    ));
  }

  String _inboundBody(int n) {
    const bodies = [
      'ping from the mock transport — ratchet advanced, all green',
      'received your last one. Vault holds.',
      'this arrived through the fake socket; nobody could tell',
      'offline test: did this queue while the ticker was stopped?',
      'keys rotated (simulated). conversation integrity nominal.',
    ];
    return '${bodies[n % bodies.length]} (tick $n)';
  }

  /// Test/teardown hook. Not part of the repository contract.
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    for (final t in _deliveryTimers) {
      t.cancel();
    }
    _deliveryTimers.clear();
    for (final t in _replyTimers) {
      t.cancel();
    }
    _replyTimers.clear();
    _typingController.close();
  }
}

/// One peer's voice: delay rhythm plus line pools covering the four
/// conversational moves (greeting, ack, question, filler). [pickReply]
/// keeps it in character: a greeting answers silence, an acknowledgement
/// or question answers you, filler keeps the thread alive.
class _PeerPersona {
  const _PeerPersona({
    required this.typingSecondsPerWord,
    required this.replyDelayRange,
    required this.greetings,
    required this.acknowledgements,
    required this.questions,
    required this.filler,
  });

  final double typingSecondsPerWord;
  final (double, double) replyDelayRange;
  final List<String> greetings;
  final List<String> acknowledgements;
  final List<String> questions;
  final List<String> filler;

  String pickReply(String incoming, Random rng) {
    final text = incoming.toLowerCase().trim();
    if (text.length <= 3) {
      return greetings[rng.nextInt(greetings.length)];
    }
    if (text.contains('?')) {
      // You asked: acknowledge before answering-ish (in-character dodge).
      final pool = rng.nextBool() ? acknowledgements : questions;
      return pool[rng.nextInt(pool.length)];
    }
    // Mostly acknowledge, sometimes volunteer something new.
    if (rng.nextDouble() < 0.65) {
      return acknowledgements[rng.nextInt(acknowledgements.length)];
    }
    return filler[rng.nextInt(filler.length)];
  }
}
