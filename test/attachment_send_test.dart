import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/database/app_database.dart';
import 'package:echo_bay/core/io/platform_io.dart';
import 'package:echo_bay/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:echo_bay/features/vault/data/repositories/mock_chat_repository.dart';
import 'package:echo_bay/features/vault/domain/entities/message.dart';

/// Attachment sends must not fail over how the file is stored: a shared
/// post carries a post id (there is no file at all), and a platform
/// without a filesystem keeps the session path instead of tripping the
/// "source missing" guard. That guard is what surfaced to the person as
/// "sendMessage failed" — on the web build, for every photo, video and
/// voice message, while plain text worked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  MockChatRepository buildRepo() => MockChatRepository(
        localDatasource: DriftVaultLocalDatasource(db),
        peerReplies: false,
        startTicker: false,
        incomingMessageInterval: const Duration(seconds: 3600),
      );

  Future<List<Message>> messages() => DriftVaultLocalDatasource(db)
      .watchMessages(conversationId: 'conv-1')
      .first;

  test('a shared post needs no file to be sent', () async {
    final repo = buildRepo();
    addTearDown(repo.dispose);
    await repo.ensureSeeded();

    final result = await repo.sendMessage(
      conversationId: 'conv-1',
      body: 'From the Square',
      attachment: const MessageAttachment.sharedPost('post-42'),
    );
    expect(result.isRight(), isTrue,
        reason: 'a post id is not a file; the copy step must skip it');

    final sent = (await messages()).firstWhere((m) => m.attachment != null);
    expect(sent.attachment!.kind, AttachmentKind.post);
    expect(sent.attachment!.sharedPostId, 'post-42');
  });

  test('a picked file is copied into the app attachment folder', () async {
    final repo = buildRepo();
    addTearDown(repo.dispose);
    await repo.ensureSeeded();

    final dir = await Directory.systemTemp.createTemp('echo-send-');
    addTearDown(() => dir.delete(recursive: true));
    final photo = File('${dir.path}/snap.jpg')..writeAsBytesSync(const [1, 2]);

    final result = await repo.sendMessage(
      conversationId: 'conv-1',
      body: '',
      attachment:
          MessageAttachment(kind: AttachmentKind.photo, path: photo.path),
    );
    expect(result.isRight(), isTrue);

    final sent = (await messages()).firstWhere((m) => m.attachment != null);
    expect(sent.attachment!.path, startsWith(await attachmentsDirPath()));
    expect(await fileExists(sent.attachment!.path), isTrue,
        reason: 'the stored copy must outlive the picker temp file');
  });
}
