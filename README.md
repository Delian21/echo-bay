# Echo Bay

*Capture the day before it fades.*

A local-first life-logging social app in Flutter — a photo journal (The
Square), end-to-end-encrypted messaging (The Vault), and community
boards and dorms (The Hallway), designed to look like it was drawn in a
0.5mm gel pen on the pages of a well-loved sketchbook.

Formerly the working names **Prism**, **Golden Hour**, then **superapp**;
renamed when the identity settled. See `docs/NAMING.md` for the decision
record.

## What's inside

- **The Square** — a chronological photo-and-sentence feed. Polaroid
  framed cards that "develop" in from their blurhash, a handwritten
  journal header, one Daily Square prompt a day (opt-in, pausable, no
  streaks). Un-liking and un-posting play the signature **rewind** — the
  app-wide undo gesture.
- **The Vault** — offline-first secure messaging. Messages are local-first
  with a full delivery lifecycle (pending → sent → delivered → read),
  reactions, read cursors, edit and delete-for-everyone tombstones (undone
  by the rewind). On desktop the list and the open chat sit side by side,
  Telegram-style. The mock peers (Rune, Mila, the Ops channel) answer in
  character, with typing indicators and realistic delays. The composer is
  an inked note box with a paper-plane send and photo/video/voice attach
  slots.
- **The Hallway** — community bulletin: the Board (broadcast channels,
  remote-first cache model) and the Dorms (group chats, local-first
  outbox model), each with its own notebook-box treatment.
- **The Landline** — a deliberate utility island: the cleanest module in
  the app (a handwritten masthead, nothing more), because a dialer with
  decorative grain is a dialer that's harder to read mid-call.

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

## Running it

```bash
flutter pub get
flutter run -d windows   # or -d chrome / your device
```

First Windows build needs the C++ ATL component (see `ARCHITECTURE.md`
§1a — two plugins in the tree link against it).

## Tests

```bash
flutter test
```

122 tests across the data layer, UI, motion, theme, goldens, and the
Daily Square anti-chore rules.
