import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/people/person_sheet.dart';
import 'package:echo_bay/core/profile/handles.dart';
import 'package:echo_bay/core/router/app_router.dart';
import 'package:echo_bay/features/social/domain/entities/peer_directory.dart';

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

  group('collision-free assignment', () {
    test('two names that slug alike get distinct handles', () {
      final directory = HandleDirectory(['Bo Tamm', 'Bo-Tamm']);
      expect(directory.handleFor('Bo Tamm'), 'bo_tamm');
      expect(directory.handleFor('Bo-Tamm'), 'bo_tamm_2');
    });

    test('each handle resolves back to exactly one name', () {
      final directory = HandleDirectory(['Bo Tamm', 'Bo-Tamm']);
      expect(directory.nameFor('bo_tamm'), 'Bo Tamm');
      expect(directory.nameFor('bo_tamm_2'), 'Bo-Tamm');
    });

    test('a handle never changes once claimed', () {
      final directory = HandleDirectory(['Bo Tamm']);
      final first = directory.handleFor('Bo Tamm');
      // A later arrival must not renumber an already-shared URL.
      directory.handleFor('Bo-Tamm');
      expect(directory.handleFor('Bo Tamm'), first);
    });

    test('a suffixed handle still fits the length cap', () {
      final long = List.filled(30, 'a').join();
      final directory = HandleDirectory([long, '$long b']);
      for (final handle in directory.handles) {
        expect(handle.length, lessThanOrEqualTo(kMaxHandleLength));
        expect(isValidHandle(handle), isTrue);
      }
      expect(directory.handles.toSet().length, 2);
    });

    test('an unclaimed handle resolves to null', () {
      expect(HandleDirectory(['Ada']).nameFor('nobody'), isNull);
    });

    test('the peer cast assigns every peer a unique handle', () {
      final handles = PeerDirectory.names.map(PeerDirectory.handleFor);
      expect(handles.toSet().length, PeerDirectory.names.length);
      for (final name in PeerDirectory.names) {
        expect(PeerDirectory.nameFor(PeerDirectory.handleFor(name)), name);
      }
    });

    test('a cold link to a cast peer shows their real name', () {
      expect(PeerDirectory.nameFor('rune'), 'Rune');
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