import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/motion/rewind_scope.dart';
import 'package:echo_bay/features/keepsake/data/repositories/drift_keepsake_repository.dart';
import 'package:echo_bay/features/keepsake/ui/keepsake_board_page.dart';

/// Logging wrapper: counts every pinPost call.
class LoggingRepo implements DriftKeepsakeRepository {
  LoggingRepo(this._inner);
  final DriftKeepsakeRepository _inner;
  var pinCalls = 0;

  @override
  Future<dynamic> noSuchMethod(Invocation invocation) async {
    if (invocation.memberName == #pinPost) pinCalls++;
    return Function.apply(
        _inner.noSuchMethod, []) ?? super.noSuchMethod(invocation);
  }
}

void main() {
  testWidgets('probe: does undo re-pin fire after unpin?', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = DriftKeepsakeRepository(db);
    final pinned = (await repo.pinPost(postId: 'p2', posX: 0.3, posY: 0.3))
        .fold((f) => throw f, (i) => i);

    await tester.pumpWidget(MaterialApp(
      home: RewindScope(child: KeepsakeBoardPage(repository: repo)),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(
        find.byKey(ValueKey<String>('keepsake-card-${pinned.id}')));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)));
    await tester.pump();

    // Count rows including tombstoned ones.
    final all = await db.select(db.keepsakeItems).get();
    // ignore: avoid_print
    print('PROBE total rows: ${all.length}, '
        'unpinned: ${all.where((r) => r.unpinnedAt != null).length}, '
        'live: ${all.where((r) => r.unpinnedAt == null).length}');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
