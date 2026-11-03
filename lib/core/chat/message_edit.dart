/// How long an author may still rewrite a message.
///
/// Shared by the Vault and the Dorms so both surfaces agree on the rule,
/// and so the repository (which enforces it) and the UI (which hides the
/// action) read the same number instead of drifting apart.
const Duration kMessageEditWindow = Duration(minutes: 15);

/// Is [createdAt] still inside the edit window?
///
/// One helper for both the menu gate and the write path: a boundary test
/// that differs by a millisecond between them is how "Edit" ends up
/// visible on a message the repository then refuses.
bool withinMessageEditWindow(DateTime createdAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(createdAt);
  return !elapsed.isNegative && elapsed < kMessageEditWindow;
}
