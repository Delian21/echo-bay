/// The app-wide local user id, resolved once at the composition root
/// from the session. Entity ownership checks ("is this mine?") read it
/// here — never against a hardcoded constant.
///
/// The legacy `'local-user'` constant still counts as mine: rows written
/// before the auth seam (seed data, older installs) were stamped with it
/// and must keep their owner. No migration needed.
class LocalIdentity {
  LocalIdentity._();

  static String _id = 'local-user';

  /// The current device user's opaque id. Falls back to the legacy
  /// constant until [init] runs (standalone tests without DI).
  static String get id => _id;

  /// Called once by the composition root after the session resolves.
  static void init(String userId) {
    if (userId.isNotEmpty) _id = userId;
  }

  /// Does this author id belong to the local user? True for the session
  /// id and for the legacy pre-auth constant.
  static bool owns(String authorId) =>
      authorId == _id || authorId == 'local-user';
}
