import 'dart:typed_data';

/// Native no-op twin of [io_web.dart]'s downloadBytesImpl. The stub's
/// conditional import compiles this on native where package:web interop
/// must not be linked; the function is never called there.
void downloadBytesImpl(String fileName, Uint8List bytes) {}
