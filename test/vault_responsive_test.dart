import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/design_system/breakpoints.dart';
import 'package:echo_bay/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:echo_bay/features/vault/data/repositories/mock_chat_repository.dart';
import 'package:echo_bay/features/vault/ui/vault_conversation_list.dart';

/// The Vault's responsive contract: embedded mode is necessary but not
/// sufficient for master-detail. Regression for the "Select a
/// conversation defeats the purpose of mobile view" bug — a narrow
/// window in the wide shell used to force the two-pane layout.
void main() {
  late AppDatabase db;
  late DriftVaultLocalDatasource local;
  late MockChatRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = DriftVaultLocalDatasource(db);
    repository = MockChatRepository(
      localDatasource: local,
      incomingMessageInterval: const Duration(hours: 1),
      startTicker: false,
    );
  });

  tearDown(() async {
    repository.dispose();
    await db.close();
  });

  Finder detailEmptyState() => find.text('Select a conversation.');

  group('Vault responsive layout', () {
    // setSurfaceSize scales the render surface but MediaQuery keeps the
    // default 800px logical width — the responsive widgets read logical
    // size, so set the view's physical size + pixel ratio instead.
    void setLogicalSize(WidgetTester tester, Size logical) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = logical; // dpr 1: physical == logical
      addTearDown(tester.view.reset);
    }

    testWidgets('embedded below breakpoint: full-page list, no detail pane',
        (tester) async {
      // Deliberately just under the shared breakpoint.
      setLogicalSize(tester, const Size(AppBreakpoints.wide - 6, 900));

      await tester.pumpWidget(MaterialApp(
        home: VaultConversationList(repository: repository, embedded: true),
      ));
      // First stream emission + staggered entrance.
      await tester.pump(const Duration(milliseconds: 600));

      // The list is the whole page: conversation tiles are findable and
      // the master-detail empty state never renders.
      expect(find.text('Rune Virtanen'), findsOneWidget);
      expect(detailEmptyState(), findsNothing);
    });

    testWidgets('embedded at/above breakpoint: master-detail panes',
        (tester) async {
      setLogicalSize(tester, const Size(AppBreakpoints.wide + 200, 900));

      await tester.pumpWidget(MaterialApp(
        home: VaultConversationList(repository: repository, embedded: true),
      ));
      await tester.pump(const Duration(milliseconds: 600));

      // Wide shell: the list pane AND the detail placeholder coexist.
      expect(find.text('Rune Virtanen'), findsOneWidget);
      expect(detailEmptyState(), findsOneWidget);
    });
  });
}
