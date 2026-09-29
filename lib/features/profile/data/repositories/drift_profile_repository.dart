import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/profile/user_profile.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../square/data/datasources/square_local_datasource.dart';
import '../../../square/domain/entities/post.dart';
import '../../domain/repositories/profile_repository.dart';

/// Drift-backed profile data: identity through [AppSettingsStore] (the
/// Settings KV table — key-value rows, so the new bio field needs no
/// schema migration) and the post grid through the Square datasource.
class DriftProfileRepository implements ProfileRepository {
  DriftProfileRepository(this._store, this._square);

  final AppSettingsStore _store;
  final SquareLocalDatasource _square;

  @override
  Future<Either<Failure, UserProfile>> loadProfile() async {
    try {
      return right(await _store.readProfile());
    } on Object catch (e) {
      return left(CacheFailure(message: 'loadProfile failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> saveProfile(UserProfile profile) async {
    try {
      await _store.writeProfile(profile);
      return right(profile);
    } on Object catch (e) {
      return left(CacheFailure(message: 'saveProfile failed', cause: e));
    }
  }

  @override
  Stream<Either<Failure, List<Post>>> watchOwnPosts() async* {
    try {
      final profile = await _store.readProfile();
      yield* _square
          .watchPostsByAuthor(profile.displayName)
          .map((posts) => Right<Failure, List<Post>>(posts));
    } on Object catch (e) {
      yield Left(CacheFailure(message: 'watchOwnPosts failed', cause: e));
    }
  }
}
