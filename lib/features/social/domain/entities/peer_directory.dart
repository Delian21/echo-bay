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

  static PeerProfile bio(String name) => PeerProfile(
        name: name,
        bio: _bios[name] ?? 'Here, mostly.',
        avatarSeed: name.hashCode & 0x7FFFFFFF,
      );
}