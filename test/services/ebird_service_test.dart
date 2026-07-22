import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:the_life_list/services/ebird_service.dart';

const _sampleObservation = {
  'speciesCode': 'amecro',
  'comName': 'American Crow',
  'sciName': 'Corvus brachyrhynchos',
  'locId': 'L123',
  'locName': 'Test Park',
  'obsDt': '2026-07-01 08:00',
  'howMany': 2,
  'lat': 41.0,
  'lng': -73.0,
  'obsValid': true,
  'locationPrivate': false,
};

const _sampleObservation2 = {
  'speciesCode': 'blujay',
  'comName': 'Blue Jay',
  'sciName': 'Cyanocitta cristata',
  'locId': 'L124',
  'locName': 'Other Park',
  'obsDt': '2026-07-02 09:00',
  'howMany': 1,
  'lat': 41.1,
  'lng': -73.1,
  'obsValid': true,
  'locationPrivate': false,
};

void main() {
  test('nearbyObservations parses a canned JSON list', () async {
    final client = MockClient((request) async {
      expect(request.headers['X-eBirdApiToken'], 'test-key');
      expect(request.url.path, contains('/data/obs/geo/recent'));
      return http.Response(
        jsonEncode([_sampleObservation, _sampleObservation2]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = EbirdService('test-key', httpClient: client);
    final obs = await service.nearbyObservations(lat: 41.0, lng: -73.0);

    expect(obs, hasLength(2));
    expect(obs.first.speciesCode, 'amecro');
    expect(obs.last.comName, 'Blue Jay');
  });

  test('nearbyNotableObservations parses canned JSON', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('/notable'));
      return http.Response(
        jsonEncode([_sampleObservation]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = EbirdService('k', httpClient: client);
    final obs = await service.nearbyNotableObservations(lat: 1, lng: 2);
    expect(obs, hasLength(1));
  });

  test('nearbyObservationsForSpecies parses canned JSON', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('/amecro'));
      return http.Response(
        jsonEncode([_sampleObservation]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = EbirdService('k', httpClient: client);
    final obs = await service.nearbyObservationsForSpecies(
      speciesCode: 'amecro',
      lat: 1,
      lng: 2,
    );
    expect(obs, hasLength(1));
    expect(obs.single.speciesCode, 'amecro');
  });

  test('recentObservationsAtLocation parses canned JSON', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('/data/obs/L999/recent'));
      return http.Response(
        jsonEncode([_sampleObservation, _sampleObservation2]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = EbirdService('k', httpClient: client);
    final obs = await service.recentObservationsAtLocation(locId: 'L999');
    expect(obs, hasLength(2));
  });

  test('hotspotSpeciesList returns raw code strings', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('/product/spplist/'));
      return http.Response(
        jsonEncode(['amecro', 'blujay', 'norcar']),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = EbirdService('k', httpClient: client);
    final codes = await service.hotspotSpeciesList(locId: 'L1');
    expect(codes, ['amecro', 'blujay', 'norcar']);
  });

  test('sends X-eBirdApiToken from constructor apiKey', () async {
    String? seenToken;
    final client = MockClient((request) async {
      seenToken = request.headers['X-eBirdApiToken'];
      return http.Response('[]', 200);
    });

    final service = EbirdService('my-secret-key', httpClient: client);
    await service.nearbyObservations(lat: 0, lng: 0);
    expect(seenToken, 'my-secret-key');
  });

  group('_checkStatus / auth errors', () {
    for (final status in [401, 403]) {
      test('$status throws key-rejected message', () async {
        final client = MockClient(
          (_) async => http.Response('unauthorized', status),
        );
        final service = EbirdService('bad', httpClient: client);

        expect(
          () => service.nearbyObservations(lat: 0, lng: 0),
          throwsA(
            isA<EbirdApiException>().having(
              (e) => e.message,
              'message',
              contains('Double-check it in Settings'),
            ),
          ),
        );
      });
    }

    test('non-200 other status throws generic message', () async {
      final client = MockClient(
        (_) async => http.Response('oops', 500),
      );
      final service = EbirdService('k', httpClient: client);

      expect(
        () => service.nearbyObservations(lat: 0, lng: 0),
        throwsA(
          isA<EbirdApiException>().having(
            (e) => e.message,
            'message',
            contains('eBird API error (500)'),
          ),
        ),
      );
    });
  });
}
