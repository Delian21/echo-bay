import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/call.dart';

/// The Calls — domain contract. Like the Square: read-mostly, mocked for
/// now; the real implementation will back this with server transport.
/// Streams (not pulls) per ARCHITECTURE.md.
abstract class CallsRepository {
  /// Chronological recents, newest first.
  Stream<Either<Failure, List<CallLogEntry>>> watchRecents();

  /// Redial: records an outgoing call to the same peer and returns the
  /// simulated call duration. The mock "connects" after a beat and fails
  /// when offline, matching the mock-seam pattern of the other modules.
  Future<Either<Failure, CallLogEntry>> placeCall({
    required String peerName,
    required String peerAvatarUrl,
    bool video = false,
  });
}
