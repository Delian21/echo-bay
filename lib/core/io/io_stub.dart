import 'dart:typed_data';

import 'package:flutter/painting.dart' show ImageProvider, NetworkImage;

import 'io_web.dart' if (dart.library.io) 'io_native_noop.dart' show downloadBytesImpl;
import 'io_web_pick.dart' if (dart.library.io) 'io_native_noop.dart' as pick_impl;

/// Web stubs for the IO seam. The browser has no local filesystem, so
/// existence checks are false, reads return null, writes are no-ops,
/// and image paths fall through to a Network provider — image_picker on
/// web hands out blob: URLs which the platform image pipeline can
/// decode within the session. Real durable attachment storage on web
/// comes from drift's IndexedDB/OPFS via the database, not files.
ImageProvider platformImageProvider(String path) => NetworkImage(path);

/// Web: trigger a client-side download of [bytes] as [fileName]. No dart:io
/// here; implemented with an anchor-download over interop.
Future<String> writeBytes(String fileName, Uint8List bytes) async {
  downloadBytes(fileName, bytes);
  return fileName;
}

/// Browser download via an object-URL anchor click.
void downloadBytes(String fileName, Uint8List bytes) =>
    downloadBytesImpl(fileName, bytes);

Future<Uint8List?> pickFileBytes({String? accept, int maxBytes = 52428800}) =>
    pick_impl.pickFileBytesImpl(accept: accept, maxBytes: maxBytes);

Future<bool> fileExists(String path) async => false;

Future<int> fileLength(String path) async => 0;

Future<String?> fileReadString(String path) async => null;

Future<void> fileWriteString(String path, String contents) async {}

Future<void> fileDelete(String path) async {}

Future<String> fileCopy(String sourcePath, String destPath) async => destPath;

Future<String> dirEnsure(String path) async => path;

String joinPath(String a, String b) => '$a/$b';

String get currentDirPath => '/';
