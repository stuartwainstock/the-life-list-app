import 'dart:convert';

import 'package:http/http.dart' as http;

// Conditional import: dart:io File I/O on mobile/desktop; no-op stub on web
// (web has no durable documents path that matches our disk-cache design).
import 'taxonomy_cache_stub.dart'
    if (dart.library.io) 'taxonomy_cache_io.dart' as cache_store;

/// Compact taxonomy row for family-grouping **and** species search.
///
/// Sourced from `GET /v2/ref/taxonomy/ebird?fmt=json`. We keep names plus
/// family/order — enough for sticky headers and local substring search
/// without storing the full eBird species record.
class TaxonomyEntry {
  final String speciesCode;
  final String comName;
  final String sciName;
  final String familyComName;
  final int taxonOrder;

  const TaxonomyEntry({
    required this.speciesCode,
    required this.comName,
    required this.sciName,
    required this.familyComName,
    required this.taxonOrder,
  });

  Map<String, dynamic> toJson() => {
        'speciesCode': speciesCode,
        'comName': comName,
        'sciName': sciName,
        'familyComName': familyComName,
        'taxonOrder': taxonOrder,
      };

  factory TaxonomyEntry.fromJson(Map<String, dynamic> json) {
    return TaxonomyEntry(
      speciesCode: json['speciesCode'] as String? ?? '',
      comName: json['comName'] as String? ?? '',
      sciName: json['sciName'] as String? ?? '',
      familyComName: json['familyComName'] as String? ?? 'Other',
      taxonOrder: (json['taxonOrder'] as num?)?.toInt() ?? 999999,
    );
  }
}

/// Fetches + caches eBird's full taxonomy so we can group sightings by family
/// and search species by name.
///
/// ## Why a separate service
/// Nearby-observation payloads don't include `familyComName` / `taxonOrder`.
/// Those fields only exist on the taxonomy reference endpoint (~tens of
/// thousands of rows). Fetching that on every list load would be wasteful
/// and slow on cellular, so we cache aggressively.
///
/// ## Cache policy
/// - **Disk JSON** under app documents (`path_provider`), **not**
///   SharedPreferences — prefs aren't meant for multi‑MB blobs.
/// - Freshness: 30 days (`fetchedAt` in the file). Stale cache is still
///   preferred over failing open with no grouping.
/// - **Web:** session memory only (see taxonomy_cache_stub.dart).
/// - [getLookup] never throws to UI callers — return `null` and let the
///   sightings screen fall back to a flat list.
///
/// ## Filter
/// We keep `category == "species"` only. Subspecies / hybrids / spuhs in
/// observation data that don't match land in the UI's "Other" bucket.
///
/// ## Cache version
/// `ebird_taxonomy_v2.json` — bumped when [TaxonomyEntry] gained
/// `comName`/`sciName` for search so v1 disk files aren't read incomplete.
class EbirdTaxonomyService {
  static const _baseUrl = String.fromEnvironment(
    'EBIRD_BASE_URL',
    defaultValue: 'https://api.ebird.org/v2',
  );

  static const _cacheFileName = 'ebird_taxonomy_v2.json';
  static const _maxAge = Duration(days: 30);

  /// In-memory session cache so we don't re-parse the file every reopen.
  static Map<String, TaxonomyEntry>? _memory;
  static DateTime? _memoryFetchedAt;

  /// speciesCode → taxonomy. `null` means "ungrouped fallback."
  Future<Map<String, TaxonomyEntry>?> getLookup(String apiKey) async {
    if (_memory != null &&
        _memoryFetchedAt != null &&
        DateTime.now().difference(_memoryFetchedAt!) < _maxAge) {
      return _memory;
    }

    final cached = await _readCache();
    if (cached != null) {
      final age = DateTime.now().difference(cached.fetchedAt);
      if (age < _maxAge) {
        _memory = cached.entries;
        _memoryFetchedAt = cached.fetchedAt;
        return cached.entries;
      }
    }

    try {
      final fresh = await _fetch(apiKey);
      await _writeCache(fresh);
      _memory = fresh.entries;
      _memoryFetchedAt = fresh.fetchedAt;
      return fresh.entries;
    } catch (_) {
      // Prefer stale disk over nothing (offline after a previous success).
      if (cached != null) {
        _memory = cached.entries;
        _memoryFetchedAt = cached.fetchedAt;
        return cached.entries;
      }
      return null;
    }
  }

