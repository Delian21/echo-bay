import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart' show FileImage, ImageProvider;
import 'package:path_provider/path_provider.dart';

/// Image provider for an on-disk attachment / avatar.
ImageProvider platformImageProvider(String path) => FileImage(File(path));

/// Writes binary bytes to a temp-ish path in the working directory and
/// returns the path (native: a real file). Used by share-card export.
Future<String> writeBytes(String fileName, Uint8List bytes) async {
  final dir = Directory(joinPath(currentDirPath, '.shares'));
  if (!await dir.exists()) await dir.create(recursive: true);
  final path = joinPath(dir.path, fileName);
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

/// Whether the file exists on disk.
Future<bool> fileExists(String path) => File(path).exists();

/// File length in bytes (0 when missing).
Future<int> fileLength(String path) async => (await File(path).exists())
    ? File(path).length()
    : 0;

/// Reads a text file; null when missing.
Future<String?> fileReadString(String path) async =>
    (await File(path).exists()) ? File(path).readAsString() : null;

/// Writes (creates or overwrites) a text file, parent dir included.
Future<void> fileWriteString(String path, String contents) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsString(contents);
}

/// Deletes a file if present. No-op when missing.
Future<void> fileDelete(String path) async {
  final f = File(path);
  if (await f.exists()) await f.delete();
}

/// Copies a file; returns the destination path. Throws when the source
/// is missing (callers treat that as a failed send).
Future<String> fileCopy(String sourcePath, String destPath) async {
  await File(sourcePath).copy(destPath);
  return destPath;
}

/// Ensures a directory exists and returns its path.
Future<String> dirEnsure(String path) async {
  final d = Directory(path);
  if (!await d.exists()) await d.create(recursive: true);
  return d.path;
}

/// Joins path segments with the platform separator.
String joinPath(String a, String b) => '$a${Platform.pathSeparator}$b';

/// The process working directory (native only).
String get currentDirPath => Directory.current.path;

/// Writable, app-scoped folder for chat attachments (photos, videos,
/// voice notes).
///
/// This must not be the process working directory: on Android and iOS
/// that is `/`, which the app cannot create directories in, so every
/// attachment send failed while plain text messages (which only need the
/// database) worked. The support directory is durable and private to the
/// app on every platform.
///
/// Falls back to a temp directory where the plugin has no implementation
/// (unit tests run without platform channels); the copy still succeeds
/// there, and the stored absolute path is what the bubbles read back.
Future<String> attachmentsDirPath() async {
  String base;
  try {
    base = (await getApplicationSupportDirectory()).path;
  } on Object {
    base = Directory.systemTemp.path;
  }
  return dirEnsure(joinPath(base, 'attachments'));
}

/// Native platforms have a real filesystem for attachments.
bool get hasFileStore => true;

/// Native file picker for restore. A full desktop file dialog needs a
/// plugin not in the dependency set; the seam stays honest by returning
/// null and letting the UI explain. (Backup files arrive by dropping
/// them into the attachments dir or a future plugin.)
Future<Uint8List?> pickFileBytes({String? accept, int maxBytes = 52428800})
    async => null;
