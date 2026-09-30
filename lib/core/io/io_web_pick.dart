import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Opens a browser file picker and resolves to the picked file's bytes,
/// or null when the user cancels. Uses <input type="file"> through
/// package:web interop — no extra dependency. The change listener fires
/// on selection; cancel fires the input's `cancel` event (and a change
/// never comes). Both paths remove the element and settle the future.
Future<Uint8List?> pickFileBytesImpl({
  String? accept,
  int maxBytes = 50 * 1024 * 1024,
}) {
  final completer = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept ?? '.json,application/json'
    ..style.display = 'none';

  web.document.body!.appendChild(input);

  void settle(FutureOr<Uint8List?> value) {
    if (completer.isCompleted) return;
    input.remove();
    completer.complete(value);
  }

  // Cancel path: the browser fires 'cancel' (no change). A fallback
  // timer unhangs the dialog if the browser never says anything.

  input.addEventListener(
    'change',
    (web.Event event) {
      final file = input.files?.item(0);
      if (file == null) return settle(null); // cancelled
      if (file.size > maxBytes) return settle(null); // service re-checks
      file.arrayBuffer().toDart.then((buffer) {
        settle(buffer.toDart.asUint8List());
      });
    }.toJS,
  );

  input.addEventListener(
    'cancel',
    ((web.Event event) {
      settle(null);
    }).toJS,
  );

  input.click();
  return completer.future;
}
