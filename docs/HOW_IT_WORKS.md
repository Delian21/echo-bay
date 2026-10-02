# How Echo Bay Works — a plain-language developer guide

This is the "explain it like I'm new" document. It covers what the app is,
how the code is organised, then traces several real flows through the
actual code: **sending a Vault message**, **drawing a chalk icon**,
**switching the theme accent**, **posting an ephemeral Square post**,
**commenting and getting a peer notification**, **pinning to the keepsake
wall**, and **travelling to a past day**. Written for someone new to
Flutter or to this codebase — no prior context assumed.

---

## 1. What is Echo Bay?

A **local-first** life-logging social app. "Local-first" means your data
lives in a SQLite database **on your device first**; a server (currently
mocked) only ever syncs on top of that. You can use the whole app offline.

It has four mainline modules plus social and keepsake layers, each a
folder under `lib/features/`:

| Module | Folder | What it does |
|---|---|---|
| **The Square** | `features/square` | A photo-and-sentence journal feed. Posts can be **ephemeral** ("fades in 24h") or permanent. |
| **The Vault** | `features/vault` | Private, local-first messaging (E2EE designed-for, not yet implemented) |
| **The Hallway** | `features/nexus` | Community: the Board (broadcast) + Dorms (group chats) |
| **The Landline** | `features/calls` | Call log and a mock call screen |
| **Social** | `features/social` | Comments on Square posts + a notices feed. Mock peers (Rune, Mila, Ops) may comment or react after a realistic delay — capped and spaced, never spammy. |
| **Keepsake wall** | `features/keepsake` | A corkboard where you pin your own posts and handwritten notes. Items drag, tilt, and can be strung together with an inked line. |

The look is "Golden Hour, Inked" — sepia paper, charcoal ink, wobbly
hand-drawn borders and chalk icons. See `docs/ART_DIRECTION.md`.

---

## 2. The layer cake (Clean Architecture in 60 seconds)

Code lives in three layers, with a one-way dependency rule:

```
presentation (widgets, pages)  →  domain (entities, contracts)  ←  data (drift, mocks)
```

