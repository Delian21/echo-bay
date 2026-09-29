import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/keepsake_item.dart';

/// Contract for the keepsake wall. Positions are board-relative
/// fractions; persistence is drift (schema v13).
abstract class KeepsakeRepository {
  /// Live board contents, oldest pin first.
  Stream<Either<Failure, List<KeepsakeItem>>> watchBoard();

  /// Pin a Square post. [posX]/[posY] are board fractions; a small
  /// deterministic tilt is applied by the implementation if none given.
  Future<Either<Failure, KeepsakeItem>> pinPost({
    required String postId,
    required double posX,
    required double posY,
    double? rotation,
  });

  /// Pin a handwritten note.
  Future<Either<Failure, KeepsakeItem>> addNote({
    required String noteText,
    required double posX,
    required double posY,
  });

  /// Persist a drag (or tilt change). Board-relative fractions.
  Future<Either<Failure, Unit>> moveItem({
    required String itemId,
    required double posX,
    required double posY,
    double? rotation,
  });

  /// String two items together (one outgoing string per item).
  Future<Either<Failure, Unit>> stringItems({
    required String fromItemId,
    required String toItemId,
  });

  /// Unpin (long-press). The row is hard-deleted; the UI plays the
  /// rewind animation for undo by re-pinning the same payload.
  Future<Either<Failure, Unit>> unpin({required String itemId});
}
