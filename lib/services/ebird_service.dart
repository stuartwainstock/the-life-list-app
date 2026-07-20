import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/observation.dart';
import '../models/hotspot.dart';

/// Thin client for eBird API 2.0.
///
/// Docs: https://documenter.getpostman.com/view/664302/S1ENwy59
/// Keygen: https://ebird.org/api/keygen
///
/// ## Auth model
/// Every request sends `X-eBirdApiToken` with the **user's** personal key.
/// We do not embed a shared key. For App Store scale we'll need a backend
/// proxy that holds server secrets and rate-limits callers.
///
/// ## Web / CORS
/// eBird often omits CORS headers. Mobile builds call api.ebird.org
/// directly. Chrome/web testing can override [_baseUrl] via:
/// `--dart-define=EBIRD_BASE_URL=http://localhost:3000/v2`
/// paired with `tools/cors_proxy.js`.
///
/// Observation endpoints do **not** include family/order — that lives in
/// the separate taxonomy reference (see [EbirdTaxonomyService]).
class EbirdService {
  /// Defaults to eBird directly. Override at build/run time for web
  /// testing if eBird's API blocks browser CORS requests, e.g.:
  ///   flutter run -d chrome --dart-define=EBIRD_BASE_URL=http://localhost:3000/v2
  /// (see tools/cors_proxy.js). Android/iOS builds never need this override.
  static const _baseUrl = String.fromEnvironment(
    'EBIRD_BASE_URL',
    defaultValue: 'https://api.ebird.org/v2',
  );

  final String apiKey;

  EbirdService(this.apiKey);

  Map<String, String> get _headers => {'X-eBirdApiToken': apiKey};

  /// Recent sightings of all species within [distKm] of (lat, lng).
  /// distKm max is 50 per the eBird API.
  Future<List<Observation>> nearbyObservations({
    required double lat,
    required double lng,
    int distKm = 25,
    int back = 7,
  }) async {
    final uri = Uri.parse('$_baseUrl/data/obs/geo/recent').replace(
      queryParameters: {
        'lat': lat.toStringAsFixed(4),
        'lng': lng.toStringAsFixed(4),
        'dist': '$distKm',
        'back': '$back',
      },
    );
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => Observation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Recent notable / rare sightings near (lat, lng).
  Future<List<Observation>> nearbyNotableObservations({
    required double lat,
    required double lng,
    int distKm = 25,
    int back = 14,
  }) async {
    final uri = Uri.parse('$_baseUrl/data/obs/geo/recent/notable').replace(
      queryParameters: {
        'lat': lat.toStringAsFixed(4),
        'lng': lng.toStringAsFixed(4),
        'dist': '$distKm',
        'back': '$back',
      },
    );
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => Observation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Recent sightings of one species (by eBird species code) near (lat, lng).
  Future<List<Observation>> nearbyObservationsForSpecies({
    required String speciesCode,
    required double lat,
    required double lng,
    int distKm = 50,
    int back = 30,
  }) async {
    final uri =
        Uri.parse('$_baseUrl/data/obs/geo/recent/$speciesCode').replace(
      queryParameters: {
        'lat': lat.toStringAsFixed(4),
        'lng': lng.toStringAsFixed(4),
        'dist': '$distKm',
        'back': '$back',
      },
    );
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => Observation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Birding hotspots near (lat, lng).
  Future<List<Hotspot>> nearbyHotspots({
    required double lat,
    required double lng,
    int distKm = 25,
  }) async {
    final uri = Uri.parse('$_baseUrl/ref/hotspot/geo').replace(
      queryParameters: {
        'lat': lat.toStringAsFixed(4),
        'lng': lng.toStringAsFixed(4),
        'dist': '$distKm',
        'fmt': 'json',
      },
    );
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Hotspot.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw EbirdApiException(
          'eBird rejected your API key. Double-check it in Settings.');
    }
    if (res.statusCode != 200) {
      throw EbirdApiException(
          'eBird API error (${res.statusCode}). Please try again.');
    }
  }
}

class EbirdApiException implements Exception {
  final String message;
  EbirdApiException(this.message);
  @override
  String toString() => message;
}
