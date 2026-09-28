import 'package:flutter/material.dart';

/// The local user's profile. Stored in the settings key-value table —
/// three keys, no schema migration needed for a new field (bump only if
/// a field needs indexing, which a profile never does).
@immutable
class UserProfile {
  const UserProfile({
    this.displayName = 'You',
    this.avatarPath,
    this.accentColor = const Color(0xFF2C5FDB),
  });

  final String displayName;

  /// Optional local avatar picked from the device's files (via
  /// image_picker). Stored as a file path — no network dependency; when
  /// absent the UI renders initials on the accent color.
  final String? avatarPath;

  /// App accent color — replaces the theme's primary role.
  final Color accentColor;

  /// Up-to-two-letter initials for the fallback avatar.
  String initials() {
    final words = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarPath,
    Color? accentColor,
    bool clearAvatar = false,
  }) =>
      UserProfile(
        displayName: displayName ?? this.displayName,
        avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
        accentColor: accentColor ?? this.accentColor,
      );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.displayName == displayName &&
      other.avatarPath == avatarPath &&
      other.accentColor.toARGB32() == accentColor.toARGB32();

  @override
  int get hashCode =>
      Object.hash(displayName, avatarPath, accentColor.toARGB32());
}

/// Preset accent palette for the profile editor — the ink pots. Curated
/// to the analog-sketchbook setting: fountain-pen blues, dusk ambers,
/// marker warmths and archive inks (iron-gall sepia, oxblood), so every
/// choice reads as part of the same notebook rather than a free-for-all
/// colour wheel. The first entry is the app's shipped default.
const kAccentPalette = <Color>[
  Color(0xFF2C5FDB), // fountain-pen cobalt (default)
  Color(0xFFD98324), // golden-hour amber
  Color(0xFFC2542E), // terracotta pencil
  Color(0xFF1E7D4F), // moss marker
  Color(0xFF6B4A2B), // iron-gall sepia
  Color(0xFF8E3B46), // oxblood
];
