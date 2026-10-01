import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';
import 'session.dart';
import 'session_store.dart';

/// Who is asking to be signed in. The local stage knows one kind — an
/// email label; the real backend adds providers beside it.
enum AuthMethod { email }

/// The request to sign the cover (create an account) or open an
/// existing sketchbook on this device. No password travels in this
/// object at any stage: the local stage verifies nothing, and the real
/// backend will use provider tokens or email links — never a stored
/// plaintext.
class AuthCredentials {
  const AuthCredentials({required this.method, required this.email});

  final AuthMethod method;
  final String email;
}

/// Auth contract. The app needs exactly three things: "who am I" (as a
/// stream, so sign-in/out is reactive), the ability to create a local
/// account, and the ability to open the existing one. Results are
/// [Either<Failure, T>]; no exception crosses this seam.
abstract class AuthRepository {
  /// The active session, re-emitted on sign-in and sign-out. Null means
  /// the book is closed — the UI shows Sign the cover / Open your
  /// sketchbook.
  Stream<Session?> watchCurrentUser();

  /// One-shot read for callers that bootstrap before subscribing.
  Future<Either<Failure, Session>> currentUser();

  /// Sign the cover: create the local profile on this device with the
  /// given name/avatar/email label. Real stage: server round-trip.
  Future<Either<Failure, Session>> signUp({
    required String displayName,
    required AuthCredentials credentials,
    String? avatarPath,
  });

  /// Open your sketchbook: sign in to the local profile that already
  /// lives on this device. The email must match the stored label —
  /// a wrong one is a [UnauthorizedFailure], which is honest about the
  /// local stage's limits without pretending to be security.
  Future<Either<Failure, Session>> signIn(AuthCredentials credentials);

  /// Close the book: clear the in-memory session AND the stored email
  /// label, but keep the opaque user id and all local data — the same
  /// sketchbook reopens on the next sign-in. (Panic-wipe semantics live
  /// in Clear all data, not here.)
  Future<Either<Failure, Unit>> signOut();

  /// Has a cover ever been signed on this device? Chooses the auth
  /// gate's screen: true → Open your sketchbook, false → Sign the
  /// cover. Survives sign-out; only a wiped device says false.
  Future<bool> hasCoverBeenSigned();
}

/// Local-only [AuthRepository]: NOT real security. The opaque user id is
/// minted once per device (see [SessionStore]); the email is a stored
/// label, never a verified credential; no password exists anywhere in
/// this flow. Every consumer is already written against the contract a
/// Firebase/Supabase implementation will take over — swap the get_it
/// registration and the screens are unchanged.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store);

  final SessionStore _store;
  Session? _cached;

  /// Broadcast on every auth transition (sign-in, sign-up, sign-out) so
  /// the running app can react immediately — sign-out closes down to
  /// Open your sketchbook without waiting for the next boot.
  final _changes = StreamController<void>.broadcast();

  /// Normalized stored email label. Kept outside [SessionStore] so the
  /// store stays exactly what it was: an opaque-id vault.
  static const _emailKey = 'auth_email_label';

  /// Distinguishes "never signed a cover here" from "signed, then closed
  /// the book": set at signUp, survives signOut. Sign-out clears only
  /// the email label, so the gate must not use the label to pick the
  /// sign-in screen.
  static const _hasCoverKey = 'auth_has_cover';

  Future<String?> _storedEmail() async {
    try {
      return await _store.readRaw(_emailKey);
    } on Object {
      return null;
    }
  }

  Future<void> _saveEmail(String? email) async {
    try {
      await _store.writeRaw(_emailKey, email);
    } on Object {
      // A failed label write keeps the session value; sign-in still
      // works by identity.
    }
  }

  @override
  Stream<Session?> watchCurrentUser() async* {
    final session = await currentUser();
    yield session.fold((_) => null, (s) => s);
    // Then stay live: every transition re-reads the session.
    yield* _changes.stream
        .asyncMap((_) async => (await currentUser()).fold(
              (_) => null,
              (s) => s,
            ));
  }

  @override
  Future<Either<Failure, Session>> currentUser() async {
    try {
      _cached ??= await _store.loadOrCreate();
      final email = _cached!.email ?? await _storedEmail();
      if (email != null && _cached!.email == null) {
        _cached = _cached!.copyWith(email: email);
      }
      return right(_cached!);
    } on Object catch (e) {
      return left(CacheFailure(message: 'session unavailable', cause: e));
    }
  }

  @override
  Future<Either<Failure, Session>> signUp({
    required String displayName,
    required AuthCredentials credentials,
    String? avatarPath,
  }) async {
    try {
      _cached ??= await _store.loadOrCreate();
      _cached = _cached!.copyWith(email: credentials.email.trim());
      await _saveEmail(credentials.email.trim());
      await _store.writeRaw(_hasCoverKey, 'true');
      _changes.add(null);
      return right(_cached!);
    } on Object catch (e) {
      return left(CacheFailure(message: 'signUp failed', cause: e));
    }
  }

  @override
  /// Has a cover ever been signed on this device? True after the first
  /// signUp, even once the book is closed (email label cleared). Fresh
  /// devices and post-Clear-all-data return false. Used by the auth
  /// gate to choose between Open your sketchbook and Sign the cover.
  Future<bool> hasCoverBeenSigned() async {
    try {
      final flag = await _store.readRaw(_hasCoverKey);
      return flag == 'true';
    } on Object {
      return false;
    }
  }

  @override
  Future<Either<Failure, Session>> signIn(AuthCredentials credentials) async {
    try {
      final session = (await currentUser()).fold((f) => throw f, (s) => s);
      final stored = session.email?.trim().toLowerCase();
      final given = credentials.email.trim().toLowerCase();
      if (stored != null && stored.isNotEmpty && stored != given) {
        return left(const UnauthorizedFailure(
          message: 'That\u2019s not the name this sketchbook knows.',
        ));
      }
      if (stored == null || stored.isEmpty) {
        // Never signed the cover: adopt the email as the label.
        _cached = session.copyWith(email: credentials.email.trim());
        await _saveEmail(credentials.email.trim());
        _changes.add(null);
        return right(_cached!);
      }
      _changes.add(null);
      return right(session);
    } on Failure catch (f) {
      return left(f);
    } on Object catch (e) {
      return left(CacheFailure(message: 'signIn failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      // Close the book, keep the pages: the opaque id stays (so all
      // authored rows still belong to this user when they return) and
      // only the email label is cleared.
      _cached = await _store.loadOrCreate();
      await _saveEmail(null);
      // The cover stays signed (hasCoverBeenSigned stays true) — only
      // Clear all data mints a fresh book.
      _cached = _cached!.copyWith(email: null);
      _changes.add(null);
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'signOut failed', cause: e));
    }
  }
}
