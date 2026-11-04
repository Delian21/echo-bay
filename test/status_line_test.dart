import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/design_system/status_line.dart';
import 'package:echo_bay/core/profile/profile_controller.dart';
import 'package:echo_bay/core/profile/status.dart';
import 'package:echo_bay/core/profile/user_profile.dart';
import 'package:echo_bay/core/settings/app_settings_store.dart';
import 'package:echo_bay/features/profile/ui/profile_page.dart';

/// Status line: one sentence, an optional expiry, and the rule that a
/// lapsed status is simply not shown. Expiry is a display-time check plus
/// a one-shot timer, never a background job.
void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        home: Scaffold(body: Center(child: child)),
      );

  group('status expiry rule', () {
    final now = DateTime(2026, 11, 4, 18, 0);

    test('blank text is never active, even with no expiry', () {
      expect(statusIsActive(null, null, now), isFalse);
      expect(statusIsActive('   ', null, now), isFalse);
    });

    test('no expiry means it stays up', () {
      expect(statusIsActive('up', null, now), isTrue);
    });

    test('it lapses at expiresAt, not a moment later', () {
      expect(
        statusIsActive('up', now.add(const Duration(seconds: 1)), now),
        isTrue,
      );
      expect(statusIsActive('up', now, now), isFalse);
      expect(
        statusIsActive('up', now.subtract(const Duration(minutes: 1)), now),
        isFalse,
      );
    });

    test('withStatus clears both fields, and Never drops a stale expiry', () {
      final withExpiry = const UserProfile()
          .withStatus('hello', now.add(const Duration(hours: 4)));
      expect(withExpiry.statusText, 'hello');
      expect(withExpiry.statusExpiresAt, isNotNull);

      final never = withExpiry.withStatus('hello', null);
      expect(never.statusExpiresAt, isNull,
          reason: 'switching to Never must not keep the old expiry');

      final cleared = never.withStatus('  ', null);
      expect(cleared.statusText, isNull);
      expect(cleared.statusExpiresAt, isNull);
    });

    test('fadeForRemaining chooses the closest choice', () {
      expect(fadeForRemaining(null).label, 'Never');
      expect(
        fadeForRemaining(const Duration(hours: 20)).label,
        '24 hours',
      );
      expect(
        fadeForRemaining(const Duration(minutes: 5)).label,
        '4 hours',
      );
      expect(
        fadeForRemaining(const Duration(days: 2, hours: 20)).label,
        '3 days',
      );
    });
  });

  group('StatusLine', () {
    testWidgets('renders the sentence in light and dark themes',
        (tester) async {
      final now = DateTime(2026, 11, 4, 12);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(host(
          StatusLine(
            text: 'On the roof, chasing a signal.',
            expiresAt: now.add(const Duration(hours: 1)),
            clock: () => now,
          ),
          brightness: brightness,
        ));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('On the roof, chasing a signal.'), findsOneWidget,
            reason: '$brightness');
      }
    });

    testWidgets('an expired status with no placeholder reserves no space',
        (tester) async {
      final now = DateTime(2026, 11, 4, 12);
      await tester.pumpWidget(host(
        StatusLine(
          text: 'gone',
          expiresAt: now.subtract(const Duration(seconds: 1)),
          clock: () => now,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('gone'), findsNothing);
      expect(tester.getSize(find.byType(StatusLine)), Size.zero);
    });

    testWidgets('it disappears while the screen is open, at the expiry moment',
        (tester) async {
      final start = DateTime(2026, 11, 4, 12);
      var now = start;
      // Fade expires 50ms after the first build.
      final expiresAt = start.add(const Duration(milliseconds: 50));

      await tester.pumpWidget(host(
        StatusLine(
          text: 'briefly here',
          expiresAt: expiresAt,
          placeholder: kStatusPlaceholder,
          clock: () => now,
        ),
      ));
      await tester.pump();
      expect(find.text('briefly here'), findsOneWidget);

      // Time moves on (both the injected clock and the timer that was
      // armed for the remaining lifetime).
      now = expiresAt.add(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('briefly here'), findsNothing);
      expect(find.text(kStatusPlaceholder), findsOneWidget,
          reason: 'the profile falls back to its quiet invitation');
    });

    testWidgets('a 60-character status renders without overflowing',
        (tester) async {
      final long = 'a' * kStatusMaxLength;
      final now = DateTime(2026, 11, 4, 12);
      await tester.pumpWidget(host(
        SizedBox(
          width: 320,
          child: StatusLine(text: long, clock: () => now),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(long), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tappable tag meets the 44px target', (tester) async {
      final now = DateTime(2026, 11, 4, 12);
      await tester.pumpWidget(host(
        StatusLine(
          text: 'tap me',
          clock: () => now,
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(44));
    });
  });

  group('persistence', () {
    test('status survives a write/read round trip and clearing removes it',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = AppSettingsStore(db);
      final expires = DateTime(2026, 11, 5, 9, 30);

      await store.writeProfile(
        const UserProfile().withStatus('Writing by the window.', expires),
      );
      final read = await store.readProfile();
      expect(read.statusText, 'Writing by the window.');
      expect(read.statusExpiresAt, expires);

      await store.writeProfile(read.withStatus(null, null));
      final cleared = await store.readProfile();
      expect(cleared.statusText, isNull);
      expect(cleared.statusExpiresAt, isNull);
      expect(cleared.displayName, 'You', reason: 'other fields are untouched');
    });

    test('Never persists as no expiry', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = AppSettingsStore(db);

      await store.writeProfile(const UserProfile().withStatus('always', null));
      final read = await store.readProfile();
      expect(read.statusText, 'always');
      expect(read.statusExpiresAt, isNull);
    });
  });

  group('profile screen', () {
    late ProfileController controller;

    setUp(() {
      controller = ProfileController();
    });

    testWidgets('shows the invitation, then the status after saving via the '
        'sheet', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(profileController: controller),
      ));
      await tester.pumpAndSettle();

      expect(find.text(kStatusPlaceholder), findsOneWidget);

      await tester.tap(find.text(kStatusPlaceholder));
      await tester.pumpAndSettle();

      final long = 'b' * kStatusMaxLength;
      await tester.enterText(find.byType(TextField), long);
      await tester.pump();

      // Default fade is 24 hours; the counter shows the cap.
      expect(find.text('Fades in'), findsOneWidget);
      expect(find.text('24 hours'), findsOneWidget);
      expect(find.text('$long'), findsWidgets);

      await tester.tap(find.text('Set status'));
      await tester.pumpAndSettle();

      expect(controller.profile.statusText, long);
      expect(controller.profile.statusExpiresAt, isNotNull);
      final remaining =
          controller.profile.statusExpiresAt!.difference(DateTime.now());
      expect(remaining.inHours, inInclusiveRange(23, 24));
      expect(find.text(long), findsOneWidget,
          reason: 'the profile now carries the real status');
      expect(find.text(kStatusPlaceholder), findsNothing);
    });

    testWidgets('Clear removes an existing status', (tester) async {
      controller.update(const UserProfile().withStatus(
        'here for a bit',
        null,
      ));
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(profileController: controller),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('here for a bit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(controller.profile.statusText, isNull);
      expect(find.text(kStatusPlaceholder), findsOneWidget);
    });

    testWidgets('an expired status shows the invitation instead',
        (tester) async {
      controller.update(UserProfile().withStatus(
        'yesterday',
        DateTime.now().subtract(const Duration(minutes: 1)),
      ));
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(profileController: controller),
      ));
      await tester.pumpAndSettle();

      expect(find.text('yesterday'), findsNothing);
      expect(find.text(kStatusPlaceholder), findsOneWidget);
    });

    testWidgets('editing the name keeps the status intact', (tester) async {
      controller.update(const UserProfile().withStatus('still here', null));
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(profileController: controller),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ada Loomis');
      await tester.pump();

      expect(controller.profile.displayName, 'Ada Loomis');
      expect(controller.profile.statusText, 'still here',
          reason: 'the edit form does not own the status, so it must carry it');
    });
  });
}
