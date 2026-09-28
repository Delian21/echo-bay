import 'dart:io';

import 'package:flutter/painting.dart' show FileImage, ImageProvider;

/// Image provider for an on-disk attachment / avatar.
ImageProvider platformImageProvider(String path) => FileImage(File(path));

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
