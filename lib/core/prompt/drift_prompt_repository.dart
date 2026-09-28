import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_repository.dart';
import '../database/app_database.dart';
import '../error/failures.dart';
import 'prompt.dart';
import 'prompt_repository.dart';

/// Drift-backed [PromptRepository]. Local-first: the rotation seeds once
/// (mock stage), prefs/actions are the user's own writes. Server-curated
/// rotation arrives with the real backend — same contract.
class DriftPromptRepository implements PromptRepository {
  DriftPromptRepository(this._db, this._auth);

  final AppDatabase _db;
  final AuthRepository _auth;
  final _uuid = const Uuid();

  Future<String> _userId() async =>
      (await _auth.currentUser()).fold((f) => 'local-user', (s) => s.userId);

  /// The seeded rotation (§6c rule 3: shapes rotate). Mock-stage
  /// vocabulary; the real backend replaces the rows, not the contract.
  static const _rotation = [
    (shape: 'photo', body: 'One photo of what is in front of you.'),
    (shape: 'sentence', body: 'One sentence about today. Just one.'),
    (shape: 'sound', body: 'What are you listening to right now?'),
    (shape: 'desk', body: 'Show your desk as it actually is.'),
    (shape: 'photo', body: 'The sky where you are, this hour.'),
  ];

  Future<void> _ensureSeeded() async {
    final existing = await _db.select(_db.prompts).get();
    if (existing.isNotEmpty) return;
    final now = DateTime.now();
    for (var i = 0; i < _rotation.length; i++) {
      await _db.into(_db.prompts).insert(PromptsCompanion.insert(
            id: _uuid.v4(),
            shape: _rotation[i].shape,
            body: _rotation[i].body,
            rotationIndex: i,
            createdAt: now,
          ));
    }
  }

  @override
  Future<Either<Failure, Prompt?>> activePrompt() async {
    try {
      await _ensureSeeded();
      final userId = await _userId();

      final prefsRow = await (_db.select(_db.promptPrefs)
            ..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();
      // No prefs row = never opted in = no prompt (§6c rule 5). Healthy.
      if (prefsRow == null || !prefsRow.optedIn) return right(null);
      if (prefsRow.pausedUntil != null &&
          prefsRow.pausedUntil!.isAfter(DateTime.now())) {
        return right(null); // paused — also healthy
      }

      // Window check (§6c rule 1): the prompt only exists inside the
      // user's chosen hour window. Outside it, null — not an error.
      final now = DateTime.now();
      if (now.hour < prefsRow.windowHour) return right(null);

      // Rotation: lowest rotationIndex the user has not acted on.
      final actions = await (_db.select(_db.promptActions)
            ..where((t) => t.userId.equals(userId)))
          .get();
      final actedIds = actions.map((a) => a.promptId).toSet();

      final allPrompts = await (_db.select(_db.prompts)
            ..orderBy([
              (t) => OrderingTerm.asc(t.rotationIndex),
            ]))
          .get();
      for (final p in allPrompts) {
        if (!actedIds.contains(p.id)) {
          return right(Prompt(
            id: p.id,
            shape: p.shape,
            body: p.body,
            rotationIndex: p.rotationIndex,
          ));
        }
      }
      // Rotation exhausted: wrap around (a ritual with no end-state
      // pressure — the same prompts return, fresh).
      if (allPrompts.isEmpty) return right(null);
      final first = allPrompts.first;
      return right(Prompt(
        id: first.id,
        shape: first.shape,
        body: first.body,
        rotationIndex: first.rotationIndex,
      ));
    } on Object catch (e) {
      return left(CacheFailure(message: 'activePrompt failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, PromptPreferences>> preferences() async {
    try {
      final userId = await _userId();
      final row = await (_db.select(_db.promptPrefs)
            ..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();
      return right(PromptPreferences(
        userId: userId,
        windowHour: row?.windowHour ?? 9,
        optedIn: row?.optedIn ?? false,
        pausedUntil: row?.pausedUntil,
      ));
    } on Object catch (e) {
      return left(CacheFailure(message: 'preferences failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, PromptPreferences>> updatePreferences(
      PromptPreferences prefs) async {
    try {
      await _db.into(_db.promptPrefs).insertOnConflictUpdate(
            PromptPrefsCompanion.insert(
              userId: prefs.userId,
              windowHour: prefs.windowHour,
              pausedUntil: Value(prefs.pausedUntil),
            ).copyWith(optedIn: Value(prefs.optedIn)),
          );
      return right(prefs);
    } on Object catch (e) {
      return left(
          CacheFailure(message: 'updatePreferences failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, PromptPreferences>> pauseUntil(DateTime until) async {
    final prefs = await preferences();
    final current = prefs.fold((f) => throw f, (p) => p);
    return updatePreferences(
        current.copyWith(pausedUntil: until));
  }

  @override
  Future<Either<Failure, PromptPreferences>> resume() async {
    final prefs = await preferences();
    final current = prefs.fold((f) => throw f, (p) => p);
    return updatePreferences(current.copyWith(clearPause: true));
  }

  @override
  Future<Either<Failure, Unit>> dismissPrompt(
      {required String promptId}) async {
    try {
      final userId = await _userId();
      await _db.into(_db.promptActions).insertOnConflictUpdate(
            PromptActionsCompanion.insert(
              promptId: promptId,
              userId: userId,
              action: 'dismissed',
              actedAt: DateTime.now(),
            ),
          );
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'dismissPrompt failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> recordPosted({
    required String promptId,
    required String postId,
  }) async {
    try {
      final userId = await _userId();
      await _db.into(_db.promptActions).insertOnConflictUpdate(
            PromptActionsCompanion.insert(
              promptId: promptId,
              userId: userId,
              action: 'posted:$postId',
              actedAt: DateTime.now(),
            ),
          );
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'recordPosted failed', cause: e));
    }
  }
}
