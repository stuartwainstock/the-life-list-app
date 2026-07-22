import 'dart:convert';

import 'package:http/http.dart' as http;

/// Species photo gallery + short blurb from Wikipedia / Wikimedia Commons.
///
/// ## Why Wikipedia + Commons (not eBird media)
/// eBird's Macaulay Library isn't on the public eBird API. Wikipedia's
/// summary endpoint is free/keyless for text + a lead image; Commons holds
/// richer galleries and license metadata (`Artist`, `LicenseShortName`).
/// See `docs/tickets/species-photo-attribution-and-gallery.md`.
///
/// ## Lookup strategy
/// Prefer **scientific name** for Commons `Category:…` (precise), then fall
/// back to the Wikipedia page summary for extract + a single lead image
/// when the category is empty or missing. Galleries always put the Wikipedia
/// lead photo first when available — Commons category files are noisier.
///
/// ## Caching
/// In-memory for the app session, including in-flight Future dedupe so a
/// scrolling list of 40 Canada Geese doesn't fire 40 identical requests.
/// List thumbnails use a lighter Wikipedia-only path (no attribution at
/// thumb size — hero attribution is the hard requirement).
///
/// ## Image CDN User-Agent
/// upload.wikimedia.org returns **403** for empty/missing User-Agent.
/// [CachedNetworkImage] must pass [imageRequestHeaders] or thumbs/heroes
/// fail intermittently.
class WikipediaService {
  static const _userAgent =
      'TheLifeList/0.1 (personal birding app; contact: github.com/stuartwainstock/the-life-list-app)';
  static const _maxGalleryPhotos = 6;

