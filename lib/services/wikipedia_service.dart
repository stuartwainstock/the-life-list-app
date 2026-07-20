import 'dart:convert';
import 'package:http/http.dart' as http;

/// Species photo + short blurb from Wikipedia's public REST API.
///
/// ## Why Wikipedia (not eBird media)
/// eBird's Macaulay Library is the gold-standard photo source but isn't
/// exposed on the public eBird API. Wikipedia's page summary endpoint is
/// free, keyless, and good enough for list thumbs + detail heroes in v1.
///
/// ## Lookup strategy
/// Prefer **scientific name** (precise) then fall back to common name
/// ("Robin" / "Redbird" style collisions are common otherwise).
///
/// ## Caching
/// In-memory for the app session, including in-flight Future dedupe so a
/// scrolling list of 40 Canada Geese doesn't fire 40 identical requests.
/// Not persisted — images are also cached by [CachedNetworkImage] on disk.
class WikipediaService {
  static final Map<String, Future<WikiSummary?>> _inflight = {};
  static final Map<String, WikiSummary?> _cache = {};

  /// Prefer scientific name (precise), fall back to common name.
  Future<WikiSummary?> fetchForSpecies({
    required String comName,
    required String sciName,
  }) async {
    if (sciName.trim().isNotEmpty) {
      final bySci = await fetchSummary(sciName.trim());
      if (bySci?.imageUrl != null || (bySci?.extract.isNotEmpty ?? false)) {
        return bySci;
      }
    }
    if (comName.trim().isEmpty) return null;
    return fetchSummary(comName.trim());
  }

  /// Thumbnail URL only — used by list rows.
  Future<String?> fetchThumbnailUrl({
    required String comName,
    required String sciName,
  }) async {
    final key = _cacheKey(comName: comName, sciName: sciName);
    final summary = await fetchForSpecies(comName: comName, sciName: sciName);
    _cache.putIfAbsent(key, () => summary);
    return summary?.imageUrl;
  }

  Future<WikiSummary?> fetchSummary(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return null;

    if (_cache.containsKey(normalized)) {
      return _cache[normalized];
    }
    return _inflight.putIfAbsent(normalized, () async {
      try {
        final uri = Uri.parse(
          'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(normalized)}',
        );
        final res = await http.get(
          uri,
          headers: const {
            // Wikipedia asks clients to identify themselves.
            'Api-User-Agent': 'TheLifeList/0.1 (personal birding app; flutter)',
          },
        );
        if (res.statusCode != 200) {
          _cache[normalized] = null;
          return null;
        }
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
        final original = json['originalimage'] as Map<String, dynamic>?;
        final summary = WikiSummary(
          extract: json['extract'] as String? ?? '',
          thumbnailUrl: thumbnail?['source'] as String?,
          originalImageUrl: original?['source'] as String?,
        );
        _cache[normalized] = summary;
        return summary;
      } catch (_) {
        _cache[normalized] = null;
        return null;
      } finally {
        _inflight.remove(normalized);
      }
    });
  }

  static String _cacheKey({required String comName, required String sciName}) {
    return '${sciName.trim().toLowerCase()}|${comName.trim().toLowerCase()}';
  }
}

class WikiSummary {
  final String extract;
  final String? thumbnailUrl;
  final String? originalImageUrl;

  WikiSummary({
    required this.extract,
    this.thumbnailUrl,
    this.originalImageUrl,
  });

  /// Best URL for list rows (small).
  String? get imageUrl => thumbnailUrl ?? originalImageUrl;

  /// Best URL for the detail hero (prefer full-resolution).
  String? get heroImageUrl => originalImageUrl ?? thumbnailUrl;
}
