import 'package:equatable/equatable.dart';

/// Pure domain entity — no drift, no json, no Flutter.
class Post extends Equatable {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.mediaUrl,
    this.blurhash,
    this.isLiked = false,
    this.likesCount = 0,
    this.deletedAt,
    this.expiresAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final String? mediaUrl;

  /// Blurhash of [mediaUrl] (Instagram lesson): encoded at write time,
  /// decoded synchronously at render time so the cache paints a
  /// meaningful placeholder offline, behind the loading image.
  final String? blurhash;
  final DateTime createdAt;

  /// Soft-delete tombstone (undo window). Non-null = hidden from the
  /// feed, still restorable until the repository purges it.
  final DateTime? deletedAt;

  /// Ephemeral expiry ("fades in 24h"). Non-null = temporary; the feed
  /// and profile hide the post once [now] passes it, and the row is
  /// purged lazily. Null = permanent.
  final DateTime? expiresAt;
  final bool isLiked;

  /// Total like count. In the mock stage the transport synthesizes a
  /// stable baseline per post id; a real backend supplies the server
  /// number and the local delta on top.
  final int likesCount;

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? body,
    String? mediaUrl,
    DateTime? createdAt,
    bool? isLiked,
    int? likesCount,
    DateTime? deletedAt,
    bool clearDeleted = false,
    DateTime? expiresAt,
    bool clearExpiry = false,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      body: body ?? this.body,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      createdAt: createdAt ?? this.createdAt,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
      // Keep-forever conversion clears the expiry.
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
    );
  }

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        body,
        mediaUrl,
        blurhash,
        createdAt,
        deletedAt,
        expiresAt,
        isLiked,
        likesCount,
      ];
}
