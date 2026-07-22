# The Life List

A birding app for the walk, not just the spreadsheet. Built on Flutter
and the free public eBird API, for Android (and web, for dev/testing).

It started from a simple instinct: open the app, see what's around you,
right now. The Life List grew its own identity from there: sightings
grouped the way birders actually think about birds (by family, not
alphabet), a species search that reaches beyond what's nearby, hotspots
with their own recent species checklists, real photo attribution instead
of borrowed images with no credit, and a personal life list that's been
designed from day one to eventually talk to eBird's own systems instead
of living in its own silo forever.

Everything here is read-only against eBird for now. The roadmap section
below covers what "eventually talk to eBird" actually means and why it's
not further along yet (short version: eBird's write access isn't
self-serve — see Phase 4).

## What's here

- `lib/main.dart` — app entry point, theme wiring, manual + system
  dark-mode handling
- `lib/screens/` — Sightings list (family-grouped, sticky headers,
  adjustable search radius + date range), Hotspots map (clustered
  markers, persistent per-marker detail sheet with a date-scoped species
  checklist), Species search, Species detail (photo gallery + hero
  transition + attribution, capped sightings feed), Life List, Settings
- `lib/services/` — eBird API client, eBird taxonomy client (family
  grouping + species search index), device location, local storage,
  species photo/media lookup (Wikimedia Commons, with attribution),
  life list storage
- `lib/models/` — Observation, Hotspot, and LifeListEntry data classes
- `lib/theme/` — design tokens (colors, typography, spacing/radius) and
  the assembled light/dark `ThemeData` — see `docs/brand.md` for the
  source values
- `lib/widgets/` — shared UI pieces (sighting list row, species
  thumbnail, hotspot detail sheet, loading skeletons) used across
  screens
- `lib/utils/` — small helpers (relative time formatting)
- `test/services/` — unit tests for the eBird client, settings
  persistence, and life list storage
- `docs/design-principles.md` — living reference for interaction
  patterns (prefer native Material 3 components, mirror established
  consumer-app patterns, minimize cognitive load)
- `docs/brand.md` — living reference for color palette and typography
- `docs/tickets/` — scoped work handed off for implementation; useful
  history of *why* something looks the way it does. Shipped tickets move
  to `docs/tickets/done/` once they've landed, so the top level only
  shows what's actually in flight.
- `tools/cors_proxy.js` — local dev-only proxy for web testing (see
  below)
- `flutter_native_splash.yaml` — native launch splash config
- `android/app/src/main/AndroidManifest.xml` — location + internet
  permissions

## Setup

### 1. Install Flutter

If you don't already have it: https://docs.flutter.dev/get-started/install
(pick Android). Then confirm your setup:

```
flutter doctor
```

Fix anything it flags (Android SDK, accepted licenses, a connected device
or emulator) before continuing.

### 2. Get a free eBird API key

eBird is run by the Cornell Lab of Ornithology. Request a key (instant,
free) at:

https://ebird.org/api/keygen

Paste it into the app itself on first launch — the app links straight
to that page for you, no code changes needed. Each contributor should
use their own key rather than sharing one.

### 3. Install packages and run

```
flutter pub get
flutter run
```

Plug in your Android phone via USB with USB debugging enabled (Settings →
About phone → tap "Build number" 7 times → Developer options → USB
debugging, and make sure the USB connection mode is set to file
transfer, not "charging only" — that trips up ADB more often than you'd
expect), or start an emulator from Android Studio, then run the command
above.

### 4. Release builds (APK vs App Bundle)

**Play Store** — ship an Android App Bundle. Play generates the
per-device APK (ABI / density / language) at download time:

