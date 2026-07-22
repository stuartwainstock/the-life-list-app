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

## What to weigh while building

The three rules above are about interaction/UX decisions. Separately,
every ticket and every piece of code should be weighed against these —
more architectural than the three rules, but just as much a source of
future rework if skipped:

- **Scale.** Would this still hold up with 10x the data, or a much
  denser area? The hotspot map's marker overlap (fixed via clustering,
  `docs/tickets/hotspot-marker-clustering.md`) and the species detail
  page's unbounded sightings list (fixed via capping,
  `docs/tickets/species-detail-sightings-list-polish.md`) are both
  examples of something that worked fine with a handful of results and
  broke down once real data volume showed up. Ask "what does this look
  like with 200 of these, not 5" before shipping a list or a map layer.
- **Digital accessibility.** Not a separate pass done once at the end —
  contrast, screen-reader labels, touch target size, and color-only
  meaning should be considered as a screen is built, the same way
  `docs/brand.md`'s palette was checked against WCAG AA as part of
  defining it, not after. See
  `docs/tickets/accessibility-quick-wins.md` and
  `docs/tickets/accessibility-verification-pass.md` for the kind of
  gaps that slip in otherwise (missing tooltips, color used as the only
  signal, etc.).
- **Overall brand.** Does this match `docs/brand.md`'s palette,
  typography, and surface philosophy, or did it reach for a stock
  Material default/color under time pressure? The hotspot map markers
  using the alert/error color instead of a brand token
  (`docs/tickets/hotspot-map-markers-and-recenter.md`) is the cautionary
  example — a real, working feature that still needed a follow-up ticket
  purely to bring it back in line with the brand.
- **Reusability.** Before hand-building something screen-specific, check
  the component inventory below — does a version of this already exist?
  If not, and this shape is likely to show up on a second screen later,
  build it as a shared widget in `lib/widgets/` now rather than
  duplicating it later. The AppBar inconsistency between Sightings and
  Hotspots (`docs/tickets/shared-appbar-component.md`) is the direct
  result of not doing this early.
- **Design systems and token strategy.** Colors, type, spacing, and
  radius should come from `lib/theme/` (`AppColors`, `AppTypography`,
  `AppSpacing`, `AppRadius`), never a hardcoded hex value or magic
  number. If a new value doesn't fit an existing token, that's a signal
  to extend `docs/brand.md` and the token layer deliberately, not to
  hardcode an exception.

## Component inventory

A running list of reusable pieces that already exist — check here before
building something new that might already be one screen tap away from
duplicating this. Roughly ordered smallest-to-largest, borrowing the
"atoms → molecules → organisms" vocabulary (Brad Frost's Atomic Design)
as a rough sizing guide, not a strict taxonomy this project maintains
folders for.

**Atoms** (`lib/theme/`):
- `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius` — the token
  layer everything else is built from. See `docs/brand.md` for the
  source values.
- `BrandProgressIndicator` (loading spinner using the brand accent
  color) — used anywhere a bare `CircularProgressIndicator` would
  otherwise appear.

**Molecules** (`lib/widgets/`):
- `SightingListRow` — thumbnail + common name + location + relative
  time. The base unit of both the sightings list and (in spirit) the
  hotspot checklist rows.
- `SpeciesThumbnail` — small species image with graceful fallback.
- Skeleton loading placeholders (`skeleton.dart`,
  `species_detail_skeleton.dart`) — shape-matched loading states, not
  bare spinners, per `docs/tickets/loading-states-polish.md`.
- The species count / life-list count badge pill (accent-tinted,
  `docs/brand.md`'s one deliberate exception to the hairline-over-card
  rule).
- The photo-with-attribution-caption treatment on the species detail
  hero (`docs/tickets/species-photo-attribution-and-gallery.md`) — a
  candidate to formally extract if a second screen ever wants a
  credited photo.

**Organisms** (`lib/widgets/`, `lib/screens/`):
- `HotspotDetailSheet` — the persistent (non-modal) bottom sheet pattern
  for map marker detail, drag-to-expand into a full checklist.
- The sticky, taxonomically-grouped section list on the sightings
  screen (`flutter_sticky_header`-based).
- The segmented all-species/notable-rare filter + its bottom-sheet
  radius/date-range slider companion.
- The collapsing hero header on species detail (`_HeroAppBar` —
  intentionally distinct from the standard app bar below, since it
  displays content, not chrome).

**Standard app bar** (in progress — see
`docs/tickets/shared-appbar-component.md`): the title + actions app bar
shape used by the four top-level tab screens (Sightings, Hotspots, Life
List, Settings) should be built from one shared widget, not
reimplemented per screen — this is what the search/tune-icon
inconsistency between screens came from.

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
