import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/profile/profile_controller.dart';
import 'package:echo_bay/core/profile/user_profile.dart';
import 'package:echo_bay/core/settings/app_settings_store.dart';
import 'package:echo_bay/features/profile/ui/profile_page.dart';
import 'package:echo_bay/features/square/data/datasources/square_local_datasource.dart';
import 'package:echo_bay/features/square/data/repositories/mock_feed_repository.dart';
import 'package:echo_bay/features/square/domain/repositories/feed_repository.dart'
    show FeedRepository;

// Every test here carries a hard timeout: a stuck drift watch or a
// slow pump must fail fast (60-90s), never park the suite for 10 minutes.
void main() {
  late AppDatabase db;
  late MockFeedRepository feed;
  late ProfileController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    feed = MockFeedRepository(
      localDatasource: DriftSquareLocalDatasource(db),
      db: db,
      localUserId: 'local-user',
      startTicker: false,
    );
    controller = ProfileController(
      onProfileChanged: AppSettingsStore(db).writeProfile,
    );
  });

  tearDown(() async {
    feed.dispose();
    await db.close();
  });

  Widget page({FeedRepository? repository}) => MaterialApp(
        home: ProfilePage(
          profileController: controller,
          feedRepository: repository ?? feed,
        ),
      );

  testWidgets(
    'shows display name and bio',
    (tester) async {
      controller.update(const UserProfile(
        displayName: 'Ada Loomis',
        bio: 'dawn walker',
      ));
      await tester.pumpWidget(page());
      await tester.pump(const Duration(milliseconds: 300));

      // The name/bio also live in the prefilled edit TextFields, so
      // match only plain Text widgets.
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Ada Loomis'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'dawn walker'),
        findsOneWidget,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'grid section: empty state, then own posts as thumbnails',
    (tester) async {
      controller.update(const UserProfile(displayName: 'You'));
      // A foreign-author write wakes the drift watch so the first
      // emission lands within this test's event loop.
      await feed.createPost(body: 'not mine', authorName: 'Bo Tamm');
      await tester.pumpWidget(page());
      await tester.pump(const Duration(milliseconds: 300));

      // The grid section sits below the fold at the default 800x600
      // test viewport — scroll the page's ListView down to it.
      await tester.scrollUntilVisible(
        find.text('PINNED SQUARES'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PINNED SQUARES'), findsOneWidget);
      // Empty state in the app's voice (Ada/You posted nothing here).
      expect(
        find.text('Nothing pinned yet. Your squares will gather here.'),
        findsOneWidget,
      );

      // Now post as the profile owner: the grid swaps the empty state
      // for a thumbnail of the new square.
      await feed.createPost(body: 'my pinned square', authorName: 'You');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('my pinned square'), findsOneWidget);
      expect(
          find.text('Nothing pinned yet. Your squares will gather here.'),
          findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'editing bio commits through the controller',
    (tester) async {
      await tester.pumpWidget(page());
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(
        find.widgetWithText(TextField, 'One line, in ink…'),
        'ink and coffee',
      );
      await tester.pump();
      expect(controller.profile.bio, 'ink and coffee');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'no feed repository means no grid section (older callers)',
    (tester) async {
      await tester.pumpWidget(page(repository: null));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.scrollUntilVisible(
        find.text('DISPLAY NAME'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PINNED SQUARES'), findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
