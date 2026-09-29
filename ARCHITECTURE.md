# Architecture — Echo Bay

A local-first life-logging social app (display name **Echo Bay**; working
names: Prism, Golden Hour, then `superapp` — see `docs/NAMING.md`) with
independent feature modules
sharing one design system and one local database. Written for someone
joining the codebase who needs to know where things go and why — not a
tutorial.

## 1. The stack, in one paragraph

Clean Architecture with a strict dependency rule: `presentation → domain ←
data`. The domain layer is pure Dart (entities, abstract repositories,
usecase contract) and imports nothing from Flutter, drift, or dio. Data
layers implement domain contracts; presentation consumes only contracts and
entities. The composition root (`lib/injection.dart`) is the only place that
knows concrete types. State management is `flutter_bloc`; the local database
is `drift` (SQLite); functional errors are `Either<Failure, T>` via `fpdart`.

## 1a. Native build prerequisites (Windows desktop)

Two plugins in the dependency tree ship native C++ Windows implementations
that link against the **Active Template Library (ATL)**:

- `flutter_local_notifications` (`core/notifications/prompt_notifier.dart`) —
  includes `atlbase.h`
- `flutter_secure_storage` (`core/auth/session_store.dart`) — includes
  `atlstr.h`

The default "Desktop development with C++" workload in Visual Studio does
**not** install ATL. Without it the Windows build fails with
`error C1083: Cannot open include file: 'atlbase.h'` (and the same for
`atlstr.h`). New machine setup therefore requires:

1. Visual Studio 2026 (v18) Community, workload **Desktop development
   with C++** (the only workload this project needs).
2. The optional component **C++ ATL for latest v14x build tools
   (x86 & x64)** — Visual Studio Installer → Modify → select the C++
   workload → check it in the right-hand "Installation details" panel under
   Optional.
3. Flutter/Windows desktop enabled (`flutter config
   --enable-windows-desktop`), and `flutter doctor` clean before the first
   `flutter run -d windows`.