  /// Headers for [CachedNetworkImage] / any fetch of upload.wikimedia.org.
  static const Map<String, String> imageRequestHeaders = {
    'User-Agent': _userAgent,
    'Api-User-Agent': _userAgent,
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  static const Map<String, String> _apiHeaders = {
    'User-Agent': _userAgent,
    'Api-User-Agent': _userAgent,
  };

  static final Map<String, Future<WikiSummary?>> _inflight = {};
  static final Map<String, WikiSummary?> _cache = {};
  static final Map<String, Future<String?>> _thumbInflight = {};
  static final Map<String, String?> _thumbCache = {};

  /// Caps concurrent Wikipedia summary calls from the scrolling list.
  static int _thumbSlots = 0;
  static const _maxThumbSlots = 4;

  /// Prefer scientific name (precise), fall back to common name.
  Future<WikiSummary?> fetchForSpecies({
    required String comName,
    required String sciName,
  }) async {
    final key = _cacheKey(comName: comName, sciName: sciName);
    if (_cache.containsKey(key)) return _cache[key];
    return _inflight.putIfAbsent(key, () async {
      try {
        final summary = await _buildSpeciesSummary(
          comName: comName,
          sciName: sciName,
        );
        _cache[key] = summary;
        return summary;
      } catch (_) {
        // Don't cache hard failures — allow a later retry.
        return null;
      } finally {
        _inflight.remove(key);
      }
    });
  }

  /// Sync peek at a thumbnail already resolved this session — used to decide
  /// whether a list→detail [Hero] can fly the same bytes the user just saw
  /// (`docs/tickets/species-photo-hero-transition.md`).
  static String? peekCachedThumbnailUrl({
    required String comName,
    required String sciName,
  }) {
    return _thumbCache[_cacheKey(comName: comName, sciName: sciName)];
  }

  /// Thumbnail URL only — Wikipedia lead image (lightweight, no attribution).
  Future<String?> fetchThumbnailUrl({
    required String comName,
    required String sciName,
  }) async {
    final key = _cacheKey(comName: comName, sciName: sciName);
    if (_thumbCache.containsKey(key)) return _thumbCache[key];
    return _thumbInflight.putIfAbsent(key, () async {
      await _acquireThumbSlot();
      try {
        WikiSummary? summary;
        if (sciName.trim().isNotEmpty) {
          summary = await _fetchWikipediaSummary(sciName.trim());
        }
        if (summary?.imageUrl == null && comName.trim().isNotEmpty) {
          summary = await _fetchWikipediaSummary(comName.trim());
        }
        final url = summary?.imageUrl;
        // Only cache hits — miss/null may be rate-limit; allow retry later.
        if (url != null && url.isNotEmpty) {
          _thumbCache[key] = url;
        }
        return url;
      } catch (_) {
        return null;
      } finally {
        _releaseThumbSlot();
        _thumbInflight.remove(key);
      }
    });
  }

  static Future<void> _acquireThumbSlot() async {
    while (_thumbSlots >= _maxThumbSlots) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    _thumbSlots++;
  }

  static void _releaseThumbSlot() {
    _thumbSlots = (_thumbSlots - 1).clamp(0, _maxThumbSlots);
  }

  Future<WikiSummary?> _buildSpeciesSummary({
    required String comName,
    required String sciName,
  }) async {
    // Wikipedia extract + reliable lead photo — try sci then common.
    WikiSummary? wiki;
    if (sciName.trim().isNotEmpty) {
      wiki = await _fetchWikipediaSummary(sciName.trim());
    }
    if ((wiki == null || wiki.extract.isEmpty || wiki.photos.isEmpty) &&
        comName.trim().isNotEmpty) {
      final byCom = await _fetchWikipediaSummary(comName.trim());
      wiki = _mergeWiki(wiki, byCom);
    }

    List<SpeciesPhoto> commons = const [];
    if (sciName.trim().isNotEmpty) {
      commons = await _fetchCommonsGallery(sciName.trim());
    }

    // Wikipedia lead first (stable CDN URL), then Commons extras.
    final photos = <SpeciesPhoto>[];
    final seen = <String>{};
    void addAll(Iterable<SpeciesPhoto> list) {
      for (final p in list) {
        if (seen.add(p.imageUrl)) photos.add(p);
        if (photos.length >= _maxGalleryPhotos) break;
      }
    }

    if (wiki != null) addAll(wiki.photos);
    if (photos.length < _maxGalleryPhotos) addAll(commons);

    final extract = wiki?.extract ?? '';
    if (extract.isEmpty && photos.isEmpty) return null;

    return WikiSummary(
      extract: extract,
      photos: photos,
      sourcePageUrl: wiki?.sourcePageUrl,
    );
  }

  WikiSummary? _mergeWiki(WikiSummary? a, WikiSummary? b) {
    if (a == null) return b;
    if (b == null) return a;
    return WikiSummary(
      extract: a.extract.isNotEmpty ? a.extract : b.extract,
      photos: a.photos.isNotEmpty ? a.photos : b.photos,
      sourcePageUrl: a.sourcePageUrl ?? b.sourcePageUrl,
    );
  }

  Future<WikiSummary?> _fetchWikipediaSummary(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(normalized)}',
      );
      final res = await http.get(uri, headers: _apiHeaders);
      if (res.statusCode == 429 || res.statusCode >= 500) {
        // Transient — caller may retry; don't treat as definitive miss.
        return null;
      }
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
      final original = json['originalimage'] as Map<String, dynamic>?;
      final contentUrls = json['content_urls'] as Map<String, dynamic>?;
      final desktop = contentUrls?['desktop'] as Map<String, dynamic>?;
      final pageUrl = desktop?['page'] as String?;
      // Prefer thumbnail for list/detail paint speed; original can be huge.
      final imageUrl =
          (thumbnail?['source'] as String?) ?? (original?['source'] as String?);
      final photos = imageUrl == null
          ? const <SpeciesPhoto>[]
          : [
              SpeciesPhoto(
                imageUrl: imageUrl,
                attributionText: 'via Wikipedia',
                licenseName: null,
                sourcePageUrl: pageUrl,
              ),
            ];
      return WikiSummary(
        extract: json['extract'] as String? ?? '',
        photos: photos,
        sourcePageUrl: pageUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Commons category named after the scientific binomial, capped at
  /// [_maxGalleryPhotos]. Empty when the category is missing or empty.
  ///
  /// Categories mix photos with audio, maps, and diagrams — we request a
  /// larger member set and keep only raster photo MIME types.
  Future<List<SpeciesPhoto>> _fetchCommonsGallery(String sciName) async {
    final category = 'Category:${sciName.trim().replaceAll(' ', '_')}';
    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'categorymembers',
        'gcmtitle': category,
        'gcmtype': 'file',
        // Pull extra members so after MIME/title filtering we still fill
        // the gallery (categories often lead with .ogg / range maps).
        'gcmlimit': '40',
        'prop': 'imageinfo',
        'iiprop': 'url|mime|size|extmetadata',
        'iiurlwidth': '1280',
        'format': 'json',
        'origin': '*',
      });
      final res = await http.get(uri, headers: _apiHeaders);
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final pages = json['query']?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return const [];

