import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:echo_bay/features/square/data/datasources/square_local_datasource.dart';
import 'package:echo_bay/injection.dart' as di;

import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/features/square/data/repositories/mock_feed_repository.dart';
import 'package:echo_bay/features/square/domain/repositories/feed_repository.dart';
import 'package:echo_bay/features/square/ui/square_card.dart';
import 'package:echo_bay/features/square/ui/square_feed_view.dart';
import 'package:echo_bay/features/square/ui/square_navigation_shell.dart';
import 'package:echo_bay/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:echo_bay/features/vault/data/repositories/mock_chat_repository.dart';
import 'package:echo_bay/features/vault/ui/vault_chat_page.dart';
import 'package:echo_bay/features/vault/ui/vault_conversation_list.dart';

/// In-memory drift stacks per test: no disk, tickers off so no periodic
/// timer trips flutter_test's pending-timer invariant.
(MockFeedRepository, AppDatabase) _makeFeedRepo() {
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

(MockChatRepository, AppDatabase) _makeChatRepo() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final local = DriftVaultLocalDatasource(db);
  final mock = MockChatRepository(
    localDatasource: local,
    incomingMessageInterval: const Duration(seconds: 3600),
    startTicker: false,
  );
  return (mock, db);
}

void main() {
  group('Desktop polish — navigation shell', () {
    testWidgets('wide window: rail + feed body from the real shell',
        (tester) async {
      final (feedRepo, feedDb) = _makeFeedRepo();
      final (chatRepo, chatDb) = _makeChatRepo();
      await chatRepo.ensureSeeded();

      // The shell's Square body reads sl<FeedRepository>(); register a
      // mock stack so the rail's first module mounts cleanly.
      di.sl
        ..registerLazySingleton<AppDatabase>(() => feedDb)
        ..registerLazySingleton<FeedRepository>(() => feedRepo);
      addTearDown(() async {
        await di.sl.reset();
        feedRepo.dispose();
        chatRepo.dispose();
        await feedDb.close();
        await chatDb.close();
      });

      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(MaterialApp(
          home: SquareNavigationShell(vaultRepository: chatRepo),
        ));
        await tester.pump(const Duration(milliseconds: 400));
      });
    });

    testWidgets('wide window shows NavigationRail, narrow shows drawer shell',
        (tester) async {
      final (feedRepo, db) = _makeFeedRepo();
      addTearDown(() async {
        feedRepo.dispose();
        await db.close();
      });

      // Narrow: scaffold + drawer chrome, no rail.
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            drawer: const Drawer(child: SizedBox.shrink()),
            appBar: AppBar(title: const Text('The Square')),
            body: SquareFeedView(repository: feedRepo),
          ),
        ));        await tester.pump(const Duration(milliseconds: 400));
        // A closed drawer isn't built at all (DrawerController returns a
        // gesture stub while dismissed), so open it to verify the chrome.
        expect(find.byType(NavigationRail), findsNothing);
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(Drawer), findsOneWidget);

        // Wide: the rail chrome is present (constrained-width shell).
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            return LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 600;
              return wide
                  ? Scaffold(
                      body: Row(
                        children: [
                          NavigationRail(
                            selectedIndex: 0,
                            onDestinationSelected: (_) {},
                            labelType: NavigationRailLabelType.all,
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.grid_view_rounded),
                                label: Text('The Square'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.lock_open_rounded),
                                label: Text('The Vault'),
                              ),
                            ],
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                    )
                  : Scaffold(
                      appBar: AppBar(title: const Text('The Square')),
                      body: SquareFeedView(repository: feedRepo),
                    );
            });
          }),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(Drawer), findsNothing);
      });
    });
  });

  group('Desktop polish — feed column + keyboard', () {
    testWidgets('feed column capped at 640px on wide windows', (tester) async {
      final (repo, db) = _makeFeedRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // The ConstrainedBox caps the list, so cards never exceed 640 wide.
        final cardWidth =
            tester.getSize(find.byType(SquareFeedCard).first).width;
        expect(cardWidth, lessThanOrEqualTo(640));
      });
    });

    testWidgets('arrow down moves card focus, L likes the focused card',
        (tester) async {
      final (repo, db) = _makeFeedRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(800, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // Focus the first card with ArrowDown, then like it with L.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pump(const Duration(milliseconds: 400));

        // One like round-tripped through the repository into the cache.
        final filledHearts = tester
            .widgetList<Icon>(find.byType(Icon))
            .where((i) =>
                i.icon == Icons.favorite_rounded &&
                i.color == const Color(0xFFE0245E) &&
                i.size == 22.0)
            .length;
        expect(filledHearts, 1);
      });
    });

    testWidgets('L without focus is a no-op (no accidental likes)',
        (tester) async {
      final (repo, db) = _makeFeedRepo();
      addTearDown(() async {
        repo.dispose();
        await db.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(800, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SquareFeedView(repository: repo)),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pump(const Duration(milliseconds: 400));

        final filledHearts = tester
            .widgetList<Icon>(find.byType(Icon))
            .where((i) =>
                i.icon == Icons.favorite_rounded &&
                i.color == const Color(0xFFE0245E) &&
                i.size == 22.0)
            .length;
        expect(filledHearts, 0);
      });
    });
  });

  group('Desktop polish — Vault master-detail', () {
    testWidgets('wide window: list pane + chat pane side by side',
        (tester) async {
      final (chatRepo, chatDb) = _makeChatRepo();
      addTearDown(() async {
        chatRepo.dispose();
        await chatDb.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: VaultConversationList(repository: chatRepo, embedded: true),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // No chat page yet — placeholder pane prompts a selection.
        expect(find.byType(VaultChatPage), findsNothing);
        expect(find.text('Select a conversation.'), findsOneWidget);

        // Tap a tile: chat pane mounts beside the list (no route push).
        await tester.tap(find.text('Rune Virtanen'));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(VaultChatPage), findsOneWidget);
        // Title appears in the list pane and the chat appbar.
        expect(find.text('Rune Virtanen'), findsNWidgets(2));
      });
    });

    testWidgets('narrow window: tapping pushes a full-screen chat page',
        (tester) async {
      final (chatRepo, chatDb) = _makeChatRepo();
      addTearDown(() async {
        chatRepo.dispose();
        await chatDb.close();
      });

      await mockNetworkImagesFor(() async {
        await tester.binding.setSurfaceSize(const Size(500, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: VaultConversationList(repository: chatRepo),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.text('Rune Virtanen'));
        await tester.pumpAndSettle();

        expect(find.byType(VaultChatPage), findsOneWidget);
      });
    });
  });
}
