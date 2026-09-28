import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/design_system/staggered_entrance.dart';
import 'package:superapp/core/motion/motion_controller.dart';
import 'package:superapp/core/motion/motion_scope.dart';
import 'package:superapp/core/settings/app_settings_store.dart';

/// Reduced-motion accessibility: the motion system must render content
/// instantly when the preference is on.
void main() {
  test('MotionController notifies and dedupes', () {
    final controller = MotionController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setReducedMotion(true);
    controller.setReducedMotion(true); // dedupe: no second notify
    expect(controller.reducedMotion, isTrue);
    expect(notifications, 1);

    controller.setReducedMotion(false);
    expect(controller.reducedMotion, isFalse);
    expect(notifications, 2);
    controller.dispose();
  });

  testWidgets('reduced motion: staggered items are fully visible on frame 1',
      (tester) async {
    final controller = MotionController()..setReducedMotion(true);
    addTearDown(controller.dispose);

    Widget buildList() => MotionScope(
          controller: controller,
          child: ListView(
            children: [
              for (var i = 0; i < 3; i++)
                StaggeredEntrance(
                  index: i,
                  child: Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: Text('item $i'),
                  ),
                ),
            ],
          ),
        );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: buildList())));
    await tester.pump(); // first build

    // With reduced motion the very first frame shows full-opacity items.
    final opacity = tester
        .widget<FadeTransition>(
          find.byType(FadeTransition).first,
        )
        .opacity
        .value;
    expect(opacity, 1.0);
  });

  testWidgets('full motion: staggered items start hidden', (tester) async {
    final controller = MotionController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: MotionScope(
        controller: controller,
        child: ListView(
          children: const [
            StaggeredEntrance(
              index: 0,
              child: SizedBox(height: 100, child: Text('item')),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(StaggeredEntrance),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 0.0);
  });

  test('settings store round trips the preference', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = AppSettingsStore(db);
    addTearDown(db.close);

    expect(await store.readReducedMotion(), isNull);
    await store.writeReducedMotion(true);
    expect(await store.readReducedMotion(), isTrue);
    await store.writeReducedMotion(false);
    expect(await store.readReducedMotion(), isFalse);
  });
}
