import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/profile/profile_controller.dart';
import 'package:superapp/core/profile/user_profile.dart';
import 'package:superapp/core/settings/app_settings_store.dart';
import 'package:superapp/features/profile/ui/profile_page.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';
import 'package:superapp/features/square/domain/repositories/feed_repository.dart'
    show FeedRepository;

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

  void useTallSurface(WidgetTester tester) {
    // The grid section sits below the fold at the default 800x600 test
    // viewport; a tall surface keeps every section laid out.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows display name, bio, and grid section', (tester) async {
    controller.update(const UserProfile(
      displayName: 'Ada Loomis',
      bio: 'dawn walker',
    ));
    // A write from a foreign author wakes the drift watch immediately,
    // so the grid section resolves to its empty state in this test's
    // event loop (Ada never posts here).
    await feed.createPost(body: 'not ada speaking', authorName: 'Bo Tamm');
    useTallSurface(tester);
    await tester.pumpWidget(page());
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The name appears twice when the edit sheet is open (header +
    // prefilled TextField), so match only plain Text widgets.
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'Ada Loomis'),
      findsOneWidget,
    );
    // Same for the bio: a prefilled edit TextField also carries the
    // text, so match only plain Text widgets.
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'dawn walker'),
      findsOneWidget,
    );
    expect(find.text('PINNED SQUARES'), findsOneWidget);
    // Empty state in the app's voice.
    expect(find.text('Nothing pinned yet. Your squares will gather here.'),
        findsOneWidget);
  });

  testWidgets('own posts appear as grid thumbnails after creation',
      (tester) async {
    controller.update(const UserProfile(displayName: 'You'));
    await feed.createPost(body: 'my pinned square', authorName: 'You');
    await tester.pumpWidget(page());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('my pinned square'), findsOneWidget);
    expect(
        find.text('Nothing pinned yet. Your squares will gather here.'),
        findsNothing);
  });

  testWidgets('editing bio commits through the controller', (tester) async {
    await tester.pumpWidget(page());
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(
      find.widgetWithText(TextField, 'One line, in ink…'),
      'ink and coffee',
    );
    await tester.pump();
    expect(controller.profile.bio, 'ink and coffee');
  });

  testWidgets('no feed repository means no grid section (older callers)',
      (tester) async {
    await tester.pumpWidget(page(repository: null));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PINNED SQUARES'), findsNothing);
  });
}
