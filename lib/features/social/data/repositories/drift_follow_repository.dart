import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:fpdart/fpdart.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/repositories/follow_repository.dart';

/// Drift-backed [FollowRepository]. Soft removal: drifting apart stamps
/// `drifted_at` and the row survives, so time travel can reconstruct the
/// circle and window as of any past moment. Reads are as-of aware (an
/// edge counts while `followed_at <= moment` and it had not yet drifted
/// by then); writes are refused while traveling.
class DriftFollowRepository implements FollowRepository {
  DriftFollowRepository(this._db, {required this.localUserId});

  final AppDatabase _db;
  final String localUserId;
  final _uuid = const Uuid();

  /// Time-travel instant (null = present).
  DateTime? _asOf;

  final _asOfTick = StreamController<DateTime?>.broadcast();

  /// Wired by the shell like the other datasources' setAsOf.
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

  DateTime get _now => _db.clock();

  Stream<DateTime?> get _asOfChanges => _asOfTick.stream.startWith(null);

  /// Visibility clause for one edge as of [_asOf]: it existed by then
  /// and had not yet drifted. In the present that's simply "active".
  Expression<bool> _visibleAsOf(Follows t) {
    final moment = _asOf;
    final active = t.driftedAt.isNull();
    if (moment == null) return active;
    return t.followedAt.isSmallerOrEqualValue(moment) &
        (t.driftedAt.isNull() | t.driftedAt.isBiggerThanValue(moment));
  }

  Future<FollowRow?> _findEdge(String followerId, String followedId) {
    final query = _db.select(_db.follows)
      ..where((t) =>
          t.followerId.equals(followerId) & t.followedId.equals(followedId));
    return query.getSingleOrNull();
  }

  PeerFollow _toEntity(FollowRow r) => PeerFollow(
        id: r.id,
        followerId: r.followerId,
        followerName: r.followerName,
        followedId: r.followedId,
        followedName: r.followedName,
        followedAt: r.followedAt,
        driftedAt: r.driftedAt,
      );

  /// Live list of active edges in one direction, newest first.
  Stream<Either<Failure, List<PeerFollow>>> _watchEdges({
    required bool intoCircle,
  }) {
    final query = _db.select(_db.follows)
      ..where((t) => intoCircle
          ? _visibleAsOf(t) & t.followedId.equals(localUserId)
          : _visibleAsOf(t) & t.followerId.equals(localUserId))
      ..orderBy([(t) => OrderingTerm(expression: t.followedAt, mode: OrderingMode.desc)]);
    return _asOfChanges.switchMap((_) =>
        query.watch().map((rows) => Right<Failure, List<PeerFollow>>(
              rows.map(_toEntity).toList(),
            )));
  }

  @override
  Stream<Either<Failure, List<PeerFollow>>> watchWindow() =>
      _watchEdges(intoCircle: false);

  @override
  Stream<Either<Failure, List<PeerFollow>>> watchCircle() =>
      _watchEdges(intoCircle: true);

  @override
  Stream<Either<Failure, PeerFollow?>> watchRelationship(String peerName) {
    final query = _db.select(_db.follows)
      ..where((t) =>
          t.followedName.equals(peerName) & t.followerId.equals(localUserId))
      ..orderBy([(t) => OrderingTerm(expression: t.followedAt, mode: OrderingMode.desc)])
      ..limit(1);
    return _asOfChanges.switchMap((_) => query.watchSingleOrNull().map(
          (row) => Right<Failure, PeerFollow?>(
              _edgeVisibleAsOf(row) ? _toEntity(row!) : null),
        ));
  }

  bool _edgeVisibleAsOf(FollowRow? row) {
    if (row == null) return false;
    final moment = _asOf;
    if (moment == null) return row.driftedAt == null;
    return !row.followedAt.isAfter(moment) &&
        (row.driftedAt == null || row.driftedAt!.isAfter(moment));
  }

  @override
  Stream<Either<Failure, PeerProfile>> watchPeerProfile(String peerName) {
    // Const bios in the mock stage; a backend replaces this stream.
    final profile = PeerDirectory.bio(peerName);
    return _asOfChanges.switchMap((_) => Stream.value(
        Right<Failure, PeerProfile>(profile)));
  }

