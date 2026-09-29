import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/features/keepsake/data/repositories/drift_keepsake_repository.dart';
import 'package:superapp/features/keepsake/domain/entities/keepsake_item.dart';
import 'package:superapp/features/keepsake/ui/keepsake_board_page.dart';

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
    await repo.pinPost(postId: 'p1', posX: 0.1, posY: 0.1);

    await tester.pumpWidget(MaterialApp(
      home: KeepsakeBoardPage(repository: repo),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('The wall is bare.'), findsNothing);

    // Drag the pinned card by a known delta and settle.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Stack).last) + const Offset(20, 20),
    );
    await gesture.moveBy(const Offset(120, 80));
    await gesture.moveBy(const Offset(60, 40));
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
    await repo.pinPost(postId: 'p2', posX: 0.3, posY: 0.3);
    await tester.pumpWidget(MaterialApp(
      home: KeepsakeBoardPage(repository: repo),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(find.byType(Stack).last);
    await tester.pump(const Duration(milliseconds: 500));

    final board = (await repo.watchBoard().first)
        .fold((_) => <KeepsakeItem>[], (l) => l.toList());
    expect(board, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
