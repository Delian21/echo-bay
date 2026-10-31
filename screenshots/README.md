# Screenshots

Every screen of Echo Bay, light and dark, captured at phone size
(390×844 CSS px at 2× — the PNGs are 780×1688).

Captured from the production build at <https://echo-bay.netlify.app> on
30 October 2026, driving headless Chrome over the DevTools protocol.

| # | File stem | Screen |
|---|-----------|--------|
| 1 | `welcome-1-the-square` | Onboarding, step 1 — The Square |
| 2 | `welcome-2-vault-and-hallway` | Onboarding, step 2 — Vault & Hallway |
| 3 | `welcome-3-nothing-is-forever` | Onboarding, step 3 — rewind spiral |
| 4 | `welcome-4-setup` | Onboarding, step 4 — setup |
| 5 | `sign-the-cover` | Sign-up / "Sign the cover" gate |
| 6 | `square` | The Square, Everyone tab (feed) |
| 7 | `square-my-window` | The Square, My Window tab |
| 8 | `compose` | New-post composer sheet |
| 9 | `day` | Journal day view (`/square/day/…`) |
| 10 | `vault` | The Vault, conversation list |
| 11 | `conversation` | A Vault conversation |
| 12 | `hallway` | The Hallway, Board tab |
| 13 | `dorm` | A Dorm group chat ("Core Devs") |
| 14 | `landline` | The Landline, call log |
| 15 | `keepsake` | Keepsake wall (empty state) |
| 16 | `notices` | Notices (empty state) |
| 17 | `search` | Search (empty state) |
| 18 | `profile` | Your own profile |
| 19 | `person` | Another person's page (`@bo_tamm`) |
| 20 | `settings` | Settings |

`light/<stem>.png` and `dark/<stem>.png` for each row.

## Things that are the app, not the capture

- **Dark mode is a boot-time decision.** `didChangePlatformBrightness` only
  re-syncs reduced motion, so the theme is resolved once when the page
  loads. The driver therefore reloads once per theme and emulates
  `prefers-color-scheme` before the load, rather than flipping live.
- **Feeds differ between the two themes.** Posts are regenerated per page
  load, so the light and dark feed screens are not the same set of mails
  in the same order.
- **The day view's photo looks washed out** in both themes — that is the
  journal treatment on that surface, not a mid-fade capture.
- **`person` repeats posts** — the seeded demo cast duplicates entries.
- The Hallway's tab bar and the composer's sheet are outside Flutter's
  accessibility tree in places, so the driver clicks some of those by
  coordinate.

## Re-capturing

```
node screenshots/tools/shoot.mjs app           # 15 signed-in screens
node screenshots/tools/shoot.mjs onboarding    # welcome flow, fresh profile
node screenshots/tools/shoot.mjs square        # photo-heavy screens only
node screenshots/tools/shoot.mjs compose       # new-post sheet over the feed
node screenshots/tools/shoot.mjs fix --attach=<port>   # dorm, person, day
```

The driver needs a signed-in Chrome profile; it launches its own with
`app` (first run walks onboarding and signs in) and reuses
`screenshots/.profile` afterwards. Profiles and logs are git-ignored.
