import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_life_list/services/api_usage_tracker.dart';

void main() {
  late ApiUsageTracker tracker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tracker = ApiUsageTracker();
  });

  test('todayCount is 0 when unset', () async {
    expect(await tracker.todayCount(ApiUsageTracker.providerEbird), 0);
  });

  test('recordCall increments and persists', () async {
    await tracker.recordCall(ApiUsageTracker.providerEbird);
    await tracker.recordCall(ApiUsageTracker.providerEbird);
    expect(await tracker.todayCount(ApiUsageTracker.providerEbird), 2);
  });

  test('providers are counted separately', () async {
    await tracker.recordCall(ApiUsageTracker.providerEbird);
    await tracker.recordCall(ApiUsageTracker.providerXenoCanto);
    await tracker.recordCall(ApiUsageTracker.providerXenoCanto);
    expect(await tracker.todayCount(ApiUsageTracker.providerEbird), 1);
    expect(await tracker.todayCount(ApiUsageTracker.providerXenoCanto), 2);
  });

  test('count resets when stored date is not today', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_usage_ebird_date', '2000-01-01');
    await prefs.setInt('api_usage_ebird_count', 99);

    expect(await tracker.todayCount(ApiUsageTracker.providerEbird), 0);

    await tracker.recordCall(ApiUsageTracker.providerEbird);
    expect(await tracker.todayCount(ApiUsageTracker.providerEbird), 1);
  });
}
