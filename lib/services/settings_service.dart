import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device settings: eBird API key, appearance, and sightings filters
/// (search radius + how far back in time).
///
/// ## Why not .env / dart-define for the key?
/// Keys are per-user and must never ship in the repo or binary. The user
/// pastes theirs in Settings; we store it in SharedPreferences only.
/// (App Store path later: backend proxy — then this key UI goes away.)
class SettingsService {
  static const _apiKeyPref = 'ebird_api_key';
  static const _themeModePref = 'theme_mode';
  static const _sightingsRadiusKmPref = 'sightings_radius_km';
  static const _sightingsBackDaysPref = 'sightings_back_days';

  /// First-launch default for nearby sightings (see radius-toggle ticket).
  static const defaultSightingsRadiusKm = 7;
  static const minSightingsRadiusKm = 1;
  static const maxSightingsRadiusKm = 20;

  /// How far back to request sightings (eBird `back` param; API max 30).
  static const defaultSightingsBackDays = 7;
  static const minSightingsBackDays = 1;
  static const maxSightingsBackDays = 30;

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPref);
  }

  /// Defaults to [ThemeMode.system] when unset.
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return themeModeFromStorage(prefs.getString(_themeModePref));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePref, themeModeToStorage(mode));
  }

  /// Nearby sightings search radius in whole km. Defaults to
  /// [defaultSightingsRadiusKm] when unset; always clamped to
  /// [minSightingsRadiusKm]–[maxSightingsRadiusKm].
  Future<int> getSightingsRadiusKm() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_sightingsRadiusKmPref);
    if (raw == null) return defaultSightingsRadiusKm;
    return raw.clamp(minSightingsRadiusKm, maxSightingsRadiusKm);
  }

  Future<void> setSightingsRadiusKm(int km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _sightingsRadiusKmPref,
      km.clamp(minSightingsRadiusKm, maxSightingsRadiusKm),
    );
  }

  /// Sightings lookback in whole days (eBird `back`). Defaults to
  /// [defaultSightingsBackDays]; clamped to
  /// [minSightingsBackDays]–[maxSightingsBackDays].
  Future<int> getSightingsBackDays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_sightingsBackDaysPref);
    if (raw == null) return defaultSightingsBackDays;
    return raw.clamp(minSightingsBackDays, maxSightingsBackDays);
  }

  Future<void> setSightingsBackDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _sightingsBackDaysPref,
      days.clamp(minSightingsBackDays, maxSightingsBackDays),
    );
  }

  static String themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode themeModeFromStorage(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
