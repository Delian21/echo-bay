import 'package:flutter/foundation.dart';

/// A status line and, optionally, when it lapses. Shared by the local
/// profile ([UserProfile]) and the mock cast ([PeerProfile]) so both
/// surfaces answer "is this still up?" the same way.
///
/// Nothing here schedules a background job: visibility is a function of
/// [expiresAt] and the moment of display (see [statusIsActive]).
@immutable
class StatusLineData {
  const StatusLineData(this.text, {this.expiresAt});

  final String text;

  /// Null = never fades. Buttons in the sheet map "Never" to null.
  final DateTime? expiresAt;

  bool isActiveAt(DateTime now) => statusIsActive(text, expiresAt, now);

  @override
  bool operator ==(Object other) =>
      other is StatusLineData &&
      other.text == text &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(text, expiresAt);
}

/// One choice in the sheet's "Fades in" row. [duration] null = Never.
@immutable
class StatusFade {
  const StatusFade(this.label, this.duration);

  final String label;
  final Duration? duration;

  bool get never => duration == null;
}

/// The fade choices, in sheet order. One list so the labels can be edited
/// in one place (and so a real backend can mirror the same set).
const List<StatusFade> kStatusFades = <StatusFade>[
  StatusFade('4 hours', Duration(hours: 4)),
  StatusFade('24 hours', Duration(hours: 24)),
  StatusFade('3 days', Duration(days: 3)),
  StatusFade('Never', null),
];

/// Index of the default choice ("24 hours").
const int kStatusDefaultFadeIndex = 1;

/// A status line is capped so it stays a line, not a paragraph.
const int kStatusMaxLength = 60;

/// Placeholder shown on the local profile when there is no status.
const String kStatusPlaceholder = "What's on your mind today?";

/// Whether a status is visible at [now].
///
/// Empty/blank text is never active. A null expiry never lapses. An expiry
/// exactly at [now] counts as gone (the status is over, not still up).
bool statusIsActive(String? text, DateTime? expiresAt, DateTime now) {
  if (text == null || text.trim().isEmpty) return false;
  if (expiresAt == null) return true;
  return expiresAt.isAfter(now);
}

/// Picks the sheet's preselected fade for a status with [remaining] left.
///
/// A status with no expiry preselects "Never"; otherwise the closest
/// choice wins, so reopening the sheet on a status set yesterday shows
/// "24 hours" rather than snapping to the default.
StatusFade fadeForRemaining(Duration? remaining) {
  if (remaining == null) return kStatusFades.last;
  StatusFade best = kStatusFades[kStatusDefaultFadeIndex];
  var bestDelta = Duration.zero;
  var first = true;
  for (final fade in kStatusFades) {
    final duration = fade.duration;
    if (duration == null) continue;
    final delta = (duration - remaining).abs();
    if (first || delta < bestDelta) {
      best = fade;
      bestDelta = delta;
      first = false;
    }
  }
  return best;
}
