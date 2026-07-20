import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches a free species photo + short summary from Wikipedia's public
/// REST API. No key required. Used as a stand-in for eBird's photo
/// library (Macaulay Library media isn't available via a public API).
///
/// Results are memoized in-memory for the app session so list views can
/// show thumbnails without re-hitting Wikipedia for the same species.
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

  /// Thumbnail URL only — used by list rows. Cached by species identity.
  Future<String?> fetchThumbnailUrl({
    required String comName,
    required String sciName,
  }) async {
    final key = _cacheKey(comName: comName, sciName: sciName);
    final summary = await fetchForSpecies(comName: comName, sciName: sciName);
    // Also stash under the composite key used by thumbnails.
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
            'Api-User-Agent': 'GoBirder/0.1 (personal birding app; flutter)',
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

  /// Best URL for list rows.
  String? get imageUrl => thumbnailUrl ?? originalImageUrl;

  /// Best URL for the detail hero — prefer the full-resolution image.
  String? get heroImageUrl => originalImageUrl ?? thumbnailUrl;
}
