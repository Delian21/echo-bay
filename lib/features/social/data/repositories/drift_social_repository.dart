import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:fpdart/fpdart.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/repositories/follow_repository.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/services/peer_planner.dart';

/// Drift-backed [SocialRepository]. Local-first: the user's own comment
/// is persisted before the future completes; mock-peer events arrive on
/// real (injectable) timers, capped and spaced by [PeerPlanner].
class DriftSocialRepository implements SocialRepository {
  DriftSocialRepository(
    this._db, {
    PeerPlanner? planner,
    FollowRepository? follows,
    this.localUserId = 'local-user',
  })  : _planner = planner ?? PeerPlanner(),
        _follows = follows;

  final AppDatabase _db;
  final PeerPlanner _planner;

  /// Follow graph for spontaneous peer follows (optional: absent in
  /// some tests, and then no follows are ever planned).
  final FollowRepository? _follows;

  /// The local user's id (session-attributed own-post counting).
  final String localUserId;
  final _uuid = const Uuid();

  /// Time-travel instant (null = present). Comment/notification reads
  /// show only rows that existed by then; writes are refused.
  DateTime? _asOf;

  final _asOfTick = StreamController<DateTime?>.broadcast();

  /// Sets the time-travel instant (null = present). Read-only.
  void setAsOf(DateTime? moment) {
    if (_asOf == moment) return;
    _asOf = moment;
    _asOfTick.add(_asOf);
  }

  void _assertWritable() {
    if (_asOf != null) {
      throw StateError('writes are refused while time traveling');
    }
  }

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
    // Time travel: re-run when the as-of instant moves; only comments
    // that existed by then.
    return _asOfTick.stream.startWith(null).switchMap((_) =>
        query.watch().map((rows) {
          final moment = _asOf;
          final visible = moment == null
              ? rows
              : rows.where((r) => !r.createdAt.isAfter(moment)).toList();
          return Right<Failure, List<PostComment>>(
            visible
                .map((r) => PostComment(
                      id: r.id,
                      postId: r.postId,
                      authorId: r.authorId,
                      authorName: r.authorName,
                      body: r.body,
                      createdAt: r.createdAt,
                    ))
                .toList(),
          );
        }));
  }

  @override
  Future<Either<Failure, PostComment>> addComment({
    required String postId,
    required String body,
  }) async {
    _assertWritable();
    try {
      final comment = PostComment(
        id: _uuid.v4(),
        postId: postId,
        authorId: localUserId,
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
            deepLink: '/square/post/$postId',
            createdAt: now,
          ),
        );
  }

  @override
  Timer onOwnPostPublished({required String postId, required String body}) {
    _assertWritable();
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
    // Spontaneous follow: a peer may quietly start keeping the local
    // user close. Rare, capped by the planner, and notified in the
    // app's voice ("Mila kept you close"). Drifting apart is never
    // planned — nothing announces an unfollow.
    unawaited(_maybePeerFollow(postId));
    return handle ?? Timer(Duration.zero, () {});
  }

  /// How many own posts exist (the planner's quiet-in + cap input).
  Future<int> _countOwnPosts() async {
    final count = _db.posts.id.count();
    final query = _db.selectOnly(_db.posts)
      ..addColumns([count])
      ..where(_db.posts.authorId.equals(localUserId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _maybePeerFollow(String postId) async {
    final postCount = await _countOwnPosts();
    final peerName = _planner.planFollow(postCount: postCount);
    if (peerName == null) return;
    // Write goes through the follow graph (local user id matches the
    // session); the notification lands with a deep link to the Square.
    final follows = _follows;
    if (follows == null) return;
    final result = await follows.peerKeepsMeClose(peerName);
    result.fold((_) {}, (_) => unawaited(_notifyFollow(peerName)));
  }

  /// The announcement, after a human-paced pause: "Mila kept you close."
  Future<void> _notifyFollow(String peerName) async {
    final delay = const Duration(seconds: 30) +
        Duration(seconds: DateTime.now().second % 30);
    Timer(delay, () async {
      await _db.into(_db.socialNotifications).insert(
            SocialNotificationsCompanion.insert(
              id: _uuid.v4(),
              kind: NotificationKind.follow,
              peerName: peerName,
              body: 'kept you close',
              deepLink: '/square',
              createdAt: DateTime.now(),
            ),
          );
    });
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
    // Time travel: only notifications created by the visited moment.
    return _asOfTick.stream.startWith(null).switchMap((_) =>
        query.watch().map((rows) {
          final moment = _asOf;
          final visible = moment == null
              ? rows
              : rows.where((r) => !r.createdAt.isAfter(moment)).toList();
          return Right<Failure, List<SocialNotification>>(
            visible
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
          );
        }));
  }

  @override
  Stream<int> watchUnreadCount() {
    // Time travel: the badge reflects the visited moment (unread = not
    // yet read as of then; readAt after the moment counts as unread).
    return _asOfTick.stream.startWith(null).switchMap((_) {
      final moment = _asOf;
      final count = _db.socialNotifications.id.count();
      final query = _db.selectOnly(_db.socialNotifications)
        ..addColumns([count])
        ..where(moment == null
            ? _db.socialNotifications.readAt.isNull()
            : _db.socialNotifications.readAt.isNull() |
                _db.socialNotifications.readAt.isBiggerThanValue(moment));
      return query.watchSingle().map((row) => row.read(count) ?? 0);
    });
  }

  @override
  Future<Either<Failure, int>> markAllRead() async {
    _assertWritable();
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