  @override
  Future<Either<Failure, Unit>> keepClose(String peerName) async {
    _assertWritable();
    try {
      final existing = await _findEdge(localUserId, peerName);
      if (existing == null) {
        await _db.into(_db.follows).insert(FollowsCompanion.insert(
              id: _uuid.v4(),
              followerId: localUserId,
              followerName: 'You',
              followedId: peerName,
              followedName: peerName,
              followedAt: _now,
            ));
      } else if (existing.driftedAt != null) {
        // Re-follow clears the tombstone; the edge's history survives.
        await (_db.update(_db.follows)
              ..where((t) => t.id.equals(existing.id)))
            .write(const FollowsCompanion(driftedAt: Value(null)));
      }
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'keepClose failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> driftApart(String peerName) async {
    _assertWritable();
    try {
      final existing = await _findEdge(localUserId, peerName);
      if (existing == null || existing.driftedAt != null) {
        return right(unit); // idempotent
      }
      await (_db.update(_db.follows)..where((t) => t.id.equals(existing.id)))
          .write(FollowsCompanion(driftedAt: Value(_now)));
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'driftApart failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> peerKeepsMeClose(String peerName) async {
    _assertWritable();
    try {
      final existing = await _findEdge(peerName, localUserId);
      if (existing != null && existing.driftedAt == null) {
        return right(unit);
      }
      if (existing == null) {
        await _db.into(_db.follows).insert(FollowsCompanion.insert(
              id: _uuid.v4(),
              followerId: peerName,
              followerName: peerName,
              followedId: localUserId,
              followedName: 'You',
              followedAt: _now,
            ));
      } else {
        await (_db.update(_db.follows)
              ..where((t) => t.id.equals(existing.id)))
            .write(const FollowsCompanion(driftedAt: Value(null)));
      }
      return right(unit);
    } on Object catch (e) {
      return left(
          CacheFailure(message: 'peerKeepsMeClose failed', cause: e));
    }
  }

  @override
  Future<bool> isInWindow(String authorName) async {
    final edge = await _findEdge(localUserId, authorName);
    return edge != null && edge.driftedAt == null;
  }

  /// Seeds: a few peers already keep the local user close. Stamped a
  /// little in the past so time travel into "just after first run" still
  /// shows a lived-in circle.
  Future<void> seedIfEmpty() async {
    final count = await _db.select(_db.follows).get().then((r) => r.length);
    if (count > 0) return;
    final base = _now.subtract(const Duration(days: 9));
    for (final (i, name) in PeerDirectory.circleSeedNames.indexed) {
      await _db.into(_db.follows).insert(FollowsCompanion.insert(
            id: _uuid.v4(),
            followerId: name,
            followerName: name,
            followedId: localUserId,
            followedName: 'You',
            followedAt: base.subtract(Duration(hours: i * 7)),
          ));
    }
  }
}

/// Hand-written peer facts for the mock stage — the same small-town cast
/// as the Vault personas. Bios live here (not in the DB) until a real
/// backend owns profiles.
class PeerDirectory {
  /// Peers who keep the local user close from the start.
  static const circleSeedNames = ['Mila', 'Rune'];

  /// All named mock peers, for avatar/bio lookups.
  static const names = ['Rune', 'Mila', 'Ops', 'Kai', 'Ada', 'Mira'];

  static const _bios = {
    'Rune': 'Fixes radios. Writes postcards to no one in particular.',
    'Mila': 'Paints the hour before sunset, over and over.',
    'Ops': 'Keeps the lights on. Does not talk about it.',
    'Kai': 'Collects field recordings of quiet places.',
    'Ada': 'Reads twice: once for the words, once for the margins.',
    'Mira': 'Bakes bread on rainy days. Sells none of it.',
  };

  static PeerProfile bio(String name) => PeerProfile(
        name: name,
        bio: _bios[name] ?? 'Here, mostly.',
        avatarSeed: name.hashCode & 0x7FFFFFFF,
      );
}
