# Naming — from Prism to Echo Bay

The working name was **Prism**: clean, geometric, optical. It fit the app
when the app was Material 3 — glassy, neutral, light-refracting. It does
not fit what the app became. You do not draw a prism in a 0.5mm gel pen on
crumpled sepia paper; you *build* one in a CAD tool. The name and the skin
now point in opposite directions, and names that fight their aesthetics
feel like placeholder apps.

## The first recommendation: **Golden Hour** (superseded)

The theme was already called Golden Hour; the journal header greets you
with time-of-day invitations; the whole identity is about capturing small
moments at the time of day photographers live for. But in use the name
turned out too saturated — warm-light photography language stacked on top
of an app that is already warm-light photography language. The name and
the art direction competed instead of completing each other.

## The decision: **Echo Bay**

A name with a place in it — a bay, a small town, the kind of place where
everyone knows whose polaroids those are on the board. It sounds like
where the sketchbook was found, not a concept someone marketed. It stays
quiet next to the ink-and-amber aesthetic instead of doubling it, and it
leaves the poetry to the tagline: *"Capture the day before it fades."*

Runners-up, for the record:

- **Chrysalis** — the growth metaphor (the app as the cocoon you develop
  in); beautiful story, but abstract and slightly cold next to warm ink.
- **The Cadence** — nice for the Daily Square ritual, but abstract.
- **Margins** — the notebook metaphor (your life in the margins); good,
  but slightly literary-cold.
- **Ferrotype** — the Victorian name for tintype photos; distinctive and
  deep-cut, but hard to say and spell.
- **Long Exposure** — explains the rewind mechanic by itself; reads as a
  photography app first, which undersells the writing half.

## Module naming scheme

The modules follow the same place-and-objects rule — name things after
what they are in a small town, not what they are in a tech stack:

| Module | Was | Is now |
|---|---|---|
| Photo journal | The Square | **The Square** |
| Encrypted chat | The Vault | **The Vault** |
| Community hub | The Nexus | **The Hallway** |
| Broadcast channels | Channels | **The Board** |
| Group chats | Groups | **Dorms** |
| Voice & video | Calls | **The Landline** |

The Hallway replaced The Nexus because Nexus was the only tech-flavoured
name in a hand-inked world — dorms hang off a hallway, the Board hangs on
a hallway wall.

## Naming decision record

| Asset | Old | New |
|---|---|---|
| Display name | superapp / Prism / Golden Hour | **Echo Bay** |
| Tagline | — | *"Capture the day before it fades."* |
| Package id | `superapp` | `echo_bay` (follow-up) |
| Exe / binary | `superapp.exe` | `echo_bay.exe` (follow-up) |

Not renamed in this pass (deliberately): the Dart package name (`superapp`
in pubspec + every import), the DB filename (`superapp.sqlite`), and the
Windows runner resources. A mechanical rename touches ~40 files for zero
product value today; it is a follow-up, not a blocker.
