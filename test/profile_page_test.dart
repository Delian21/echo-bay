import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/core/database/app_database.dart';
import 'package:superapp/core/profile/profile_controller.dart';
import 'package:superapp/core/profile/user_profile.dart';
import 'package:superapp/core/settings/app_settings_store.dart';
import 'package:superapp/features/profile/data/repositories/drift_profile_repository.dart';
import 'package:superapp/features/profile/ui/profile_page.dart';
import 'package:superapp/features/square/data/datasources/square_local_datasource.dart';
import 'package:superapp/features/square/data/repositories/mock_feed_repository.dart';

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

  Widget page() => MaterialApp(
        home: ProfilePage(
          profileController: controller,
          feedRepository: feed,
        ),
      );

  testWidgets('shows display name, bio, and grid section', (tester) async {
    controller.update(const UserProfile(
      displayName: 'Ada Loomis',
      bio: 'dawn walker',
    ));
    await tester.pumpWidget(page());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ada Loomis'), findsOneWidget);
    expect(find.text('dawn walker'), findsOneWidget);
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
    await tester.pumpWidget(MaterialApp(
      home: ProfilePage(profileController: controller),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PINNED SQUARES'), findsNothing);
  });
}
