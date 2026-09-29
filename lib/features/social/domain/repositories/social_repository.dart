import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/social_entities.dart';
export '../../../../core/database/app_database.dart'
    show NotificationKind;

/// Contract for the social layer: comments under Square posts plus the
/// peer-notification feed. Implementations own the mock-peer engine
/// (who comments, who reacts, when) behind [onOwnPostPublished] — the
/// UI never schedules peer activity itself.
abstract class SocialRepository {
  /// Live comments for one post, oldest first.
  Stream<Either<Failure, List<PostComment>>> watchComments(String postId);

  /// Persist the local user's comment. Local-first: the row lands
  /// before the future completes.
  Future<Either<Failure, PostComment>> addComment({
    required String postId,
    required String body,
  });

  /// Live notification feed, newest first.
  Stream<Either<Failure, List<SocialNotification>>> watchNotifications();

  /// Live unread count for the app-bar badge.
  Stream<int> watchUnreadCount();

  /// Mark everything read (opened the feed). Returns rows touched.
  Future<Either<Failure, int>> markAllRead();

  /// Called by the feed layer right after the local user publishes a
  /// post. Starts the mock-peer choreography: one or two peers may
  /// comment or react after a realistic delay. Capped and spaced —
  /// never more than two events per post, never less than ~20s apart.
  /// Returns a cancel handle (tests pass fake zone timers).
  Timer onOwnPostPublished({required String postId, required String body});
}
