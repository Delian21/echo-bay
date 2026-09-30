import 'package:drift/drift.dart';

import '../../../../core/attachments/attachment.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/nexus.dart';

// -- mappers (data-layer concern) -------------------------------------------

extension NexusChannelRowMapper on NexusChannelRow {
  NexusChannel toEntity() => NexusChannel(
        id: id,
        title: title,
        description: description,
        lastPostAt: lastPostAt,
      );
}

extension ChannelPostRowMapper on ChannelPostRow {
  ChannelPost toEntity() => ChannelPost(
        id: id,
        channelId: channelId,
        authorName: authorName,
        body: body,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
}

extension NexusGroupRowMapper on NexusGroupRow {
  NexusGroup toEntity({required NexusMemberRole? myRole}) => NexusGroup(
        id: id,
        title: title,
        memberIds: decodeIds(memberIds),
        myRole: switch (myRole) {
          NexusMemberRole.owner => MemberRole.owner,
          NexusMemberRole.admin => MemberRole.admin,
          NexusMemberRole.member => MemberRole.member,
          null => MemberRole.member,
        },
        lastActivityAt: lastActivityAt,
      );
}

extension GroupMessageRowMapper on GroupMessageRow {
  GroupMessage toEntity() => GroupMessage(
        id: id,
        groupId: groupId,
        senderId: senderId,
        body: body,
        createdAt: createdAt,
        editedAt: editedAt,
        deletedAt: deletedAt,
        status: switch (syncStatus) {
          MsgSyncStatus.pending => OutboxStatus.pending,
          MsgSyncStatus.sent => OutboxStatus.sent,
          MsgSyncStatus.delivered => OutboxStatus.sent,
          MsgSyncStatus.read => OutboxStatus.sent,
          MsgSyncStatus.failed => OutboxStatus.failed,
        },
        attachment: _attachmentFromDb(
            attachmentKind, attachmentPath, attachmentDurationMs),
      );

  static MessageAttachment? _attachmentFromDb(
      String? kind, String? path, int? durationMs) {
    if (kind == null || path == null) return null;
    final parsed = switch (kind) {
      'photo' => AttachmentKind.photo,
      'video' => AttachmentKind.video,
      'voice' => AttachmentKind.voice,
      'post' => AttachmentKind.post,
      _ => null,
    };
    if (parsed == null) return null;
    return MessageAttachment(
        kind: parsed, path: path, durationMs: durationMs);
  }
}

extension MemberRoleRowMapper on MemberRoleRow {
  GroupMembership toEntity() => GroupMembership(
        groupId: groupId,
        userId: userId,
        role: switch (role) {
          NexusMemberRole.owner => MemberRole.owner,
          NexusMemberRole.admin => MemberRole.admin,
          NexusMemberRole.member => MemberRole.member,
        },
        syncStatus: switch (syncStatus) {
          MemberSyncStatus.pending => MembershipSyncStatus.pending,
          MemberSyncStatus.synced => MembershipSyncStatus.synced,
          MemberSyncStatus.failed => MembershipSyncStatus.failed,
          MemberSyncStatus.left => MembershipSyncStatus.left,
        },
        updatedAt: updatedAt,
      );
}

String encodeIds(List<String> ids) =>
    '[${ids.map((e) => '"$e"').join(',')}]';

List<String> decodeIds(String json) {
  final trimmed = json.trim();
  if (trimmed.isEmpty || trimmed == '[]') return const [];
  return trimmed
      .substring(1, trimmed.length - 1)
      .split(',')
      .map((e) => e.trim().replaceAll('"', ''))
      .where((e) => e.isNotEmpty)
      .toList();
}

// -- datasource --------------------------------------------------------------

/// Local store access for the Nexus. Channels: cache reads + cache fills.
/// Groups: source-of-truth reads/writes with outbox state.
abstract class NexusLocalDatasource {
  // channels (cache)
  Stream<List<NexusChannel>> watchChannels();
  Stream<List<ChannelPost>> watchChannelPosts({required String channelId});
  Future<void> insertChannel(NexusChannelsCompanion entry);
  Future<void> insertChannelPost(ChannelPostsCompanion entry);

