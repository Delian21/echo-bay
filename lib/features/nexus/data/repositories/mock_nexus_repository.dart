import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/attachments/attachment.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/nexus.dart';
import '../../domain/repositories/nexus_repository.dart';
import '../datasources/nexus_local_datasource.dart';

/// Mock implementation of [NexusRepository].
///
/// Simulates a live Nexus backend:
///  - seeds two channels + two groups on first use;
///  - a channel ticker pushes broadcast posts into the cache (remote-first
///    read path, identical to the Square's);
///  - a group ticker delivers peer messages through the datasource, so
///    the offline read path matches the online one (Vault model);
///  - `sendGroupMessage` persists pending, then simulates delivery.
class MockNexusRepository implements NexusRepository {
  MockNexusRepository({
    required NexusLocalDatasource localDatasource,
    this.localUserId = 'local-user',
    Duration channelPostInterval = const Duration(seconds: 25),
    Duration groupMessageInterval = const Duration(seconds: 18),
    this.deliveryDelay = const Duration(milliseconds: 800),
    bool startTickers = true,
  })  : _local = localDatasource,
        _channelPostInterval = channelPostInterval,
        _groupMessageInterval = groupMessageInterval {
    // Opt-in tickers: periodic timers trip flutter_test's pending-timer
    // invariant (teardowns run after the check), so tests disable them.
    if (startTickers) {
      _startTickers();
    }
  }

  final NexusLocalDatasource _local;

  /// The local session's opaque id, injected from the auth seam.
  final String localUserId;
  final Duration _channelPostInterval;
  final Duration _groupMessageInterval;
  final Duration deliveryDelay;
  final _uuid = const Uuid();
  final _random = Random(7); // deterministic for reproducible demos

  Timer? _channelTicker;
  Timer? _groupTicker;
  bool _seeded = false;
  bool _online = true;
  int _channelTick = 0;
  int _groupTick = 0;

  // -- NexusRepository: channels ---------------------------------------------

  @override
  Stream<Either<Failure, List<NexusChannel>>> watchChannels() async* {
    await ensureSeeded();
    yield* _local
        .watchChannels()
        .map((list) => Right<Failure, List<NexusChannel>>(list));
  }

  @override
  Stream<Either<Failure, List<ChannelPost>>> watchChannelPosts({
    required String channelId,
  }) async* {
    await ensureSeeded();
    await _local.purgeExpiredChannelPosts();
    yield* _local
        .watchChannelPosts(channelId: channelId)
        .map((list) => Right<Failure, List<ChannelPost>>(list));
  }

  @override
  Future<Either<Failure, Unit>> refreshChannels() async {
    if (!_online) {
      return left(const NetworkFailure(message: 'offline: channels unavailable'));
    }
    await _pushChannelPosts(count: 3);
    return right(unit);
  }

  // -- NexusRepository: groups ------------------------------------------------

  @override
  Stream<Either<Failure, List<NexusGroup>>> watchGroups() async* {
    await ensureSeeded();
    yield* _local
        .watchGroups()
        .map((list) => Right<Failure, List<NexusGroup>>(list));
  }

  @override
  Stream<Either<Failure, List<GroupMessage>>> watchGroupMessages({
    required String groupId,
  }) async* {
    await ensureSeeded();
    yield* _local
        .watchGroupMessages(groupId: groupId)
        .map((list) => Right<Failure, List<GroupMessage>>(list));
  }

  @override
  Future<Either<Failure, GroupMessage>> sendGroupMessage({
    required String groupId,
    required String body,
    MessageAttachment? attachment,
  }) async {
    try {
      final group = await _local.findGroup(groupId);
      if (group == null) {
        return left(const NotFoundFailure(message: 'group not found'));
      }

      final stored = attachment == null ? null : await _storeAttachment(attachment);

      final message = GroupMessage(
        id: _uuid.v4(),
        groupId: groupId,
        senderId: localUserId,
        body: body,
        createdAt: DateTime.now(),
        status: OutboxStatus.pending,
        attachment: stored,
      );

      // LOCAL-FIRST: persist before any transport attempt.
      await _local.insertGroupMessage(GroupMessagesCompanion.insert(
        id: message.id,
        groupId: message.groupId,
        senderId: message.senderId,
        body: message.body,
        syncStatus: MsgSyncStatus.pending,
        createdAt: message.createdAt,
        attachmentKind: Value(stored?.kind.name),
        attachmentPath: Value(stored?.path),
        attachmentDurationMs: Value(stored?.durationMs),
      ));
      await _touchGroup(groupId, message.createdAt);

      // Simulated transport: ack after [deliveryDelay].
      unawaited(_simulateDelivery(message.id));

      return right(message);
    } catch (e) {
      return left(CacheFailure(message: 'sendGroupMessage failed', cause: e));
    }
  }

