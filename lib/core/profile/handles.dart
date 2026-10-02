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

/// A one-to-one name ↔ handle assignment.
///
/// [handleForName] is a pure function of a single name, so two different
/// names that slugify alike — "Bo Tamm" and "Bo-Tamm" — would land on
/// the same URL and the second would shadow the first. This directory
/// keeps the mapping injective: the first name to claim a slug keeps the
/// bare form, later ones take `_2`, `_3`, and so on.
///
/// Built from a known cast, the assignment is deterministic — the same
/// peer gets the same handle on every launch and on every device, with
/// no storage involved and no handle ever renumbered by a later arrival.
/// Names outside the cast are claimed lazily on first sight; those hold
/// for the session, which is the honest limit for a mock stage. A real
/// backend turns uniqueness into a server-side guarantee and this class
/// becomes the client-side cache of it.
class HandleDirectory {
  HandleDirectory(Iterable<String> names) {
    for (final name in names) {
      handleFor(name);
    }
  }

  final Map<String, String> _byName = {};
  final Map<String, String> _byHandle = {};

  /// The handle for [name], claiming one on first sight. Idempotent:
  /// the same name always gets the same handle back, so a peer's URL is
  /// safe to share the moment it is first tapped.
  String handleFor(String name) {
    final existing = _byName[name];
    if (existing != null) return existing;
    final base = handleForName(name);
    var candidate = base;
    var attempt = 1;
    while (_byHandle.containsKey(candidate)) {
      attempt++;
      candidate = _withSuffix(base, attempt);
    }
    _byName[name] = candidate;
    _byHandle[candidate] = name;
    return candidate;
  }

  /// The name behind [handle], or null when that handle was never
  /// claimed. A deep link for a peer this install has never seen falls
  /// back to the inverse slug.
  String? nameFor(String handle) => _byHandle[handle];

  /// Every handle claimed so far, in assignment order.
  Iterable<String> get handles => _byHandle.keys;

  /// Appends `_n` to [base] without breaking the length cap — the base
  /// gives up characters rather than the suffix pushing the handle past
  /// [kMaxHandleLength].
  static String _withSuffix(String base, int n) {
    final suffix = '_$n';
    final room = kMaxHandleLength - suffix.length;
    final trimmed =
        base.length <= room ? base : base.substring(0, room < 1 ? 1 : room);
    return '${trimmed.replaceAll(_edgeUnderscores, '')}$suffix';
  }
}
