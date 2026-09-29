import 'package:equatable/equatable.dart';

import '../../../../core/database/app_database.dart'
    show NotificationKind;

/// One comment under a Square post. Pure domain — no drift.
class PostComment extends Equatable {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  bool get isMine => authorId == 'local-user';

  @override
  List<Object?> get props =>
      [id, postId, authorId, authorName, body, createdAt];
}

/// One entry in the notification feed.
class SocialNotification extends Equatable {
  const SocialNotification({
    required this.id,
    required this.kind,
    required this.peerName,
    required this.body,
    required this.deepLink,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final NotificationKind kind;
  final String peerName;
  final String body;

  /// go_router location the notification opens when tapped.
  final String deepLink;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  @override
  List<Object?> get props =>
      [id, kind, peerName, body, deepLink, createdAt, readAt];
}
