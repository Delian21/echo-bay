import 'dart:math' as math;

import '../../../../core/database/app_database.dart'
    show NotificationKind;

/// One planned peer event for a freshly published post.
class PlannedPeerEvent {
  const PlannedPeerEvent({
    required this.peerName,
    required this.kind,
    required this.delay,
    this.commentBody,
    this.reaction,
  });

  final String peerName;
  final NotificationKind kind;
  final Duration delay;

  /// Non-null for [NotificationKind.comment].
  final String? commentBody;

  /// Emoji reaction for [NotificationKind.reaction].
  final String? reaction;
}

/// In-character mock peers (same small-town cast as the Vault's ticker).
class PeerPlanner {
  PeerPlanner({double Function()? random})
      : _random = random ?? _defaultRandom;

  /// Injectable RNG so tests can pin the draw.
  final double Function() _random;

  static double _defaultRandom() => math.Random().nextDouble();

  static const peers = ['Rune', 'Mila', 'Ops'];

  static const _commentPool = [
    'This one belongs on the board.',
    'Okay, the light in this is unfair.',
    'Saving this for a gray day.',
    'The whole square felt like this today. You wrote it down first.',
    'I walked past that exact spot an hour ago.',
    'Framed it in my head before I read the caption.',
  ];

  static const _reactionPool = ['❤️', '🌞', '🖌️', '📖', '☕'];

  /// Plans 0..2 events for one own post. Guarantees:
  ///  - at most [maxEventsPerPost] (2) events;
  ///  - distinct peers;
  ///  - first event at least [minFirstDelay] out (peers are people, not
  ///    push services), each subsequent at least [minSpacing] later;
  ///  - roughly 1 in 6 posts draws no response at all — no performance
  ///    anxiety, in line with the Daily Square's no-chores stance.
  List<PlannedPeerEvent> planForPost({
    int maxEventsPerPost = 2,
    Duration minFirstDelay = const Duration(seconds: 20),
    Duration maxFirstDelay = const Duration(seconds: 90),
    Duration minSpacing = const Duration(seconds: 25),
  }) {
    if (_random() < 1 / 6) return const [];

    final eventCount = _random() < 0.6 ? 1 : 2;
    final firstOffset = minFirstDelay.inMilliseconds +
        (_random() *
                (maxFirstDelay.inMilliseconds - minFirstDelay.inMilliseconds))
            .round();

    final events = <PlannedPeerEvent>[];
    var cumulative = firstOffset;
    for (var i = 0; i < eventCount && i < maxEventsPerPost; i++) {
      // Deterministic rotation through the cast for peer variety without
      // needing a shuffle on the injected source.
      final peer = peers[(firstOffset + i) % peers.length];
      final isReaction = _random() < 0.4;
      events.add(
        isReaction
            ? PlannedPeerEvent(
                peerName: peer,
                kind: NotificationKind.reaction,
                delay: Duration(milliseconds: cumulative),
                reaction:
                    _reactionPool[(_random() * _reactionPool.length).floor()],
              )
            : PlannedPeerEvent(
                peerName: peer,
                kind: NotificationKind.comment,
                delay: Duration(milliseconds: cumulative),
                commentBody:
                    _commentPool[(_random() * _commentPool.length).floor()],
              ),
      );
      cumulative +=
          minSpacing.inMilliseconds + (_random() * 40000).round();
    }
    return events;
  }

  /// Whether a peer starts keeping the local user close after [postCount]
  /// own posts. Deliberately rare and capped: at most [maxFollowEvents]
  /// spontaneous follows ever (lifetime), and only after a quiet-in — the
  /// first few posts never trigger it. Drifting apart is never planned:
  /// nobody quietly unfriends you in Echo Bay.
  ///
  /// Returns the peer's name, or null when nothing happens.
  String? planFollow({
    required int postCount,
    int maxFollowEvents = 3,
    int quietInPosts = 3,
  }) {
    if (postCount <= quietInPosts) return null;
    if (postCount % 4 != 0) return null; // check at most every 4th post
    if (_random() >= 0.5) return null; // then still a coin flip
    if (postCount > quietInPosts + maxFollowEvents * 4) return null;
    return peers[(_random() * peers.length).floor()];
  }
}
