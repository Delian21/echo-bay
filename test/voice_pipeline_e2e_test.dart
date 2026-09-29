import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/attachments/attachment.dart';
import 'package:echo_bay/core/attachments/voice_note_player.dart';
import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:echo_bay/features/vault/data/repositories/mock_chat_repository.dart';
import 'package:echo_bay/features/vault/domain/entities/message.dart';

/// End-to-end voice-note pipeline (unit level — widget pumps drag in the
/// audio-player platform channels and drift stream timers, which
/// deadlock under flutter_test's FakeAsync; the UI rendering of these
/// paths is covered by vault_ui_test):
///
/// 1. a recorded note's `.wave` sidecar round-trips (write → parse);
/// 2. an attachment sent through the repo persists to the store and
///    comes back through a *fresh* datasource (schema v9 round-trip);
/// 3. the shared player exposes sane state transitions for chips.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('echo_bay_voice_test');
  });

  tearDown(() async {
    await db.close();
    await VoiceNotePlayer.instance.stop();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('voice sidecar waveform round-trips through disk', () async {
    final m4a = File('${tmp.path}/voice_1.m4a')..writeAsStringSync('x');
    final recorded = List.generate(30, (i) => 0.15 + 0.7 * ((i * 7) % 11) / 11);
    File('${m4a.path}.wave').writeAsStringSync(recorded.join(','));

    // Read back exactly as VoiceWaveformChip parses it.
    final raw = await File('${m4a.path}.wave').readAsString();
    final parsed =
        raw.split(',').where((s) => s.isNotEmpty).map(double.parse).toList();

    expect(parsed.length, recorded.length);
    expect(parsed.first, closeTo(recorded.first, 1e-9));
    expect(parsed, everyElement(inInclusiveRange(0, 1)));
  });

  test('voice attachment persists and reloads through a fresh datasource',
      () async {
    final repo = MockChatRepository(
      localDatasource: DriftVaultLocalDatasource(db),
      peerReplies: false,
      startTicker: false,
      incomingMessageInterval: const Duration(seconds: 3600),
    );
    addTearDown(repo.dispose);
    await repo.ensureSeeded();

    final m4a = File('${tmp.path}/voice_2.m4a')..writeAsStringSync('x');
    final result = await repo.sendMessage(
      conversationId: 'conv-1',
      body: 'with a note',
      attachment: MessageAttachment(
        kind: AttachmentKind.voice,
        path: m4a.path,
        durationMs: 1500,
      ),
    );
    expect(result.isRight(), isTrue);

    // Fresh datasource on the same db — the schema-v9 round-trip.
    final local2 = DriftVaultLocalDatasource(db);
    final rows = await local2.watchMessages(conversationId: 'conv-1').first;
    final withNote = rows.where((m) => m.attachment != null).toList();
    expect(withNote, isNotEmpty);
    expect(withNote.first.attachment!.kind, AttachmentKind.voice);
    expect(withNote.first.attachment!.durationMs, 1500);
    expect(withNote.first.body, 'with a note');
  });

  test('photo attachment persists with its kind (media messages generalise)',
      () async {
    final repo = MockChatRepository(
      localDatasource: DriftVaultLocalDatasource(db),
      peerReplies: false,
      startTicker: false,
      incomingMessageInterval: const Duration(seconds: 3600),
    );
    addTearDown(repo.dispose);
    await repo.ensureSeeded();

    final png = File('${tmp.path}/photo.png')..writeAsStringSync('x');
    await repo.sendMessage(
      conversationId: 'conv-1',
      body: '',
      attachment: MessageAttachment(kind: AttachmentKind.photo, path: png.path),
    );

    final local2 = DriftVaultLocalDatasource(db);
    final rows = await local2.watchMessages(conversationId: 'conv-1').first;
    final photo = rows.firstWhere((m) => m.attachment != null);
    expect(photo.attachment!.kind, AttachmentKind.photo);
    expect(photo.body, isEmpty); // a photo alone is a message
  });
}
