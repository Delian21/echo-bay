import '../../../../core/profile/handles.dart';

import 'social_entities.dart';

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

  /// Handle assignment for the cast. Built once from [names], so the
  /// name ↔ handle mapping is identical on every launch and on every
  /// device without any stored state. Two cast members that slugify
  /// alike get distinct handles rather than shadowing each other.
  static final HandleDirectory handles = HandleDirectory(names);

  /// The peer's stable, collision-free @handle.
  static String handleFor(String name) => handles.handleFor(name);

  /// The peer behind [handle], or null when it was never claimed.
  static String? nameFor(String handle) => handles.nameFor(handle);

  /// Peers matching [query], best match first, so a typed `@handle`
  /// jumps straight to that person instead of only being reachable by
  /// tapping one of their posts.
  ///
  /// Match tiers, in order: an exact handle, a handle starting with the
  /// query, a display name starting with it, then a name containing it.
  /// The leading `@` is optional — people type it, but nothing requires
  /// it. An empty query matches nobody, so the section only appears
  /// once something has actually been typed.
  static List<PeerProfile> lookup(String query) {
    final q = query.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
    if (q.isEmpty) return const <PeerProfile>[];
    final ranked = <(int, PeerProfile)>[];
    for (final name in names) {
      final peer = bio(name);
      final handle = handleFor(name);
      final lowerName = peer.name.toLowerCase();
      final int tier;
      if (handle == q) {
        tier = 0;
      } else if (handle.startsWith(q)) {
        tier = 1;
      } else if (lowerName.startsWith(q)) {
        tier = 2;
      } else if (lowerName.contains(q)) {
        tier = 3;
      } else {
        continue;
      }
      ranked.add((tier, peer));
    }
    // Stable within a tier: the cast order survives, which is the order
    // the town is introduced in.
    ranked.sort((a, b) => a.$1.compareTo(b.$1));
    return ranked.map((r) => r.$2).toList();
  }

  static PeerProfile bio(String name) => PeerProfile(
        name: name,
        bio: _bios[name] ?? 'Here, mostly.',
        avatarSeed: name.hashCode & 0x7FFFFFFF,
      );
}