      final candidates = <_CommonsCandidate>[];
      for (final page in pages.values) {
        final map = page as Map<String, dynamic>;
        if (map.containsKey('missing')) continue;
        final title = map['title'] as String? ?? '';
        if (!_looksLikeSpeciesPhoto(title)) continue;

        final infos = map['imageinfo'] as List?;
        if (infos == null || infos.isEmpty) continue;
        final info = infos.first as Map<String, dynamic>;
        final mime = (info['mime'] as String? ?? '').toLowerCase();
        if (!_isRasterPhotoMime(mime)) continue;

        final url = (info['thumburl'] as String?) ?? (info['url'] as String?);
        if (url == null || url.isEmpty) continue;
        // Commons serves a speaker PNG for audio thumbs — skip if URL still
        // points at a file-type icon asset.
        if (url.contains('file-type-icons')) continue;

        final width = (info['thumbwidth'] as num?)?.toInt() ??
            (info['width'] as num?)?.toInt() ??
            0;
        final meta = info['extmetadata'] as Map<String, dynamic>? ?? {};
        final artist = _plainText(_metaValue(meta, 'Artist'));
        final license = _plainText(_metaValue(meta, 'LicenseShortName'));
        final credit = _plainText(_metaValue(meta, 'Credit'));
        final attribution = _formatAttribution(
              artist: artist,
              credit: credit,
              license: license,
            ) ??
            'via Wikimedia Commons';
        candidates.add(
          _CommonsCandidate(
            width: width,
            photo: SpeciesPhoto(
              imageUrl: url,
              attributionText: attribution,
              licenseName: license,
              sourcePageUrl: info['descriptionurl'] as String?,
            ),
          ),
        );
      }

      // Prefer wider images (real photos over tiny icons/maps that slipped by).
      candidates.sort((a, b) => b.width.compareTo(a.width));
      return [
        for (final c in candidates.take(_maxGalleryPhotos)) c.photo,
      ];
    } catch (_) {
      return const [];
    }
  }

  static bool _isRasterPhotoMime(String mime) {
    return mime == 'image/jpeg' ||
        mime == 'image/png' ||
        mime == 'image/webp' ||
        mime == 'image/gif';
  }

  /// Drop range maps, sonograms, diagrams, etc. by file title heuristics.
  static bool _looksLikeSpeciesPhoto(String title) {
    final t = title.toLowerCase();
    const reject = [
      'map',
      'range',
      'distribution',
      'sonogram',
      'spectrogram',
      'diagram',
      'silhouette',
      'logo',
      'icon',
      'phylogen',
    ];
    for (final word in reject) {
      if (t.contains(word)) return false;
    }
    return true;
  }

  static String? _metaValue(Map<String, dynamic> meta, String key) {
    final node = meta[key];
    if (node is Map<String, dynamic>) {
      return node['value'] as String?;
    }
    return null;
  }

  static String? _plainText(String? html) {
    if (html == null) return null;
    final text = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  static String? _formatAttribution({
    String? artist,
    String? credit,
    String? license,
  }) {
    final who = artist ?? credit;
    if (who != null && license != null) return '$who · $license';
    if (who != null) return who;
    if (license != null) return license;
    return null;
  }

  static String _cacheKey({required String comName, required String sciName}) {
    return '${sciName.trim().toLowerCase()}|${comName.trim().toLowerCase()}';
  }
}

class _CommonsCandidate {
  final int width;
  final SpeciesPhoto photo;

  _CommonsCandidate({required this.width, required this.photo});
}

/// One species photo with optional Commons license metadata.
class SpeciesPhoto {
  final String imageUrl;
  final String? attributionText;
  final String? licenseName;
  final String? sourcePageUrl;

  const SpeciesPhoto({
    required this.imageUrl,
    this.attributionText,
    this.licenseName,
    this.sourcePageUrl,
  });
}

class WikiSummary {
  final String extract;
  final List<SpeciesPhoto> photos;
  final String? sourcePageUrl;

  WikiSummary({
    required this.extract,
    this.photos = const [],
    this.sourcePageUrl,
  });

  /// Best URL for list rows (small) — first gallery / lead image.
  String? get imageUrl =>
      photos.isEmpty ? null : photos.first.imageUrl;

  /// Best URL for a single-image hero when gallery chrome isn't needed.
  String? get heroImageUrl => imageUrl;
}
