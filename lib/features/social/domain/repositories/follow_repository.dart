import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/social_entities.dart';

/// Contract for the follow graph (mock peers in this stage). Vocabulary
/// is fixed: keep close = follow, drift apart = unfollow; "My Circle" is
/// who keeps the local user close, "My Window" is who the local user
/// keeps close. Implementations must not leak storage types here — a
/// future backend replaces them behind this seam.
abstract class FollowRepository {
  /// People the local user keeps close, newest first. Live: re-emits on
  /// graph changes and time-travel moves.
  Stream<Either<Failure, List<PeerFollow>>> watchWindow();

  /// People who keep the local user close, newest first.
  Stream<Either<Failure, List<PeerFollow>>> watchCircle();

  /// The local user's relationship with [peerName]: the follow edge if
  /// one exists and is active, null otherwise. Live.
  Stream<Either<Failure, PeerFollow?>> watchRelationship(String peerName);

  /// A peer's profile (name, bio, avatar seed). Live so a future backend
  /// can push updates.
  Stream<Either<Failure, PeerProfile>> watchPeerProfile(String peerName);

  /// The local user starts keeping [peerName] close.
  Future<Either<Failure, Unit>> keepClose(String peerName);

  /// The local user drifts apart from [peerName]. Soft removal — the
  /// edge's history survives for time travel. No notification fires.
  Future<Either<Failure, Unit>> driftApart(String peerName);

  /// A peer keeps the local user close (mock-peer engine only). Writes
  /// the edge and — uniquely for follows — a notification.
  Future<Either<Failure, Unit>> peerKeepsMeClose(String peerName);

  /// Whether [authorName] is in the local user's window right now. Used
  /// by the Square's "My Window" feed filter (one-shot, cheap).
  Future<bool> isInWindow(String authorName);
}
