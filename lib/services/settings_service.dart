import 'package:shared_preferences/shared_preferences.dart';

/// Persists small pieces of app state (currently just the user's
/// eBird API key) to local device storage.
class SettingsService {
  static const _apiKeyPref = 'ebird_api_key';

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
}
