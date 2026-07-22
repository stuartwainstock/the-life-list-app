import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Display preference for distances — storage and eBird API stay in km.
enum DistanceUnit {
  kilometers,
  miles;

  static const milesPerKm = 0.621371192;

  /// Label for a radius stored as whole kilometers.
  String formatRadiusKm(int km) {
    switch (this) {
      case DistanceUnit.kilometers:
        return '$km km';
      case DistanceUnit.miles:
        final mi = km * milesPerKm;
        final text = mi >= 10 ? mi.round().toString() : mi.toStringAsFixed(1);
        return '$text mi';
    }
  }

  /// Min–max hint for the sightings radius slider (display units only).
  String radiusRangeHint({
    required int minKm,
    required int maxKm,
  }) {
    switch (this) {
      case DistanceUnit.kilometers:
        return '$minKm–$maxKm km';
      case DistanceUnit.miles:
        final minMi = minKm * milesPerKm;
        final maxMi = maxKm * milesPerKm;
        return '${minMi.toStringAsFixed(1)}–${maxMi.round()} mi';
    }
  }
}

/// On-device settings: eBird API key, appearance, distance units, and
/// sightings/hotspots filters (search radii + lookback days).
///
/// ## Why not .env / dart-define for the key?
/// Keys are per-user and must never ship in the repo or binary. The user
/// pastes theirs in Settings; we store it in SharedPreferences only.
/// (App Store path later: backend proxy — then this key UI goes away.)
class SettingsService {
  static const _apiKeyPref = 'ebird_api_key';
  static const _themeModePref = 'theme_mode';
  static const _distanceUnitPref = 'distance_unit';
  static const _sightingsRadiusKmPref = 'sightings_radius_km';
  static const _sightingsBackDaysPref = 'sightings_back_days';
  static const _hotspotsRadiusKmPref = 'hotspots_radius_km';

  /// First-launch default for nearby sightings (see radius-toggle ticket).
  static const defaultSightingsRadiusKm = 7;
  static const minSightingsRadiusKm = 1;
  static const maxSightingsRadiusKm = 20;

  /// How far back to request sightings (eBird `back` param; API max 30).
  static const defaultSightingsBackDays = 7;
  static const minSightingsBackDays = 1;
  static const maxSightingsBackDays = 30;

  /// Nearby hotspots search radius — separate from sightings (broader browse).
  /// Default 20 km ≈ prior hardcoded 25, within the shared 1–20 slider range.
  static const defaultHotspotsRadiusKm = 20;
  static const minHotspotsRadiusKm = 1;
  static const maxHotspotsRadiusKm = 20;

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

  /// Display unit for distances. Defaults to [DistanceUnit.kilometers].
  /// Radius storage and eBird `dist` stay in km regardless.
  Future<DistanceUnit> getDistanceUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return distanceUnitFromStorage(prefs.getString(_distanceUnitPref));
  }

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_distanceUnitPref, distanceUnitToStorage(unit));
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

  /// Nearby hotspots search radius in whole km. Defaults to
  /// [defaultHotspotsRadiusKm]; clamped to
  /// [minHotspotsRadiusKm]–[maxHotspotsRadiusKm]. Separate from
  /// [getSightingsRadiusKm].
  Future<int> getHotspotsRadiusKm() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_hotspotsRadiusKmPref);
    if (raw == null) return defaultHotspotsRadiusKm;
    return raw.clamp(minHotspotsRadiusKm, maxHotspotsRadiusKm);
  }

  Future<void> setHotspotsRadiusKm(int km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _hotspotsRadiusKmPref,
      km.clamp(minHotspotsRadiusKm, maxHotspotsRadiusKm),
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

  static String distanceUnitToStorage(DistanceUnit unit) {
    switch (unit) {
      case DistanceUnit.miles:
        return 'miles';
      case DistanceUnit.kilometers:
        return 'kilometers';
    }
  }

  static DistanceUnit distanceUnitFromStorage(String? raw) {
    switch (raw) {
      case 'miles':
        return DistanceUnit.miles;
      case 'kilometers':
      default:
        return DistanceUnit.kilometers;
    }
  }
}
