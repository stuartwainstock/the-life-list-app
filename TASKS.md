# Tasks

## Active

- [ ] **Splash: cream background in all modes** - simpler fix than debugging the dark-mode asset bug; drop the separate dark splash variant entirely and use `#FAF6EE` + the loon in both light and dark system mode — see `docs/tickets/web-splash-dark-mode-bugfix.md`
- [x] **Accessibility: quick wins** - missing icon-button tooltips, species photo alt text, touch target sizing on map markers/drag handle — see `docs/tickets/accessibility-quick-wins.md`
- [x] **Accessibility: verification pass** - confirm hairline dividers never serve as sole interactive-boundary indicator, dynamic text scaling holds up, no state relies on color alone — see `docs/tickets/accessibility-verification-pass.md`

## Waiting On

## Someday
- [ ] **Bird call audio** - Xeno-canto has a free public API (https://xeno-canto.org/explore/api), could slot in next to the Wikipedia photo on the species page
- [ ] **Life list Phase 2: export to eBird** - package logged sightings into eBird's checklist-format CSV, hand off to eBird's own import page
- [ ] **Life list Phase 3: deep-link hand-off** - share/deep-link into eBird's own app to submit a live checklist, pre-filled with as much context as possible
- [ ] **Life list Phase 4: true eBird API sync (aspirational)** - one-tap sync via eBird's submission API; not self-serve, requires a direct relationship with the eBird/Cornell Lab team, not something granted through the API keygen page

## Done

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
