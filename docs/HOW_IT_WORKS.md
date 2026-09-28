# How Echo Bay Works — a plain-language developer guide

This is the "explain it like I'm new" document. It covers what the app is,
how the code is organised, then traces three real flows through the actual
code: **sending a Vault message**, **drawing a chalk icon**, and
**switching the theme accent**. Written for someone new to Flutter or to
this codebase — no prior context assumed.

---

## 1. What is Echo Bay?

A **local-first** life-logging social app. "Local-first" means your data
lives in a SQLite database **on your device first**; a server (currently
mocked) only ever syncs on top of that. You can use the whole app offline.

It has four modules, each a folder under `lib/features/`:

| Module | Folder | What it does |
|---|---|---|
| **The Square** | `features/square` | A photo-and-sentence journal feed |
| **The Vault** | `features/vault` | Private messaging (mock E2EE-ready) |
| **The Hallway** | `features/nexus` | Community: the Board (broadcast) + Dorms (group chats) |
| **The Landline** | `features/calls` | Call log and a mock call screen |

The look is "Golden Hour, Inked" — sepia paper, charcoal ink, wobbly
hand-drawn borders and chalk icons. See `docs/ART_DIRECTION.md`.

---

## 2. The layer cake (Clean Architecture in 60 seconds)

Code lives in three layers, with a one-way dependency rule:

```
presentation (widgets, pages)  →  domain (entities, contracts)  ←  data (drift, mocks)
```