  // groups (source of truth)
  Stream<List<NexusGroup>> watchGroups();
  Stream<List<GroupMessage>> watchGroupMessages({required String groupId});
  Future<NexusGroup?> findGroup(String id);
  Future<void> insertGroup(NexusGroupsCompanion entry);
  Future<void> insertGroupMessage(GroupMessagesCompanion entry);
  Future<void> setRole({
    required String groupId,
    required String userId,
    required NexusMemberRole role,
  });

  /// Membership ops with their sync state, ordered by operation time.
  Stream<List<GroupMembership>> watchMembers({required String groupId});

  Future<GroupMembership?> findMembership({
    required String groupId,
    required String userId,
  });

  /// Write a membership row with its outbox status (join/leave/role op).
  Future<void> upsertMembership(MemberRolesCompanion entry);

  /// Membership rows awaiting the transport.
  Future<List<GroupMembership>> pendingMemberships();

  /// Mark a membership op as synced (or failed) after the transport run.
  Future<void> updateMembershipStatus({
    required String groupId,
    required String userId,
    required MembershipSyncStatus status,
  });

  Future<List<GroupMessage>> pendingGroupMessages();
  Future<void> updateGroupMessageStatus({
    required String messageId,
    required OutboxStatus status,
  });

  /// Hard-delete channel posts past their retention window. Called on
  /// read paths opportunistically; retention never resurrects rows.
  Future<void> purgeExpiredChannelPosts();
}

class DriftNexusLocalDatasource implements NexusLocalDatasource {
  DriftNexusLocalDatasource(this._db, {this.localUserId = 'local-user'});

  final AppDatabase _db;

  /// The local session's opaque id, injected from the auth seam. Drives
  /// role lookups in [watchGroups] and [findGroup].
  final String localUserId;

