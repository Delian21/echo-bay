import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/features/social/domain/services/peer_planner.dart';

/// Unit tests for the spontaneous follow draw (pure logic — no widgets,
/// no DB). The cap and quiet-in are product rules, so they are pinned.
void main() {
  test('quiet-in: no follows planned for the first few posts', () {
    final planner = PeerPlanner();
    for (var n = 0; n <= 3; n++) {
      expect(planner.planFollow(postCount: n), isNull, reason: 'n=$n');
    }
  });

  test('follows only fire on every 4th post and are capped for life', () {
    var heads = 0;
    // Deterministic planner that always lands the coin flip.
    final always = PeerPlanner(random: () => 0.0);
    for (var n = 4; n <= 100; n++) {
      final peer = always.planFollow(postCount: n);
      if (n % 4 != 0) {
        expect(peer, isNull, reason: 'n=$n');
      } else if (peer != null) {
        heads++;
      }
    }
    // At most maxFollowEvents (3) over the whole lifetime.
    expect(heads, lessThanOrEqualTo(3));
  });

  test('coin-flip miss: a 4th post draws nothing on a high roll', () {
    final never = PeerPlanner(random: () => 0.999);
    expect(never.planFollow(postCount: 8), isNull);
  });

  test('a planned follow names a real cast member', () {
    final planner = PeerPlanner();
    // Scan many RNG draws for one hit; any hit must be from the cast.
    var hit = false;
    for (var i = 0; i < 500; i++) {
      final peer = planner.planFollow(postCount: 4 + (i % 40));
      if (peer != null) {
        hit = true;
        expect(PeerPlanner.peers, contains(peer));
      }
    }
    expect(hit, isTrue, reason: 'a run of 500 draws should land at least one');
  });
}
