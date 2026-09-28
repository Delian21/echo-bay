import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/auth/auth_repository.dart';
import 'package:superapp/core/auth/session_store.dart';
import 'package:superapp/core/error/failures.dart';

/// #6 identity posture: opaque, device-stable, non-derivable session.
void main() {
  // flutter_secure_storage touches platform channels; mock the channel
  // with an in-memory key-value map (the plugin has no fake, and the
  // real keystore is not available in the test env).
  TestWidgetsFlutterBinding.ensureInitialized();
  final secureBacking = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      switch (call.method) {
        case 'read':
          return secureBacking[call.arguments['key'] as String];
        case 'write':
          secureBacking[call.arguments['key'] as String] =
              call.arguments['value'] as String;
          return null;
        case 'delete':
          secureBacking.remove(call.arguments['key'] as String);
          return null;
        default:
          return null;
      }
    },
  );
  group('SessionStore', () {
    test('secure store mints once, then returns the same id', () async {
      final store = SecureSessionStore();

      final first = await store.loadOrCreate();
      final second = await store.loadOrCreate();

      expect(first.userId, second.userId);
      expect(first.userId, isNot('local-user'),
          reason: 'ids are minted, not the legacy constant');
    });

    test('clear destroys the identity; next load mints a new one',
        () async {
      final store = SecureSessionStore();
      final first = await store.loadOrCreate();
      await store.clear();
      final second = await store.loadOrCreate();
      expect(second.userId, isNot(first.userId));
    });
  });

  group('LocalAuthRepository', () {
    test('currentUser is stable across calls and signOut resets it',
        () async {
      final repo = LocalAuthRepository(SecureSessionStore());

      final a = await repo.currentUser();
      final b = await repo.currentUser();
      expect(
        a.fold((f) => null, (s) => s.userId),
        b.fold((f) => null, (s) => s.userId),
      );

      await repo.signOut();
      final c = await repo.currentUser();
      expect(
        c.fold((f) => null, (s) => s.userId),
        isNot(a.fold((f) => null, (s) => s.userId)),
      );
    });

    test('in-memory store is deterministic with a fixed id', () async {
      final repo = LocalAuthRepository(
        InMemorySessionStore(fixedUserId: 'test-user-1'),
      );
      final result = await repo.currentUser();
      expect(result.fold((f) => null, (s) => s.userId), 'test-user-1');
    });

    test('opaque id format: uuid-shaped, no personal data', () async {
      final repo = LocalAuthRepository(SecureSessionStore());
      final session = (await repo.currentUser())
          .fold((Failure f) => throw f, (s) => s);
      // UUID v4 shape — the whole point is that it is meaningless.
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(session.userId),
        isTrue,
      );
    });
  });
}