  /// Copy an attachment into `.attachments/` (same contract as the
  /// Vault's mock — duplicated on purpose: features may not import each
  /// other, and the shared helper would have to live in core data layer).
  Future<MessageAttachment> _storeAttachment(MessageAttachment a) async {
    final source = File(a.path);
    if (!await source.exists()) {
      throw StateError('attachment source missing: ${a.path}');
    }
    final dir = Directory(
        '${Directory.current.path}${Platform.pathSeparator}.attachments');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = a.path.contains('.') ? a.path.split('.').last : 'bin';
    final dest = File(
        '${dir.path}${Platform.pathSeparator}${_uuid.v4()}.$ext');
    await source.copy(dest.path);
    return MessageAttachment(
      kind: a.kind,
      path: dest.path,
      durationMs: a.durationMs,
    );
  }

  @override
  Future<Either<Failure, Unit>> syncOutbox() async {
    try {
      final pending = await _local.pendingGroupMessages();
      for (final m in pending) {
        await _local.updateGroupMessageStatus(
          messageId: m.id,
          status: OutboxStatus.sent,
        );
      }
      // Membership ops flush through the same outbox discipline.
      final pendingMemberships = await _local.pendingMemberships();
      for (final membership in pendingMemberships) {
        await _local.updateMembershipStatus(
          groupId: membership.groupId,
          userId: membership.userId,
          status: MembershipSyncStatus.synced,
        );
      }
      return right(unit);
    } catch (e) {
      return left(CacheFailure(message: 'syncOutbox failed', cause: e));
    }
  }

  // -- membership (first-class sync entity) ----------------------------------

  @override
  Stream<Either<Failure, List<GroupMembership>>> watchMembers(
      {required String groupId}) async* {
    await ensureSeeded();
    yield* _local
        .watchMembers(groupId: groupId)
        .map((list) => Right<Failure, List<GroupMembership>>(list));
  }

