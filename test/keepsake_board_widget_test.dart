import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/design_system/sketch_kit.dart';
import 'package:echo_bay/features/keepsake/data/repositories/drift_keepsake_repository.dart';
import 'package:echo_bay/features/keepsake/domain/entities/keepsake_item.dart';
import 'package:echo_bay/features/keepsake/ui/keepsake_board_page.dart';

// One fast widget test: pin a post, drag its card, verify the new
// board-relative position landed in drift.
void main() {
  late AppDatabase db;
  late DriftKeepsakeRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftKeepsakeRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('drag persists the new board position', (tester) async {
    final pinned =
        (await repo.pinPost(postId: 'p1', posX: 0.1, posY: 0.1))
            .fold((f) => throw f, (i) => i);

    await tester.pumpWidget(MaterialApp(
      home: KeepsakeBoardPage(repository: repo),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('The wall is bare.'), findsNothing);

    // Drag the pinned card by a known delta and settle. The card carries
    // a stable key — a bare Stack finder picked up nested chrome instead.
    // Frames are pumped between moves the way a real finger arrives:
    // without a frame the pan recognizer's queued updates can't flush,
    // and the drag lands short.
    final card = find.byKey(ValueKey<String>('keepsake-card-${pinned.id}'));
    expect(card, findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(card),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(120, 80));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(60, 40));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    final board = (await repo.watchBoard().first)
        .fold((_) => <KeepsakeItem>[], (l) => l.toList());
    expect(board, hasLength(1));
    // Position moved right/down from the pin point (fraction space).
    expect(board.single.posX, greaterThan(0.1));
    expect(board.single.posY, greaterThan(0.1));
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('long-press unpins; board empties', (tester) async {
    final pinned =
        (await repo.pinPost(postId: 'p2', posX: 0.3, posY: 0.3))
            .fold((f) => throw f, (i) => i);
    await tester.pumpWidget(MaterialApp(
      home: KeepsakeBoardPage(repository: repo),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(
      find.byKey(ValueKey<String>('keepsake-card-${pinned.id}')),
    );
    // The unpin rides RewindScope: the tombstone write fires at the
    // animation's 250ms midpoint, then the board re-emit crosses another
    // async boundary.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    final board = (await repo.watchBoard().first)
        .fold((_) => <KeepsakeItem>[], (l) => l.toList());
    expect(board, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('card ink is pinned charcoal under a dark theme',
      (tester) async {
    // Regression: the card is always cream (theme-independent), but its
    // ink used to come from Theme — chalk under dark mode, invisible.
    await repo.addNote(noteText: 'soup night', posX: 0.1, posY: 0.1);
    await repo.pinPost(postId: 'p1', posX: 0.4, posY: 0.4);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: KeepsakeBoardPage(repository: repo),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final note = tester.widget<Text>(find.text('soup night'));
    expect(note.style?.color, SketchInk.charcoal,
        reason: 'the note must read on cream, not in chalk');

    // No FeedRepository in DI here, so the pinned post renders the
    // faded note — same paper, same rule.
    final faded = tester.widget<Text>(find.textContaining('rewound'));
    expect(faded.style?.color, SketchInk.charcoal);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
