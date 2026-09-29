import 'dart:async';

import 'package:drift/drift.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/keepsake_item.dart';
import '../../domain/repositories/keepsake_repository.dart';

/// Drift-backed [KeepsakeRepository] over the keepsake_items table
/// (schema v13). All geometry is board-relative fractions.
class DriftKeepsakeRepository implements KeepsakeRepository {
  DriftKeepsakeRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  /// Time-travel instant (null = present). Board reads show only items
  /// pinned by then; writes are refused (read-only past).
  DateTime? _asOf;

  final _asOfTick = StreamController<DateTime?>.broadcast();

  /// Sets the time-travel instant (null = present). NOTE: unpins and
  /// hard-delete the row, so a past board cannot show an item that was
  /// later unpinned — see the schema constraint note in the feature
  /// summary. Everything else (drags, strings) survives.
  void setAsOf(DateTime? moment) {
    if (_asOf == moment) return;
    _asOf = moment;
    _asOfTick.add(_asOf);
  }

  void _assertWritable() {
    if (_asOf != null) {
      throw StateError('writes are refused while time traveling');
    }
  }

  KeepsakeItem _toItem(KeepsakeItemRow r) => KeepsakeItem(
        id: r.id,
        kind: r.kind,
        postId: r.postId,
        noteText: r.noteText,
        posX: r.posX,
        posY: r.posY,
        rotation: r.rotation,
        strungTo: r.strungTo,
        pinnedAt: r.pinnedAt,
      );

  @override
  Stream<Either<Failure, List<KeepsakeItem>>> watchBoard() {
    final query = _db.select(_db.keepsakeItems)
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.pinnedAt,
              mode: OrderingMode.asc,
            ),
      ]);
    // Time travel: re-run when the as-of instant moves; show only items
    // pinned by then. switchMap tears down the previous watch when the
    // instant moves, so exactly one live query per screen.
    return _asOfTick.stream
        .startWith(null)
        .switchMap((_) => query.watch().map((rows) {
              final moment = _asOf;
              final visible = moment == null
                  ? rows.map(_toItem).toList()
                  : rows
                      .where((r) => !r.pinnedAt.isAfter(moment))
                      .map(_toItem)
                      .toList();
              return Right<Failure, List<KeepsakeItem>>(visible);
            }));
  }

  @override
  Future<Either<Failure, KeepsakeItem>> pinPost({
    required String postId,
    required double posX,
    required double posY,
    double? rotation,
  }) async {
    _assertWritable();
    try {
      final item = KeepsakeItem(
        id: _uuid.v4(),
        kind: KeepsakeKind.post,
        postId: postId,
        posX: posX.clamp(0.0, 0.9),
        posY: posY.clamp(0.0, 0.9),
        rotation: rotation ?? _gentleTilt(postId),
        pinnedAt: DateTime.now(),
      );
      await _insert(item);
      return right(item);
    } on Object catch (e) {
      return left(CacheFailure(message: 'pinPost failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, KeepsakeItem>> addNote({
    required String noteText,
    required double posX,
    required double posY,
  }) async {
    _assertWritable();
    try {
      final item = KeepsakeItem(
        id: _uuid.v4(),
        kind: KeepsakeKind.note,
        noteText: noteText,
        posX: posX.clamp(0.0, 0.9),
        posY: posY.clamp(0.0, 0.9),
        pinnedAt: DateTime.now(),
        rotation: _gentleTilt(noteText),
      );
      await _insert(item);
      return right(item);
    } on Object catch (e) {
      return left(CacheFailure(message: 'addNote failed', cause: e));
    }
  }

  Future<void> _insert(KeepsakeItem item) =>
      _db.into(_db.keepsakeItems).insert(KeepsakeItemsCompanion.insert(
            id: item.id,
            kind: item.kind,
            postId: Value(item.postId),
            noteText: Value(item.noteText),
            posX: item.posX,
            posY: item.posY,
            rotation: item.rotation,
            strungTo: Value(item.strungTo),
            pinnedAt: item.pinnedAt,
          ));

  @override
  Future<Either<Failure, Unit>> moveItem({
    required String itemId,
    required double posX,
    required double posY,
    double? rotation,
  }) async {
    _assertWritable();
    try {
      await (_db.update(_db.keepsakeItems)
            ..where((t) => t.id.equals(itemId)))
          .write(KeepsakeItemsCompanion(
        posX: Value(posX.clamp(0.0, 0.95)),
        posY: Value(posY.clamp(0.0, 0.95)),
        rotation: rotation == null ? const Value.absent() : Value(rotation),
      ));
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'moveItem failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> stringItems({
    required String fromItemId,
    required String toItemId,
  }) async {
    _assertWritable();
    try {
      if (fromItemId == toItemId) return right(unit);
      await (_db.update(_db.keepsakeItems)
            ..where((t) => t.id.equals(fromItemId)))
          .write(KeepsakeItemsCompanion(strungTo: Value(toItemId)));
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'stringItems failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> unpin({required String itemId}) async {
    _assertWritable();
    try {
      // Also drop any string that pointed at this item.
      await (_db.update(_db.keepsakeItems)
            ..where((t) => t.strungTo.equals(itemId)))
          .write(const KeepsakeItemsCompanion(strungTo: Value(null)));
      await (_db.delete(_db.keepsakeItems)
            ..where((t) => t.id.equals(itemId)))
          .go();
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'unpin failed', cause: e));
    }
  }

  /// Deterministic small tilt from the payload — a thumbtacked print,
  /// never a kite (±0.05 rad ≈ ±3°).
  double _gentleTilt(String seed) =>
      ((seed.hashCode % 100) / 100 - 0.5) * 2 * 0.05;
}
