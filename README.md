# GoBirder

A simple, GoBird-inspired birding app for Android, built on Flutter and the
free public eBird API. Shows recent bird sightings and hotspots near you,
and species detail pages with photos pulled from Wikipedia.

## What's here

- `lib/main.dart` — app entry point
- `lib/screens/` — Sightings list, Hotspots map, Species detail, Life List, Settings
- `lib/services/` — eBird API client, device location, local storage, Wikipedia photo lookup, life list storage
- `lib/models/` — Observation, Hotspot, and LifeListEntry data classes
- `android/app/src/main/AndroidManifest.xml` — location + internet permissions

This is `lib/` + a few config files only — no full native Android/iOS
scaffolding. You'll generate that with `flutter create` (step 2 below),
which won't touch the files above.

## 1. Install Flutter

If you don't already have it: https://docs.flutter.dev/get-started/install
(pick Android). Then confirm your setup:

```
flutter doctor
```

Fix anything it flags (Android SDK, accepted licenses, a connected device
or emulator) before continuing.

## 2. Get a free eBird API key

eBird is run by the Cornell Lab of Ornithology and is what GoBird itself is
built on. Request a key (instant, free) at:

https://ebird.org/api/keygen

You'll paste this into the app itself on first launch — no code changes
needed.

## 3. Scaffold native Android files

From inside this `gobirder/` folder:

```
flutter create --platforms=android --org com.thenerdbirder .
```

This generates the missing `android/` build files without overwriting the
`lib/`, `pubspec.yaml`, or `AndroidManifest.xml` already here (say yes if
it asks to overwrite `AndroidManifest.xml` — ours already has the right
permissions added, but check the generated one merges cleanly; if it gets
overwritten just re-copy the two `<uses-permission>` lines for location
back in).

## 4. Install packages and run

```
flutter pub get
flutter run
```

Plug in your Android phone via USB with USB debugging enabled (Settings →
About phone → tap "Build number" 7 times → Developer options → USB
debugging), or start an emulator from Android Studio, then run the command
above. `flutter run` will install and launch the app directly on the
device.

On first launch, tap "Set up API key" and paste the key from step 2.

## 5. Build a real APK to install anytime

```
flutter build apk --release
```

The installable file lands at `build/app/outputs/flutter-apk/app-release.apk`
— copy it to your phone (or `flutter install`) to use it without a cable.

## 6. Faster iteration: run it in the browser (localhost)

If you're used to a web dev loop (`npm run dev`-style hot reload), Flutter
has an equivalent — no phone or emulator needed for quick UI iteration:

```
flutter config --enable-web
flutter create --platforms=web .
flutter run -d chrome
```

The first line turns on web support (off by default). The second adds the
missing `web/` scaffolding — it won't touch existing `lib/` code. The third
builds and serves the app at a local port and opens Chrome, with the usual
`r` (hot reload) / `R` (full restart) keys in the terminal.

**Known gotcha:** the eBird API is built for server-side/mobile use, and
may not send the CORS headers a browser requires. If sightings/hotspots
fail to load in Chrome but work fine on Android, open DevTools (F12) →
Console and look for a red CORS error — that confirms it.

If you hit that, run the included local proxy alongside the app:

```
node tools/cors_proxy.js
```

Then point the app at it instead of eBird directly:

```
flutter run -d chrome --dart-define=EBIRD_BASE_URL=http://localhost:3000/v2
```

The proxy just forwards your request to eBird and adds the missing CORS
header — no data changes, no key changes. Android/iOS builds never need
this; they call eBird directly with no CORS restriction.

## What's implemented vs. what's next

Implemented, mirroring GoBird's core loop:
- Nearby recent sightings list (all species + notable/rare toggle)
- Nearby hotspots map (OpenStreetMap, no Google Maps key needed)
- Species detail page with photo/summary (Wikipedia) and recent local
  sightings of that species
- **My Life List** — mark any species as seen (count, location, date) from
  its detail page; view/remove entries in the Life List tab. Stored
  locally on-device only — nothing is sent to eBird yet.
- Local API key storage, no account/login required

### The life list roadmap

"Add to life list" is intentionally local-only for now (Phase 1). The
`LifeListEntry` fields were chosen to line up with eBird's own
["Checklist Format" spreadsheet import](https://support.ebird.org/en/support/solutions/articles/48000907878-upload-spreadsheet-data-to-ebird)
columns, so later phases are mostly formatting work, not a data model
rewrite:

- **Phase 2** — an "export to eBird" action that packages logged sightings
  into eBird's checklist-format CSV, handed off to eBird's own import page.
- **Phase 3** — a share/deep-link hand-off into eBird's own app to submit a
  live checklist, pre-filled with as much context as we can pass through
  an intent.
- **Phase 4 (aspirational)** — true one-tap sync via eBird's submission
  API. This isn't self-serve — eBird's public API is read-only, and
  write access is a relationship you'd build directly with the eBird/
  Cornell Lab team, not something granted through the API keygen page.

Reasonable next steps beyond the life list, roughly in order of effort:
1. **Species search** — search all 10,000+ eBird species by name, not just
   ones seen recently nearby.
2. **Offline caching** — cache last results so the list isn't empty with
   no signal.
3. **Bird call audio** — Xeno-canto has a free public API
   (https://xeno-canto.org/explore/api) that could slot in next to the
   Wikipedia photo on the species page.
4. **App icon / branding** — currently uses Flutter's default icon.

## eBird API reference

Full docs: https://documenter.getpostman.com/view/664302/S1ENwy59
- Rate limits are generous for personal use but not published exactly —
  if you start hitting 429s, add simple response caching.