- **domain** — plain Dart. Entities (`Post`, `Message`, `KeepsakeItem`)
  and abstract repository *contracts* (`ChatRepository` = "someone who
  can send a message", without saying how). Imports no Flutter, no
  database.
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

`lib/core/database/app_database.dart` declares the schema (15 versions so
far — posts, messages, group messages, reactions, read cursors, FTS5
search tables, tombstone columns, attachment columns, post comments,
social notifications, keepsake items, the `unpinned_at` soft-unpin
column, and the `unliked_at` soft-unlike column). Drift generates
type-safe code from it (`app_database.g.dart` — never edit).

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
- **`SketchIconKind`** — an enum of 41 icon shapes (hearts, spirals,
  handset, dialPad, sunMark, moonCrescent, scribbleLine…).
- **`SketchIcon`** — takes a `kind:` and a `seed:` and paints the shape
  with two jittered passes of charcoal (or chalk in dark mode), so the
  line looks like the pen went over it twice.
- **`SketchBox`** — wobbly notebook-border container.
- **`WobblyCircleClipper`** — clips avatars into imperfect circles.
- **`hand_date.dart`** — the app's handwritten *date voice*, shared by
  every surface that prints a date the reader sees as handwriting:
  `handDateTime` (the maker's mark, `'Fri 2 Oct · 18:40'`) and
  `handDayLine` (the masthead long form, `'Friday, October 2'`). Pure
  string work with no Flutter import, which is what lets the non-widget
  share-card renderer print in the same voice as the feed.

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

**No Material glyphs in app chrome.** The FAB's long-press quick-action
sheet (Photo / Sentence / Sound / Time travel) and the Board's channel
tiles all draw chalk glyphs; a Material icon sitting next to them reads
as an unfinished seam. There is a regression test
(`test/fab_bar_test.dart`) asserting the sheet leads with four `SketchIcon`s.

**Ink on paper is pinned, never themed.** A surface that is the same
colour in both themes (the keepsake card is always cream) must not take
its ink from `Theme` — dark mode hands you chalk and the text vanishes.
Such surfaces hard-code `SketchInk.charcoal`.

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
5. The peer persona (Rune, Mila…) schedules an in-character reply with an
   is-writing indicator ("Rune is writing…") exposed via `watchTyping`.
6. Offline (`setOnline(false)`)? Timers stall, messages pile up as
   pending; `syncOutbox()` is the one function a future background worker
   will call to flush them.

Edits and delete-for-everyone are **tombstone writes** (`editedAt` /
`deletedAt` timestamps), never hard deletes — a deleted message keeps its
row with a blanked body, and the same machinery can undo it (the app-wide
**rewind** gesture, ~600ms mirror-wobble whose undo fires at the visual
midpoint). The tombstone reads "You rewound this message" and carries the
rewind spiral: the app's own vocabulary, not a stock delete notice.

**Message rhythm.** Every conversation list computes whether a message
*opens a sender's run* (`index == 0 || previous.senderId != mine`) and
passes that flag down. The Vault turns it into vertical margin — 12px when
the speaker changes, 2px inside a run — so a burst reads as one block.
The Dorms additionally show the sender's name only on the message that
opens the run, instead of repeating it above every bubble.

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

## 8. Ephemeral posts ("fades in 24h")

When composing, the "Fades in 24h" toggle sets `posts.expires_at` (schema
v11). The rules:

- **Visibility is a query-time filter** (`expiresAt IS NULL OR
  expiresAt > now`) applied in every Square read path — feed, day view,
  profile grid, search. Correctness never depends on a background job.
- The card **fades visually** as expiry approaches (opacity keyed to time
  remaining, floored at 0.2) and carries a hand-drawn clock-tick strip.
- A **"keep it"** action on your own ephemeral post clears `expires_at` —
  the post becomes permanent instantly (the stream re-emits).
- **Purge is lazy**: `purgeExpiredPosts(now)` hard-deletes expired rows
  (and their likes) once per app start. Expired-but-unpurged rows are
  already invisible; the purge only reclaims storage and search-index
  entries.
- All expiry checks go through an **injectable clock** (`DateTime
  Function()` on the datasource, `AppDatabase.clock` for search/purge) so
  tests pin a fixed instant and the boundary (`expiresAt == now` counts as
  expired) is deterministic.

## 9. Comments, peer notifications (Social)

- Comments live in `post_comments` (v13); the composer is an inked note
  box under each post.
- After **you** publish, the feed calls
  `SocialRepository.onOwnPostPublished`. The **`PeerPlanner`** (pure
  domain, injectable RNG) decides whether anybody responds: at most **2
  events per post**, distinct peers, first event ≥20s out, ≥25s between
  events, and roughly **1-in-6 posts draw silence** — the no-chore,
  no-guilt rule from the Daily Square.
- Each event lands as a comment row and/or a `social_notifications` row;
  the app-bar bell shows a live unread count (`watchUnreadCount`), and
  the notices page deep-links to the context and marks everything read
  on the way out.

## 10. The keepsake wall

`keepsake_items` (v13/v14) stores items as **board-relative fractions**
(posX/posY in 0..1) plus a small rotation — so the same layout scales
across phone and desktop. Drag ends persist the new fraction; a thumbtack
handle strings two items together (`strungTo`), drawn as a wobbly 2-pass
ink line. **Unpin is a soft tombstone** (`unpinned_at`, v14): the row
survives so time travel can rebuild past boards; the present board simply
filters `unpinned_at IS NULL`.

The corkboard ground and the cards on it are fixed colours in *both*
themes, so everything printed on a card pins its ink to
`SketchInk.charcoal` rather than reading it from `Theme`. Taking it from
`Theme` meant dark mode painted chalk on cream paper and the notes became
unreadable. `test/keepsake_board_widget_test.dart` renders the board under
`ThemeData.dark()` and asserts the note ink, so the regression can't
quietly come back.

**The maker's mark.** Every card is stamped bottom-left in
`handDateTime` format, like the imprint on the back of a passport photo —
the wall was the only undated surface in an app otherwise obsessed with
*when*. Which clock it shows depends on the card: a pinned post or message
stamps the **moment's own** time (a photo of a sunset pinned on Saturday
reads Friday 18:40), a handwritten note stamps when it was scratched down,
and a card whose moment can no longer resolve falls back to its pin time
rather than going blank. The stamp is a `Positioned` overlay, never a
footer: the card body clips to three lines and five, and a date that
reflows the thing it labels would be worse than no date at all.

## 11. Time travel (read-only past)

One `TimeTravelController` lives above `MaterialApp`
(`core/timetravel/time_travel_scope.dart`); the shell fans the as-of
instant out to the Square, Vault, social, and keepsake datasources, which
filter every read by timestamp:

- Square: `createdAt <= asOf` AND (`deletedAt` null or > asOf) AND
  ephemeral expiry evaluated **at the visited instant**.
- Vault: messages existing by then; delete-for-everyone tombstones hidden
  from the moment they happened.
- Social: comments/notifications created by then; the unread badge
  counts `readAt`-after-the-moment as still unread.
- Keepsake: pinned by then, not yet unpinned by then.

While active, **every write path throws** (`writes are refused while time
traveling`) — the past is read-only. The scrubber is a hand-drawn film
strip; "Return to today" exits through the app-wide rewind animation.

Two entry points, one handler: the rewind spiral at the end of the
Square header on **wide** layouts (the rail already carries Settings at
its foot), and the "Time travel" row in the compose FAB's long-press sheet
on every platform. Both toggle the same controller — in and out of
yesterday — and the mobile header keeps its gear, because the bottom bar
carries no Settings destination.

Honest limits: post hard-purge (the 10s undo window) and pre-edit Vault
bodies are not reconstructible — those writes overwrite history. Making
them historical needs append-only rows, which we judged not worth it.

---

## 12. Running it

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
