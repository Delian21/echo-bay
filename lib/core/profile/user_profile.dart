import 'package:flutter/material.dart';

import 'status.dart';

/// The local user's profile. Stored in the settings key-value table —
/// one key per field, no schema migration needed for a new field (bump
/// only if a field needs indexing, which a profile never does).
@immutable
class UserProfile {
  const UserProfile({
    this.displayName = 'You',
    this.handle = 'you',
    this.bio,
    this.avatarPath,
    this.accentColor = const Color(0xFFD98324),
    this.statusText,
    this.statusExpiresAt,
  });

  final String displayName;

  /// The local user's @handle — a display slug for `/person/:handle`
  /// links, not a globally unique id (uniqueness awaits a backend).
  /// Edited in the profile editor; the stored value is always a valid
  /// slug (see handles.dart).
  final String handle;

  /// Handwritten one-liner shown under the display name on the profile
  /// page (Caveat). Null = never written; the UI shows a quiet invitation
  /// instead of an empty gap.
  final String? bio;

  /// Optional local avatar picked from the device's files (via
  /// image_picker). Stored as a file path — no network dependency; when
  /// absent the UI renders initials on the accent color.
  final String? avatarPath;

  /// App accent color — replaces the theme's primary role.
  final Color accentColor;

  /// The short status line ("one sentence") shown under the name on the
  /// profile, on other people's pages that read this profile, in DM
  /// headers and as a tooltip on feed avatars. Null = never set.
  ///
  /// Visibility is computed at display time from [statusExpiresAt]; a
  /// lapsed status is hidden without any background job.
  final String? statusText;

  /// When [statusText] stops showing. Null = it never fades ("Never").
  final DateTime? statusExpiresAt;

  /// The status line as it should be shown at [now], or null when absent
  /// or already faded.
  String? activeStatusTextAt(DateTime now) =>
      statusIsActive(statusText, statusExpiresAt, now)
          ? statusText!.trim()
          : null;

  /// Sets (or clears, with a null [text]) the status line as one edit, so
  /// "Never" can drop a previous expiry instead of keeping it.
  UserProfile withStatus(String? text, DateTime? expiresAt) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) {
      return UserProfile(
        displayName: displayName,
        handle: handle,
        bio: bio,
        avatarPath: avatarPath,
        accentColor: accentColor,
      );
    }
    return UserProfile(
      displayName: displayName,
      handle: handle,
      bio: bio,
      avatarPath: avatarPath,
      accentColor: accentColor,
      statusText: trimmed,
      statusExpiresAt: expiresAt,
    );
  }

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
    String? handle,
    String? bio,
    String? avatarPath,
    Color? accentColor,
    bool clearAvatar = false,
    bool clearBio = false,
    String? statusText,
    DateTime? statusExpiresAt,
    bool clearStatus = false,
  }) =>
      UserProfile(
        displayName: displayName ?? this.displayName,
        handle: handle ?? this.handle,
        bio: clearBio ? null : (bio ?? this.bio),
        avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
        accentColor: accentColor ?? this.accentColor,
        statusText: clearStatus ? null : (statusText ?? this.statusText),
        statusExpiresAt:
            clearStatus ? null : (statusExpiresAt ?? this.statusExpiresAt),
      );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.displayName == displayName &&
      other.handle == handle &&
      other.bio == bio &&
      other.avatarPath == avatarPath &&
      other.accentColor.toARGB32() == accentColor.toARGB32() &&
      other.statusText == statusText &&
      other.statusExpiresAt == statusExpiresAt;

  @override
  int get hashCode => Object.hash(displayName, handle, bio, avatarPath,
      accentColor.toARGB32(), statusText, statusExpiresAt);
}

/// Preset accent palette for the profile editor — the ink pots. Curated
/// to the analog-sketchbook setting: fountain-pen blues, dusk ambers,
/// marker warmths and archive inks (iron-gall sepia, oxblood), so every
/// choice reads as part of the same notebook rather than a free-for-all
/// colour wheel. The first entry is the app's shipped default.
const kAccentPalette = <Color>[
  Color(0xFFD98324), // golden-hour amber (default — the sketchbook's own ink)
  Color(0xFF2C5FDB), // fountain-pen cobalt
  Color(0xFFC2542E), // terracotta pencil
  Color(0xFF1E7D4F), // moss marker
  Color(0xFF6B4A2B), // iron-gall sepia
  Color(0xFF8E3B46), // oxblood
];
