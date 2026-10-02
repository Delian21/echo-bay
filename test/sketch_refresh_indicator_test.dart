import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/design_system/sketch_refresh_indicator.dart';
import 'package:echo_bay/core/motion/motion_controller.dart';
import 'package:echo_bay/core/motion/motion_scope.dart';

/// The list the gesture watches — taller than the test viewport so the drag
/// really overscrolls, and always scrollable so a pull at the top works even
/// when the content doesn't fill the screen.
Widget _harness({
  required Future<void> Function() onRefresh,
  bool reducedMotion = false,
}) {
  final controller = MotionController(reducedMotion: reducedMotion);
  return MotionScope(
    controller: controller,
    child: MaterialApp(
      home: Scaffold(
        body: SketchRefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: 60,
            itemBuilder: (context, index) =>
                SizedBox(height: 80, child: Text('row $index')),
          ),
        ),
      ),
    ),
  );
}

/// Drags straight down in steps, the way a thumb does — one big moveBy
/// would be swallowed by the gesture arena's touch slop and never reach the
/// overscroll.
Future<void> _pull(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(ListView)),
  );
  await tester.pump(const Duration(milliseconds: 16));
  const steps = 8;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 32));
}

void main() {
  testWidgets('a pull short of the trigger does not refresh', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_harness(
      onRefresh: () async => calls++,
    ));
    await tester.pump();

    await _pull(tester, 40);
    // Long enough for a collapse animation that should never start.
    await tester.pump(const Duration(milliseconds: 400));

    expect(calls, 0, reason: '72px trigger must not fire on a 40px drag');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('a pull past the trigger runs the refresh', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_harness(
      onRefresh: () async => calls++,
    ));
    await tester.pump();

    await _pull(tester, 200);
    // The indicator snaps to rest before it calls onRefresh, so the call
    // lands after that 180ms settle.
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);

    // It collapses again and does not re-fire.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
    expect(find.text('Refreshing…'), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('reduced motion still refreshes, without spinning',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_harness(
      onRefresh: () async => calls++,
      reducedMotion: true,
    ));
    await tester.pump();

    await _pull(tester, 200);
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, 1,
        reason: 'reduced motion must drop the animation, not the action');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('the control carries a labelled tap action for readers',
      (tester) async {
    final handle = tester.ensureSemantics();

    var calls = 0;
    await tester.pumpWidget(_harness(
      onRefresh: () async => calls++,
    ));
    await tester.pump();

    // Present at rest, not only while pulled — otherwise a reader has no
    // route to a gesture-only refresh at all.
    expect(find.bySemanticsLabel('Refresh feed'), findsOneWidget);

    // Dispatched through the semantics channel, not by pointer: the
    // overlay is IgnorePointer'd so it can never swallow the drag it
    // listens for, which also means hit testing can't reach it.
    final node = tester.getSemantics(find.bySemanticsLabel('Refresh feed'));
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue,
        reason: 'a control with no tap action is decoration, not a control');
    node.owner!.performAction(node.id, ui.SemanticsAction.tap, null);
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('Refresh feed'), findsOneWidget);
    // Disposed inside the body: the binding checks for live handles before
    // running addTearDown callbacks, so it has to happen before we return.
    handle.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
