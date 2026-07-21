import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale from `docs/brand.md`.
///
/// - **Newsreader** (serif): content you read — species names, scientific
///   names, Wikipedia body.
/// - **Public Sans** (sans): interface you use — AppBar/page titles, nav,
///   buttons, section eyebrows, metadata.
///
/// Roles are mapped to what existing screens already request via
/// `Theme.of(context).textTheme` so this cascades without per-screen edits:
/// - `headlineMedium` → detail common name (display)
/// - `titleLarge` → AppBar / page titles ("Nearby Sightings", etc.) — sans
/// - `titleMedium` → list species name (serif)
/// - `labelMedium` → scientific name (screens already italicize this role)
/// - `bodyMedium` / `bodyLarge` → Wikipedia body
/// - `titleSmall` / `labelLarge` → section eyebrows (family headers, etc.)
/// - `bodySmall` → location / relative time / counts
///
/// [AppBarTheme.titleTextStyle] is wired to [titleLarge] in [AppTheme], so
/// generic screen titles pick up Public Sans centrally. Species detail's
/// no-photo AppBar is the exception — it shows the species common name as
/// content, so that screen opts into Newsreader explicitly.
///
/// ## Font loading choice (v1)
/// Runtime fetch via `google_fonts` (package default), per `docs/brand.md`.
/// Avoids bundling `.ttf` assets in this PR. First paint may need network
/// (or a warm cache); offline after first successful fetch is fine.
/// Bundle-as-assets is a follow-up if cold-start-offline becomes required.
abstract final class AppTypography {
  static TextTheme textTheme({required Brightness brightness}) {
    final ink = brightness == Brightness.light
        ? AppColors.lightInk
        : AppColors.darkInk;
    final muted = brightness == Brightness.light
        ? AppColors.lightMutedInk
        : AppColors.darkMutedInk;

    return TextTheme(
      // Display — species common name on the detail page (below hero).
      headlineMedium: GoogleFonts.newsreader(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: ink,
      ),
      headlineSmall: GoogleFonts.newsreader(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: ink,
      ),
      // List row species names (serif content).
      titleMedium: GoogleFonts.newsreader(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ink,
      ),
      // AppBar / page titles — Public Sans chrome, not literary serif
      // (brand.md "AppBar / page title" row: 20–22 SemiBold).
      titleLarge: GoogleFonts.publicSans(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ink,
      ),
      // Section labels — family headers, "Recent sightings near you".
      // Call sites often recolor to ColorScheme.primary.
      titleSmall: GoogleFonts.publicSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.2,
        color: ink,
      ),
      // Sub-display — scientific name (italic). Detail screen already uses
      // labelMedium + FontStyle.italic; baking italic in keeps hierarchy.
      labelMedium: GoogleFonts.newsreader(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.3,
        letterSpacing: 0.4,
        color: muted,
      ),
      // UI labels — buttons, segmented control, form-ish chrome.
      labelLarge: GoogleFonts.publicSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: ink,
      ),
      labelSmall: GoogleFonts.publicSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ink,
      ),
      // Body — Wikipedia extract and other long reading.
      bodyLarge: GoogleFonts.newsreader(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: ink,
      ),
      bodyMedium: GoogleFonts.newsreader(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ink,
      ),
      // Metadata — location, relative time, counts.
      bodySmall: GoogleFonts.publicSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: muted,
      ),
    );
  }
}