Verify on disk that ATL landed before rebuilding: an `atlmfc` folder must
exist under `VC\Tools\MSVC\<toolset>\`. If a future dependency swap removes
both plugins above, this component stops being required — update this
section then.

## 2. The modules

| Module | Purpose | Read/write model | Source of truth |
|---|---|---|---|
| **The Square** (`features/square`) | Public text-and-media chronological feed; posts can be **ephemeral** ("fades in 24h") | Read-mostly; network-first | Remote (mocked for now); drift is a cache |
| **The Vault** (`features/vault`) | Secure offline-first E2EE messaging | Write-heavy; local-first | **Local (drift)**; remote is a dumb sync transport |
| **The Hallway** (`features/nexus`) | Community hub: the **Board** (broadcast channels) + the **Dorms** (group chats) | Hybrid | Board: remote-first like Square. Dorms: local-first outbox like Vault minus E2EE |
| **The Landline** (`features/calls`) | Voice & video call log + mock call flow | Read-mostly | Local log; transport mocked |
| **Social** (`features/social`) | Comments on Square posts + the notices feed; mock peers (Rune, Mila, Ops) react to your posts on a capped, spaced schedule | Read-mostly; writes only in the present | Local (drift) |
| **Keepsake wall** (`features/keepsake`) | Corkboard of pinned own-posts and handwritten notes; drag/tilt/string | Write-local; geometry stored as board-relative fractions | Local (drift); unpin is a soft tombstone (v14) |
| **Profile** (`features/profile`) | Display name, bio, avatar, accent + a grid of your own squares | Local KV (settings table) + author-matched watch | Local (drift) |

**Time travel** (`core/timetravel`) is a cross-cutting read mode, not a
module: one `TimeTravelController` above `MaterialApp` holds the as-of
instant; the shell fans it to the Square/Vault/social/keepsake
datasources, which filter every read by timestamp and refuse writes
while active.

Display names follow the small-town rule (`docs/NAMING.md`): the Dart
feature directories and class names keep their code names
(`nexus`, `NexusRepository`, `calls`) — renaming code identifiers is part
of the deferred mechanical rename, not this pass.

The hybrid split is deliberate. Board channels are 1→many and read-heavy,
so they get the Square's cache model. Dorms are many→many and
write-heavy, so they get the Vault's outbox model. `NexusRepository` is
one domain contract whose implementation composes a channel cache and a
group outbox internally. The modules do **not** share a god-repository
and do not import from each other.

## 3. Directory layout

```
lib/
├── main.dart / bootstrap.dart / app.dart     # entry + MaterialApp root (T-003, pending)
├── injection.dart                            # get_it composition root — the ONLY place
│                                             #   that knows concrete implementations
├── core/
│   ├── constants/
│   ├── error/
│   │   ├── failures.dart                     # sealed Failure hierarchy (domain-side)
│   │   └── exceptions.dart                   # data-layer exceptions, mapped at repo edge
│   ├── network/                              # dio client + interceptors (contracted, unused)
│   ├── database/
│   │   ├── app_database.dart                 # drift schema: Posts, PostLikes,
│   │   │                                     #   Conversations, Messages (schema v1)
│   │   └── app_database.g.dart               # generated — never hand-edit
│   ├── storage/                              # flutter_secure_storage wrapper (pending)
│   ├── crypto/                               # primitives only — no protocol logic
│   ├── usecase/usecase.dart                  # UseCase<Output, Input>, Either-based
│   ├── router/                               # go_router shell (pending)
│   ├── theme/app_theme.dart                  # light+dark ThemeData, semantic tokens
│   └── design_system/status_tick.dart        # atomic widgets shared by features
└── features/
    ├── shell/                                # bottom-nav hosting all modules (pending)
    ├── auth/                                 # session, tokens (pending)
    ├── square/
    │   ├── domain/
    │   │   ├── entities/post.dart            # pure Post
    │   │   └── repositories/feed_repository.dart
    │   ├── data/
    │   │   ├── datasources/square_local_datasource.dart   # drift access
    │   │   └── repositories/mock_feed_repository.dart     # implements contract
    │   └── presentation/
    │       └── widgets/feed_card.dart        # atomic card, pure-entity input
    └── vault/
        ├── domain/
        │   ├── entities/message.dart         # Message, Conversation, DeliveryStatus
        │   └── repositories/chat_repository.dart
        ├── data/
        │   ├── datasources/vault_local_datasource.dart
        │   └── repositories/mock_chat_repository.dart
        ├── security/                         # vault-private E2EE (X3DH/ratchet) — NOT core
        └── presentation/
            └── widgets/chat_bubble.dart      # bubble + StatusTick composition
