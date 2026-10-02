import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:echo_bay/core/error/failures.dart';
import 'package:echo_bay/core/search/search_hit.dart';
import 'package:echo_bay/core/search/search_page.dart';
import 'package:echo_bay/core/search/search_repository.dart';
import 'package:echo_bay/features/social/domain/entities/peer_directory.dart';

/// Searching for people: a typed `@handle` (or a name) resolves to that
/// person's page above the content hits, and resolves even when the
/// boards have nothing matching at all.
class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository(this.hits);

  final List<SearchHit> hits;

  @override
  Future<Either<Failure, List<SearchHit>>> search({
    required String query,
    int limit = 20,
  }) async =>
      right(hits);
}

void main() {
  group('peer lookup', () {
    test('an exact handle matches, with or without the @', () {
      expect(PeerDirectory.lookup('rune').map((p) => p.name), ['Rune']);
      expect(PeerDirectory.lookup('@rune').map((p) => p.name), ['Rune']);
      expect(PeerDirectory.lookup('  @RUNE ').map((p) => p.name), ['Rune']);
    });

    test('a handle prefix matches, best first', () {
      expect(PeerDirectory.lookup('mi').map((p) => p.name), ['Mila', 'Mira']);
    });

    test('an exact handle outranks a prefix match', () {
      final names = PeerDirectory.lookup('ada').map((p) => p.name);
      expect(names.first, 'Ada');
    });

    test('a name match still finds someone who never typed a handle',
        () {
      expect(PeerDirectory.lookup('ops').map((p) => p.name), ['Ops']);
    });

    test('an empty query matches nobody', () {
      expect(PeerDirectory.lookup(''), isEmpty);
      expect(PeerDirectory.lookup('   '), isEmpty);
      expect(PeerDirectory.lookup('@'), isEmpty);
    });

    test('a query nobody matches returns empty', () {
      expect(PeerDirectory.lookup('zzz'), isEmpty);
    });
  });

  group('people in results', () {
    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      // The page debounces 250ms before it queries.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }

    testWidgets('a handle offers that person above the boards',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SearchPage(searchRepository: _FakeSearchRepository(const [])),
      ));
      await tester.pump();
      await search(tester, 'rune');

      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.text('Rune'), findsOneWidget);
      expect(find.text('@rune'), findsOneWidget);
      // The "nothing found" voice must not fire over a real match.
      expect(find.textContaining('Nothing on the boards'), findsNothing);
    });

    testWidgets('people come before content hits', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SearchPage(
          searchRepository: _FakeSearchRepository([
            const SearchHit(
              source: SearchSource.squarePost,
              id: 'p1',
              containerId: 'p1',
              containerTitle: 'Kai',
              snippet: 'rune[..]and rain',
              rank: 1,
            ),
          ]),
        ),
      ));
      await tester.pump();
      await search(tester, 'rune');

      final people = tester.getTopLeft(find.text('PEOPLE'));
      final posts = tester.getTopLeft(find.text('SQUARE POSTS'));
      expect(people.dy, lessThan(posts.dy));
    });

    testWidgets('a board match with no person shows no people section',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SearchPage(
          searchRepository: _FakeSearchRepository([
            const SearchHit(
              source: SearchSource.squarePost,
              id: 'p2',
              containerId: 'p2',
              containerTitle: 'Kai',
              snippet: 'lantern[..]parade',
              rank: 1,
            ),
          ]),
        ),
      ));
      await tester.pump();
      await search(tester, 'lantern');

      expect(find.text('PEOPLE'), findsNothing);
      expect(find.text('SQUARE POSTS'), findsOneWidget);
    });

    testWidgets('tapping a person opens their page, search stays behind',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SearchPage(searchRepository: _FakeSearchRepository(const [])),
      ));
      await tester.pump();
      await search(tester, '@rune');

      await tester.tap(find.text('Rune'));
      await tester.pumpAndSettle();

      // The person page, reached without a router in place.
      expect(find.text('On the Square'), findsOneWidget);
      expect(find.text('@rune'), findsOneWidget);
    });

    testWidgets('an unknown handle falls back to the empty state',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SearchPage(searchRepository: _FakeSearchRepository(const [])),
      ));
      await tester.pump();
      await search(tester, 'nobodyhere');

      expect(find.text('PEOPLE'), findsNothing);
      expect(find.textContaining('Nothing on the boards'), findsOneWidget);
    });
  });
}