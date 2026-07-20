import 'package:flutter/material.dart';

/// Raw brand palette — single source of truth from `docs/brand.md`.
///
/// Screens should not hardcode these hex values; they should read from
/// [ThemeData.colorScheme] (wired in [AppTheme]). Keeping the named roles
/// here makes the brand doc ↔ code mapping obvious for reviewers.
abstract final class AppColors {
  // --- Light ---
  static const Color lightBackground = Color(0xFFFAF6EE);
  static const Color lightSurface = Color(0xFFF3EEE1);
  static const Color lightInk = Color(0xFF201F1C);
  static const Color lightMutedInk = Color(0xFF6B6558);
  /// Refined brand green (replaces the old ad hoc `#2E7D32` seed).
  static const Color lightAccent = Color(0xFF3A5A40);
  static const Color lightAccentTint = Color(0xFFE4EAE1);
  static const Color lightHairline = Color(0xFFDDD6C6);
  static const Color lightError = Color(0xFFA6432D);

  // --- Dark (warm invert — not pure black/white) ---
  static const Color darkBackground = Color(0xFF1C1B17);
  static const Color darkSurface = Color(0xFF252420);
  static const Color darkInk = Color(0xFFF2EEE3);
  static const Color darkMutedInk = Color(0xFFA39C8A);
  static const Color darkAccent = Color(0xFF7FA687);
  static const Color darkAccentTint = Color(0xFF2E362F);
  static const Color darkHairline = Color(0xFF3A382F);
  static const Color darkError = Color(0xFFD97B63);
}
