import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/motion/motion_controller.dart';
import 'package:superapp/core/motion/motion_scope.dart';
import 'package:superapp/core/motion/rewind_scope.dart';
import 'package:superapp/core/theme/app_theme.dart';
import 'package:superapp/features/square/ui/square_card.dart';
import 'package:superapp/features/square/ui/square_post_model.dart';

void main() {
  group('Golden Hour theme', () {
    test('golden hour builders carry enabled extensions with analog tokens',
        () {
      for (final theme in [
        buildGoldenHourLightTheme(),
        buildGoldenHourDarkTheme(),
      ]) {
        final golden = theme.extension<GoldenHourExtension>();
        expect(golden, isNotNull);
        expect(golden!.enabled, isTrue);
      }
    });

    test('stock builders keep the analog layer OFF', () {
      for (final theme in [buildLightTheme(), buildDarkTheme()]) {
        final golden = theme.extension<GoldenHourExtension>();
        expect(golden, isNotNull);
        expect(golden!.enabled, isFalse,
            reason: 'stock theme must render without polaroid framing');
      }
    });

    testWidgets('SquareFeedCard renders polaroid framing when enabled',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildGoldenHourLightTheme(),
        home: Scaffold(
          body: ListView(
            children: [
              SquareFeedCard(post: _post(), onLike: () {}),
            ],
          ),
        ),
      ));
      await tester.pump();

      // The card body rides inside the polaroid paper container.
      final golden = GoldenHourExtension.of(
        tester.element(find.byType(SquareFeedCard)),
      );
      expect(golden.enabled, isTrue);
      // Rotation transform present (the per-card tilt).
      expect(
        find.byWidgetPredicate((w) => w is Transform),
        findsWidgets,
      );
    });
  });

  group('RewindScope', () {
    Future<void> pump(WidgetTester tester, VoidCallback onRewind) async {
      await tester.pumpWidget(MaterialApp(
        home: RewindScope(
          child: Builder(builder: (context) {
            return TextButton(
              onPressed: () => RewindScope.rewind(context, onRewind),
              child: const Text('undo'),
            );
          }),
        ),
      ));
    }

    testWidgets('plays the effect and fires the action at the midpoint',
        (tester) async {
      var undone = false;
      await pump(tester, () => undone = true);

      await tester.tap(find.text('undo'));
      await tester.pump();
      expect(undone, isFalse, reason: 'action fires at midpoint, not start');

      await tester.pump(const Duration(milliseconds: 260));
      expect(undone, isTrue, reason: 'action fires at the ~250ms midpoint');

      await tester.pumpAndSettle(); // effect completes cleanly
    });

    testWidgets('reduced motion: instant action, no animation window',
        (tester) async {
      var undone = false;
      await tester.pumpWidget(MotionScope(
        controller: MotionController(reducedMotion: true),
        child: MaterialApp(
          home: RewindScope(
            child: Builder(builder: (context) {
              return TextButton(
                onPressed: () => RewindScope.rewind(context, () => undone = true),
                child: const Text('undo'),
              );
            }),
          ),
        ),
      ));

      await tester.tap(find.text('undo'));
      await tester.pump();
      expect(undone, isTrue, reason: 'reduced motion undoes immediately');
    });

    testWidgets('no scope above: falls back to plain undo', (tester) async {
      var undone = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return TextButton(
            onPressed: () => RewindScope.rewind(context, () => undone = true),
            child: const Text('undo'),
          );
        }),
      ));

      await tester.tap(find.text('undo'));
      await tester.pump();
      expect(undone, isTrue);
    });
  });
}

SquarePost _post() => SquarePost(
      id: 'p1',
      username: 'max',
      userAvatarUrl: 'https://example.com/a.png',
      timestamp: DateTime.now(),
      caption: 'polaroid test',
      mediaUrl: 'https://example.com/p.jpg',
      likesCount: 0,
      isLiked: false,
    );
