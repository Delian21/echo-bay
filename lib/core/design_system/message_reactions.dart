import 'package:flutter/material.dart';

/// The reaction palette, in one place.
///
/// Every surface (Vault DMs, Dorm group chats) reads its choices from
/// [kMessageReactions], so swapping emoji for hand-drawn glyphs later is a
/// one-file change. [ReactionChoice.id] is what reaches storage — the
/// `message_reactions.reaction` column has carried shortcodes since v6, so
/// ids stay stable English words ('heart') and the glyph is presentation.
class ReactionChoice {
  const ReactionChoice({
    required this.id,
    required this.emoji,
    required this.label,
  });

  /// Stored value. Never renamed without a migration — existing rows use
  /// it ('heart' was the double-tap reaction before this menu existed).
  final String id;

  /// What the pill and the picker draw.
  final String emoji;

  /// Screen-reader name.
  final String label;
}

const List<ReactionChoice> kMessageReactions = [
  ReactionChoice(id: 'heart', emoji: '❤️', label: 'Heart'),
  ReactionChoice(id: 'laugh', emoji: '😂', label: 'Laugh'),
  ReactionChoice(id: 'wow', emoji: '😮', label: 'Wow'),
  ReactionChoice(id: 'sad', emoji: '😢', label: 'Sad'),
  ReactionChoice(id: 'thumbs_up', emoji: '👍', label: 'Thumbs up'),
];

/// Glyph for a stored reaction id. Unknown ids (an older build, a peer
/// with a wider palette) fall through as themselves rather than throwing
/// or rendering nothing.
String reactionEmoji(String id) {
  for (final choice in kMessageReactions) {
    if (choice.id == id) return choice.emoji;
  }
  return id;
}

/// Screen-reader name for a stored reaction id.
String reactionLabel(String id) {
  for (final choice in kMessageReactions) {
    if (choice.id == id) return choice.label;
  }
  return id;
}

/// One pill's worth of reactions: who many, and whether it's mine.
@immutable
class ReactionPillData {
  const ReactionPillData({
    required this.reaction,
    required this.count,
    required this.mine,
  });

  final String reaction;
  final int count;

  /// The local user reacted with exactly this emoji.
  final bool mine;
}

/// Collapse raw rows into pills: one per distinct reaction, ordered by
/// count (busiest first) and then by the palette order, so pills don't
/// jump around as counts change.
List<ReactionPillData> summarizeReactions(
  Iterable<({String userId, String reaction})> rows, {
  required String localUserId,
}) {
  final counts = <String, int>{};
  final mine = <String>{};
  for (final row in rows) {
    counts[row.reaction] = (counts[row.reaction] ?? 0) + 1;
    if (row.userId == localUserId) mine.add(row.reaction);
  }
  int paletteIndex(String id) {
    final i = kMessageReactions.indexWhere((c) => c.id == id);
    return i == -1 ? kMessageReactions.length : i;
  }

  final pills = counts.entries
      .map((e) => ReactionPillData(
            reaction: e.key,
            count: e.value,
            mine: mine.contains(e.key),
          ))
      .toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return paletteIndex(a.reaction).compareTo(paletteIndex(b.reaction));
    });
  return pills;
}
