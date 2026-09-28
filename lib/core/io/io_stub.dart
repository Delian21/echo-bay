import 'package:flutter/painting.dart' show ImageProvider, NetworkImage;

/// Web stubs for the IO seam. The browser has no local filesystem, so
/// existence checks are false, reads return null, writes are no-ops,
/// and image paths fall through to a Network provider — image_picker on
/// web hands out blob: URLs which the platform image pipeline can
/// decode within the session. Real durable attachment storage on web
/// comes from drift's IndexedDB/OPFS via the database, not files.
ImageProvider platformImageProvider(String path) => NetworkImage(path);

Future<bool> fileExists(String path) async => false;

Future<int> fileLength(String path) async => 0;

Future<String?> fileReadString(String path) async => null;

Future<void> fileWriteString(String path, String contents) async {}

Future<void> fileDelete(String path) async {}

Future<String> fileCopy(String sourcePath, String destPath) async => destPath;

Future<String> dirEnsure(String path) async => path;

String joinPath(String a, String b) => '$a/$b';

String get currentDirPath => '/';