  @override
  Stream<List<NexusChannel>> watchChannels() {
    final query = _db.select(_db.nexusChannels)
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.lastPostAt,
              mode: OrderingMode.desc,
            ),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.toEntity()).toList());
  }

  @override
  Stream<List<ChannelPost>> watchChannelPosts({required String channelId}) {
    final query = _db.select(_db.channelPosts)
      ..where((tbl) => tbl.channelId.equals(channelId))
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
      ]);
    return query.watch().map((rows) {
      final now = DateTime.now();
      return rows
          .where((r) => r.expiresAt == null || r.expiresAt!.isAfter(now))
          .map((r) => r.toEntity())
          .toList();
    });
  }

  @override
  Future<void> insertChannel(NexusChannelsCompanion entry) =>
      _db.into(_db.nexusChannels).insertOnConflictUpdate(entry);

  @override
  Future<void> insertChannelPost(ChannelPostsCompanion entry) =>
      _db.into(_db.channelPosts).insertOnConflictUpdate(entry);

  @override
  Stream<List<NexusGroup>> watchGroups() {
    final roles = _db.alias(_db.memberRoles, 'mr');
    final query = _db.select(_db.nexusGroups).join([
      leftOuterJoin(
        roles,
        roles.groupId.equalsExp(_db.nexusGroups.id) &
            roles.userId.equals(localUserId),
      ),
    ])
      ..orderBy([
        OrderingTerm(
          expression: _db.nexusGroups.lastActivityAt,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch().map((rows) => rows.map((row) {
          final group = row.readTable(_db.nexusGroups);
          final role = row.readTableOrNull(roles)?.role;
          return group.toEntity(myRole: role);
        }).toList());
  }

  @override
  Stream<List<GroupMessage>> watchGroupMessages({required String groupId}) {
    final query = _db.select(_db.groupMessages)
      ..where((tbl) => tbl.groupId.equals(groupId))
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.asc,
            ),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.toEntity()).toList());
  }

  @override
  Future<NexusGroup?> findGroup(String id) async {
    final query = _db.select(_db.nexusGroups)
      ..where((tbl) => tbl.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final roleRows = await (_db.select(_db.memberRoles)
          ..where((tbl) =>
              tbl.groupId.equals(id) &
              tbl.userId.equals(localUserId)))
        .get();
    return row.toEntity(
      myRole: roleRows.isEmpty ? null : roleRows.first.role,
    );
  }

  @override
  Future<void> insertGroup(NexusGroupsCompanion entry) =>
      _db.into(_db.nexusGroups).insertOnConflictUpdate(entry);

  @override
  Future<void> insertGroupMessage(GroupMessagesCompanion entry) =>
      _db.into(_db.groupMessages).insertOnConflictUpdate(entry);

  /// Seed-stage convenience: writes an already-synced membership row so
  /// seeded groups don't queue phantom join operations.
  @override
  Future<void> setRole({
    required String groupId,
    required String userId,
    required NexusMemberRole role,
  }) =>
      _db.into(_db.memberRoles).insertOnConflictUpdate(MemberRolesCompanion(
            groupId: Value(groupId),
            userId: Value(userId),
            role: Value(role),
            syncStatus: const Value(MemberSyncStatus.synced),
            updatedAt: Value(DateTime.now()),
          ));

  @override
  Stream<List<GroupMembership>> watchMembers({required String groupId}) {
    final query = _db.select(_db.memberRoles)
      ..where((tbl) => tbl.groupId.equals(groupId))
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.updatedAt,
              mode: OrderingMode.asc,
            ),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.toEntity()).toList());
  }

  @override
  Future<GroupMembership?> findMembership({
    required String groupId,
    required String userId,
  }) async {
    final query = _db.select(_db.memberRoles)
      ..where((tbl) =>
          tbl.groupId.equals(groupId) & tbl.userId.equals(userId));
    final row = await query.getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<void> upsertMembership(MemberRolesCompanion entry) =>
      _db.into(_db.memberRoles).insertOnConflictUpdate(entry);

  @override
  Future<List<GroupMembership>> pendingMemberships() async {
    final query = _db.select(_db.memberRoles)
      ..where((tbl) =>
          tbl.syncStatus.equalsValue(MemberSyncStatus.pending) |
          tbl.syncStatus.equalsValue(MemberSyncStatus.failed))
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.updatedAt,
              mode: OrderingMode.asc,
            ),
      ]);
    final rows = await query.get();
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<void> updateMembershipStatus({
    required String groupId,
    required String userId,
    required MembershipSyncStatus status,
  }) {
    final dbStatus = switch (status) {
      MembershipSyncStatus.pending => MemberSyncStatus.pending,
      MembershipSyncStatus.synced => MemberSyncStatus.synced,
      MembershipSyncStatus.failed => MemberSyncStatus.failed,
      MembershipSyncStatus.left => MemberSyncStatus.left,
    };
    return (_db.update(_db.memberRoles)
          ..where((tbl) =>
              tbl.groupId.equals(groupId) & tbl.userId.equals(userId)))
        .write(MemberRolesCompanion(syncStatus: Value(dbStatus)));
  }

  @override
  Future<List<GroupMessage>> pendingGroupMessages() async {
    final query = _db.select(_db.groupMessages)
      ..where((tbl) =>
          tbl.syncStatus.equalsValue(MsgSyncStatus.pending) |
          tbl.syncStatus.equalsValue(MsgSyncStatus.failed))
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.asc,
            ),
      ]);
    final rows = await query.get();
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<void> updateGroupMessageStatus({
    required String messageId,
    required OutboxStatus status,
  }) {
    final dbStatus = switch (status) {
      OutboxStatus.pending => MsgSyncStatus.pending,
      OutboxStatus.sent => MsgSyncStatus.sent,
      OutboxStatus.failed => MsgSyncStatus.failed,
    };
    return (_db.update(_db.groupMessages)
          ..where((tbl) => tbl.id.equals(messageId)))
        .write(GroupMessagesCompanion(syncStatus: Value(dbStatus)));
  }

  @override
  Future<void> purgeExpiredChannelPosts() {
    // NULL expiresAt rows never match (SQL NULL comparison), so
    // keep-forever posts are untouched.
    return (_db.delete(_db.channelPosts)
          ..where((tbl) => tbl.expiresAt
              .isSmallerThan(Variable.withDateTime(DateTime.now()))))
        .go();
  }
}
