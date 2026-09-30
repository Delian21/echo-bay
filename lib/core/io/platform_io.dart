/// Platform IO seam: on native platforms these helpers touch the real
/// filesystem; on the web they degrade gracefully (existence checks are
/// false, reads return null, writes no-op, and image paths resolve
/// through a Network provider since the browser has no local
/// filesystem). This keeps the attachment pipeline compiling — and
/// non-fatal — in the browser, where real persistence comes from
/// drift's IndexedDB/OPFS storage instead of files.
library;

export 'io_stub.dart' if (dart.library.io) 'io_native.dart';

// The stub's download path delegates to io_web.dart, which is safe:
// io_stub is only actually compiled on web (on native the conditional
// export picks io_native and the stub's web call is never linked).
// package:web is a dependency of the Flutter SDK on web builds.
export 'io_web.dart' if (dart.library.io) 'io_native.dart' show downloadBytesImpl;

/// File picker for restore: real browser <input type=file> on web via
/// package:web interop; native returns null for now (no file-dialog
/// plugin in the dependency set — the UI explains the path forward).
export 'io_web_pick.dart' if (dart.library.io) 'io_native_noop.dart' show pickFileBytesImpl;
