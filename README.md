# Echo Bay

*Capture the day before it fades.*

A local-first life-logging social app in Flutter — a photo journal (The
Square), private local-first messaging (The Vault), and community
boards and dorms (The Hallway), designed to look like it was drawn in a
0.5mm gel pen on the pages of a well-loved sketchbook.

Formerly the working names **Prism**, **Golden Hour**, then **superapp**;
renamed when the identity settled. See `docs/NAMING.md` for the decision
record.

## What's inside

- **The Square** — a chronological photo-and-sentence feed. Polaroid
  framed cards that "develop" in from their blurhash, a handwritten
  journal header, one Daily Square prompt a day (opt-in, pausable, no
  streaks). Posts can be **ephemeral** ("fades in 24h", with a keep-it
  action) or permanent. Un-liking and un-posting play the signature
  **rewind** — the app-wide undo gesture. Comments with mock-peer
  replies, a notices bell with unread badges, share-any-post-as-image
  export cards (tilted a couple of degrees, like a print set down by
  hand), an audience switch between **Everyone** and **My
  Window** (only people you keep close), and a **time travel** scrubber
  that rewinds the whole app to any past day (read-only; deletes are
  soft, so the past stays recoverable). On wide screens the Square header
  ends with the rewind spiral that toggles that mode — the narrow header
  keeps its gear instead, since the mobile bar has no Settings slot.
  Peers' names and avatars open their profile, where you can **Keep
  close** (follow) or **Drift apart** (unfollow) — no confirm, no fuss. From your own profile, **My
  Circle** lists who keeps you close and **My Window** lists who you
  keep close; drifts are soft, so time travel shows past states. Once
  in a while a peer starts keeping you close on their own — you get a
  quiet "Mila kept you close" notice. Nobody ever announces drifting
  apart.
- **The Vault** — private, local-first messaging. Messages live in a
  local database with a full delivery lifecycle (pending → sent →
  delivered → read), reactions, read cursors, edit and
  delete-for-everyone tombstones (undone by the rewind), and
  photo/video/voice attachments with playable waveform chips. On
  desktop the list and the open chat sit side by side, Telegram-style.
  The mock peers (Rune, Mila, the Ops channel) answer in character,
  with "Rune is writing…" indicators and realistic delays. Messages
  group by sender: a run of the same person stacks tight, and a change
  of speaker gets a breath of space. A deleted-for-everyone message
  leaves a rewind tombstone ("You rewound this message") with the
  rewind spiral, never a stock delete notice. The composer is an
  inked note box with a paper-plane send. The schema carries an
  unused ciphertext column for end-to-end encryption — a design goal,
  not a shipped feature.
- **The Hallway** — community bulletin: the Board (broadcast channels,
  remote-first cache model) and the Dorms (group chats, local-first
  outbox model), each with its own notebook-box treatment. Board tiles
  lead with the hand-drawn megaphone, and Dorms group their messages by
  sender the same way the Vault does.
- **The Landline** — a deliberate utility island: the cleanest module in
  the app (a handwritten masthead, nothing more), because a dialer with
  decorative grain is a dialer that's harder to read mid-call. Redial
  from the log or straight from a Vault conversation.
- **Profile** — name, picture, and accent color (six-ink palette,
  golden-hour amber by default), with your own posts gathered as
  polaroid thumbnails that open the day they belong to.
- **Keepsake wall** — a corkboard where you pin your own posts and
  handwritten notes; items drag, tilt, and string together with an
  inked line. Every card is stamped bottom-left with the time it
  remembers — the moment's own clock for a pinned post, the writing
  hour for a note. The paper is the same cream in both themes, so the
  cards' ink is pinned to charcoal and the notes stay readable under dark
  mode. Unpinning is a soft tombstone, so time travel can show the board
  as it was.
- **Search** — one box across posts, board posts, and messages (FTS5,
  tombstone-aware) with recent searches.
- **Settings** — theme, reduced motion, Daily Square prefs, and profile
  entry.

## The look

"Golden Hour, Inked" (see `docs/ART_DIRECTION.md`): warm sepia paper and
dusk blue-black surfaces, charcoal ink strokes with deterministic wobble,
scribble-fill selection states, wobbly notebook borders, and a five-icon
hand-drawn set (scribble heart, rewind spiral, X-scratched heart, jagged
speech bubble, paper plane). Handwritten voice in Caveat (SIL OFL);
body text in Roboto. Three neon accents — Rewind Blue, Graffiti Red,
Punk Marker Yellow — used sparingly, max one competing accent per screen.
("Golden Hour, Inked" is the style's name — the app itself is Echo Bay.)

The visual language is inspired by analog sketchbooks, zine culture, and
indie narrative adventures. It is an original design system: no assets,
fonts, logos, or named elements from any game or other property are used.

## Architecture

Clean Architecture with a strict dependency rule (`presentation → domain ←
data`), drift (SQLite) as the local source of truth, `Either<Failure, T>`
error handling, and get_it as the single composition root. Full details,
schema history, and the normative decisions live in
[`ARCHITECTURE.md`](ARCHITECTURE.md).

New here? Start with [`docs/HOW_IT_WORKS.md`](docs/HOW_IT_WORKS.md) — a
plain-language guide that traces real flows (sending a message, drawing a
chalk icon, switching the accent) through the actual code.

## Running it

```bash
flutter pub get
flutter run -d windows   # or -d chrome / your device
```

The same code runs in the browser: `flutter build web --release` produces
`build/web` (a static folder you can host anywhere — it runs SQLite via
WASM through `drift_flutter`). The file-touching seam in `lib/core/io/`
keeps `dart:io` out of `lib/`, so no per-platform forks.

First Windows build needs the C++ ATL component (see `ARCHITECTURE.md`
§1a — two plugins in the tree link against it).

## Tests

```bash
flutter test
```

The suite covers the data layer, UI, motion, theme, goldens, and the
Daily Square anti-chore rules.
