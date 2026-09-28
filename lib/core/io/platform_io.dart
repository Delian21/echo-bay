/// Platform IO seam: on native platforms these helpers touch the real
/// filesystem; on the web they degrade gracefully (existence checks are
/// false, reads return null, writes no-op, and image paths resolve
/// through a Network provider since the browser has no local
/// filesystem). This keeps the attachment pipeline compiling — and
/// non-fatal — in the browser, where real persistence comes from
/// drift's IndexedDB/OPFS storage instead of files.
library;

export 'io_stub.dart' if (dart.library.io) 'io_native.dart';
