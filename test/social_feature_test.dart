import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/features/social/data/repositories/drift_social_repository.dart';
import 'package:echo_bay/features/social/domain/entities/social_entities.dart';
import 'package:echo_bay/features/social/domain/services/peer_planner.dart';

// Fast, deterministic: in-memory drift, no real timers — peer events
// are applied directly via the planner, and scheduling rules are
// asserted on the planner's output (pure logic), not on wall time.
void main() {
  late AppDatabase db;
  late DriftSocialRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftSocialRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('comments', () {
    test('own comment persists and streams back', () async {
      final result = await repo.addComment(postId: 'p1', body: 'first!');
      expect(result.isRight(), isTrue);

      final comments = await repo.watchComments('p1').first;
      final list = comments.fold((_) => <PostComment>[], (l) => l);
      expect(list, hasLength(1));
      expect(list.single.body, 'first!');
      expect(list.single.isMine, isTrue);
    });
  });

  group('peer events create notifications', () {
    test('a comment event lands in notifications and comments', () async {
      await (repo as dynamic)._applyPeerEvent(
        const PlannedPeerEvent(
          peerName: 'Rune',
          kind: NotificationKind.comment,
          delay: Duration(seconds: 30),
          commentBody: 'Saving this for a gray day.',
        ),
        'p1',
      );

      final notifications = await repo.watchNotifications().first;
      final list = notifications.fold((_) => <SocialNotification>[], (l) => l);
      expect(list, hasLength(1));
      expect(list.single.peerName, 'Rune');
      expect(list.single.isUnread, isTrue);

      final comments = await repo.watchComments('p1').first;
      expect(comments.fold((_) => 0, (l) => l.length), 1);
    });

    test('a reaction event creates a notification but no comment', () async {
      await (repo as dynamic)._applyPeerEvent(
        const PlannedPeerEvent(
          peerName: 'Mila',
          kind: NotificationKind.reaction,
          delay: Duration(seconds: 40),
          reaction: '🌞',
        ),
        'p1',
      );

      final List<SocialNotification> list =
          (await repo.watchNotifications().first).fold(
        (_) => <SocialNotification>[],
        (l) => l,
      );
      expect(list.single.kind, NotificationKind.reaction);
      expect(
        (await repo.watchComments('p1').first).fold((_) => 0, (l) => l),
        0,
      );
    });
  });

  group('unread count', () {
    test('starts at 0, grows with events, markAllRead clears it', () async {
      expect(await repo.watchUnreadCount().first, 0);

      await (repo as dynamic)._applyPeerEvent(
        const PlannedPeerEvent(
          peerName: 'Ops',
          kind: NotificationKind.comment,
          delay: Duration(seconds: 25),
          commentBody: 'The whole square felt like this today.',
        ),
        'p1',
      );
      await (repo as dynamic)._applyPeerEvent(
        const PlannedPeerEvent(
          peerName: 'Rune',
          kind: NotificationKind.reaction,
          delay: Duration(seconds: 60),
          reaction: '❤️',
        ),
        'p1',
      );

      expect(await repo.watchUnreadCount().first, 2);

      final marked = await repo.markAllRead();
      expect(marked.fold((_) => 0, (n) => n), 2);
      expect(await repo.watchUnreadCount().first, 0);
    });
  });

  group('planner caps and spacing (pinned RNG)', () {
    int draw = 0;
    setUp(() => draw = 0);

    /// Deterministic sequence: 0.99 (no silence) → 0.99 (two events) →
    /// offsets/reactions from a stable pseudo-ramp.
    double pinned() {
      draw += 1;
      return switch (draw) {
        1 => 0.99, // not silent
        2 => 0.99, // two events
        _ => ((draw * 37) % 100) / 100,
      };
    }

    test('never more than 2 events per post, peers distinct, spaced out',
        () {
      final planner = PeerPlanner(random: pinned);
      final events = planner.planForPost();
      expect(events.length, lessThanOrEqualTo(2));
      expect(events.map((e) => e.peerName).toSet().length, events.length);
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i].delay,
          greaterThanOrEqualTo(
            events[i - 1].delay + const Duration(seconds: 25),
          ),
        );
      }
      expect(
        events.first.delay,
        greaterThanOrEqualTo(const Duration(seconds: 20)),
      );
    });

    test('a fully-silent draw plans nothing', () {
      final planner = PeerPlanner(random: () => 0.0);
      expect(planner.planForPost(), isEmpty);
    });
  });
}
