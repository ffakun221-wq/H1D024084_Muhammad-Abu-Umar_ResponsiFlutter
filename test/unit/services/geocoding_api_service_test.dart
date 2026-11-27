import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/geocoding_api_service.dart';

class _TrackingMockClient extends http.BaseClient {
  _TrackingMockClient(this._handler);

  final Future<http.Response> Function(http.Request request) _handler;
  bool wasClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.Request httpRequest = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    final http.Response response = await _handler(httpRequest);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() {
    wasClosed = true;
    super.close();
  }
}

void main() {
  group('GeocodingApiService', () {
    test('sends expected GET request and parses LocationModel list', () async {
      late Uri capturedUri;
      late String capturedMethod;

      final MockClient client = MockClient((http.Request request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'results': <dynamic>[
              <String, dynamic>{
                'id': 1642911,
                'name': 'Jakarta',
                'latitude': -6.21462,
                'longitude': 106.84513,
                'country': 'Indonesia',
                'admin1': 'Jakarta Raya',
              },
            ],
          }),
          200,
        );
      });

      final GeocodingApiService service = GeocodingApiService(client: client);
      final List<LocationModel> results = await service.searchCities('  Jakarta  ');

      expect(capturedMethod, equals('GET'));
      expect(capturedUri.scheme, equals('https'));
      expect(capturedUri.host, equals('geocoding-api.open-meteo.com'));
      expect(capturedUri.path, equals('/v1/search'));
      expect(capturedUri.queryParameters['name'], equals('Jakarta'));
      expect(capturedUri.queryParameters['count'], equals('10'));
      expect(capturedUri.queryParameters['language'], equals('id'));
      expect(capturedUri.queryParameters['format'], equals('json'));

      expect(results, hasLength(1));
      expect(results.first.id, equals(1642911));
      expect(results.first.name, equals('Jakarta'));
    });

    test('returns empty list when results key is absent, null, or empty', () async {
      final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[
        <String, dynamic>{'generationtime_ms': 0.5},
        <String, dynamic>{'results': null},
        <String, dynamic>{'results': <dynamic>[]},
      ];

      for (final Map<String, dynamic> payload in payloads) {
        final MockClient client = MockClient(
          (http.Request request) async => http.Response(jsonEncode(payload), 200),
        );
        final GeocodingApiService service = GeocodingApiService(client: client);
        final List<LocationModel> results = await service.searchCities('Unknown');
        expect(results, isEmpty);
      }
    });

    test('returns empty list without HTTP calls for blank or whitespace queries', () async {
      int httpCallCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        httpCallCount++;
        return http.Response('{}', 200);
      });

      final GeocodingApiService service = GeocodingApiService(client: client);

      expect(await service.searchCities(''), isEmpty);
      expect(await service.searchCities('   \t\n  '), isEmpty);
      expect(httpCallCount, equals(0));
    });

    test('throws on non-200 HTTP responses or malformed JSON', () async {
      for (final int status in <int>[429, 500]) {
        final MockClient client = MockClient(
          (http.Request request) async => http.Response('fail', status),
        );
        final GeocodingApiService service = GeocodingApiService(client: client);

        await expectLater(
          service.searchCities('Bandung'),
          throwsA(isA<Exception>()),
        );
      }

      final MockClient badJsonClient = MockClient(
        (http.Request request) async => http.Response('invalid-json', 200),
      );
      final GeocodingApiService badService = GeocodingApiService(
        client: badJsonClient,
      );
      await expectLater(
        badService.searchCities('Bandung'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws Exception on timeout and does not close injected client', () async {
      final _TrackingMockClient client = _TrackingMockClient((
        http.Request request,
      ) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      });

      final GeocodingApiService service = GeocodingApiService(
        client: client,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.searchCities('Surabaya'),
        throwsA(isA<Exception>()),
      );

      service.dispose();
      expect(client.wasClosed, isFalse);
    });
  });
}
