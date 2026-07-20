# The Life List

A simple, editorial-minimalist birding app for Android (and web, for
dev/testing), built on Flutter and the free public eBird API. Originally
inspired by GoBird, it's grown its own identity: nearby sightings grouped
by taxonomic family, hotspots, species detail pages, and a personal life
list — all read-only against eBird today, with a real path toward eBird
interoperability (see the roadmap below).

## What's here

- `lib/main.dart` — app entry point, theme wiring, manual + system
  dark-mode handling
- `lib/screens/` — Sightings list (family-grouped, sticky headers),
  Hotspots map, Species detail, Life List, Settings
- `lib/services/` — eBird API client, eBird taxonomy client (for family
  grouping), device location, local storage, Wikipedia photo lookup,
  life list storage
- `lib/models/` — Observation, Hotspot, and LifeListEntry data classes
- `lib/theme/` — design tokens (colors, typography, spacing/radius) and
  the assembled light/dark `ThemeData` — see `docs/brand.md` for the
  source values
- `lib/widgets/` — shared UI pieces (sighting list row, species
  thumbnail) used across screens
- `lib/utils/` — small helpers (relative time formatting)
- `docs/design-principles.md` — living reference for interaction
  patterns (prefer native Material 3 components, mirror established
  consumer-app patterns, minimize cognitive load)
- `docs/brand.md` — living reference for color palette and typography
- `docs/tickets/` — scoped work handed off for implementation; useful
  history of *why* something looks the way it does
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

Paste it into the app itself on first launch (Settings) — no code
changes needed. Each contributor should use their own key rather than
sharing one — see the earlier discussion in this repo's history if that
tradeoff needs re-explaining to someone new.

### 3. Install packages and run

```
flutter pub get
flutter run
```

Plug in your Android phone via USB with USB debugging enabled (Settings →
About phone → tap "Build number" 7 times → Developer options → USB
debugging), or start an emulator from Android Studio, then run the
command above.

### 4. Build a real APK to install anytime

```
flutter build apk --release
```

Lands at `build/app/outputs/flutter-apk/app-release.apk` — copy to your
phone (or `flutter install`) to use without a cable.

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
  sticky family-grouped headers, native launch splash).
- Visual direction is minimalist/editorial — warm cream/ink palette, a
  serif (Newsreader) for anything you read paired with a sans (Public
  Sans) for interface chrome, hairline dividers preferred over
  tinted/bordered cards. See `brand.md` for the full palette and type
  scale, and `lib/theme/` for how it's implemented as code tokens.
- `docs/tickets/` holds scoped, standalone specs for work handed off for
  implementation — useful both as a handoff format and as a record of
  why a given screen looks the way it does.

## What's implemented vs. what's next

Implemented:
- Nearby recent sightings, grouped by taxonomic family with sticky
  section headers in eBird taxonomic order (not alphabetical), plus an
  all-species/notable-rare segmented filter
- Nearby hotspots map (OpenStreetMap, no Google Maps key needed)
- Species detail page — collapsing hero photo, serif/sans typographic
  hierarchy, photo/summary via Wikipedia, recent local sightings of that
  species
- **My Life List** — mark any species as seen (count, location, date)
  from its detail page; view/remove entries in the Life List tab. Stored
  locally on-device only — nothing is sent to eBird yet (see roadmap
  below)
- Local eBird API key storage, no account/login required
- Design tokens (`lib/theme/`) implementing `brand.md`'s palette and
  type scale, with real light/dark support (system-following by default,
  manual override available)
- Native launch splash (Android `SplashScreen` API via
  `flutter_native_splash`) — icon and colors are still interim
  placeholders pending a real app icon/logo

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

### Reasonable next steps, roughly in order of effort

1. **Real app icon / logo** — the splash screen currently uses a
   clearly-flagged placeholder icon; needs actual brand asset work.
2. **Screen-level hairline-vs-card pass** — `brand.md`'s surface
   philosophy calls for replacing the remaining tinted/bordered card
   sections (detail page description block, sightings section) with
   hairline dividers now that tokens exist to build from.
3. **Species search** — search all 10,000+ eBird species by name, not
   just ones seen recently nearby.
4. **Offline caching** — cache last results so the list isn't empty with
   no signal.
5. **Bird call audio** — Xeno-canto has a free public API
   (https://xeno-canto.org/explore/api) that could slot in next to the
   Wikipedia photo on the species page.

## eBird API reference

Full docs: https://documenter.getpostman.com/view/664302/S1ENwy59
- Rate limits are generous for personal use but not published exactly —
  if you start hitting 429s, add simple response caching.
