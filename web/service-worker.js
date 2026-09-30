/*
 * Echo Bay offline service worker (hand-rolled).
 *
 * Flutter's generated service worker is deprecated in this Flutter version
 * and ships as a self-unregistering stub — it precaches nothing, so the
 * app did not load offline. This worker takes over:
 *   - Precaches the entire app shell on first visit (including the two
 *     files the golden-hour look depends on and the two files drift's
 *     web database depends on: sqlite3.wasm and drift_worker.js).
 *   - Serves those cache-first. After the first successful visit the app
 *     boots with the network completely down.
 *   - Navigations fall back to the cached index.html (deep links work
 *     offline).
 *   - Runtime-caches new asset URLs (e.g. a newly picked avatar) as
 *     they're fetched, so they survive reloads offline.
 *
 * Version bump (CACHE_NAME) invalidates old caches on redeploy.
 */
'use strict';

const CACHE_NAME = 'echo-bay-shell-v1';

const PRECACHE_URLS = [
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'flutter.js',
  'version.json',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'sqlite3.wasm',
  'drift_worker.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) =>
        // addAll is atomic: if any file 404s the install fails and the
        // old worker stays in charge. Warm one-by-one so one missing
        // file can't break offline for everything else.
        Promise.all(
          PRECACHE_URLS.map((url) =>
            cache.add(new Request(url, { cache: 'reload' })).catch((e) => {
              console.warn('[sw] precache failed:', url, e);
            }),
          ),
        ),
      )
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // App shell + build outputs: cache-first (immutable per CACHE_NAME).
  // Compare the path relative to the scope (e.g. 'main.dart.js').
  const rel = url.pathname.startsWith('/')
    ? url.pathname.slice(1)
    : url.pathname;
  const isShell =
    url.origin === self.location.origin &&
    (PRECACHE_URLS.includes(rel) || /\/(assets|canvaskit)\//.test(url.pathname));
  // CanvasKit also loads from the gstatic CDN depending on the build
  // config; cache whatever variant was actually fetched.
  const isCanvaskitCdn = url.hostname === 'www.gstatic.com';

  if (isShell || isCanvaskitCdn) {
    event.respondWith(
      caches.match(req, { ignoreSearch: true }).then((cached) => {
        if (cached) return cached;
        return fetch(req)
          .then((resp) => {
            if (resp && (resp.ok || resp.type === 'opaque')) {
              const copy = resp.clone();
              caches.open(CACHE_NAME).then((c) => c.put(req, copy));
            }
            return resp;
          })
          .catch(() =>
            // Navigation requests fall back to the cached shell so
            // deep links open offline.
            req.mode === 'navigate'
              ? caches.match('index.html')
              : Response.error(),
          );
      }),
    );
    return;
  }

  // Everything else (e.g. user files, API): network-first, cached as a
  // fallback so previously-seen content stays visible offline.
  event.respondWith(
    fetch(req)
      .then((resp) => {
        if (resp && resp.ok && url.origin === self.location.origin) {
          const copy = resp.clone();
          caches.open(CACHE_NAME).then((c) => c.put(req, copy));
        }
        return resp;
      })
      .catch(() => caches.match(req, { ignoreSearch: true })),
  );
});