  /// Case-insensitive substring match on **common name only**.
  ///
  /// Scientific epithets share roots across unrelated genera (e.g.
  /// "pileatus"), so matching `sciName` made results noisy — see
  /// `docs/tickets/species-search-common-name-only.md`. `sciName` remains
  /// on [TaxonomyEntry] for display and detail navigation.
  ///
  /// Results are sorted by common name and capped so a one-letter query
  /// doesn't dump thousands of rows into a ListView.
  static List<TaxonomyEntry> search(
    Map<String, TaxonomyEntry> lookup,
    String query, {
    int limit = 75,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final hits = <TaxonomyEntry>[];
    for (final entry in lookup.values) {
      if (entry.comName.toLowerCase().contains(q)) {
        hits.add(entry);
      }
    }
    hits.sort((a, b) => a.comName.compareTo(b.comName));
    if (hits.length <= limit) return hits;
    return hits.sublist(0, limit);
  }

  Future<_TaxonomyCache> _fetch(String apiKey) async {
    final uri = Uri.parse('$_baseUrl/ref/taxonomy/ebird').replace(
      queryParameters: {'fmt': 'json'},
    );
    final res = await http.get(
      uri,
      headers: {'X-eBirdApiToken': apiKey},
    );
    if (res.statusCode != 200) {
      throw StateError('Taxonomy fetch failed (${res.statusCode})');
    }

    final list = jsonDecode(res.body) as List;
    final entries = <String, TaxonomyEntry>{};
    for (final raw in list) {
      final map = raw as Map<String, dynamic>;
      if (map['category'] != 'species') continue;
      final code = map['speciesCode'] as String?;
      if (code == null || code.isEmpty) continue;
      final family = (map['familyComName'] as String?)?.trim();
      entries[code] = TaxonomyEntry(
        speciesCode: code,
        comName: (map['comName'] as String?)?.trim() ?? '',
        sciName: (map['sciName'] as String?)?.trim() ?? '',
        familyComName: (family == null || family.isEmpty) ? 'Other' : family,
        taxonOrder: (map['taxonOrder'] as num?)?.toInt() ?? 999999,
      );
    }

    return _TaxonomyCache(
      fetchedAt: DateTime.now().toUtc(),
      entries: entries,
    );
  }

  Future<_TaxonomyCache?> _readCache() async {
    try {
      final path = await _cachePath();
      if (path == null) return null;
      final raw = await cache_store.readTaxonomyCacheFile(path);
      if (raw == null) return null;
      return _TaxonomyCache.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(_TaxonomyCache cache) async {
    try {
      final path = await _cachePath();
      if (path == null) return;
      await cache_store.writeTaxonomyCacheFile(path, jsonEncode(cache.toJson()));
    } catch (_) {
      // Disk write is best-effort; memory cache still covers the session.
    }
  }

  Future<String?> _cachePath() async {
    final dir = await cache_store.taxonomyDocumentsPath();
    if (dir == null) return null;
    return '$dir/$_cacheFileName';
  }
}

class _TaxonomyCache {
  final DateTime fetchedAt;
  final Map<String, TaxonomyEntry> entries;

  _TaxonomyCache({required this.fetchedAt, required this.entries});

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'entries': entries.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory _TaxonomyCache.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as Map<String, dynamic>? ?? {};
    return _TaxonomyCache(
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entries: rawEntries.map(
        (k, v) {
          final map = Map<String, dynamic>.from(v as Map);
          // Older/partial rows may omit speciesCode — fall back to map key.
          map.putIfAbsent('speciesCode', () => k);
          return MapEntry(k, TaxonomyEntry.fromJson(map));
        },
      ),
    );
  }
}
