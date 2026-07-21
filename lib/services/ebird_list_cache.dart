import 'dart:convert';

import '../models/hotspot.dart';
import '../models/observation.dart';
import 'list_cache_stub.dart'
    if (dart.library.io) 'list_cache_io.dart' as cache_store;

/// Disk cache for nearby sightings + hotspots (stale-while-revalidate).
///
/// ## Why a separate service
/// [EbirdService] stays a pure network client. Screens read cache first,
/// paint, then refresh — see `docs/tickets/offline-caching.md`.
///
/// ## Keys
/// Files are keyed by call kind + lat/lng (3 decimal places ≈ 110m) +
/// distKm so a 7km Boston cache isn't served for a 20km query or a
/// different city. A parallel "last success" file lets screens paint
/// before GPS resolves when the stored radius still matches.
///
/// ## Web
/// Session has no durable disk cache (stub); behavior falls back to
/// network-only like before this ticket.
class EbirdListCache {
  static const _subdir = 'ebird_list_cache';
  static const _coordDecimals = 3;
  static const _lastSightingsFile = 'last_sightings.json';
  static const _lastHotspotsFile = 'last_hotspots.json';

  /// Param-keyed observation list (all-species or notable).
  Future<CachedObservations?> readObservations({
    required bool notable,
    required double lat,
    required double lng,
    required int distKm,
  }) async {
    final path = await _keyedPath(
      kind: notable ? 'obs_notable' : 'obs_all',
      lat: lat,
      lng: lng,
      distKm: distKm,
    );
    if (path == null) return null;
    return _readObservationsFile(path);
  }

  Future<void> writeObservations({
    required bool notable,
    required double lat,
    required double lng,
    required int distKm,
    required List<Observation> items,
    DateTime? fetchedAt,
  }) async {
    final path = await _keyedPath(
      kind: notable ? 'obs_notable' : 'obs_all',
      lat: lat,
      lng: lng,
      distKm: distKm,
    );
    if (path == null) return;
    await _writeObservationsFile(
      path,
      CachedObservations(
        fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
        lat: lat,
        lng: lng,
        distKm: distKm,
        items: items,
      ),
    );
  }

  Future<CachedHotspots?> readHotspots({
    required double lat,
    required double lng,
    required int distKm,
  }) async {
    final path = await _keyedPath(
      kind: 'hotspots',
      lat: lat,
      lng: lng,
      distKm: distKm,
    );
    if (path == null) return null;
    return _readHotspotsFile(path);
  }

  Future<void> writeHotspots({
    required double lat,
    required double lng,
    required int distKm,
    required List<Hotspot> items,
    DateTime? fetchedAt,
  }) async {
    final path = await _keyedPath(
      kind: 'hotspots',
      lat: lat,
      lng: lng,
      distKm: distKm,
    );
    if (path == null) return;
    await _writeHotspotsFile(
      path,
      CachedHotspots(
        fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
        lat: lat,
        lng: lng,
        distKm: distKm,
        items: items,
      ),
    );
  }

