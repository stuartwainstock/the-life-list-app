# Design Principles

A short, living reference for how we make UI decisions on this app.
Point future tickets back here instead of re-explaining the reasoning
each time. Update it when a new pattern decision gets made — this should
stay a living document, not a one-time writeup.

## The three rules

**1. Prefer native Material 3 components over custom-built ones.**
If Flutter/Material already ships a widget for the interaction we need,
use it before reaching for a hand-rolled alternative. Stock components
come with behavior users already understand for free — the right
animation curves, the right touch targets, the right accessibility
defaults — none of which we'd get right by rebuilding it ourselves.

**2. Mirror patterns from established consumer apps over inventing new
interactions.** If a major app (Android system apps, Spotify, Airbnb,
Google Maps, etc.) has already solved a given interaction problem well
and it's widely used, borrow it rather than designing something novel.
Novelty in UI is a cost users pay in confusion, not a feature.

**3. Minimize cognitive load.** This app's core value is quick,
scannable identification and logging in the field — often one-handed,
often while also watching a bird. Every new gesture, new visual language,
or new decision point works against that. When in doubt, cut a choice
rather than add one.

## Patterns already in use (reference these, don't reinvent them)

- **Segmented filter control** (`SegmentedButton`) — nearby sightings'
  all-species/notable toggle. One pill, two states, native sliding
  indicator, instead of two independent chip buttons.
- **Collapsing hero header** (`SliverAppBar` + `flexibleSpace`) — species
  detail page photo. Same pattern as Play Store listings, Airbnb, Spotify
  album pages: photo shrinks into the app bar on scroll rather than
  sitting as a static, disconnected image block.
- **Sticky section headers grouped by category** — sightings list grouped
  by taxonomic family. Same shape as a phone contacts list grouped
  alphabetically; birders already think in family groupings, so this
  maps a native pattern onto a domain-native mental model.
- **Pull-to-refresh** (`RefreshIndicator`) — already used on the
  sightings list and hotspots map. Standard Android refresh gesture,
  no custom refresh button needed alongside it.
- **Native launch splash** (`flutter_native_splash` / Android
  `SplashScreen` API) — system splash that dismisses on first Flutter
  frame, not a hand-rolled Flutter route. Uses the Common Loon brand
  mark and `docs/brand.md` cream/dark backgrounds; see
  `flutter_native_splash.yaml`.
- **App launcher icon** (`flutter_launcher_icons`) — adaptive icon with
  loon foreground on brand cream (`#FAF6EE`); source art in
  `assets/icon/`.
- **Design tokens** (`lib/theme/`) — color, type, spacing, radius from
  `docs/brand.md`, wired through `AppTheme.light` / `AppTheme.dark` with
  `ThemeMode.system`. Prefer `Theme.of(context)` and `AppSpacing` /
  `AppRadius` over hardcoded hex or magic numbers.

## Patterns to reach for next, as relevant tickets come up

- **Bottom sheets over centered dialogs** for secondary actions/confirmations
  (`showModalBottomSheet` instead of `AlertDialog`) — bottom sheets read as
  more native on Android; centered modal dialogs feel more iOS/desktop.
- **Swipe-to-action on list rows** (e.g. swipe-to-delete on the life list)
  instead of tap-then-confirm-dialog flows, where the action is common
  enough to warrant the shortcut.
- **Relative time over absolute timestamps** in scannable lists ("2 hours
  ago" vs "Jul 20, 2026 12:41 PM") — already applied via
  `lib/utils/relative_time.dart`; keep using it anywhere a timestamp
  shows up in a list context.

## How to use this in a ticket

When writing or reviewing a ticket, ask two questions before specifying
a custom widget or interaction:

1. Does Material 3 already have a stock component for this?
2. Does a major consumer app already solve this problem in a way people
   recognize on sight?

If the answer to either is yes, the ticket should say so explicitly and
name the component/pattern, rather than describing the interaction from
scratch and leaving the implementation to guess at the reference.