```
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

Before any real Play upload, replace the debug `signingConfig` in
`android/app/build.gradle.kts` with a proper release keystore — the
current TODO there is a hard blocker for store submission.

**Direct / sideloaded APK** (USB install, sharing a build outside Play)
— use ABI splitting so you don't ship a fat universal APK that bundles
every architecture:

```
flutter build apk --release --split-per-abi
```

That produces per-ABI APKs under `build/app/outputs/flutter-apk/`
(e.g. `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`). We
use Flutter's `--split-per-abi` flag rather than a manual Gradle
`splits { abi { ... } }` block so the split stays in the Flutter
toolchain and matches what `flutter build` already documents.

A plain `flutter build apk --release` (no split) still builds a
universal APK — avoid that for day-to-day testing installs; it's the
main reason an install can land at ~100MB+.

### 5. Faster iteration: run it in the browser (localhost)

Flutter's equivalent of an `npm run dev` hot-reload loop:

```
flutter run -d chrome
```

**Known gotcha:** eBird's API may not send the CORS headers a browser
requires. If sightings/hotspots fail to load in Chrome but work fine on
Android, open DevTools (F12) → Console and look for a red CORS error —
that confirms it. If so, run the included local proxy alongside the app:

```
node tools/cors_proxy.js
```

then point the app at it:

```
flutter run -d chrome --dart-define=EBIRD_BASE_URL=http://localhost:3000/v2
```

The proxy forwards requests to eBird and adds the missing CORS header —
no data or key changes. Android/iOS builds never need this.

## Design & branding

UI decisions on this app aren't made screen-by-screen from scratch —
`docs/design-principles.md` and `docs/brand.md` are living references,
and new work should point back to them rather than re-deriving the
reasoning each time:

- Prefer native Material 3 components over custom-built ones, and mirror
  patterns from established consumer apps over inventing new
  interactions — see `design-principles.md` for the specific patterns
  already in use (segmented filter control, collapsing hero header,
  sticky family-grouped headers, persistent bottom sheets, native launch
  splash).
- Visual direction is minimalist/editorial — warm cream/ink palette, a
  serif (Newsreader) for anything you read paired with a sans (Public
  Sans) for interface chrome, hairline dividers preferred over
  tinted/bordered cards. See `brand.md` for the full palette and type
  scale, and `lib/theme/` for how it's implemented as code tokens.
- Accessibility isn't a separate pass bolted on at the end — the palette
  was checked against WCAG AA contrast minimums as part of building it
  (every core text/background pairing clears 4.5:1 in both light and
  dark mode), and a follow-up audit covered screen-reader labels, touch
  target sizing, dynamic text scaling, and making sure nothing relies on
  color alone to convey meaning.
- `docs/tickets/` holds scoped, standalone specs for work handed off for
  implementation — useful both as a handoff format and as a record of
  why a given screen looks the way it does.

## What's implemented vs. what's next

Implemented:
- Nearby recent sightings, grouped by taxonomic family with sticky
  section headers in eBird taxonomic order (not alphabetical), an
  all-species/notable-rare segmented filter, and two independent
  filters: search radius (1–20 km, defaults to a tight 7 km so you start
  close and expand outward) and how far back to look (1–30 days,
  defaults to 7)
- Species search across the full eBird taxonomy (10,000+ species by
  common name — scientific name is shown but not searched, since it was
  pulling in unrelated species that happen to share a Latin epithet) —
  not limited to what's shown up nearby recently
- Nearby hotspots map (OpenStreetMap, no Google Maps key needed, proper
  "© OpenStreetMap contributors" attribution shown on the map itself),
  with clustering so dense urban areas collapse into a legible count
  badge instead of an overlapping pile of pins, on-brand marker styling,
  and a "recenter on me" control. Its own search radius and species
  search entry point live in the map's AppBar, independent from the
  sightings list's. Tapping a marker opens a bottom sheet — drag it up
  and it expands to nearly full height, showing that location's species
  seen within the same shared date range as the sightings list (with the
  all-time species count kept as secondary context, not the headline)
- Species detail page — collapsing hero photo (swipeable gallery with
  photographer attribution when Wikimedia Commons has more than one
  image for a species) that animates in from the thumbnail you tapped
  rather than cutting straight to it, serif/sans typographic hierarchy,
  Wikipedia summary, and a capped/expandable feed of recent local
  sightings
- **My Life List** — mark any species as seen (count, location, date)
  from its detail page, with a small on-brand animation on the button
  when you do; view/remove entries in the Life List tab. Stored locally
  on-device only — nothing is sent to eBird yet (see roadmap below)
- Local eBird API key storage, no account/login required — first launch
  walks you straight to eBird's free key-request page rather than just
  telling you to go find one yourself
- Settings: light/dark/system theme, a miles/kilometers display toggle
  (distance is always stored and sent to eBird in km — miles is a
  display-only conversion), and an About section crediting eBird,
  Wikipedia/Wikimedia Commons, and OpenStreetMap as data sources
- Design tokens (`lib/theme/`) implementing `brand.md`'s palette and
  type scale, with real light/dark support (system-following by default,
  manual override available), and an accessibility pass on top of it
- Offline-friendly loading — last-known sightings/hotspots results are
  cached and shown instantly while a fresh fetch happens quietly in the
  background, with skeleton loading states instead of bare spinners
- Bounded on-device caches for map tiles (~50 MB) and species photos
  (~100 images / 21 days) so footprint doesn't grow without limit
- Native launch splash (Android `SplashScreen` API via
  `flutter_native_splash`) and adaptive launcher icon — Common Loon
  brand mark on cream in both light and dark system modes (app UI dark
  theme is unchanged)
- A first real unit-test baseline (`test/services/`) covering the eBird
  client, settings persistence, and life list storage — no more relying
  solely on manual on-device testing to catch a regression

### The life list roadmap

"Add to life list" is intentionally local-only for now (Phase 1). The
`LifeListEntry` fields were chosen to line up with eBird's own
["Checklist Format" spreadsheet import](https://support.ebird.org/en/support/solutions/articles/48000907878-upload-spreadsheet-data-to-ebird)
columns, so later phases are mostly formatting work, not a data model
rewrite:

- **Phase 2** — an "export to eBird" action that packages logged
  sightings into eBird's checklist-format CSV, handed off to eBird's own
  import page.
- **Phase 3** — a share/deep-link hand-off into eBird's own app to
  submit a live checklist, pre-filled with as much context as we can
  pass through an intent.
- **Phase 4 (aspirational)** — true one-tap sync via eBird's submission
  API. Not self-serve — eBird's public API is read-only, and write
  access is a relationship you'd build directly with the eBird/Cornell
  Lab team, not something granted through the API keygen page.

### Someday / backlog

- **Bird call audio** — Xeno-canto has a free public API
  (https://xeno-canto.org/explore/api) that could slot in next to the
  photo on the species page.

## eBird API reference

Full docs: https://documenter.getpostman.com/view/664302/S1ENwy59
- Rate limits are generous for personal use but not published exactly —
  if you start hitting 429s, add simple response caching.
