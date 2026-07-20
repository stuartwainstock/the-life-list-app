import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device settings: eBird API key + appearance preference.
///
/// ## Why not .env / dart-define for the key?
/// Keys are per-user and must never ship in the repo or binary. The user
/// pastes theirs in Settings; we store it in SharedPreferences only.
/// (App Store path later: backend proxy — then this key UI goes away.)
class SettingsService {
  static const _apiKeyPref = 'ebird_api_key';
  static const _themeModePref = 'theme_mode';

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
