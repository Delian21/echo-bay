import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'session.dart';

/// Durable, encrypted-at-rest storage for the local session.
///
/// Identity posture (see ARCHITECTURE.md, "Identity posture"):
///  - the user id is generated once on this device, stored in
///    [FlutterSecureStorage] (Keychain / Keystore / Windows credential
///    vault behind the plugin), and never re-derived from any personal
///    identifier;
///  - the server will only ever see this opaque string — contact
///    discovery via private set intersection is the design constraint
///    for the real backend, so no plaintext identifiers are uploaded;
///  - when real E2EE lands in vault/security/, the identity keys live in
///    the same store; this class is the single seam for that.
abstract class SessionStore {
  /// Returns the device-stable session, creating it on first call.
  Future<Session> loadOrCreate();

  /// Destroys the session (logout / panic wipe). Next [loadOrCreate]
  /// mints a fresh identity — old data becomes unreachable, which is
  /// the point.
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'vault_session_user_id';
  static const _createdKey = 'vault_session_created_at';

  @override
  Future<Session> loadOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) {
      final created = await _storage.read(key: _createdKey);
      return Session(
        userId: existing,
        createdAt: DateTime.tryParse(created ?? '') ?? DateTime.now(),
      );
    }
    // Mint a fresh opaque id: UUID v4 from the platform CSPRNG. No
    // personal input, no derivability.
    final userId = const Uuid().v4();
    final now = DateTime.now();
    await _storage.write(key: _key, value: userId);
    await _storage.write(key: _createdKey, value: now.toIso8601String());
    return Session(userId: userId, createdAt: now);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _createdKey);
  }
}

/// In-memory [SessionStore] for tests that pump shells without DI. The
/// id is random-but-stable per instance so assertions on authored
/// content stay reproducible within a test.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore({this.fixedUserId});

  /// Optional deterministic id for tests that assert on exact ids.
  final String? fixedUserId;
  Session? _session;

  @override
  Future<Session> loadOrCreate() async {
    _session ??= Session(
      userId: fixedUserId ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );
    return _session!;
  }

  @override
  Future<void> clear() async => _session = null;
}
