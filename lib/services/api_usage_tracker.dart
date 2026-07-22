import 'package:shared_preferences/shared_preferences.dart';

/// Client-side daily call counts for eBird and Xeno-canto.
///
/// Neither provider exposes a usage dashboard — this answers "how close am
/// I to the published ceiling?" during testing
/// (`docs/tickets/api-usage-counter.md`). Counts only real network
/// attempts (instrumented in [EbirdService] / [XenoCantoService]), not
/// cache hits.
class ApiUsageTracker {
  static const providerEbird = 'ebird';
  static const providerXenoCanto = 'xeno_canto';

  static const _countPrefix = 'api_usage_';
  static const _dateSuffix = '_date';
  static const _countSuffix = '_count';

  String _countKey(String provider) => '$_countPrefix$provider$_countSuffix';
  String _dateKey(String provider) => '$_countPrefix$provider$_dateSuffix';

  /// Local calendar day as `yyyy-MM-dd` (device timezone).
  String _todayStamp([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Record one outbound network attempt for [provider].
  Future<void> recordCall(String provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayStamp();
      final dateKey = _dateKey(provider);
      final countKey = _countKey(provider);

      final storedDate = prefs.getString(dateKey);
      var count = prefs.getInt(countKey) ?? 0;
      if (storedDate != today) {
        count = 0;
        await prefs.setString(dateKey, today);
      }
      await prefs.setInt(countKey, count + 1);
    } catch (_) {
      // Never break API calls if prefs are unavailable (e.g. bare unit tests).
    }
  }

  /// Today's count for [provider], resetting if the stored day has rolled.
  Future<int> todayCount(String provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayStamp();
      final dateKey = _dateKey(provider);
      final countKey = _countKey(provider);

      final storedDate = prefs.getString(dateKey);
      if (storedDate != today) return 0;
      return prefs.getInt(countKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
