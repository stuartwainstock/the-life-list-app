# Tasks

## Active

## Waiting On

- [ ] **Live TalkBack verification pass** - prep done (sheet expand/collapse/close + gallery Semantics); awaiting Stuart’s on-device TalkBack walkthrough, then fix anything found — see `docs/tickets/talkback-verification-pass.md`

## Someday
- [ ] **Play Store readiness checklist** - real release signing key (currently debug-signed, see TODO in `android/app/build.gradle.kts`), a privacy policy (required once requesting location + storing an API key), store listing assets (screenshots, feature graphic, descriptions), the Play Console content rating questionnaire, and **a backend proxy for both the eBird and Xeno-canto API keys** (personal/embedded keys are fine solo-dev/QA but neither survives public distribution — server holds both secrets, rate-limits/authenticates callers, mobile app embeds neither key directly) — revisit once actually ready to submit
- [ ] **Life list Phase 2: export to eBird** - package logged sightings into eBird's checklist-format CSV, hand off to eBird's own import page
- [ ] **Life list Phase 3: deep-link hand-off** - share/deep-link into eBird's own app to submit a live checklist, pre-filled with as much context as possible
- [ ] **Life list Phase 4: true eBird API sync (aspirational)** - one-tap sync via eBird's submission API; not self-serve, requires a direct relationship with the eBird/Cornell Lab team, not something granted through the API keygen page

## Done

- [x] ~~API usage counter~~ (2026-07-22)
- [x] ~~Species detail: reorder Songs & Calls below description~~ (2026-07-22)
- [x] ~~Songs & calls (Xeno-canto)~~ (2026-07-22)
- [x] ~~Extract shared AppBar component~~ (2026-07-22)
- [x] ~~Test coverage baseline~~ (2026-07-22)
- [x] ~~First-run onboarding fix~~ (2026-07-22)
- [x] ~~OSM attribution wording fix~~ (2026-07-22)
- [x] ~~Life List celebration animation~~ (2026-07-22)
- [x] ~~Species photo hero transition~~ (2026-07-22)
- [x] ~~Hotspot sheet polish~~ (2026-07-22)
- [x] ~~Hotspots map: AppBar parity with sightings~~ (2026-07-22)
- [x] ~~Settings: units toggle + About skeleton~~ (2026-07-22)
- [x] ~~Hotspot checklist: scope to shared date range~~ (2026-07-22)
- [x] ~~Sightings filter: date-range slider~~ (2026-07-22)
- [x] ~~Hotspot map: marker clustering~~ (2026-07-21)
- [x] ~~Hotspot map: on-brand markers + recenter control~~ (2026-07-21)
- [x] ~~App footprint: build format + cache limits~~ (2026-07-21)
- [x] ~~Splash: cream background in all modes (no separate dark variant)~~ (2026-07-20)
- [x] ~~Accessibility: quick wins~~ (2026-07-21)
- [x] ~~Accessibility: verification pass~~ (2026-07-21)
- [x] ~~Species photos: Commons gallery + hero attribution~~ (2026-07-21)
- [x] ~~Hotspot detail: all-time species checklist on drag-up~~ (2026-07-21)
- [x] ~~Species search: match common name only~~ (2026-07-21)
- [x] ~~Species search (full taxonomy, AppBar entry on sightings list)~~ (2026-07-21)
- [x] ~~Screen-level hairline-vs-card pass (species detail description + sightings)~~ (2026-07-21)
- [x] ~~Standardize hotspot marker detail panel (persistent peek sheet above nav)~~ (2026-07-21)
- [x] ~~Species detail: cap long sightings list + FAB clearance~~ (2026-07-21)
- [x] ~~Offline caching (stale-while-revalidate for sightings + hotspots)~~ (2026-07-21)
- [x] ~~Fix AppBar title typography (Public Sans page titles; species detail stays Newsreader)~~ (2026-07-21)
- [x] ~~Sightings radius toggle (1–20 km bottom sheet, persisted, default 7 km)~~ (2026-07-21)
- [x] ~~Loading states polish (skeleton rows/detail, map overlay spinner)~~ (2026-07-21)
- [x] ~~Scaffold core Flutter app (sightings, hotspots, species detail, settings, eBird API integration, location)~~ (2026-07-20)
- [x] ~~Build Life List feature, Phase 1 (local-only add/view/remove)~~ (2026-07-20)
- [x] ~~Add web platform support + local CORS proxy for browser testing~~ (2026-07-20)
- [x] ~~Species detail page redesign (collapsing hero header, typographic hierarchy, relative time)~~ (2026-07-20)
- [x] ~~Sightings list redesign + taxonomic family clustering with sticky headers~~ (2026-07-20)
- [x] ~~Fix sticky-header stacking bug (switched to flutter_sticky_header)~~ (2026-07-20)
- [x] ~~Native launch splash skeleton (flutter_native_splash, placeholder icon/colors)~~ (2026-07-20)
- [x] ~~Design principles doc (docs/design-principles.md)~~ (2026-07-20)
- [x] ~~Brand doc: color palette + typography v1 (docs/brand.md)~~ (2026-07-20)
- [x] ~~Design tokens v1 implemented in lib/theme/, wired into ThemeData light/dark~~ (2026-07-20)
- [x] ~~README rewritten to match current feature set and actual project name~~ (2026-07-20)
- [x] ~~Rename GoBirder → The Life List (pubspec, classes, Android app label/id)~~ (2026-07-20)
- [x] ~~Design real app icon (Common Loon, generated via Gemini, cleaned up and safe-zone cropped)~~ (2026-07-20)
- [x] ~~Wire the real loon app icon into the build (launcher icons + splash)~~ (2026-07-20)
