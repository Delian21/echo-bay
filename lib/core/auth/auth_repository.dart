import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';
import 'session.dart';
import 'session_store.dart';

/// Minimal auth contract: the app needs exactly one thing from auth —
/// "who am I" — plus the guarantee that the answer is durable. Token
/// refresh, multi-device, and real credential flows arrive with the real
/// backend; this contract is shaped so those grow *inside* the auth
/// module, not as a rewrite of its consumers.
abstract class AuthRepository {
  /// The active session. Local-only stage: resolves immediately from the
  /// device-stable [SessionStore]. Real stage: validates tokens, falls
  /// back to the stored session offline.
  Future<Either<Failure, Session>> currentUser();

  /// Wipes the local identity. Real stage also revokes server-side state.
  Future<Either<Failure, Unit>> signOut();
}

/// Local-only [AuthRepository]: identity is minted and stored on this
/// device (see [SessionStore]). No server, no credentials — but every
/// consumer is already written against the contract the real backend
/// will implement.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store);

  final SessionStore _store;
  Session? _cached;

  @override
  Future<Either<Failure, Session>> currentUser() async {
    try {
      _cached ??= await _store.loadOrCreate();
      return right(_cached!);
    } on Object catch (e) {
      return left(CacheFailure(message: 'session unavailable', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _store.clear();
      _cached = null;
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'signOut failed', cause: e));
    }
  }
}
