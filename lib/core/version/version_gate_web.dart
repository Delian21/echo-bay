/// Web seam for [VersionChecker]: browser fetch, Cache Storage cleanup,
/// page reload. Compiled only on web (see the conditional import in
/// version_checker.dart); everything here tolerates partial failure —
/// a blocked Cache API or a failed unregister must never block the
/// refresh.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Cache-busted GET of the deployed version.json. Returns the body
/// text, or null when the fetch fails (offline, 404).
Future<String?> fetchVersionJsonBody() async {
  final uri = 'version.json?_=${DateTime.now().millisecondsSinceEpoch}';
  try {
    final response = await web.window.fetch(uri.toJS).toDart;
    if (!response.ok) return null;
    return (await response.text().toDart).toDart;
  } on Object {
    return null;
  }
}

@JS('caches.keys')
external JSPromise<JSArray<JSString>> _cacheKeys();

@JS('caches.delete')
external JSPromise<JSBoolean> _cacheDelete(JSString name);

@JS('navigator.serviceWorker.getRegistrations')
external JSPromise<JSArray<JSObject>> _getRegistrations();

@JS('navigator.serviceWorker.controller')
external _ServiceWorkerContainer? _getSwController();

@JS('location.reload')
external void _locationReload();

@JS()
extension type _ServiceWorkerContainer._(JSObject _) implements JSObject {
  external JSPromise? get ready;

  external void postMessage(JSObject? message, [JSObject? options]);
}

@JS()
extension type _ServiceWorkerRegistration._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean?> unregister();
}

/// Drops every Cache Storage bucket (the offline worker's shell cache
/// included) and nudges the controlling worker to activate the new one,
/// so the reload below boots the truly deployed build. Best-effort
/// throughout.
void clearCachesAndWorkers() {
  // 1. Clear every cache bucket.
  try {
    _cacheKeys().toDart.then((keys) {
      for (final key in keys.toDart) {
        _cacheDelete(key).toDart.catchError((_) => true.toJS);
      }
    }).catchError((_) {});
  } on Object {
    // No Cache API: fall through to the reload.
  }

  // 2. Tell the controlling worker to hand over: the new worker's
  //    install handler answers {type:'SKIP_WAITING'} and calls
  //    clients.claim(), so the *next* load is served by the new code.
  try {
    _getSwController()?.postMessage(JSObject());
  } on Object {
    // Best-effort: the reload handles most of the update.
  }

  // 3. Unregister leftovers (the deprecated Flutter stub especially).
  try {
    _getRegistrations().toDart.then((regs) {
      for (final reg in regs.toDart) {
        (reg as _ServiceWorkerRegistration).unregister();
      }
    }).catchError((_) {});
  } on Object {
    // Best-effort.
  }
}

/// Hard reload into the new build.
void reloadPage() {
  _locationReload();
}
