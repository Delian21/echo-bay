import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/features/keepsake/data/repositories/drift_keepsake_repository.dart';
import 'package:echo_bay/features/keepsake/domain/entities/keepsake_item.dart';

// Repository tests are pure drift — fast, no timers, no pumping.
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

  test('pin post persists board-relative position and rotation', () async {
    final result = await repo.pinPost(
      postId: 'p1',
      posX: 0.25,
      posY: 0.4,
      rotation: 0.03,
    );
    final item = result.fold((_) => throw StateError('expected right'), (i) => i);
    expect(item.postId, 'p1');
    expect(item.posX, 0.25);
    expect(item.posY, 0.4);
    expect(item.rotation, 0.03);

    final board = (await repo.watchBoard().first)
        .fold((_) => <KeepsakeItem>[], (l) => l);
    expect(board, hasLength(1));
  });

  test('moveItem persists a drag', () async {
    final pinned =
        (await repo.pinPost(postId: 'p2', posX: 0.1, posY: 0.1))
            .fold((_) => throw StateError('x'), (i) => i);

    await repo.moveItem(itemId: pinned.id, posX: 0.7, posY: 0.6, rotation: -0.02);

    final List<KeepsakeItem> board = (await repo.watchBoard().first)
        .fold((_) => <KeepsakeItem>[], (l) => l.toList());
    expect(board.single.posX, closeTo(0.7, 0.0001));
    expect(board.single.posY, closeTo(0.6, 0.0001));
    expect(board.single.rotation, closeTo(-0.02, 0.0001));
  });

  test('stringItems links two items; unpin drops strings into it',
      () async {
    final a =
        (await repo.pinPost(postId: 'p3', posX: 0.1, posY: 0.1))
            .fold((_) => throw StateError('x'), (i) => i);
    final b =
        (await repo.addNote(noteText: 'hello', posX: 0.6, posY: 0.5))
            .fold((_) => throw StateError('x'), (i) => i);

    await repo.stringItems(fromItemId: a.id, toItemId: b.id);
    var board = (await repo.watchBoard().first)
        .fold((_) => <KeepsakeItem>[], (l) => l.toList());
    expect(board.firstWhere((i) => i.id == a.id).strungTo, b.id);

    await repo.unpin(itemId: b.id);
    board = (await repo.watchBoard().first)
        .fold((_) => <KeepsakeItem>[], (l) => l.toList());
    // The string dangling into the unpinned item is cleaned up.
    expect(board.single.id, a.id);
    expect(board.single.strungTo, isNull);
  });
}


