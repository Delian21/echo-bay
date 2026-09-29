import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/services/peer_planner.dart';

/// Drift-backed [SocialRepository]. Local-first: the user's own comment
/// is persisted before the future completes; mock-peer events arrive on
/// real (injectable) timers, capped and spaced by [PeerPlanner].
class DriftSocialRepository implements SocialRepository {
  DriftSocialRepository(this._db, {PeerPlanner? planner})
      : _planner = planner ?? PeerPlanner();

  final AppDatabase _db;
  final PeerPlanner _planner;
  final _uuid = const Uuid();

  @override
  Stream<Either<Failure, List<PostComment>>> watchComments(String postId) {
    final query = _db.select(_db.postComments)
      ..where((t) => t.postId.equals(postId))
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.asc,
            ),
      ]);
    return query.watch().map(
          (rows) => Right(
            rows
                .map((r) => PostComment(
                      id: r.id,
                      postId: r.postId,
                      authorId: r.authorId,
                      authorName: r.authorName,
                      body: r.body,
                      createdAt: r.createdAt,
                    ))
                .toList(),
          ),
        );
  }

  @override
  Future<Either<Failure, PostComment>> addComment({
    required String postId,
    required String body,
  }) async {
    try {
      final comment = PostComment(
        id: _uuid.v4(),
        postId: postId,
        authorId: 'local-user',
        authorName: 'You',
        body: body,
        createdAt: DateTime.now(),
      );
      await _db.into(_db.postComments).insert(PostCommentsCompanion.insert(
            id: comment.id,
            postId: comment.postId,
            authorId: comment.authorId,
            authorName: comment.authorName,
            body: comment.body,
            createdAt: comment.createdAt,
          ));
      return right(comment);
    } on Object catch (e) {
      return left(CacheFailure(message: 'addComment failed', cause: e));
    }
  }

  /// Inserts a peer event: the comment row (when it is one) and the
  /// notification, as one unit. Also used by the tests via the engine.
  Future<void> _applyPeerEvent(PlannedPeerEvent event, String postId) async {
    final now = DateTime.now();
    if (event.kind == NotificationKind.comment) {
      await _db.into(_db.postComments).insert(PostCommentsCompanion.insert(
            id: _uuid.v4(),
            postId: postId,
            authorId: 'peer-${event.peerName}',
            authorName: event.peerName,
            body: event.commentBody ?? '',
            createdAt: now,
          ));
    }
    await _db.into(_db.socialNotifications).insert(
          SocialNotificationsCompanion.insert(
            id: _uuid.v4(),
            kind: event.kind,
            peerName: event.peerName,
            body: event.kind == NotificationKind.comment
                ? event.commentBody ?? ''
                : 'reacted ${event.reaction ?? ''}'.trim(),
            deepLink: '/square',
            createdAt: now,
          ),
        );
  }

  @override
  Timer onOwnPostPublished({required String postId, required String body}) {
    final events = _planner.planForPost();
    // One timer for the first event; each event schedules the next, so
    // spacing stays honest even if the zone's clock is virtual.
    Timer? handle;
    void schedule(List<PlannedPeerEvent> remaining) {
      if (remaining.isEmpty) return;
      final next = remaining.first;
      handle = Timer(next.delay, () {
        _applyPeerEvent(next, postId);
        schedule(remaining.sublist(1));
      });
    }

    schedule(events);
    return handle ?? Timer(Duration.zero, () {});
  }

  @override
  Stream<Either<Failure, List<SocialNotification>>> watchNotifications() {
    final query = _db.select(_db.socialNotifications)
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.desc,
            ),
      ]);
    return query.watch().map(
          (rows) => Right(
            rows
                .map((r) => SocialNotification(
                      id: r.id,
                      kind: r.kind,
                      peerName: r.peerName,
                      body: r.body,
                      deepLink: r.deepLink,
                      createdAt: r.createdAt,
                      readAt: r.readAt,
                    ))
                .toList(),
          ),
        );
  }

  @override
  Stream<int> watchUnreadCount() {
    final count = _db.socialNotifications.id.count();
    final query = _db.selectOnly(_db.socialNotifications)
      ..addColumns([count])
      ..where(_db.socialNotifications.readAt.isNull());
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  @override
  Future<Either<Failure, int>> markAllRead() async {
    try {
      final touched = await (_db.update(_db.socialNotifications)
            ..where((t) => t.readAt.isNull()))
          .write(SocialNotificationsCompanion(
        readAt: Value(DateTime.now()),
      ));
      return right(touched);
    } on Object catch (e) {
      return left(CacheFailure(message: 'markAllRead failed', cause: e));
    }
  }
}
