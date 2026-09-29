import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../square/domain/entities/post.dart';
import '../../domain/repositories/profile_repository.dart';

/// The local user's own Square posts — the profile grid's source.
class WatchOwnPosts
    implements UseCase<Stream<Either<Failure, List<Post>>>, NoParams> {
  WatchOwnPosts(this._repo);

  final ProfileRepository _repo;

  @override
  Future<Either<Failure, Stream<Either<Failure, List<Post>>>>> call(
    NoParams params,
  ) async {
    // The repository exposes a stream directly; wrap it so the Either
    // contract holds (a stream is not a value that can fail to load).
    try {
      return Right(_repo.watchOwnPosts());
    } on Object catch (e) {
      return Left(CacheFailure(message: 'watchOwnPosts failed', cause: e));
    }
  }
}
