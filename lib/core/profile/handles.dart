/// Local @handle helpers.
///
/// A handle is a display slug, not a globally unique identifier — global
/// uniqueness waits on a backend. The local user picks their own in the
/// profile editor; a peer's handle is derived from their display name, so
/// every person is addressable as `/person/:handle` today with no server.
library;

/// Longest allowed handle, in characters.
const int kMaxHandleLength = 24;

final RegExp _invalidRuns = RegExp(r'[^a-z0-9]+');
final RegExp _edgeUnderscores = RegExp(r'^_+|_+$');
final RegExp _valid = RegExp(r'^[a-z0-9](?:[a-z0-9_]{0,22}[a-z0-9])$');

/// Slugifies [name] into a handle: lowercased, runs of anything else
/// collapsed to a single underscore, trimmed and capped. Never empty —
/// an unusable name falls back to `sketcher`.
String handleForName(String name) {
  var slug = name.toLowerCase().trim().replaceAll(_invalidRuns, '_');
  slug = slug.replaceAll(RegExp(r'_{2,}'), '_');
  slug = slug.replaceAll(_edgeUnderscores, '');
  if (slug.length > kMaxHandleLength) {
    slug = slug.substring(0, kMaxHandleLength);
    slug = slug.replaceAll(_edgeUnderscores, '');
  }
  return slug.isEmpty ? 'sketcher' : slug;
}

/// The display name behind a handle — the inverse slug, best-effort.
/// `rune_sketcher` reads back as `Rune Sketcher`.
String nameForHandle(String handle) {
  final words = handle.split('_').where((w) => w.isNotEmpty);
  if (words.isEmpty) return handle;
  return words
      .map((w) => w.length == 1
          ? w.toUpperCase()
          : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// True when [handle] is well formed: 2–24 chars of `[a-z0-9_]`, with a
/// letter or digit at each end. Used only to coach the editor — the
/// stored value is always a slug, so a malformed handle never reaches a
/// route.
bool isValidHandle(String handle) =>
    handle.length >= 2 &&
    handle.length <= kMaxHandleLength &&
    _valid.hasMatch(handle);
