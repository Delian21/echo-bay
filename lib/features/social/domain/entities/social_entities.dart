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

/// One follow edge, pure domain — no drift. [driftedAt] non-null means
/// the two have drifted apart (soft removal keeps history for time
/// travel). UI vocabulary: "Keep close" / "Drift apart".
class PeerFollow extends Equatable {
  const PeerFollow({
    required this.id,
    required this.followerId,
    required this.followerName,
    required this.followedId,
    required this.followedName,
    required this.followedAt,
    this.driftedAt,
  });

  final String id;
  final String followerId;
  final String followerName;
  final String followedId;
  final String followedName;
  final DateTime followedAt;
  final DateTime? driftedAt;

  bool get isActive => driftedAt == null;

  @override
  List<Object?> get props =>
      [id, followerId, followedId, followedAt, driftedAt];
}

/// A mock peer's profile. Mock-stage peers are name-keyed; a real
/// backend swaps ids in behind the repository without touching callers.
class PeerProfile extends Equatable {
  const PeerProfile({
    required this.name,
    required this.bio,
    required this.avatarSeed,
  });

  final String name;

  /// One hand-written line in the peer's own voice.
  final String bio;

  /// Stable hash seed for deterministic avatar tint per peer.
  final int avatarSeed;

  @override
  List<Object?> get props => [name, bio, avatarSeed];
}
