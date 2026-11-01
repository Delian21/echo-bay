import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/auth/auth_repository.dart';
import 'package:echo_bay/core/auth/session_store.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/onboarding/first_run.dart';
import 'package:echo_bay/core/onboarding/guest_mode.dart';
import 'package:echo_bay/core/onboarding/launch_gate.dart';
import 'package:echo_bay/core/profile/profile_controller.dart';
import 'package:echo_bay/core/settings/app_settings_store.dart';
import 'package:echo_bay/features/landing/ui/landing_page.dart';
import 'package:echo_bay/features/square/ui/guest_banner.dart';
import 'package:echo_bay/injection.dart';

void main() {
  group('the "/" decision', () {
    test('a fresh device sees the landing page', () {
      expect(
        showsLandingPage(hasCoverBeenSigned: false, guestMode: false),
        isTrue,
      );
    });

    test('a member never sees it, signed out or not', () {
      // hasCoverBeenSigned survives sign-out, so a returning member goes
      // straight to the Square's own sign-in gate.
      expect(
        showsLandingPage(hasCoverBeenSigned: true, guestMode: false),
        isFalse,
      );
    });

    test('a guest goes straight into the Square', () {
      expect(
        showsLandingPage(hasCoverBeenSigned: false, guestMode: true),
        isFalse,
      );
    });
  });

  group('guest mode', () {
    late AppDatabase db;
    late AppSettingsStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = AppSettingsStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('starts dormant, turns on, and can be dismissed', () async {
      expect(await GuestMode.isActive(store), isFalse);

      await GuestMode.start(store);
      expect(await GuestMode.isActive(store), isTrue);
      expect(await GuestMode.bannerDismissed(store), isFalse);
      // The intro is part of what the landing page already said.
      expect(await FirstRun.isCompleted(store), isTrue);

      await GuestMode.dismissBanner(store);
      expect(await GuestMode.bannerDismissed(store), isTrue);
    });

    test('signing up ends guest mode and resets the banner', () async {
      await GuestMode.start(store);
      await GuestMode.dismissBanner(store);

      await GuestMode.finish(store);

      expect(await GuestMode.isActive(store), isFalse);
      expect(await GuestMode.bannerDismissed(store), isFalse);
    });
  });

  group('converting a guest keeps their pages', () {
    test('signUp leaves the device identity and its content untouched',
        () async {
      final storage = InMemorySessionStore(fixedUserId: 'guest-device');
      final auth = LocalAuthRepository(storage);

      // The guest browses under the device id — posts, keepsakes and
      // messages are authored against it.
      final before = await auth.currentUser();
      final guestId = before.fold((_) => null, (s) => s.userId);
      expect(guestId, 'guest-device');
      expect(await auth.hasCoverBeenSigned(), isFalse);

      final result = await auth.signUp(
        displayName: 'Ada Loomis',
        credentials:
            const AuthCredentials(method: AuthMethod.email, email: 'a@b.co'),
      );

      final userId = result.fold((_) => null, (s) => s.userId);
      expect(userId, guestId); // same sketchbook, same rows
      expect(await auth.hasCoverBeenSigned(), isTrue);
    });

    test('signing in marks the cover signed, so "/" stops showing landing',
        () async {
      final auth = LocalAuthRepository(InMemorySessionStore());
      final signedIn = await auth.signIn(
        const AuthCredentials(method: AuthMethod.email, email: 'x@y.co'),
      );
      expect(signedIn.isRight(), isTrue);
      expect(await auth.hasCoverBeenSigned(), isTrue);
    });
  });

  testWidgets('a fresh device lands on the front porch', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());
    await sl.reset();
    sl.registerSingleton<AppSettingsStore>(AppSettingsStore(db));
    sl.registerSingleton<AuthRepository>(
      LocalAuthRepository(InMemorySessionStore()),
    );
    addTearDown(() async => sl.reset());

    await tester.pumpWidget(const MaterialApp(home: LaunchGate()));
    await tester.pump(); // the decision reads one settings key
    await tester.pump();

    expect(find.byType(LandingPage), findsOneWidget);
    expect(find.text(LandingPage.tagline), findsOneWidget);
  });

  testWidgets('the guest banner shows, and can be put away',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());
    await sl.reset();
    final store = AppSettingsStore(db);
    sl.registerSingleton<AppSettingsStore>(store);
    addTearDown(() async => sl.reset());
    await GuestMode.start(store);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GuestBanner()),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(find.textContaining('trying Echo Bay as a guest'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));

    expect(find.textContaining('trying Echo Bay as a guest'), findsNothing);
    expect(await GuestMode.bannerDismissed(store), isTrue);
  });

  testWidgets('landing page: title, promise, and both ways in',
      (tester) async {
    var entered = false;
    await tester.pumpWidget(MaterialApp(
      home: LandingPage(onEntered: () => entered = true),
    ));

    expect(find.text('Echo Bay'), findsOneWidget);
    expect(find.text(LandingPage.tagline), findsOneWidget);
    expect(find.text('Sign the cover'), findsOneWidget);
    expect(find.text('Try it first'), findsOneWidget);
    expect(find.text('Open your sketchbook'), findsOneWidget);
    // Three promises, in the app's voice.
    expect(find.textContaining('fade after 24 hours'), findsOneWidget);
    expect(find.textContaining('Time travel'), findsOneWidget);
    expect(find.textContaining('Vault'), findsWidgets);
    expect(entered, isFalse);
  });

  testWidgets('try it first creates a guest profile and enters',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());
    // reset() is async in get_it 7 — awaiting it matters, or its disposal
    // finishes after these registrations and clears them.
    await sl.reset();
    sl.registerSingleton<AppSettingsStore>(AppSettingsStore(db));
    sl.registerSingleton<ProfileController>(ProfileController());
    addTearDown(() async => sl.reset());

    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var entered = false;
    await tester.pumpWidget(MaterialApp(
      home: LandingPage(onEntered: () => entered = true),
    ));

    expect(sl.isRegistered<AppSettingsStore>(), isTrue);
    expect(sl.isRegistered<ProfileController>(), isTrue);

    await tester.tap(find.text('Try it first'));
    // Guest start touches the real settings database: let those futures
    // resolve on a real clock before checking the result.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(await GuestMode.isActive(sl<AppSettingsStore>()), isTrue,
        reason: 'guest flag persisted');
    expect(sl<ProfileController>().profile.displayName, 'Guest');
    expect(sl<ProfileController>().profile.handle, 'guest');
    expect(entered, isTrue, reason: 'landing handed off to the Square');
  });
}