```

Rules the layout enforces:

- Feature-to-feature imports are forbidden. Shared concepts get promoted to
  `core/` explicitly, and only when at least two features need them.
- `vault/security/` is vault-private on purpose. The Hallway (Nexus) is
  not E2EE by default (Telegram model); sharing Vault's key material with
  it would leak the threat model across modules. `core/crypto/` stays
  primitives-only.
- Row classes (`PostRow`, `MessageRow`, …) are data-layer vocabulary;
  `@DataClassName` aliases them so they never collide with domain entities.

## 4. Cross-cutting decisions

**Errors.** Repositories return `Either<Failure, T>`; they never throw
across the domain boundary. Data-layer exceptions exist and are mapped at
the repository edge. Presentation switches on `Failure` subtypes, never on
string messages.

**Streams over pulls.** Every read that can change is a
`Stream<Either<...>>` backed by drift's reactive queries. The UI never
polls and never holds a mutable copy of "the list"; it renders what the
stream emits.

**Sync state machine (normative).** Every Vault message row carries
`syncStatus ∈ {pending, sent, delivered, read, failed}`. `sendMessage`
persists locally as `pending` *before* any transport attempt, then hands
off. `syncOutbox()` flushes pending/failed rows — the exact function a
background worker will call. Inbound "delivery" writes through the same
datasource, so the offline read path is identical to the online one.
Edits and delete-for-everyone are **tombstone writes, never hard
deletes**: `editedAt` / `deletedAt` nullable columns on `messages` (and
`group_messages`), synced like any other row. A deleted message keeps its
row with a blanked body; the UI renders the placeholder from the
tombstone, not the text. The contract members are `editMessage` and
`deleteMessage`; peers' messages are neither editable nor deletable, and
deleted ones cannot be edited (`ConflictFailure`). Dorm (Nexus group)
messages
map the shared `MsgSyncStatus` storage enum down to their 3-value
`OutboxStatus` (`delivered`/`read` collapse into `sent` until the Nexus
grows its own read-state vocabulary).

**The mock/real seam.** The mock repositories simulate a live server with
`Stream.periodic` tickers and write through the real datasource. They also
expose `setOnline(bool)` so offline behavior (ticker stops, refresh fails,
messages pile up pending) is testable without a backend. Swapping to real
implementations at backend integration changes `injection.dart` and nothing
else. Contract semantics — `Either`, streams, local-first writes — were
frozen in the contracts before the mocks existed, which is the whole point
of Interface-Driven Development here.

## 5. Schema notes (drift, v14)

**Migration rules (normative, learned the hard way on Windows):**

1. **Every `onUpgrade` step must be idempotent.** A step that throws midway
   leaves `user_version` at the old value, so the next launch re-runs the
   whole chain. Steps therefore check existence before acting (columns via
   `PRAGMA table_info`, tables/FTS via `IF NOT EXISTS`).
2. **`m.addColumn` only for nullable or defaulted columns.** SQLite rejects
   `ADD COLUMN` of a NOT NULL column without a constant default, and drift
   has no default with `m.addColumn`. NOT NULL additions go through raw
   `customStatement` with `DEFAULT` (see the v3→v4 `member_roles` step).

| Table | Module | Purpose |
|---|---|---|
| `posts` | Square | feed cache; `mediaUrl`/`blurhash` nullable; `deleted_at` tombstone (v8); `expires_at` ephemeral expiry (v11) |
| `post_likes` | Square | offline like state; sync direction later: local → server |
| `conversations` | Vault | participants as JSON array (schema already multi-party) |
| `messages` | Vault | source of truth; `ciphertext` column present from day one so real E2EE changes no schema; `editedAt`/`deletedAt` tombstones (v4); attachment kind/path/duration (v9/v10) |
| `post_comments` | Social | comments on Square posts (v13) |
| `social_notifications` | Social | peer notices: kind/peer/body/deepLink + `readAt` unread tracking (v13) |
| `keepsake_items` | Keepsake | pinned posts + notes; board-relative posX/posY/rotation; `strungTo` string link; `pinnedAt`; `unpinned_at` soft-unpin tombstone (v14) |

Schema versions v1→v14 all shipped through the idempotent migration
chain; see `onUpgrade` in `app_database.dart`. v12 added the Hallway
board FTS index (`channel_posts_fts`) — the boards had been missed in
v5. FTS5 is confirmed compiled into the pinned `web/sqlite3.wasm`
(bm25/snippet symbols present), so search works on web too.

Hallway (Nexus) additions (pending T-004, still schema v1 since nothing
shipped): `channels`, `channel_messages` (with `expiresAt` for retention
from day one), `group_conversations`, `group_messages`, `member_roles`.

### Planned additions from the social-app audit (schema first, no code yet)

A gap analysis against Discord, Telegram, Instagram, WhatsApp, Reddit,
Signal, and BeReal produced four schema-level lessons. All four are now
**implemented** (lifecycle tombstones + membership in schema v4, search
+ blurhash in schema v5); the notes below describe the shipped shape.

**Local full-text search (Discord/WhatsApp/Signal) — implemented, schema
v5.** Search runs entirely on device: FTS5 virtual tables (`posts_fts`,
`messages_fts`, `group_messages_fts`) created and queried through raw SQL
(drift's table DSL cannot express virtual tables), kept in lockstep with
the content tables by AFTER INSERT/UPDATE/DELETE triggers — repositories
never touch the index, they write content rows as usual. The `Search`
domain surface lives in `core/search/`: `SearchHit` (source, container
id/title for deep-linking, highlighted snippet, bm25 rank) and
`SearchRepository.search(query)`. Vault hits come from the
*decrypted-at-rest* body — plaintext never leaves the device (the Signal
posture). User queries are sanitized into quoted FTS5 terms (no syntax
injection); tombstoned messages stop matching automatically because
delete-for-everyone blanks the body and the UPDATE trigger re-indexes.
The UI (`SearchPage`) is reachable from the Square's app bar with
debounced as-you-type search.

**Blurhash placeholders (Instagram) — implemented, schema v5.**
`blurhash` nullable columns on `posts`, `channel_posts`, and
`group_messages`; encoded at write time, decoded synchronously at render
time (the drift cache paints a meaningful placeholder offline), full
image fetched behind it. The Square mock writes a deterministic hash per
photo id; `_CardMedia` paints a gradient sampled from the decoded hash
under the network image and keeps it visible when the image fails
offline — the media slot never shows an empty gray block when a hash
exists.

**Message lifecycle tombstones (Telegram/WhatsApp) — implemented, schema
v4.** `syncStatus ∈ {pending, sent, delivered, read, failed}` with
`editedAt`/`deletedAt` tombstones on `messages` (and `group_messages`).
Deletes are tombstone writes that sync like any other row — the
local-first answer to delete-for-everyone, keeping the offline read path
identical to the online one. See "Sync state machine (normative)" in
section 4; `status_tick.dart` renders the full vocabulary.

**Membership as a sync entity (Reddit/Discord) — implemented, schema
v4.** `member_roles` carries the membership outbox: `syncStatus ∈ {pending,
synced, failed, left}` (storage enum `MemberSyncStatus`, domain
`MembershipSyncStatus`) plus `updatedAt`. The contract grew
`watchMembers` / `joinGroup` / `leaveGroup` / `setMemberRole`; joins and
role changes queue as `pending` rows and flush through `syncOutbox`,
`left` is terminal and idempotent, and seeded groups write already-synced
rows so no phantom join ops queue. Per-channel read cursors remain open
work riding the same machinery.

Non-lessons, deliberately not adopted: algorithmic feeds (the Square's
chronology is a stated product choice), server-side profile graphs
(conflicts with the Signal-style identity posture under "Auth module"
in open items), and stories-style ephemeral stories (covered better by
the `expiresAt` retention already planned for channels).

## 6. Package choices (and the two rejections)

Chosen: `flutter_bloc` (state — maps 1:1 onto Clean Architecture
boundaries), `drift` (local DB — typed SQLite, reactive streams,
background isolate), `get_it`+`injectable` (DI), `fpdart` (`Either`),
`dio` (HTTP), `flutter_secure_storage` (keys/tokens — Keychain/Keystore),
`cryptography` (audited primitives for Vault E2EE), `go_router`,
`web_socket_channel`, `workmanager`, `json_serializable`+`freezed`.

Rejected: **Hive** — unmaintained lineage and weak relational queries for a
sync-heavy outbox. **Provider** — too loose a state layer at this scale.
**Riverpod** — good library, but its provider graph blurs the
presentation/domain seam this architecture depends on.

## 6a. Identity posture (ADR — decided, enforce on review)

The local user's identity is an **opaque, device-stable id**: a UUID v4
minted once per install, stored in `flutter_secure_storage`
(`core/auth/session_store.dart`), and never derived from any personal
identifier. Rules that follow from the Signal posture, enforced on
review:

1. **No hardcoded user ids.** Every module receives the session id
   injected from the auth seam (`localUserId` constructor parameter on
   repositories/datasources). `Conversation.localUserId` remains only as
   a mock-seed fallback and must not gain new comparisons.
2. **The server sees opaque ids only.** No phone numbers, no emails, no
   contact upload. Contact discovery at integration must be private set
   intersection — a plaintext-identifier design is rejected at review.
3. **Identity keys live in the session store.** When real E2EE lands in
   `vault/security/`, the long-term identity keys are stored through the
   same [SessionStore] seam, not a new persistence path.
4. **`signOut` mints a new identity.** Clearing the store makes old
   ciphertext permanently unreachable — that is a feature (panic wipe),
   not data loss.

## 6b. Reactions and read state (Discord/WhatsApp lessons — implemented,
schema v6)

**Reactions are outbox rows.** `message_reactions` carries one row per
(user, message, emoji) with `targetModule` routing (vault | nexus_group)
and its own `syncStatus ∈ {pending, synced, failed}` — toggling writes
or deletes the row locally first, exactly like `sendMessage`. The flush
runs through `syncOutbox` alongside messages and memberships; there is
no separate reaction transport.

**Read state is a cursor, not a flag.** `read_cursors` holds one row per
(conversation, user): the last-read message id and timestamp. Opening a
conversation calls `markConversationRead`, which advances the cursor
(idempotently — never backwards) and flips the peer's `delivered`
messages to `read` through the same sync machinery that drives the
ticks. `unreadCount` derives from the cursor position, excluding own
writes. No per-message "read" booleans anywhere.

## 6c. The Daily Square — ritual design principles (anti-chore, decided
before build)

The BeReal lesson has two halves. Its growth loop — a recurring prompt
that asks for one real moment — is the one mechanism no feed algorithm
replicates. Its failure was making that ritual mandatory, daily, and
unrewarding until users described it as a chore (the most-cited reason
for quitting, per exit coverage). The Daily Square adopts the loop with
every failure point inverted. These rules are **product decisions**;
a prompt implementation that violates any of them is rejected at
review:

1. **User-owned window, never a random interrupt.** The prompt fires
   inside a window the user picked (morning / evening / weekend); it
   never rings outside it.
2. **No deadline, no late state.** The prompt is an invitation. Posting
   hours later is equally valid; there is no streak, no "late" badge,
   no counter anywhere in the UI.
3. **Rotating shape, never a template.** The prompt's ask rotates
   (one photo / one sentence / sound / desk) so the ritual cannot
   calcify into a daily obligation with a fixed form.
4. **Payoff on open.** Opening the app during the window shows
   something worth seeing (collated recent squares), so skipping a
   day still leaves a reason to look.
5. **Opt-in and pausable without guilt.** One tap pauses the prompt;
   copy never shames, counts, or compares.
6. **Garnish, not toll booth.** The prompt rides on an app people
   already open (feed, Vault, Hallway) — it is never the only reason to
   open it, and never gates any content.

**Theme-mode & nav contrast.** The Settings theme-mode segmented buttons use
chalk glyphs (`sunMark` / `moonCrescent` / `autoA`) with
`showSelectedIcon: false` — M3 otherwise prepends a ✓ that shoves the glyph
aside. The nav rail's selected pill mixes ~22% accent into the surface;
`navSelectedIconColor(scheme)` computes that composite pill colour and picks
an icon tint with ≥3:1 contrast against it (the original amber washed out on
its own pale pill). `test/nav_accent_contrast_test.dart` asserts the ratio
for all six accents × golden/stock × light/dark, plus a regression test
proving the pre-fix amber failed.

**Web support.** `flutter build web --release` is a supported target. The
stack: `drift_flutter`'s `driftDatabase()` with both `native:` and `web:`
options (`web:` is mandatory on web — omitting it throws at runtime),
`sqlite3.wasm` + `drift_worker.js` version-locked to `pubspec.lock` and
served from `web/`. All `dart:io` usage is quarantined behind the
`lib/core/io/platform_io.dart` conditional-export seam
(`io_native.dart` / `io_stub.dart`) — nothing else in `lib/` imports
`dart:io`. Web no-ops: attachment copies and voice-peak persistence are
session-only in the browser. Known cosmetic issue: seeded pravatar
avatars are CORS-blocked on web; the errorBuilder renders chalk glyphs.

## 7. Open items

- ~~Rename the mechanical identifiers~~ Done: the Dart package is
  `echo_bay` (all imports), the database file `echo_bay.sqlite`, and the
  Windows runner `OriginalFilename` `echo_bay.exe`.
- T-002: blocs + pages wiring widgets to repositories.
- T-003: `main.dart`, `go_router` shell, DI bootstrap, theme switching.
- T-004: Hallway implementation (contracts + schema + mock) — layout
  approved, awaiting build.
- Auth module: identity is now device-stable and opaque (see "Identity
  posture" below); what remains is the real credential/token flow at
  backend integration.
- Time travel limits: keepsake unpin is soft (v14), but post hard-purge
  (the 10s undo window) and pre-edit Vault message bodies overwrite
  history — reconstructing those needs append-only rows (deliberately
  deferred).
- The social layer's peer engine is mock-only; a real backend replaces
  `DriftSocialRepository.onOwnPostPublished` with server push without
  touching the UI.
- Daily Square: settings UI (opt-in, window, pause) shipped in the
  Settings page (§6c rules encoded in `daily_square_settings_card.dart`);
  what remains is the payoff view (rule 4: collated recent squares on
  open).
- Media pipeline: `FeedCard` media slot is a placeholder; swap in
  `cached_network_image` without touching callers.

## 8. The Golden Hour identity layer (added post-scaffold)

The design system grew an analog identity on top of the M3 base. All of
it is gated behind the `GoldenHourExtension.enabled` token — stock themes
render identically to the pre-identity build, and every piece degrades
cleanly under reduced motion.

**Theme variant.** `buildGoldenHourLightTheme/DarkTheme` (palette: warm
sepia paper / dusk blue-black; pine-teal primary; amber accent) plus the
`GoldenHourExtension` theme extension (polaroid paper/shadow, amber,
`enabled`). `main.dart` resolves to the Golden Hour builders; the stock
builders remain for A/B comparison. Handwritten display voice: Caveat
(SIL OFL, `assets/fonts/`), wired through `displaySmall` and
`kHandwrittenTextStyle`; body text stays Roboto.

**User accent palette.** `kAccentPalette` (user_profile.dart) is the six
ink pots the profile editor offers: fountain-pen cobalt (default),
golden-hour amber, terracotta pencil, moss marker, iron-gall sepia
#6B4A2B and oxblood #8E3B46. The last two replaced the earlier violet
#7C4DFF and graffiti rose #E91E63, which read as screen-native Material
colours rather than inks that could come out of a pen pot.

**Sketch kit** (`core/design_system/sketch_kit.dart`). The scratchy ink
language: `SketchBox` (wobbly notebook border — seeded jittered polyline,
fill painted behind the child, border in front; a foreground fill painter
was the "blank card" bug), `ScribbleFill` (three authored hatch/loop
variants clipped to a path, chosen by seed), and `SketchIcon` — the five
hand-drawn icons (scribble heart, rewind spiral, X-scratched heart,
jagged bubble, paper plane). Every wobble/scribble is **deterministic**
(seed from element id) — nothing re-randomizes on rebuild, nothing
animates per frame.

**The rewind** (`core/motion/rewind_scope.dart`). The signature undo
gesture: a ~600ms mirror-wobble with the undo action firing at the
visual midpoint (plus a haptic tick). Consumers: un-like, post delete,
Vault delete-for-everyone. Reduced motion = instant undo, no animation.

**Post soft-delete.** `posts.deleted_at` tombstone (schema v8, idempotent
migration). `deletePost` hides the post immediately and schedules a
10-second purge; `restorePost` clears the tombstone — a true undo
(same id, timestamp, likes), not a repost. The feed query and
`postsOnDay` (journal day-view) both filter tombstones.

**Inhabited Vault peers.** `MockChatRepository` carries per-peer
personas (voice, vocabulary, typing speed); sending a message schedules
an in-character reply after the delivery chain lands, with a typing
indicator exposed via `watchTyping` (word-count-proportional, clamped
to 0.8–4s — a 14-word filler line must not pin the label for 13s).
Reply timers are tracked and cancelled in `dispose` like the delivery
timers, and the whole persona chain can be disabled with
`peerReplies: false` (test teardown invariant, same family as
`startTicker: false`).

**Daily Square E2E.** All composer entry points (app bar, deep link
from the notification tap, FAB quick actions) route through the shell's
prompt-aware `_openComposer`: it fetches `activePrompt()`, pre-seeds the
composer with the prompt copy, and `recordPosted` retires the prompt on
publish (§6c rule 2). A quick-action shape overrides the prompt's own
shape; a prompt-less open (opted out / paused / outside window / already
acted) is a normal, healthy state.

**Vault two-pane.** The embedded Vault renders master-detail above the
600px breakpoint: the conversation list takes ~34% of the shell body
(clamped 280–420px) and the open chat takes the rest — Telegram
proportions. A fixed 320px list pane starved the chat pane on scaled
desktop windows (the "squished Vault" bug).

**Vault composer.** Inked note box (SketchBox, stroke-only restraint)
with "Write a message" as the hint, the sketch paper-plane send on an
amber disc, and photo/video/voice attach buttons (snackbar stubs until
media messages land). Non-ink mode keeps plain Material chrome.

**Stream-rebind gotcha.** Both Vault pages create their watch streams
**once** in State (`late final _messages = ...`), never inside `build`:
`watchMessages()` returns a fresh stream per call, so rebuilding with a
new stream (e.g. a typing-indicator `setState`) resets the StreamBuilder
to `ConnectionState.waiting` and flashes the chat to a skeleton. Same
pattern as the conversation list's `_conversations`.

**Ink coverage.** Square cards (frame + action row), Vault chat bubbles
and composer (restrained: stroke, no scribble/paper per spec §4),
Hallway Board + Dorms tiles + bulletin masthead, composer sheet (title
+ media frame), Landline masthead (handwriting only, no boxes), empty
states in Landline/Hallway/search, and the rewind-spiral icon in the
undo snackbar.

**Social layer** (`features/social`, schema v13). Comments on Square
posts (`post_comments`) plus a notices feed (`social_notifications`,
kind ∈ {comment, reaction, reply}, `readAt` unread tracking, `deepLink`
navigation). The **peer engine** lives in the domain: `PeerPlanner`
(injectable RNG) plans 0–2 events per own post — distinct peers,
first ≥20s out, ≥25s spacing, ~1-in-6 posts draw silence (the no-chore
rule). The drift repository schedules real timers per plan and inserts
comment/notification rows; the UI consumes only the `SocialRepository`
contract. Unread badge = live count query on the shell.

**Keepsake wall** (`features/keepsake`, schema v13/v14). A corkboard of
pinned own-posts and freehand notes. Geometry is stored as
**board-relative fractions** (posX/posY 0..1 + rotation), so the same
row renders correctly at any viewport — positions are never screen
pixels. Items string together (`strungTo`, one outgoing string each,
drawn as a stable seeded wobbly ink line). Unpin is a **soft tombstone**
(`unpinned_at`, v14): the present board filters unpinned rows query-side,
and time travel can reconstruct a past board exactly.

**Time travel** (`core/timetravel`, no schema change). A read-only
"as of" mode. One `TimeTravelController` above `MaterialApp` holds the
instant; the shell fans it to the four time-aware datasources
(`setAsOf`), which re-run their live streams via a tick stream +
`switchMap` and timestamp-filter in memory or in the where-clause:
Square (created-by / tombstone-after / expiry-at), Vault (existing-by /
deleted-after), Social (created-by; `readAt`-after counts unread),
Keepsake (pinned-by, not-unpinned-by). While active every write path
throws `StateError` — the past cannot be modified. Exit rides the
existing rewind animation.

**Ephemeral posts** (schema v11). `posts.expires_at` nullable; visibility
is a query-time filter on every Square read path so correctness never
depends on the lazy purge (`purgeExpiredPosts` on app start reclaims
storage). The card fades (opacity floored at 0.2) with a hand-drawn
clock-tick strip; "keep it" clears the column. All expiry checks use an
injectable clock (`DateTime Function()`) for deterministic tests.

**Post share-as-image** (`features/square/domain/services/
post_share_card.dart`). A pure `dart:ui` `PictureRecorder` composition
(no widget/RepaintBoundary path — that failed to work on web), rendering
the polaroid card with handwritten date and the "made with Echo Bay"
corner mark. `SharePostAsImage` returns `Either<Failure, Uint8List>`;
delivery goes through the IO seam (`core/io`): share sheet on native,
anchor-download on web. No `dart:io` under `lib/`.
