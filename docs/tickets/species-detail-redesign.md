# Species Detail Page — Visual Hierarchy Redesign

## Context

`lib/screens/species_detail_screen.dart` currently renders the photo,
scientific name, description, and recent-sightings list with almost no
visual hierarchy — everything is roughly the same size, weight, and
color, so the page reads as flat. This ticket restyles that screen only.
No data/API/model changes are required — this is presentation-layer work
on top of the existing `_summary`, `_sightings`, and life-list state that
already populate the screen.

Reference screenshot of current state: species detail page for
"Ruby-throated Hummingbird" — full-width photo, italic scientific name,
body paragraph, "Recent sightings near you" label, then a plain
`ListTile` list, with a floating "Add to life list" button that currently
overlaps/clips the last list item.

## Goals

- Establish clear visual hierarchy: photo → identity block → description
  → sightings feed, each visually distinct from the next.
- Make the sightings list read as a scannable activity feed (this is the
  most-loved part of the reference app, GoBird — it should get the most
  polish).
- Fix the FAB overlap bug where the last sighting row is clipped.
- Use the existing brand seed color (`0xFF2E7D32`, forest green, set in
  `main.dart`'s `ThemeData.colorSchemeSeed`) as a structural/accent color
  rather than leaving the page monochrome.

## Non-goals

- No changes to `EbirdService`, `WikipediaService`, or `LifeListService`.
- No changes to the sightings list screen, hotspots screen, or settings
  screen — scope is `species_detail_screen.dart` only (a shared
  "sightings row" widget is fine if it's introduced here and only used
  here for now).
- No new packages beyond what's already in `pubspec.yaml`
  (`cached_network_image`, `intl`) unless a specific requirement below
  calls for one.

## Requirements

### 1. Hero photo header

- Replace the static top-of-page `CachedNetworkImage` with a collapsing
  header using `CustomScrollView` + `SliverAppBar` (`flexibleSpace`
  showing the photo, `pinned: true` so the app bar remains after
  collapse, back button visible throughout).
- Add a bottom gradient scrim on the photo (dark, semi-transparent,
  bottom-anchored) so light-colored bird photos still have readable
  contrast if we later overlay text.
- If no photo is available (`_summary?.imageUrl == null`), collapse to a
  standard fixed-height `AppBar` with the common name as the title (i.e.
  don't leave a large blank hero area).

### 2. Identity block (common name / scientific name)

- Common name: keep as the primary heading, at least one type-scale step
  larger than anything else on the page.
- Scientific name: restyle as a small, letter-spaced, muted-color label
  (not full-size italic body text) — visually subordinate to the common
  name, not competing with it.
- Tight spacing between common name and scientific name (they're one
  group); clear, larger spacing before the description starts (new
  group).

### 3. Description block

- Keep the Wikipedia-sourced description text, but give its container a
  distinct surface — either a subtly different background tone from the
  page background, or a bounded card with rounded corners — so it reads
  as a separate zone from the sightings feed below it, not a continuous
  scroll of same-toned text.

### 4. Sightings section header

- Restyle "Recent sightings near you" as a section eyebrow: bold, smaller
  than the common name, colored with the brand green accent.
- Add a count badge next to it reflecting `_sightings.length` (e.g. a
  small pill showing "4").

### 5. Sightings list rows

- Each row gets a location-pin leading icon (`Icons.location_on_outlined`
  or similar), sized and colored consistently.
- Replace the absolute date/time string with a relative time
  ("2 hours ago", "Yesterday", falling back to a short date past ~7 days)
  — introduce a small formatting helper function for this rather than
  inlining logic in the widget.
- Keep the "N seen" count, but visually de-emphasize it relative to the
  location name (smaller/muted), matching the existing hierarchy
  direction.
- Give the whole sightings section a bounded card or tinted-surface
  container distinct from the description block above it.

### 6. FAB overlap fix

- Add bottom padding to the scrollable content equal to the FAB's
  effective height + margin, so the last sightings row is never clipped
  regardless of list length.
- Confirm the fix by checking a species with 1 sighting and a species
  with 6+ sightings — both should scroll fully clear of the FAB.

### 7. Empty / loading states

- Loading state: keep the existing centered spinner, but make sure it
  renders inside the new `CustomScrollView`/`SliverAppBar` structure
  without layout errors (i.e. don't return a bare `CircularProgressIndicator`
  outside a `Scaffold`/`Sliver` context).
- No-sightings state: keep existing "No recent nearby sightings of this
  species" message, but give it the same card/section treatment as the
  populated state so it doesn't look like a layout break.

## Acceptance criteria

- [ ] Photo header collapses on scroll and stays pinned with a visible
      back button at all scroll positions.
- [ ] Scientific name is visually distinct (smaller/muted/letter-spaced)
      from both the common name and the body description.
- [ ] Description text sits in a visually separate zone from the
      sightings list (card, tint, or divider — implementer's choice, but
      it must be visually obvious, not just a `SizedBox` gap).
- [ ] Sightings section header shows a count badge and uses the brand
      green accent color.
- [ ] Every sightings row has a location icon and a relative-time string.
- [ ] FAB never overlaps or clips the last row, tested with 1 sighting
      and 6+ sightings.
- [ ] No species with a null/failed photo renders a broken or blank hero
      area — falls back to a standard app bar.
- [ ] `flutter analyze` passes with no new warnings introduced by this
      change.

## Files likely touched

- `lib/screens/species_detail_screen.dart` (primary)
- Possibly a new small helper, e.g. `lib/utils/relative_time.dart`, for
  the relative-time formatting used in requirement 5.

## Out of scope / follow-up ideas (not part of this ticket)

- Applying the same sightings-row styling to `sightings_list_screen.dart`
  (worth a follow-up ticket once this pattern is proven out here).
- A dedicated "quick facts" chip row (family, conservation status, etc.)
  — would require a new data source, not currently available from eBird
  or the Wikipedia summary call.
