import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembled [ThemeData] for light and dark — wired from brand tokens.
///
/// Explicit [ColorScheme] (not `colorSchemeSeed`) so we get the restrained
/// paper/ink palette from `docs/brand.md` rather than a generated Material
/// tonal palette from a single green.
abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        ink: AppColors.lightInk,
        mutedInk: AppColors.lightMutedInk,
        accent: AppColors.lightAccent,
        accentTint: AppColors.lightAccentTint,
        hairline: AppColors.lightHairline,
        error: AppColors.lightError,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        ink: AppColors.darkInk,
        mutedInk: AppColors.darkMutedInk,
        accent: AppColors.darkAccent,
        accentTint: AppColors.darkAccentTint,
        hairline: AppColors.darkHairline,
        error: AppColors.darkError,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color ink,
    required Color mutedInk,
    required Color accent,
    required Color accentTint,
    required Color hairline,
    required Color error,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: brightness == Brightness.light
          ? AppColors.lightBackground
          : AppColors.darkBackground,
      primaryContainer: accentTint,
      onPrimaryContainer: ink,
      secondary: accent,
      onSecondary: brightness == Brightness.light
          ? AppColors.lightBackground
          : AppColors.darkBackground,
      secondaryContainer: accentTint,
      onSecondaryContainer: ink,
      tertiary: accent,
      onTertiary: brightness == Brightness.light
          ? AppColors.lightBackground
          : AppColors.darkBackground,
      error: error,
      onError: brightness == Brightness.light
          ? AppColors.lightBackground
          : AppColors.darkInk,
      surface: background,
      onSurface: ink,
      onSurfaceVariant: mutedInk,
      // Subtle separation surface (badges, sticky headers) — prefer hairlines
      // for most separation (brand surface philosophy; follow-up ticket).
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      outline: mutedInk,
      outlineVariant: hairline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: ink,
      onInverseSurface: background,
      inversePrimary: accentTint,
    );

    final textTheme = AppTypography.textTheme(brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: hairline,
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: AppStroke.hairline,
        space: AppStroke.hairline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: accentTint,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: brightness == Brightness.light
            ? AppColors.lightBackground
            : AppColors.darkBackground,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: hairline, width: AppStroke.hairline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accentTint,
        labelStyle: textTheme.labelLarge,
        side: BorderSide(color: hairline),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentTint;
            return background;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return mutedInk;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: hairline, width: AppStroke.hairline),
          ),
        ),
      ),
    );
  }
}