  @override
  Future<Either<Failure, GroupMembership>> joinGroup(
      {required String groupId}) async {
    try {
      final group = await _local.findGroup(groupId);
      if (group == null) {
        return left(const NotFoundFailure(message: 'group not found'));
      }
      final existing = await _local.findMembership(
        groupId: groupId,
        userId: localUserId,
      );
      if (existing != null &&
          existing.syncStatus != MembershipSyncStatus.left) {
        return right(existing); // already a member — idempotent
      }

      // LOCAL-FIRST: membership row written as pending, synced later.
      final membership = GroupMembership(
        groupId: groupId,
        userId: localUserId,
        role: MemberRole.member,
        syncStatus: MembershipSyncStatus.pending,
        updatedAt: DateTime.now(),
      );
      await _local.upsertMembership(MemberRolesCompanion.insert(
        groupId: membership.groupId,
        userId: membership.userId,
        role: NexusMemberRole.member,
        syncStatus: MemberSyncStatus.pending,
        updatedAt: membership.updatedAt,
      ));
      return right(membership);
    } catch (e) {
      return left(CacheFailure(message: 'joinGroup failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> leaveGroup(
      {required String groupId}) async {
    try {
      final existing = await _local.findMembership(
        groupId: groupId,
        userId: localUserId,
      );
      if (existing == null) return right(unit); // idempotent

      final left_ = existing.copyWith(
        syncStatus: MembershipSyncStatus.left,
        updatedAt: DateTime.now(),
      );
      await _local.upsertMembership(MemberRolesCompanion.insert(
        groupId: left_.groupId,
        userId: left_.userId,
        role: NexusMemberRole.member,
        syncStatus: MemberSyncStatus.left,
        updatedAt: left_.updatedAt,
      ));
      return right(unit);
    } catch (e) {
      return left(CacheFailure(message: 'leaveGroup failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, GroupMembership>> setMemberRole({
    required String groupId,
    required String userId,
    required MemberRole role,
  }) async {
    try {
      final existing = await _local.findMembership(
        groupId: groupId,
        userId: userId,
      );
      if (existing == null) {
        return left(const NotFoundFailure(message: 'membership not found'));
      }

      final updated = existing.copyWith(
        role: role,
        syncStatus: MembershipSyncStatus.pending,
        updatedAt: DateTime.now(),
      );
      await _local.upsertMembership(MemberRolesCompanion.insert(
        groupId: updated.groupId,
        userId: updated.userId,
        role: switch (role) {
          MemberRole.owner => NexusMemberRole.owner,
          MemberRole.admin => NexusMemberRole.admin,
          MemberRole.member => NexusMemberRole.member,
        },
        syncStatus: MemberSyncStatus.pending,
        updatedAt: updated.updatedAt,
      ));
      return right(updated);
    } catch (e) {
      return left(CacheFailure(message: 'setMemberRole failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> ensureSeeded() async {
    if (_seeded) return right(unit);
    try {
      final now = DateTime.now();

      const channels = [
        (
          id: 'chan-ann',
          title: 'Announcements',
          description: 'Product news, straight from the source.',
        ),
        (
          id: 'chan-eng',
          title: 'Engineering Log',
          description: 'What shipped, what broke, what is next.',
        ),
      ];
      for (final c in channels) {
        await _local.insertChannel(NexusChannelsCompanion.insert(
          id: c.id,
          title: c.title,
          description: c.description,
          lastPostAt: now,
        ));
        await _local.insertChannelPost(ChannelPostsCompanion.insert(
          id: _uuid.v4(),
          channelId: c.id,
          authorName: c.id == 'chan-ann' ? 'The Team' : 'Build Bot',
          body: c.id == 'chan-ann'
              ? 'Welcome to the Nexus. Channels broadcast, groups discuss.'
              : 'Nightly build green. Cache layer verified offline-first.',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ));
      }

      const groups = [
        (id: 'grp-core', title: 'Core Devs'),
        (id: 'grp-design', title: 'Design Crit'),
      ];
      for (final g in groups) {
        await _local.insertGroup(NexusGroupsCompanion.insert(
          id: g.id,
          title: g.title,
          memberIds:
              encodeIds([localUserId, 'peer-ada', 'peer-bo']),
          lastActivityAt: now,
        ));
        await _local.setRole(
          groupId: g.id,
          userId: localUserId,
          role: NexusMemberRole.admin,
        );
        // Peer members get synced membership rows too — the memberIds
        // list and the membership table must agree from day one.
        for (final peer in const ['peer-ada', 'peer-bo']) {
          await _local.setRole(
            groupId: g.id,
            userId: peer,
            role: NexusMemberRole.member,
          );
        }
      }

      _seeded = true;
      return right(unit);
    } catch (e) {
      return left(CacheFailure(message: 'nexus seed failed', cause: e));
    }
  }

  // -- Fake network simulation ------------------------------------------------

  /// Toggle the simulated network. Offline: tickers stop, channel refresh
  /// fails, group messages pile up pending — the outbox path.
  void setOnline(bool online) {
    _online = online;
    if (online) {
      _startTickers();
    } else {
      _channelTicker?.cancel();
      _groupTicker?.cancel();
    }
  }

  void _startTickers() {
    _channelTicker?.cancel();
    _groupTicker?.cancel();
    _channelTicker = Timer.periodic(_channelPostInterval, (_) {
      _channelTick++;
      _pushChannelPosts(count: 1);
    });
    _groupTicker = Timer.periodic(_groupMessageInterval, (_) {
      _groupTick++;
      _deliverGroupMessage();
    });
  }

  Future<void> _pushChannelPosts({required int count}) async {
    if (!_online) return;
    final now = DateTime.now();
    for (var i = 0; i < count; i++) {
      final target = _channelTick.isEven ? 'chan-ann' : 'chan-eng';
      await _local.insertChannelPost(ChannelPostsCompanion.insert(
        id: _uuid.v4(),
        channelId: target,
        authorName: 'Broadcast Bot',
        body: 'Channel push (tick $_channelTick). The cache mirrors the wire.',
        createdAt: now.subtract(Duration(seconds: i)),
        // Retention demo: broadcast posts expire after 1 hour in the mock.
        expiresAt: Value(now.add(const Duration(hours: 1))),
      ));
    }
  }

  Future<void> _deliverGroupMessage() async {
    if (!_online) return;
    final groups = await _local.watchGroups().first;
    if (groups.isEmpty) return;

    final target = groups[_random.nextInt(groups.length)];
    final peers = target.memberIds
        .where((m) => m != localUserId)
        .toList();
    if (peers.isEmpty) return;
    final peer = peers[_random.nextInt(peers.length)];

    final now = DateTime.now();
    await _local.insertGroupMessage(GroupMessagesCompanion.insert(
      id: _uuid.v4(),
      groupId: target.id,
      senderId: peer,
      body: 'peer ping from the mock transport (tick $_groupTick)',
      syncStatus: MsgSyncStatus.sent, // inbound: already "delivered"
      createdAt: now,
    ));
    await _touchGroup(target.id, now);
  }

  Future<void> _simulateDelivery(String messageId) async {
    try {
      await Future<void>.delayed(deliveryDelay);
      await _local.updateGroupMessageStatus(
        messageId: messageId,
        status: OutboxStatus.sent,
      );
    } on Object {
      // Simulation only; real transport errors map to Failures at the edge.
    }
  }

  Future<void> _touchGroup(String id, DateTime at) async {
    final g = await _local.findGroup(id);
    if (g == null) return;
    await _local.insertGroup(NexusGroupsCompanion.insert(
      id: g.id,
      title: g.title,
      memberIds: encodeIds(g.memberIds),
      lastActivityAt: at,
    ));
  }

  /// Test/teardown hook. Not part of the repository contract.
  void dispose() {
    _channelTicker?.cancel();
    _groupTicker?.cancel();
    _channelTicker = null;
    _groupTicker = null;
  }
}