- **domain** — plain Dart. Entities (`Post`, `Message`) and abstract
  repository *contracts* (`ChatRepository` = "someone who can send a
  message", without saying how). Imports no Flutter, no database.
- **data** — implements the contracts. Today the implementations are
  **mocks** that write through to the real local database, so the app
  behaves like a real backed app offline.
- **presentation** — widgets and blocs. They only ever see the domain
  contracts, never the mock classes.

Why bother? Because swapping the mocks for a real backend later means
changing **one file**: `lib/injection.dart`, the single place that wires
concrete implementations into the contracts (via the `get_it` service
locator).

**Errors** cross the boundary as `Either<Failure, T>` (from `fpdart`):
a repository returns either a `Failure` (left) or the data (right). It
never throws.

**Streams over pulls:** every list that can change is a `Stream` from
drift's reactive queries. The UI renders what the stream emits; nothing
polls.

---

## 3. The database: drift + SQLite

`lib/core/database/app_database.dart` declares the schema (10 versions so
far — posts, messages, group messages, reactions, read cursors, FTS5
search tables, tombstone columns, `attachment_duration_ms`). Drift
generates type-safe code from it (`app_database.g.dart` — never edit).

Key rule: **migrations must be idempotent.** Each `onUpgrade` step checks
whether a column/table already exists before acting, because a crash
mid-migration leaves `user_version` at the old value and the whole chain
re-runs on next launch.

### Desktop vs web in one file

The same schema runs on Windows and in the browser:

```dart
// app_database.dart
AppDatabase _open() => AppDatabase(_openConnection());

QueryExecutor _openConnection() => driftDatabase(
  name: 'echo_bay',
  native: DriftNativeOptions(databasePath: () async => 'echo_bay.sqlite'),
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  ),
);
```

On the web, drift runs SQLite compiled to WebAssembly. The two asset files
`web/sqlite3.wasm` and `web/drift_worker.js` **must match the versions in
`pubspec.lock`** (sqlite3 2.9.4 / drift 2.31.0 today) or you get runtime
errors. If you bump drift in `pubspec.yaml`, re-download both from the
matching releases.

---

## 4. The IO seam (why there's no `dart:io` in `lib/`)

Browsers have no files. Windows code wants `dart:io.File`. The fix is a
**conditional export seam** in `lib/core/io/`:

- `platform_io.dart` — the seam: `export 'io_stub.dart' if (dart.library.io) 'io_native.dart';`
- `io_native.dart` — real implementations (`FileImage`, real reads/writes)
- `io_stub.dart` — browser no-ops (`platformImageProvider` returns a
  `NetworkImage` for blob URLs, writes do nothing, `fileExists` → false)

The compiler picks the right file per platform. **Rule: nothing under
`lib/` may `import 'dart:io'` directly** — go through `platformImageProvider`,
`fileExists`, `joinPath`, etc. (Check with `grep -rln "import 'dart:io'" lib/`,
which should print nothing.)

Consequence to know: voice-note *peaks* and attachments are computed with
real files on desktop, but on web the persisted copies are no-ops, so
attachments are **session-only** in the browser.

---

## 5. The sketch kit: how a chalk icon gets drawn

All hand-drawn visuals live in `lib/core/design_system/sketch_kit.dart`.
The building blocks:

- **`SketchRng`** — a seeded random number generator. Same seed → same
  wobble, every rebuild. Nothing is ever `Random()` unseeded, so nothing
  re-randomises when Flutter rebuilds a widget.
- **`SketchIconKind`** — an enum of 38 icon shapes (hearts, spirals,
  handset, dialPad, sunMark, moonCrescent…).
- **`SketchIcon`** — takes a `kind:` and a `seed:` and paints the shape
  with two jittered passes of charcoal (or chalk in dark mode), so the
  line looks like the pen went over it twice.
- **`SketchBox`** — wobbly notebook-border container.
- **`WobblyCircleClipper`** — clips avatars into imperfect circles.

### Tracing one icon end-to-end

When the Settings page shows the light-mode toggle, it does:

```dart
// settings_page.dart — helper (inside the theme-mode card state class)
Widget themeSwitchIcon(SketchIconKind kind, IconData fallback) {
  // In "ink" mode draw the chalk glyph; otherwise fall back to Material.
  return GoldenHourExtension.enabled
      ? SketchIcon(kind: kind, size: 20, seed: kind.index * 13 + 3)
      : Icon(fallback);
}
```

`SketchIcon` builds a `CustomPaint` whose painter walks the shape's path
definition, feeding each point through the seeded `SketchRng` to offset it
by ≤1dp, then strokes the path twice. Identical pixels on every rebuild —
the icon does not "shiver". The segments also set `showSelectedIcon: false`,
because Material 3 otherwise prepends a ✓ that shoves the glyph aside.

To add an icon: add an enum value to `SketchIconKind`, write its painter
case, and use it with a stable seed.

---

## 6. Tracing a sent message (The Vault)

1. You type in the composer and hit send.
2. The Vault page calls the `ChatRepository` **contract** (never the mock
   class directly).
3. `MockChatRepository.sendMessage` **writes the row to drift first** with
   `syncStatus = pending` — this is the local-first rule: persist before
   any network attempt.
4. It then schedules the fake delivery chain: `pending → sent →
   delivered → read`, each step a timer that updates the row; drift's
   reactive stream pushes the change to the UI automatically — that's
   what drives the tick marks (`status_tick.dart`).
5. The peer persona (Rune, Mila…) schedules an in-character reply with a
   typing indicator exposed via `watchTyping`.
6. Offline (`setOnline(false)`)? Timers stall, messages pile up as
   pending; `syncOutbox()` is the one function a future background worker
   will call to flush them.

Edits and delete-for-everyone are **tombstone writes** (`editedAt` /
`deletedAt` timestamps), never hard deletes — a deleted message keeps its
row with a blanked body, and the same machinery can undo it (the app-wide
**rewind** gesture, ~600ms mirror-wobble whose undo fires at the visual
midpoint).

---

## 7. Tracing a theme accent switch

1. The palette lives in `kAccentPalette` (`core/profile/user_profile.dart`):
   six ink pots — cobalt (default), amber, terracotta, moss, iron-gall
   sepia, oxblood.
2. Choosing one updates the profile controller, which rebuilds
   `MaterialApp` with `buildGoldenHourLightTheme(colorSeed: ...)` — the
   accent is threaded through as `ColorScheme.primary`.
3. Everything tints from `primary`. One non-obvious consumer:
   `navSelectedIconColor(scheme)` in `app_theme.dart`. The nav rail draws
   a pill behind the selected icon by mixing ~22% accent into the surface;
   the icon colour must contrast against **that pill**, not the bare
   surface. Amber-on-pale-amber failed the 3:1 contrast bar, so the
   helper computes the pill colour and picks a higher-contrast icon tint.
   `test/nav_accent_contrast_test.dart` locks this in: 25 tests across all
   six accents × light/dark, plus one regression test proving the old
   amber value failed.

Every hand-drawn extra is gated behind `GoldenHourExtension.enabled`;
when it's off (e.g. plain `MaterialApp` in tests), stock Material renders.

---

## 8. Running it

```bash
flutter pub get
flutter run -d windows   # desktop
flutter run -d chrome    # web (dev)

flutter build web --release   # outputs build/web; serve the folder with any static server
flutter test                  # the full suite
```

First Windows build needs the Visual Studio **C++ ATL** component (see
`ARCHITECTURE.md` §1a). Web needs the two wasm/worker assets in `web/`
described in §3.
