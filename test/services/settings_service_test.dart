import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_life_list/services/settings_service.dart';

void main() {
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
  });

  group('radius and lookback defaults / clamping', () {
    test('unset getters return documented defaults', () async {
      expect(
        await settings.getSightingsRadiusKm(),
        SettingsService.defaultSightingsRadiusKm,
      );
      expect(
        await settings.getSightingsBackDays(),
        SettingsService.defaultSightingsBackDays,
      );
      expect(
        await settings.getHotspotsRadiusKm(),
        SettingsService.defaultHotspotsRadiusKm,
      );
    });

    test('getSightingsRadiusKm clamps out-of-range stored values', () async {
      SharedPreferences.setMockInitialValues({'sightings_radius_km': 999});
      expect(
        await settings.getSightingsRadiusKm(),
        SettingsService.maxSightingsRadiusKm,
      );

      SharedPreferences.setMockInitialValues({'sightings_radius_km': 0});
      expect(
        await settings.getSightingsRadiusKm(),
        SettingsService.minSightingsRadiusKm,
      );
    });

    test('getHotspotsRadiusKm clamps out-of-range stored values', () async {
      SharedPreferences.setMockInitialValues({'hotspots_radius_km': 999});
      expect(
        await settings.getHotspotsRadiusKm(),
        SettingsService.maxHotspotsRadiusKm,
      );
    });

    test('getSightingsBackDays clamps out-of-range stored values', () async {
      SharedPreferences.setMockInitialValues({'sightings_back_days': 999});
      expect(
        await settings.getSightingsBackDays(),
        SettingsService.maxSightingsBackDays,
      );
    });

    test('setters clamp on write', () async {
      await settings.setSightingsRadiusKm(999);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('sightings_radius_km'),
        SettingsService.maxSightingsRadiusKm,
      );

      await settings.setSightingsRadiusKm(0);
      expect(
        prefs.getInt('sightings_radius_km'),
        SettingsService.minSightingsRadiusKm,
      );

      await settings.setHotspotsRadiusKm(999);
      expect(
        prefs.getInt('hotspots_radius_km'),
        SettingsService.maxHotspotsRadiusKm,
      );

      await settings.setSightingsBackDays(0);
      expect(
        prefs.getInt('sightings_back_days'),
        SettingsService.minSightingsBackDays,
      );
    });
  });

  group('API key', () {
    test('set/get/clear round-trip and trim whitespace', () async {
      expect(await settings.getApiKey(), isNull);

      await settings.setApiKey('  test-key-123  ');
      expect(await settings.getApiKey(), 'test-key-123');

      await settings.clearApiKey();
      expect(await settings.getApiKey(), isNull);
    });
  });

  group('themeMode storage helpers', () {
    test('round-trip every ThemeMode', () {
      for (final mode in ThemeMode.values) {
        final stored = SettingsService.themeModeToStorage(mode);
        expect(SettingsService.themeModeFromStorage(stored), mode);
      }
    });

    test('fromStorage falls back to system on null or garbage', () {
      expect(SettingsService.themeModeFromStorage(null), ThemeMode.system);
      expect(SettingsService.themeModeFromStorage('nope'), ThemeMode.system);
    });
  });

  group('distanceUnit storage helpers', () {
    test('round-trip every DistanceUnit', () {
      for (final unit in DistanceUnit.values) {
        final stored = SettingsService.distanceUnitToStorage(unit);
        expect(SettingsService.distanceUnitFromStorage(stored), unit);
      }
    });

    test('fromStorage falls back to kilometers on null or garbage', () {
      expect(
        SettingsService.distanceUnitFromStorage(null),
        DistanceUnit.kilometers,
      );
      expect(
        SettingsService.distanceUnitFromStorage('furlongs'),
        DistanceUnit.kilometers,
      );
    });
  });

  group('DistanceUnit display helpers', () {
    test('formatRadiusKm kilometers is passthrough', () {
      expect(DistanceUnit.kilometers.formatRadiusKm(7), '7 km');
    });

    test('formatRadiusKm miles: one decimal under 10, whole number at ≥10', () {
      // 7 km ≈ 4.3 mi
      expect(DistanceUnit.miles.formatRadiusKm(7), '4.3 mi');
      // 16 km ≈ 9.9 mi — still under 10, one decimal
      expect(DistanceUnit.miles.formatRadiusKm(16), '9.9 mi');
      // 20 km ≈ 12.4 → rounds to 12
      expect(DistanceUnit.miles.formatRadiusKm(20), '12 mi');
    });

    test('radiusRangeHint spot-check', () {
      expect(
        DistanceUnit.kilometers.radiusRangeHint(minKm: 1, maxKm: 20),
        '1–20 km',
      );
      expect(
        DistanceUnit.miles.radiusRangeHint(minKm: 1, maxKm: 20),
        '0.6–12 mi',
      );
    });
  });
}
