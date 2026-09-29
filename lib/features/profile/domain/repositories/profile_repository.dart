import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/profile/user_profile.dart';
import '../../../square/domain/entities/post.dart';

/// The current user's profile seam: identity (name, bio, avatar) plus the
/// grid of their own Square posts. The domain knows this interface only;
/// persistence details live behind it.
abstract class ProfileRepository {
  /// The stored profile, or the defaults when never edited.
  Future<Either<Failure, UserProfile>> loadProfile();

  /// Persist identity changes. Returns the saved profile on success.
  Future<Either<Failure, UserProfile>> saveProfile(UserProfile profile);

  /// The local user's own non-deleted Square posts, newest first — the
  /// profile grid. Live: emits again when a post is created/deleted.
  Stream<Either<Failure, List<Post>>> watchOwnPosts();
}
