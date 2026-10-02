# Art Direction — "Golden Hour, Inked" (LiS-inspired)

> Naming note: "Golden Hour, Inked" is the name of this *style*, not the
> app. The product is **Echo Bay** (see `docs/NAMING.md`). This document
> keeps the style name because it describes the palette and stroke
> language, which remain warm-light and inked.

Short version: the app looks like a **sketchbook drawn with a 0.5mm black gel
pen** — imperfect, overlapping strokes, notebook boxes, scribble fills — set
on **analog paper surfaces**, punctuated by **three neon accents used
sparingly**. Life is Strange is the *mood reference* (analog photography,
PNW golden hour, teenage marginalia); the assets and identity are ours.

---

## 1. The stroke language ("everything is drawn")

Every line in the UI pretends it was inked by hand:

- **Stroke.** 2dp nominal weight, round caps, charcoal ink (#2B2A26 in
  light, warm chalk #E8E4D8 in dark — never pure #000; pure black kills the
  pen feel on screens).
- **Imperfection.** Strokes wobble: ≤1dp deviation, deterministic per
  element (seeded from the widget's identity, never random per frame).
  Overlapping stroke pairs (the pen "went over the line twice") are allowed
  at low opacity on large containers only.
- **Wobbly borders.** Containers — media frames, avatars, chips, input
  fields — sit in slightly uneven rounded rectangles ("notebook boxes").
  The wobble applies to the *border path*; content inside stays perfectly
  laid out. Small radii (4–8dp): pen-drawn rectangles, not capsules.
- **Scribble fill.** Selection/active states are never solid blocks. Fill
  with 3–4 pre-authored cross-hatch/scribble path variants, tinted with the
  active accent at ~35% alpha under the charcoal stroke. Deterministic
  choice per element (seed); cached as `ui.Picture`s — scribbles must never
  re-randomize on rebuild, and never animate per-frame.
- **The grain line.** Optional: content surfaces may carry a faint diagonal
  hatch in the far background (≤4% alpha) to suggest paper tooth. Never on
  text areas, never on the Vault.

**What stays clean:** text layout, spacing, alignment, hit targets. The
hand-drawn language is a *stroke costume* over a rigorous grid — if the
layout wobbles, it reads broken, not hand-made.

## 2. Icon set (five custom sketch icons)

All drawn as deterministic `CustomPaint` path sets, charcoal stroke, 2dp.
No filled Material glyphs on action rows.

| Slot | Icon | Semantics |
| --- | --- | --- |
| **Like** | Scribble heart — rough heart outline; when active, cross-hatch fills the heart in Graffiti Red at ~40% | Heart stays universally readable; the scribble is the signature |
| **Unlike / undo** | Rewind spiral — messy continuous loop, center outward (our own path, not the game's glyph) | Pairs with the rewind gesture; also the app-wide undo mark |
| **Unlike accent** | X-scratch — aggressive pen "X" over the heart, shown *during* un-like (the rewind moment) | The undo of a like; never the resting like icon |
| **Comment** | Jagged speech bubble — sharp comic-book bubble, uneven pointer tail | Generic enough to own; rougher is better |
| **Share** | Paper airplane — simplified fold-line sketch | Universal "send"; the fold lines carry the sketch feel |

**Rejected on purpose:** butterfly as "like" (says nothing about liking, and
it's the one symbol too identifying with the reference property), polaroid-
frame and journal-tab as "comment" (they mean photo/file, not reply),
double arrows as "share" (reads as seek).

**Beyond the five.** The kit has grown to 41 kinds so that *chrome* can
stay hand-drawn too — the Board tiles' megaphone, the call affordances,
the delivery ticks, the composer's attach tools, and the quick-action
sheet's Photo / Sentence / Sound rows. The rule that started as "no
Material glyphs on action rows" is now app-wide: a Material icon sitting
beside four chalk ones reads as an unfinished seam. ("Sentence" needed a
kind of its own, `scribbleLine` — three trailing chalk rules — rather than
falling back to Material.)

## 3. Palette

- **Surfaces (light):** warm sepia paper #F5EFE2, aged cardboard #E7DCC4,
  chalk-slate option #EDEDE8 for utility screens.
- **Surfaces (dark):** dusk blue-black #14181F, chalk text #E8E4D8.
- **Ink:** charcoal #2B2A26 (light) / #E8E4D8 (dark).
- **Accents — max one competing accent per screen:**
  - Rewind Blue `#5CE1E6` — stroke/fill accent ONLY. Fails contrast for
    text on light surfaces; never used for text below 24dp or essential
    glyphs on sepia.
  - Graffiti Red `#E0245E` — like fills, destructive emphasis.
  - Punk Marker Yellow `#F5C518` — highlighter sweeps behind text (at ≤35%
    alpha), amber annotations. Never for body text on light surfaces.

The Golden Hour palette (pine teal primary, warm paper) remains the theme
base; the ink language and accents layer on top rather than replacing it.

## 4. Per-module treatment

| Module | Treatment |
| --- | --- |
| **The Square** | *Full ink.* Sketch icons, wobbly polaroid frames, scribble like-fills, handwritten headers, develop reveal. This is the showpiece. The exported share card sits crooked on square paper — see §6. |
| **The Hallway** (the Board + the Dorms) | *Bulletin board.* Same stroke language on every tile (channels and group chats alike), handwritten masthead ("The board is up."), yellow highlighter emphasis, slightly denser layout. Channel tiles lead with the sketch megaphone on the amber disc. |
| **The Vault** | *Restrained ink.* Wobbly borders and sketch strokes but NO paper textures, NO scribble fills — a notebook that takes secrets seriously. The composer is an inked note box with the paper-plane send on an amber disc; the is-writing indicator sits above it like a pencil margin note ("Rune is writing…"). Standard encrypted-green tick marks, drawn at 16px so they read beside the timestamp. Bubbles group by sender: tight within a run, a breath across a speaker change. Handwritten initials on every identity disc. |
| **The Landline** | *Cleanest.* Handwritten masthead ("The line is open.") and nothing else — no ink boxes, no paper. A dialer with grain is a dialer that's harder to read mid-call. |

Rule of thumb: **ink intensity scales with how "memory-like" the surface
is.** Square = full sketchbook, Hallway = pinned notes on a board, Vault =
restrained notes, Landline = plain pen.

### Module naming (decided)

Names follow the small-town rule — what the thing *is* in a place, not in
a tech stack: The Square, The Vault, The Hallway (hub), the Board
(broadcast channels), the Dorms (group chats), the Landline (calls).
Full decision record in `docs/NAMING.md`.

## 5. IP discipline (unchanged, tightened)

- Borrow the *mood*: analog sketchbook, zine energy, indie-novel
  marginalia. Never game assets, name, logo, fonts, characters, or audio.
- The **butterfly appears nowhere in the UI.** If it survives at all, it's a
  hidden easter egg (e.g. an about-page doodle) — never a control, never
  the brand mark.
- README and store copy describe the style as *"inspired by analog
  sketchbooks, zine culture, and indie narrative adventures"* — without
  naming the property. Naming it in public reads as affiliation and
  documents awareness of the reference; a disclaimer is not a license.
- Generic vocabulary (hearts, X marks, spirals, speech bubbles, paper
  planes, wobbly borders, scribble fills, sepia paper) is free to use and
  carries most of the soul anyway.

## 6. Implementation notes

- Icon paths + wobble/scribble painters live in a shared
  `core/design_system` sketch kit: `SketchBox` (wobbly border container),
  `ScribbleFill` (cached hatch pictures), `SketchIcon` (five signature
  icons, now 41 kinds). Adding one = enum value + painter case + label.
- All wobble/scribble randomness is **seeded** (widget id, post id) and
  **deterministic** — identical output on every build, cheap to render.
- Reduced motion: scribble fill appears/disappears without animation.
- Fonts: Caveat (OFL) stays the handwriting voice; body text stays Roboto.
- **Ink on fixed-colour paper is pinned, not themed.** A surface that is
  the same colour in both modes (keepsake cards are always cream) must
  hard-code `SketchInk.charcoal`; dark mode would otherwise paint chalk
  on paper and the note disappears.
- **Dates are a maker's mark.** Every date the reader sees as handwriting
  is formatted by one shared voice (`handDateTime` / `handDayLine`) so a
  keepsake stamp, the feed masthead and an exported card say the same
  thing in the same shape. Short form `'Fri 2 Oct · 18:40'` for anything
  stamped onto an object; long form `'Friday, October 2'` only where a
  masthead has room.
- **Tilt, but keep the ground flat.** Cards on the wall and the exported
  polaroid sit crooked (±2.5° is "placed down", not "shaken"), but the
  corkboard and the sheet of paper stay square — a crooked card on a
  square ground reads as an object in a room; a tilted *ground* just
  looks like a cropping bug. Seed the angle from the item id so the same
  card always comes out the same way.
