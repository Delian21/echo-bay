import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/onboarding/first_run.dart';
import 'package:echo_bay/core/profile/profile_controller.dart';
import 'package:echo_bay/core/settings/app_settings_store.dart';
import 'package:echo_bay/features/square/data/datasources/square_local_datasource.dart';
import 'package:echo_bay/features/square/data/repositories/mock_feed_repository.dart';

/// Regression: the onboarding setup step ("What should the town call
/// you?") painted blank — ProfilePage is a ListView, and a ListView
/// inside a Column inside a SingleChildScrollView gets zero height.
/// The step is now a CustomScrollView with the heading as a sliver
/// above the shrink-wrapped profile list; this test asserts the name
/// field is actually visible.
void main() {
  testWidgets(
    'setup step shows the embedded profile editor under the heading',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final feed = MockFeedRepository(
        localDatasource: DriftSquareLocalDatasource(db),
        db: db,
        localUserId: 'local-user',
        startTicker: false,
      );
      final controller = ProfileController(
        onProfileChanged: AppSettingsStore(db).writeProfile,
      );
      addTearDown(() async {
        feed.dispose();
        await db.close();
      });

      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // setupProfileStep returns the step's scroll structure itself —
      // exactly what the real _SetupProfileStep builds — so it goes
      // straight into the Scaffold body (nesting it in another
      // scrollable would give the inner viewport unbounded height).
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: FirstRunFlow.setupProfileStep(
              controller: controller,
              feedRepository: feed,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // The heading renders…
      expect(find.text('What should the town call you?'), findsOneWidget);
      // …and the profile editor below it is VISIBLE (the regression:
      // zero-height ListView meant finders hit but hit-test/screenshot
      // showed nothing; assert the field's actual geometry on screen).
      final nameField = find.text('Your name');
      expect(nameField, findsOneWidget);
      final box = tester.renderObject<RenderBox>(nameField);
      expect(box.size.height, greaterThan(0));
      expect(box.localToGlobal(Offset.zero).dy, lessThan(1000));
      // The accent picker section made it too (scrolled content exists).
      expect(find.text('ACCENT COLOR'), findsOneWidget);
    },
  );
}
