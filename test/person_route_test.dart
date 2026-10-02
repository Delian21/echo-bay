import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/people/person_sheet.dart';
import 'package:echo_bay/core/profile/handles.dart';
import 'package:echo_bay/core/router/app_router.dart';

/// Person taps are real navigation now: every surface lands on
/// `/person/:handle`. These cover the two things that can go wrong —
/// the slug the URL carries, and the exact name the page displays.
void main() {
  group('@handle slugs', () {
    test('display names slug to lowercase underscored handles', () {
      expect(handleForName('Ada Loomis'), 'ada_loomis');
      expect(handleForName('  Bo   Tamm '), 'bo_tamm');
    });

    test('punctuation collapses to one underscore; unusable names fall back', () {
      expect(handleForName('J.P. Aurelio'), 'j_p_aurelio');
      expect(handleForName('!!!'), 'sketcher');
    });

    test('a slug reads back as a name', () {
      expect(nameForHandle('bo_tamm'), 'Bo Tamm');
    });

    test('validity is length and edge characters', () {
      expect(isValidHandle('bo_tamm'), isTrue);
      expect(isValidHandle('a'), isFalse, reason: 'too short to link');
      expect(isValidHandle('_bo'), isFalse, reason: 'no leading underscore');
      expect(isValidHandle('Bo'), isFalse, reason: 'handles are lowercase');
    });
  });

  group('/person/:handle', () {
    test('the path carries the handle', () {
      expect(AppRoutes.person('bo_tamm'), '/person/bo_tamm');
    });

    testWidgets('an in-app tap shows the exact name, not the slug inverse',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PersonRoutePage(handle: 'j_p_aurelio', name: 'J.P. Aurelio'),
      ));
      // The name the author was stored under must survive the slug.
      expect(find.text('J.P. Aurelio'), findsWidgets);
      expect(find.text('@j_p_aurelio'), findsOneWidget);
    });

    testWidgets('a cold deep link falls back to the inverse slug',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PersonRoutePage(handle: 'bo_tamm'),
      ));
      expect(find.text('Bo Tamm'), findsWidgets);
      expect(find.text('@bo_tamm'), findsOneWidget);
    });

    testWidgets('an unknown person shows the honest empty state',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PersonRoutePage(handle: 'bo_tamm', name: 'Bo Tamm'),
      ));
      await tester.pump();
      expect(
        find.text('No squares from Bo Tamm yet —\ntheir page fills as they post.'),
        findsOneWidget,
      );
      expect(find.text('Keep close'), findsOneWidget);
    });
  });
}