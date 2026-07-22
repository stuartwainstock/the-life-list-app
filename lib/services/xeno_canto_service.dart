import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/xeno_canto_recording.dart';
import 'api_usage_tracker.dart';

/// Thin client for Xeno-canto API v3 recordings.
///
/// Docs: https://xeno-canto.org/explore/api
///
/// ## Auth
/// One app-level key injected at build time via
/// `--dart-define=XENO_CANTO_API_KEY=…` (not a per-user paste flow).
/// Empty key → all lookups return null (Songs & Calls section stays hidden).
/// For Play Store scale, move behind a backend proxy with eBird — see
/// `TASKS.md` Play Store readiness.
///
/// ## Matching
/// Query by scientific name (`gen` + `sp`), same join strategy as
/// Wikipedia thumbs. Zero results / redacted `file` = no audio, not an error
/// (`docs/tickets/xeno-canto-audio.md`).
class XenoCantoService {
  static const _baseUrl = 'https://xeno-canto.org/api/3/recordings';

  /// Build-time key — never commit a real value into source.
  static const apiKey = String.fromEnvironment('XENO_CANTO_API_KEY');

  final http.Client? _httpClient;

  XenoCantoService({http.Client? httpClient}) : _httpClient = httpClient;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// Best-quality Song and Call for [sciName], when both (or either) exist.
  Future<({XenoCantoRecording? song, XenoCantoRecording? call})>
      bestSongAndCall({required String sciName}) async {
    if (!hasApiKey) return (song: null, call: null);
    final parts = _splitBinomial(sciName);
    if (parts == null) return (song: null, call: null);

    final results = await Future.wait([
      bestRecording(genus: parts.genus, epithet: parts.epithet, soundType: 'song'),
      bestRecording(genus: parts.genus, epithet: parts.epithet, soundType: 'call'),
    ]);
    return (song: results[0], call: results[1]);
  }

  /// Top recording for [soundType] (`song` or `call`), sorted by quality A→E.
  Future<XenoCantoRecording?> bestRecording({
    required String genus,
    required String epithet,
    required String soundType,
  }) async {
    if (!hasApiKey) return null;

    final query = 'gen:"$genus" sp:"$epithet" type:$soundType';
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'query': query,
        'key': apiKey,
        'page': '1',
        // API accepts per_page; keep the page small — we only need the best.
        'per_page': '10',
      },
    );

    try {
      final res = await _get(uri);
      _checkStatus(res);
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return null;

      final list = body['recordings'];
      if (list is! List || list.isEmpty) return null;

      final parsed = <XenoCantoRecording>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final rec = XenoCantoRecording.tryParse(item);
        if (rec != null) parsed.add(rec);
      }
      if (parsed.isEmpty) return null;

      parsed.sort((a, b) => _qualityRank(a.qualityRating)
          .compareTo(_qualityRank(b.qualityRating)));
      return parsed.first;
    } catch (_) {
      // Auth / network / parse failures → no audio (don't alarm the user).
      return null;
    }
  }

  Future<http.Response> _get(Uri uri) async {
    await ApiUsageTracker().recordCall(ApiUsageTracker.providerXenoCanto);
    final client = _httpClient;
    if (client != null) return client.get(uri);
    return http.get(uri);
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw XenoCantoApiException(
        'Xeno-canto rejected the API key (${res.statusCode}).',
      );
    }
    if (res.statusCode != 200) {
      throw XenoCantoApiException(
        'Xeno-canto API error (${res.statusCode}).',
      );
    }
  }

  /// eBird species-level names are binomial; take first two tokens.
  static ({String genus, String epithet})? _splitBinomial(String sciName) {
    final parts = sciName.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final genus = parts[0];
    final epithet = parts[1];
    if (genus.isEmpty || epithet.isEmpty) return null;
    return (genus: genus, epithet: epithet);
  }

  /// A best … E worst; blank/unknown last.
  static int _qualityRank(String q) {
    switch (q.toUpperCase()) {
      case 'A':
        return 0;
      case 'B':
        return 1;
      case 'C':
        return 2;
      case 'D':
        return 3;
      case 'E':
        return 4;
      default:
        return 5;
    }
  }
}

class XenoCantoApiException implements Exception {
  final String message;
  XenoCantoApiException(this.message);
  @override
  String toString() => message;
}
