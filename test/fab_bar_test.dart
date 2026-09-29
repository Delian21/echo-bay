import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/design_system/sketch_kit.dart';
import 'package:echo_bay/features/square/data/datasources/square_local_datasource.dart';
import 'package:echo_bay/features/square/data/repositories/mock_feed_repository.dart';
import 'package:echo_bay/features/square/ui/fab_bottom_bar.dart';
import 'package:echo_bay/features/square/ui/post_composer.dart';

/// Tests run with real async gesture timing disabled; the long-press
/// recognizer needs the 500ms hold to actually elapse.
const _longPressHold = Duration(milliseconds: 600);

const _modules = [
  ('The Square', SketchIconKind.slateGrid),
  ('The Vault', SketchIconKind.padlock),
  ('The Hallway', SketchIconKind.spiralHub),
  ('The Landline', SketchIconKind.handset),
];

Future<void> _pumpBar(WidgetTester tester, int selectedIndex) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      bottomNavigationBar: FabBottomBar(
        modules: _modules,
        selectedIndex: selectedIndex,
        onSelected: (_) {},
        onCompose: () {},
      ),
    ),
  ));
  // Let the icon/text tint transitions settle.
  await tester.pump(const Duration(milliseconds: 400));
}

/// Test value for the bar width: four 88px slots + the 72px center gap
/// reserved for the docked FAB.
const _barWidth = 4 * 88.0 + 72.0;

void main() {
  group('FabBottomBar active state (no pill, color-only)', () {
    testWidgets('no pill/highlight shape exists anywhere in the bar',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(_barWidth, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpBar(tester, 0);

      // The sliding pill was removed (never stayed visually centered);
      // this guards against it sneaking back into the bar's own tree.
      expect(find.byKey(const ValueKey('fab-pill')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('fab-bottom-bar')),
          matching: find.byType(AnimatedPositioned),
        ),
        findsNothing,
      );
    });

    for (var slot = 0; slot < 4; slot++) {
      testWidgets(
        'destination $slot (${_modules[slot].$1}) renders primary-tinted '
        'when selected, muted when not',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(_barWidth, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await _pumpBar(tester, slot);

          final context = tester.element(
            find.descendant(
              of: find.byKey(const ValueKey('fab-bottom-bar')),
              matching: find.text(_modules[slot].$1),
            ),
          );
          final scheme = Theme.of(context).colorScheme;

          // Style lives on the AnimatedDefaultTextStyle ancestor, not
          // on the Text itself (its own style stays null).
          TextStyle labelStyleOf(String label) {
            final element = tester.element(
              find.descendant(
                of: find.byKey(const ValueKey('fab-bottom-bar')),
                matching: find.text(label),
              ),
            );
            return DefaultTextStyle.of(element).style;
          }

          expect(
            labelStyleOf(_modules[slot].$1).color,
            scheme.primary,
            reason: 'selected label must be primary-tinted',
          );

          // Every other destination stays muted.
          for (var other = 0; other < 4; other++) {
            if (other == slot) continue;
            expect(
              labelStyleOf(_modules[other].$1).color,
              scheme.onSurfaceVariant,
              reason: 'unselected ${_modules[other].$1} must stay muted',
            );
          }
        },
      );
    }

    testWidgets('tapping a destination re-tints to it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(_barWidth, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Stateful harness so onSelected actually moves the selection —
      // the shared _pumpBar fixture passes a no-op callback.
      int selected = 0;
      final taps = <int>[];
      late StateSetter setRootState;
      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setRootState = setState;
            return Scaffold(
              bottomNavigationBar: FabBottomBar(
                modules: _modules,
                selectedIndex: selected,
                onSelected: (i) {
                  taps.add(i);
                  setRootState(() => selected = i);
                },
                onCompose: () {},
              ),
            );
          },
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('The Landline'), warnIfMissed: true);
      // Two pumps: the first starts the implicit animation (registers the
      // new target style), the second advances it to completion. A single
      // timed pump would never tick the controller.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(taps, [3], reason: 'tap on the Calls label must invoke onSelected');
      expect(
        tester.widget<FabBottomBar>(find.byType(FabBottomBar)).selectedIndex,
        3,
        reason: 'harness must rebuild the bar with the new selection',
      );

      final context = tester.element(
        find.descendant(
          of: find.byKey(const ValueKey('fab-bottom-bar')),
          matching: find.text('The Landline'),
        ),
      );
      final labelStyle = DefaultTextStyle.of(
        tester.element(
          find.descendant(
            of: find.byKey(const ValueKey('fab-bottom-bar')),
            matching: find.text('The Landline'),
          ),
        ),
      ).style;
      expect(labelStyle.color, Theme.of(context).colorScheme.primary);
    });
  });

  group('ComposeFab long-press quick actions', () {
    testWidgets('long press shows photo/sentence/sound, tap invokes shape',
        (tester) async {
      String? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: ComposeFab(
            onPressed: () {},
            onQuickAction: (shape) => picked = shape,
          ),
        ),
      ));

      final fab = find.byType(FloatingActionButton);
      final gesture = await tester.startGesture(tester.getCenter(fab));
      await tester.pump(_longPressHold);
      await gesture.up();
      await tester.pumpAndSettle();

      // One entry per interactive prompt shape of the Daily Square
      // rotation; 'desk' has no distinct compose affordance.
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Sentence'), findsOneWidget);
      expect(find.text('Sound'), findsOneWidget);

      await tester.tap(find.text('Sentence'));
      await tester.pumpAndSettle();

      expect(picked, 'sentence');
      expect(find.text('Sentence'), findsNothing); // sheet dismissed
    });

    testWidgets('dismissing the sheet picks nothing', (tester) async {
      String? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: ComposeFab(
            onPressed: () {},
            onQuickAction: (shape) => picked = shape,
          ),
        ),
      ));

      final fab = find.byType(FloatingActionButton);
      final gesture = await tester.startGesture(tester.getCenter(fab));
      await tester.pump(_longPressHold);
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 100)); // scrim tap = cancel
      await tester.pumpAndSettle();

      expect(picked, isNull);
      expect(find.text('Photo'), findsNothing);
    });
  });

  group('showPostComposer promptShape', () {
    (MockFeedRepository, AppDatabase) makeRepo() {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final local = DriftSquareLocalDatasource(db);
      final mock = MockFeedRepository(
        localDatasource: local,
        db: db,
        incomingPostInterval: const Duration(hours: 1),
        startTicker: false,
      );
      return (mock, db);
    }

    testWidgets('photo shape shows the prompt hint in the composer',
        (tester) async {
      final (repo, db) = makeRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      // Not awaited: showPostComposer's future resolves only when the
      // sheet closes, and it never closes here. Without the await the
      // sheet stays open through the end of the test body.
      unawaited(
        showPostComposer(
        tester.element(find.byType(Scaffold)),
        repository: repo,
          authorName: 'You',
          promptShape: 'photo',
        ),
      );
      // Fixed pumps, not pumpAndSettle: the composer's autofocused text
      // field blinks its cursor forever and pumpAndSettle never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Same copy as the 'photo' prompt in the seeded rotation — the FAB
      // quick action and the notification tap path share one vocabulary.
      expect(
        find.text('One photo of what is in front of you.'),
        findsOneWidget,
      );
    });

    testWidgets('null shape keeps the generic composer hint',
        (tester) async {
      final (repo, db) = makeRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      unawaited(
        showPostComposer(
          tester.element(find.byType(Scaffold)),
          repository: repo,
          authorName: 'You',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("What's happening on the Square?"), findsOneWidget);
    });
  });
}