  /// Most recent successful sightings pair (any location), for instant paint.
  Future<CachedSightingsBundle?> readLastSightings() async {
    final dir = await _cacheDir();
    if (dir == null) return null;
    try {
      final raw =
          await cache_store.readListCacheFile('$dir/$_lastSightingsFile');
      if (raw == null) return null;
      return CachedSightingsBundle.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeLastSightings(CachedSightingsBundle bundle) async {
    final dir = await _cacheDir();
    if (dir == null) return;
    try {
      await cache_store.writeListCacheFile(
        '$dir/$_lastSightingsFile',
        jsonEncode(bundle.toJson()),
      );
    } catch (_) {}
  }

  Future<CachedHotspots?> readLastHotspots() async {
    final dir = await _cacheDir();
    if (dir == null) return null;
    try {
      final raw =
          await cache_store.readListCacheFile('$dir/$_lastHotspotsFile');
      if (raw == null) return null;
      return CachedHotspots.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeLastHotspots(CachedHotspots bundle) async {
    final dir = await _cacheDir();
    if (dir == null) return;
    try {
      await cache_store.writeListCacheFile(
        '$dir/$_lastHotspotsFile',
        jsonEncode(bundle.toJson()),
      );
    } catch (_) {}
  }

  Future<String?> _cacheDir() async {
    final root = await cache_store.listCacheDocumentsPath();
    if (root == null) return null;
    return '$root/$_subdir';
  }

  Future<String?> _keyedPath({
    required String kind,
    required double lat,
    required double lng,
    required int distKm,
  }) async {
    final dir = await _cacheDir();
    if (dir == null) return null;
    final latKey = lat.toStringAsFixed(_coordDecimals);
    final lngKey = lng.toStringAsFixed(_coordDecimals);
    // Sanitize for filenames (negative coords).
    final safeLat = latKey.replaceAll('-', 'm').replaceAll('.', 'p');
    final safeLng = lngKey.replaceAll('-', 'm').replaceAll('.', 'p');
    return '$dir/${kind}_${safeLat}_${safeLng}_${distKm}km.json';
  }

  Future<CachedObservations?> _readObservationsFile(String path) async {
    try {
      final raw = await cache_store.readListCacheFile(path);
      if (raw == null) return null;
      return CachedObservations.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeObservationsFile(
    String path,
    CachedObservations cache,
  ) async {
    try {
      await cache_store.writeListCacheFile(path, jsonEncode(cache.toJson()));
    } catch (_) {}
  }

  Future<CachedHotspots?> _readHotspotsFile(String path) async {
    try {
      final raw = await cache_store.readListCacheFile(path);
      if (raw == null) return null;
      return CachedHotspots.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeHotspotsFile(String path, CachedHotspots cache) async {
    try {
      await cache_store.writeListCacheFile(path, jsonEncode(cache.toJson()));
    } catch (_) {}
  }
}

class CachedObservations {
  final DateTime fetchedAt;
  final double lat;
  final double lng;
  final int distKm;
  final List<Observation> items;

  CachedObservations({
    required this.fetchedAt,
    required this.lat,
    required this.lng,
    required this.distKm,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'distKm': distKm,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory CachedObservations.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return CachedObservations(
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      distKm: (json['distKm'] as num?)?.toInt() ?? 0,
      items: rawItems
          .map((e) => Observation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// All-species + notable payloads from one successful refresh.
class CachedSightingsBundle {
  final DateTime fetchedAt;
  final double lat;
  final double lng;
  final int distKm;
  final List<Observation> all;
  final List<Observation> notable;

  CachedSightingsBundle({
    required this.fetchedAt,
    required this.lat,
    required this.lng,
    required this.distKm,
    required this.all,
    required this.notable,
  });

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'distKm': distKm,
        'all': all.map((e) => e.toJson()).toList(),
        'notable': notable.map((e) => e.toJson()).toList(),
      };

  factory CachedSightingsBundle.fromJson(Map<String, dynamic> json) {
    final rawAll = json['all'] as List? ?? const [];
    final rawNotable = json['notable'] as List? ?? const [];
    return CachedSightingsBundle(
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      distKm: (json['distKm'] as num?)?.toInt() ?? 0,
      all: rawAll
          .map((e) => Observation.fromJson(e as Map<String, dynamic>))
          .toList(),
      notable: rawNotable
          .map((e) => Observation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CachedHotspots {
  final DateTime fetchedAt;
  final double lat;
  final double lng;
  final int distKm;
  final List<Hotspot> items;

  CachedHotspots({
    required this.fetchedAt,
    required this.lat,
    required this.lng,
    required this.distKm,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'distKm': distKm,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory CachedHotspots.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return CachedHotspots(
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      distKm: (json['distKm'] as num?)?.toInt() ?? 0,
      items: rawItems
          .map((e) => Hotspot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
