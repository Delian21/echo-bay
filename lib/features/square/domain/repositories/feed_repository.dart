import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/post.dart';

/// Contract for the feed data layer. The domain knows this interface only;
/// today it is implemented by a mock backed by the local cache + fake
/// streams, later by a real remote implementation with identical semantics.
abstract class FeedRepository {
  /// Chronological feed, newest first. Cache-backed; emits again whenever
  /// the underlying table changes (including inserts from the mock ticker).
  Stream<Either<Failure, List<Post>>> watchFeed();

  /// One-shot refresh. In the mock stage this triggers the fake remote to
  /// push new posts into the cache; offline it returns [NetworkFailure].
  Future<Either<Failure, Unit>> refreshFeed();

  /// Create a post locally and "publish it". Mock stage: lands in cache,
  /// marked as published. Real stage: outbox + server round-trip.
  /// [authorName] carries the profile display name; defaults preserve the
  /// pre-profile 'You' label for callers that do not pass it.
  /// [ephemeral] opts the post into "fades in 24h": it disappears from
  /// feed and profile after [ephemeralLifetime] and can be made permanent
  /// with [keepPost] before that.
  Future<Either<Failure, Post>> createPost({
    required String body,
    String? mediaUrl,
    String authorName = 'You',
    bool ephemeral = false,
  });

  /// Toggle like on a post; persists to the local like table.
  Future<Either<Failure, Unit>> toggleLike({required String postId});

  /// Soft-delete one of the local user's own posts (author match). The
  /// post leaves the feed immediately but stays restorable for a short
  /// window; a real backend swaps in an outbox write without changing
  /// this contract.
  Future<Either<Failure, Unit>> deletePost({required String postId});

  /// Undo a [deletePost] inside the restore window. Returns failure
  /// when the post no longer exists or the window has closed.
  Future<Either<Failure, Unit>> restorePost({required String postId});

  /// Posts created on [day] (local midnight to midnight) — the journal
  /// day-view behind the clickable date in the feed header.
  Future<Either<Failure, List<Post>>> postsOnDay(DateTime day);

  /// One post by id, regardless of tombstones or expiry — cross-module
  /// surfaces (shared-post cards, keepsake wall) need the raw row to
  /// decide how to present it (live, faded, rewound). Null when purged.
  Future<Either<Failure, Post?>> findPostById(String postId);

  /// One author's visible posts, newest first — the person sheet's
  /// "their squares" list. Tombstoned/expired posts excluded.
  Future<Either<Failure, List<Post>>> findPostsByAuthor(String authorName);

  /// Lifetime of an ephemeral ("fades in 24h") post.
  static const ephemeralLifetime = Duration(hours: 24);

  /// "Keep it": converts one of the local user's own ephemeral posts to
  /// permanent by clearing its expiry. Returns failure when the post
  /// does not exist or is not the caller's.
  Future<Either<Failure, Unit>> keepPost({required String postId});
}
