import 'package:equatable/equatable.dart';

/// Domain-level failure hierarchy. Repositories return
/// `Either<Failure, T>` — never throw across the domain boundary.
sealed class Failure extends Equatable {
  const Failure({this.message, this.cause});

  final String? message;
  final Object? cause;

  @override
  List<Object?> get props => [message, cause];
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message, super.cause});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message, super.cause});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message, super.cause});
}

class CryptoFailure extends Failure {
  const CryptoFailure({super.message, super.cause});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message, super.cause});
}

/// A state conflict — e.g. editing a tombstoned (deleted) message. The
/// request is well-formed but the local state forbids it.
class ConflictFailure extends Failure {
  const ConflictFailure({super.message, super.cause});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message, super.cause});
}
