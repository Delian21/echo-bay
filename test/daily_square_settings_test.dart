import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:echo_bay/core/auth/auth_repository.dart';
import 'package:echo_bay/core/auth/session_store.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/error/failures.dart';
import 'package:echo_bay/core/prompt/drift_prompt_repository.dart';
import 'package:echo_bay/core/prompt/prompt.dart';
import 'package:echo_bay/core/prompt/prompt_repository.dart';
import 'package:echo_bay/features/settings/ui/daily_square_settings_card.dart';

/// Daily Square settings card (§6c). Locks the anti-chore rules in UI
/// terms: opt-in defaults off, window is user-picked, pause/resume is
/// one tap each with no penalty copy.
void main() {
  late AppDatabase db;
  late LocalAuthRepository auth;
  late DriftPromptRepository prompts;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = LocalAuthRepository(InMemorySessionStore(fixedUserId: 'user-1'));
    prompts = DriftPromptRepository(db, auth);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [DailySquareSettingsCard(repository: prompts)]),
      ),
    ));
    // preferences() round-trip.
    await tester.pumpAndSettle();
  }

  testWidgets('opt-in starts OFF — never default-on (rule 5)',
      (tester) async {
    await pumpCard(tester);

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    // Window picker and pause only appear once opted in.
    expect(find.text('My window opens at'), findsNothing);
    expect(find.text('Pause for a week'), findsNothing);
  });

  testWidgets('opting in reveals window picker + pause, persists',
      (tester) async {
    await pumpCard(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('My window opens at'), findsOneWidget);
    expect(find.text('Pause for a week'), findsOneWidget);

    // Persisted: a fresh repository read sees optedIn = true.
    final stored = await prompts.preferences();
    expect(stored.fold((f) => throw f, (p) => p.optedIn), isTrue);
  });

  testWidgets('pause shows paused-until line; resume clears it (rule 5)',
      (tester) async {
    await pumpCard(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pause for a week'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paused until'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Pause for a week'), findsNothing);

    // Persisted pause timestamp exists and is in the future.
    final stored = await prompts.preferences();
    final prefs = stored.fold((f) => throw f, (p) => p);
    expect(prefs.pausedUntil, isNotNull);
    expect(prefs.pausedUntil!.isAfter(DateTime.now()), isTrue);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Pause for a week'), findsOneWidget);
    expect(find.textContaining('Paused until'), findsNothing);
  });

  testWidgets('repository failure surfaces an error card, not a crash',
      (tester) async {
    final broken = _BrokenPromptRepository();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [DailySquareSettingsCard(repository: broken)]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Daily Square unavailable'), findsOneWidget);
  });
}

class _BrokenPromptRepository implements PromptRepository {
  @override
  Future<Either<Failure, Prompt?>> activePrompt() async =>
      left(const CacheFailure(message: 'broken'));

  @override
  Future<Either<Failure, PromptPreferences>> preferences() async =>
      left(const CacheFailure(message: 'broken'));

  @override
  Future<Either<Failure, PromptPreferences>> updatePreferences(
          PromptPreferences prefs) async =>
      left(const CacheFailure(message: 'broken'));

  @override
  Future<Either<Failure, PromptPreferences>> pauseUntil(DateTime until) async =>
      left(const CacheFailure(message: 'broken'));

  @override
  Future<Either<Failure, PromptPreferences>> resume() async =>
      left(const CacheFailure(message: 'broken'));

  @override
  Future<Either<Failure, Unit>> dismissPrompt({required String promptId}) async =>
      left(const CacheFailure(message: 'broken'));

  @override
  Future<Either<Failure, Unit>> recordPosted(
          {required String promptId, required String postId}) async =>
      left(const CacheFailure(message: 'broken'));
}
