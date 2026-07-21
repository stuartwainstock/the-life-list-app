# Brand: Color & Typography

A living reference for the app's visual identity — companion to
`docs/design-principles.md` (which covers interaction patterns; this
covers color, type, and surface treatment). Point future tickets here
instead of re-deriving these choices.

## Direction

Minimalist editorial, inspired by a cluster of current identifier/
lifestyle/reading apps (Picture Insect, Plantify, Plant Parent, Bevel,
Artifact, The New Yorker) that independently converge on the same
language: type does the hierarchy work instead of boxes and color
blocking; palettes are restrained to near-monochrome plus one disciplined
accent; photography is full-bleed and unfussy; thin hairline rules
separate content instead of filled/tinted cards. For this app
specifically, a serif-for-reading / sans-for-interface split also
reinforces the "field guide" identity behind the app's name and concept.

## Color palette

Warm, paper-like neutrals rather than stark white/black or a cool gray
scale — the app should feel like ink on a page, not a software surface.

| Role | Light mode | Usage |
|---|---|---|
| Background | `#FAF6EE` | Page background |
| Surface | `#F3EEE1` | Subtle separation only where truly needed (e.g. the life-list count badge) — prefer a hairline divider over a surface change first |
| Ink (primary text) | `#201F1C` | Headings, body copy, primary content — not pure black |
| Muted ink (secondary text) | `#6B6558` | Metadata, timestamps, captions, scientific names |
| Accent (brand green, refined) | `#3A5A40` | Used sparingly: section labels, active states, the FAB, count badges. Refined from the original ad hoc seed color (`#2E7D32`) toward something more muted/ink-like — same family, more restrained |
| Accent tint | `#E4EAE1` | Backgrounds behind accent-colored elements (e.g. badge fill) — never used as a large surface |
| Hairline / divider | `#DDD6C6` | Replaces most current bordered/tinted card containers |
| Alert / error | `#A6432D` | Muted brick/rust rather than a stock saturated red — errors should still feel like they belong to this palette |

### Dark mode

Same philosophy inverted warmly — not a straight light/dark flip to pure
black and white:

| Role | Dark mode |
|---|---|
| Background | `#1C1B17` |
| Surface | `#252420` |
| Ink (primary text) | `#F2EEE3` |
| Muted ink (secondary text) | `#A39C8A` |
| Accent | `#7FA687` (lightened for contrast against the dark background) |
| Accent tint | `#2E362F` |
| Hairline / divider | `#3A382F` |
| Alert / error | `#D97B63` |

These dark values should also be what
`docs/tickets/splash-screen-skeleton.md`'s dark-mode splash background
gets updated to once this palette is implemented — that ticket used a
placeholder dark green specifically pending this doc.

## Typography

Two typefaces, each with a clear job:

- **Serif — for content you read.** Species common names, scientific
  names, and the Wikipedia description body copy. Recommendation:
  **Newsreader** (Google Fonts) — designed for on-screen reading, has a
  genuine italic (useful for scientific names, which are already
  conventionally italicized), and reads as literary/field-guide rather
  than decorative.
- **Sans — for interface you use.** Navigation labels, buttons, section
  eyebrows, list metadata (location, relative time, counts), settings.
  Recommendation: **Public Sans** (Google Fonts) — neutral, highly
  legible at small sizes, doesn't compete with the serif for attention.

### Suggested type scale

| Style | Font | Size / weight | Where |
|---|---|---|---|
| Display | Newsreader | 28–32, Medium/SemiBold | Species common name (detail page) |
| Sub-display (italic) | Newsreader Italic | 15–16, Regular | Scientific name |
| Body | Newsreader | 16, Regular, generous line-height (1.5+) | Wikipedia description paragraph |
| **AppBar / page title** | **Public Sans** | **20–22, SemiBold** | **"Nearby Sightings," "Hotspots," "My Life List," "Settings" — every top-level screen title** |
| Section label | Public Sans | 13, SemiBold, letter-spacing +0.3 | "Recent sightings near you," family group headers |
| UI label | Public Sans | 14–15, Medium | Buttons, nav labels, form labels |
| Metadata | Public Sans | 13, Regular, muted ink color | Location, relative time, counts |

**Note on AppBar titles specifically:** these were an ambiguous gap in
the original scale, not a deliberate serif choice — they ended up
rendered in Newsreader by default alongside species names, which reads
as if the screen title and the bird's name carry equal weight as
"content." An AppBar title is navigational chrome (the same job as the
bottom nav labels and the segmented filter control sitting right below
it), not reading content, so it belongs with the sans/UI group. This
also sharpens the hierarchy rather than flattening it — serif becomes
exclusively the species name's territory, making it stand out more on a
screen that's otherwise all sans chrome, not less.

## Surface philosophy

Prefer a hairline divider (`#DDD6C6` light / `#3A382F` dark) over a
tinted or bordered card as the default way to separate content blocks.
Reserve an actual surface-color change for places that need real visual
weight — the life-list count badge, the FAB — not as the general-purpose
separation tool it's currently being used as on the detail and sightings
screens. This is the single biggest visual shift from where the app is
today: less "boxes," more "breathing room."

## Implementation notes for whoever picks this up

- This is a `ThemeData`-level change, not a per-screen one. Both
  `species_detail_screen.dart` and `sightings_list_screen.dart` already
  read colors and text styles from `Theme.of(context)` rather than
  hardcoding hex values — so defining this palette and type scale
  centrally in `main.dart`'s `ThemeData` (an explicit `ColorScheme.light()`/
  `ColorScheme.dark()` pair, not `colorSchemeSeed`, since a single-seed
  generation won't reproduce this specific restrained palette) should
  cascade across already-built screens with minimal per-screen rework.
- Use the `google_fonts` package for Newsreader and Public Sans rather
  than bundling font files manually.
- This deserves its own implementation ticket once you're ready — happy
  to draft one covering the `ThemeData` rewrite, replacing the current
  tinted-card sections with hairline dividers, and updating the splash
  screen's placeholder colors to match.
