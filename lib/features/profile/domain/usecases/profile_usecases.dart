import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/profile/user_profile.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/repositories/profile_repository.dart';

/// Load the current profile (defaults when never edited).
class LoadProfile implements UseCase<UserProfile, NoParams> {
  LoadProfile(this._repo);

  final ProfileRepository _repo;

  @override
  Future<Either<Failure, UserProfile>> call(NoParams params) =>
      _repo.loadProfile();
}

/// Persist an edited profile (name, bio, avatar, accent).
class SaveProfile implements UseCase<UserProfile, UserProfile> {
  SaveProfile(this._repo);

  final ProfileRepository _repo;

  @override
  Future<Either<Failure, UserProfile>> call(UserProfile params) =>
      _repo.saveProfile(params);
}
