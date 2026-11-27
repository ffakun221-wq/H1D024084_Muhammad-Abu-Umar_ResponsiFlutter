import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responsi_flutter/models/weather_model.dart';
import 'package:responsi_flutter/services/weather_api_service.dart';

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
  final Map<String, dynamic> validPayload = <String, dynamic>{
    'latitude': -6.25,
    'longitude': 106.875,
    'timezone': 'Asia/Jakarta',
    'current': <String, dynamic>{
      'temperature_2m': 30.2,
      'relative_humidity_2m': 74,
      'apparent_temperature': 34.0,
      'precipitation': 0.0,
      'weather_code': 2,
      'wind_speed_10m': 9.4,
    },
    'daily': <String, dynamic>{
      'time': <dynamic>['2026-11-26', '2026-11-27'],
      'temperature_2m_max': <dynamic>[32.0, 31.5],
      'temperature_2m_min': <dynamic>[24.5, 24.0],
      'precipitation_probability_max': <dynamic>[40, 60],
    },
  };

  group('WeatherApiService', () {
    test('sends expected GET request with exact Open-Meteo query parameters', () async {
      late Uri capturedUri;
      late String capturedMethod;

      final MockClient client = MockClient((http.Request request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(jsonEncode(validPayload), 200);
      });

      final WeatherApiService service = WeatherApiService(client: client);
      final WeatherModel result = await service.fetchWeather(
        latitude: -6.21462,
        longitude: 106.84513,
      );

      expect(capturedMethod, equals('GET'));
      expect(capturedUri.scheme, equals('https'));
      expect(capturedUri.host, equals('api.open-meteo.com'));
      expect(capturedUri.path, equals('/v1/forecast'));
      expect(capturedUri.queryParameters['latitude'], equals('-6.21462'));
      expect(capturedUri.queryParameters['longitude'], equals('106.84513'));
      expect(capturedUri.queryParameters['timezone'], equals('auto'));
      expect(
        capturedUri.queryParameters['current'],
        equals(
          'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m',
        ),
      );
      expect(
        capturedUri.queryParameters['daily'],
        equals(
          'temperature_2m_max,temperature_2m_min,precipitation_probability_max',
        ),
      );
      expect(result.current.temperature2m, equals(30.2));
      expect(result.daily, hasLength(2));
    });

    test('throws Exception on non-200 HTTP status codes', () async {
      for (final int status in <int>[400, 404, 500]) {
        final MockClient client = MockClient(
          (http.Request request) async => http.Response('error', status),
        );
        final WeatherApiService service = WeatherApiService(client: client);

        await expectLater(
          service.fetchWeather(latitude: -6.2, longitude: 106.8),
          throwsA(isA<Exception>()),
        );
      }
    });

    test('throws Exception when API returns error flag in JSON', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'error': true,
            'reason': 'Invalid coordinates',
          }),
          200,
        ),
      );
      final WeatherApiService service = WeatherApiService(client: client);

      await expectLater(
        service.fetchWeather(latitude: 999.0, longitude: 999.0),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on malformed JSON or client network errors', () async {
      final MockClient badJsonClient = MockClient(
        (http.Request request) async => http.Response('not json', 200),
      );
      final WeatherApiService badJsonService = WeatherApiService(
        client: badJsonClient,
      );
      await expectLater(
        badJsonService.fetchWeather(latitude: -6.2, longitude: 106.8),
        throwsA(isA<FormatException>()),
      );

      final MockClient networkErrorClient = MockClient(
        (http.Request request) async => throw Exception('No network'),
      );
      final WeatherApiService errorService = WeatherApiService(
        client: networkErrorClient,
      );
      await expectLater(
        errorService.fetchWeather(latitude: -6.2, longitude: 106.8),
        throwsA(isA<Exception>()),
      );
    });

    test('throws Exception on timeout and does not close injected client', () async {
      final _TrackingMockClient client = _TrackingMockClient((
        http.Request request,
      ) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode(validPayload), 200);
      });

      final WeatherApiService service = WeatherApiService(
        client: client,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.fetchWeather(latitude: -6.2, longitude: 106.8),
        throwsA(isA<Exception>()),
      );

      service.dispose();
      expect(client.wasClosed, isFalse);
    });
  });
}
