import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';

/// Contract for all domain use cases. Params void when none needed.
abstract class UseCase<Output, Input> {
  Future<Either<Failure, Output>> call(Input params);
}

class NoParams {
  const NoParams();
}
