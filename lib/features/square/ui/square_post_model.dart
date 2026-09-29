/// The Square — feed post model for the first vertical slice.
///
/// Slice-local presentation model: preformatted helpers, plain fields,
/// zero framework deps. At integration this maps 1:1 onto the domain
/// `Post` entity and the drift cache behind it — this class exists so
/// the UI slice ships today without dragging the data layer along.
class SquarePost {
  const SquarePost({
    required this.id,
    required this.username,
    required this.userAvatarUrl,
    required this.timestamp,
    required this.caption,
    this.mediaUrl,
    this.blurhash,
    required this.likesCount,
    required this.isLiked,
    this.expiresAt,
    this.clock,
  });

  final String id;
  final String username;
  final String userAvatarUrl;
  final DateTime timestamp;
  final String caption;
  final String? mediaUrl;

  /// Blurhash placeholder decoded synchronously while the network image
  /// loads (or fails) behind it — the offline media pattern.
  final String? blurhash;

  final int likesCount;
  final bool isLiked;

  /// Ephemeral expiry ("fades in 24h"); null = permanent.
  final DateTime? expiresAt;

  /// Injectable clock for fade math; production passes DateTime.now.
  final DateTime Function()? clock;

  /// Whether this post is ephemeral and already past its expiry.
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    final now = clock?.call() ?? DateTime.now();
    return !now.isBefore(expiry);
  }

  /// 1.0 (fresh) -> 0.0 (expiry): how far the polaroid has faded.
  /// Permanent posts never fade.
  double fadeFactor({DateTime? now}) {
    final expiry = expiresAt;
    if (expiry == null) return 1.0;
    final current = now ?? clock?.call() ?? DateTime.now();
    final created = timestamp;
    if (!current.isBefore(expiry)) return 0.0;
    if (!current.isAfter(created)) return 1.0;
    final total = expiry.difference(created).inMilliseconds;
    if (total <= 0) return 0.0;
    final remaining = expiry.difference(current).inMilliseconds;
    return remaining / total;
  }

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  SquarePost copyWith({int? likesCount, bool? isLiked}) => SquarePost(
        id: id,
        username: username,
        userAvatarUrl: userAvatarUrl,
        timestamp: timestamp,
        caption: caption,
        mediaUrl: mediaUrl,
        likesCount: likesCount ?? this.likesCount,
        isLiked: isLiked ?? this.isLiked,
        expiresAt: expiresAt,
        clock: clock,
      );

  /// Compact age for the card header: "4m", "3h", "2d".
  String get timeAgo {
    final delta = DateTime.now().difference(timestamp);
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }

  /// "1,204" / "12.4k" formatting for the like counter.
  String get likesLabel {
    if (likesCount < 1000) return '$likesCount';
    final k = likesCount / 1000;
    return k < 10 ? '${k.toStringAsFixed(1)}k' : '${k.round()}k';
  }
}
