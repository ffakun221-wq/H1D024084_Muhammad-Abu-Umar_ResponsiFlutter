import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/models/weather_model.dart';
import 'package:responsi_flutter/services/geocoding_api_service.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:responsi_flutter/services/weather_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FaultInjectedPrefs implements SharedPreferences {
  _FaultInjectedPrefs({
    this.failOnGet = false,
    this.failSetCount = 0,
  });

  final bool failOnGet;
  int failSetCount;
  final Map<String, Object> _data = <String, Object>{};

  @override
  String? getString(String key) {
    if (failOnGet) {
      throw Exception('Simulated SharedPreferences read error');
    }
    final Object? value = _data[key];
    return value is String ? value : null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (failSetCount > 0) {
      failSetCount--;
      throw Exception('Simulated transient SharedPreferences write error');
    }
    _data[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _validWeatherPayload({
  List<dynamic>? times,
  List<dynamic>? maxTemps,
  List<dynamic>? minTemps,
  List<dynamic>? probs,
}) {
  return <String, dynamic>{
    'latitude': -6.25,
    'longitude': 106.875,
    'timezone': 'Asia/Jakarta',
    'current': <String, dynamic>{
      'temperature_2m': 30.4,
      'relative_humidity_2m': 72,
      'apparent_temperature': 34.1,
      'precipitation': 1.2,
      'weather_code': 61,
      'wind_speed_10m': 11.5,
    },
    'daily': <String, dynamic>{
      'time': times ?? <dynamic>['2026-11-26'],
      'temperature_2m_max': maxTemps ?? <dynamic>[32.5],
      'temperature_2m_min': minTemps ?? <dynamic>[24.2],
      'precipitation_probability_max': probs ?? <dynamic>[80],
    },
  };
}

void main() {
  group('T5-MDL-01: Models equality, hashCode, toString, and validation', () {
    test('LocationModel equality, hashCode, toString, and non-finite rejection', () {
      const LocationModel a1 = LocationModel(
        id: 1,
        name: 'Jakarta',
        latitude: -6.2,
        longitude: 106.8,
        country: 'Indonesia',
        admin1: 'DKI Jakarta',
      );
      const LocationModel a2 = LocationModel(
        id: 1,
        name: 'Jakarta',
        latitude: -6.2,
        longitude: 106.8,
        country: 'Indonesia',
        admin1: 'DKI Jakarta',
      );
      const LocationModel b = LocationModel(
        id: 2,
        name: 'Bandung',
        latitude: -6.9,
        longitude: 107.6,
      );

      expect(a1 == a1, isTrue);
      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1 == b, isFalse);
      expect(a1 == Object(), isFalse);
      expect(a1.toString(), contains('LocationModel('));
      expect(a1.toString(), contains('Jakarta'));

      for (final num bad in <num>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => LocationModel.fromGeocodingJson(<String, dynamic>{
            'id': bad,
            'name': 'Jakarta',
            'latitude': -6.2,
            'longitude': 106.8,
          }),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => LocationModel.fromGeocodingJson(<String, dynamic>{
            'id': 1,
            'name': 'Jakarta',
            'latitude': bad,
            'longitude': 106.8,
          }),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => LocationModel.fromGeocodingJson(<String, dynamic>{
            'id': 1,
            'name': 'Jakarta',
            'latitude': -6.2,
            'longitude': bad,
          }),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('CurrentWeather, DailyForecast, WeatherModel equality, hashCode, toString', () {
      const CurrentWeather c1 = CurrentWeather(
        temperature2m: 30.0,
        relativeHumidity2m: 70,
        apparentTemperature: 33.0,
        precipitation: 0.5,
        weatherCode: 1,
        windSpeed10m: 8.0,
      );
      const CurrentWeather c2 = CurrentWeather(
        temperature2m: 30.0,
        relativeHumidity2m: 70,
        apparentTemperature: 33.0,
        precipitation: 0.5,
        weatherCode: 1,
        windSpeed10m: 8.0,
      );
      const CurrentWeather cDiff = CurrentWeather(
        temperature2m: 29.0,
        relativeHumidity2m: 70,
        apparentTemperature: 33.0,
        precipitation: 0.5,
        weatherCode: 1,
        windSpeed10m: 8.0,
      );

      expect(c1 == c1, isTrue);
      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
      expect(c1 == cDiff, isFalse);
      expect(
        c1 ==
            const CurrentWeather(
              temperature2m: 30.0,
              relativeHumidity2m: 71,
              apparentTemperature: 33.0,
              precipitation: 0.5,
              weatherCode: 1,
              windSpeed10m: 8.0,
            ),
        isFalse,
      );
      expect(
        c1 ==
            const CurrentWeather(
              temperature2m: 30.0,
              relativeHumidity2m: 70,
              apparentTemperature: 34.0,
              precipitation: 0.5,
              weatherCode: 1,
              windSpeed10m: 8.0,
            ),
        isFalse,
      );
      expect(
        c1 ==
            const CurrentWeather(
              temperature2m: 30.0,
              relativeHumidity2m: 70,
              apparentTemperature: 33.0,
              precipitation: 1.5,
              weatherCode: 1,
              windSpeed10m: 8.0,
            ),
        isFalse,
      );
      expect(
        c1 ==
            const CurrentWeather(
              temperature2m: 30.0,
              relativeHumidity2m: 70,
              apparentTemperature: 33.0,
              precipitation: 0.5,
              weatherCode: 2,
              windSpeed10m: 8.0,
            ),
        isFalse,
      );
      expect(
        c1 ==
            const CurrentWeather(
              temperature2m: 30.0,
              relativeHumidity2m: 70,
              apparentTemperature: 33.0,
              precipitation: 0.5,
              weatherCode: 1,
              windSpeed10m: 9.0,
            ),
        isFalse,
      );
      expect(c1 == Object(), isFalse);
      expect(c1.toString(), contains('CurrentWeather('));

      const DailyForecast d1 = DailyForecast(
        date: '2026-11-26',
        temperature2mMax: 33.0,
        temperature2mMin: 24.0,
        precipitationProbabilityMax: 45,
      );
      const DailyForecast d2 = DailyForecast(
        date: '2026-11-26',
        temperature2mMax: 33.0,
        temperature2mMin: 24.0,
        precipitationProbabilityMax: 45,
      );
      const DailyForecast dDiff = DailyForecast(
        date: '2026-11-27',
        temperature2mMax: 33.0,
        temperature2mMin: 24.0,
        precipitationProbabilityMax: 45,
      );

      expect(d1 == d1, isTrue);
      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1 == dDiff, isFalse);
      expect(
        d1 ==
            const DailyForecast(
              date: '2026-11-26',
              temperature2mMax: 34.0,
              temperature2mMin: 24.0,
              precipitationProbabilityMax: 45,
            ),
        isFalse,
      );
      expect(
        d1 ==
            const DailyForecast(
              date: '2026-11-26',
              temperature2mMax: 33.0,
              temperature2mMin: 23.0,
              precipitationProbabilityMax: 45,
            ),
        isFalse,
      );
      expect(
        d1 ==
            const DailyForecast(
              date: '2026-11-26',
              temperature2mMax: 33.0,
              temperature2mMin: 24.0,
              precipitationProbabilityMax: 50,
            ),
        isFalse,
      );
      expect(d1 == Object(), isFalse);
      expect(d1.toString(), contains('DailyForecast('));

      final WeatherModel w1 = WeatherModel(
        latitude: -6.2,
        longitude: 106.8,
        timezone: 'Asia/Jakarta',
        current: c1,
        daily: const <DailyForecast>[d1],
      );
      final WeatherModel w2 = WeatherModel(
        latitude: -6.2,
        longitude: 106.8,
        timezone: 'Asia/Jakarta',
        current: c2,
        daily: const <DailyForecast>[d2],
      );
      final WeatherModel wDiffDaily = WeatherModel(
        latitude: -6.2,
        longitude: 106.8,
        timezone: 'Asia/Jakarta',
        current: c1,
        daily: const <DailyForecast>[dDiff],
      );
      final WeatherModel wEmptyDaily = WeatherModel(
        latitude: -6.2,
        longitude: 106.8,
        timezone: 'Asia/Jakarta',
        current: c1,
        daily: const <DailyForecast>[],
      );

      expect(w1 == w1, isTrue);
      expect(w1, equals(w2));
      expect(w1.hashCode, equals(w2.hashCode));
      expect(w1 == wDiffDaily, isFalse);
      expect(w1 == wEmptyDaily, isFalse);
      expect(w1 == Object(), isFalse);
      expect(w1.toString(), contains('WeatherModel('));
    });

    test('WeatherModel rejects non-finite nums, non-String map keys, and malformed fields', () {
      // Dynamic map with String keys converts cleanly.
      final Map<dynamic, dynamic> dynamicStringKeyCurrent = <dynamic, dynamic>{
        'temperature_2m': 28.0,
        'relative_humidity_2m': 75,
        'apparent_temperature': 30.0,
        'precipitation': 0.0,
        'weather_code': 0,
        'wind_speed_10m': 5.0,
      };
      final Map<dynamic, dynamic> dynamicStringKeyDaily = <dynamic, dynamic>{
        'time': <dynamic>[],
        'temperature_2m_max': <dynamic>[],
        'temperature_2m_min': <dynamic>[],
        'precipitation_probability_max': <dynamic>[],
      };
      final WeatherModel emptyDaily = WeatherModel.fromJson(<String, dynamic>{
        'latitude': -6.2,
        'longitude': 106.8,
        'timezone': 'Asia/Jakarta',
        'current': dynamicStringKeyCurrent,
        'daily': dynamicStringKeyDaily,
      });
      expect(emptyDaily.daily, isEmpty);

      // Non-String map keys throw FormatException instead of _TypeError.
      expect(
        () => WeatherModel.fromJson(<String, dynamic>{
          'latitude': -6.2,
          'longitude': 106.8,
          'timezone': 'Asia/Jakarta',
          'current': <dynamic, dynamic>{1: 28.0},
          'daily': dynamicStringKeyDaily,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WeatherModel.fromJson(<String, dynamic>{
          'latitude': -6.2,
          'longitude': 106.8,
          'timezone': 'Asia/Jakarta',
          'current': dynamicStringKeyCurrent,
          'daily': <dynamic, dynamic>{1: <dynamic>[]},
        }),
        throwsA(isA<FormatException>()),
      );

      // Non-finite numbers rejected with FormatException across top-level, current, and daily.
      for (final num bad in <num>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => WeatherModel.fromJson(
            _validWeatherPayload()..['latitude'] = bad,
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => WeatherModel.fromJson(
            _validWeatherPayload()..['longitude'] = bad,
          ),
          throwsA(isA<FormatException>()),
        );
        final Map<String, dynamic> badCurrentTemp = _validWeatherPayload();
        (badCurrentTemp['current'] as Map<String, dynamic>)['temperature_2m'] =
            bad;
        expect(
          () => WeatherModel.fromJson(badCurrentTemp),
          throwsA(isA<FormatException>()),
        );

        final Map<String, dynamic> badCurrentCode = _validWeatherPayload();
        (badCurrentCode['current'] as Map<String, dynamic>)['weather_code'] =
            bad;
        expect(
          () => WeatherModel.fromJson(badCurrentCode),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => WeatherModel.fromJson(
            _validWeatherPayload(maxTemps: <dynamic>[bad]),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => WeatherModel.fromJson(
            _validWeatherPayload(minTemps: <dynamic>[bad]),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => WeatherModel.fromJson(
            _validWeatherPayload(probs: <dynamic>[bad]),
          ),
          throwsA(isA<FormatException>()),
        );
      }

      // Missing/invalid longitude, timezone, and daily element types.
      expect(
        () => WeatherModel.fromJson(
          _validWeatherPayload()..['longitude'] = 'bad',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WeatherModel.fromJson(
          _validWeatherPayload()..['timezone'] = '   ',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WeatherModel.fromJson(
          _validWeatherPayload()..['current'] = <String, dynamic>{
            'temperature_2m': 'bad',
            'relative_humidity_2m': 70,
            'apparent_temperature': 30,
            'precipitation': 0,
            'weather_code': 0,
            'wind_speed_10m': 5,
          },
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WeatherModel.fromJson(
          _validWeatherPayload()..['current'] = <String, dynamic>{
            'temperature_2m': 28,
            'relative_humidity_2m': 'bad',
            'apparent_temperature': 30,
            'precipitation': 0,
            'weather_code': 0,
            'wind_speed_10m': 5,
          },
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WeatherModel.fromJson(
          _validWeatherPayload(times: <dynamic>['']),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WeatherModel.fromJson(
          _validWeatherPayload(maxTemps: <dynamic>['bad']),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WeatherModel.fromJson(
          _validWeatherPayload(minTemps: <dynamic>['bad']),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => WeatherModel.fromJson(
          _validWeatherPayload(probs: <dynamic>['bad']),
        ),
        throwsA(isA<FormatException>()),
      );
      final Map<String, dynamic> badDailyArrays = _validWeatherPayload();
      (badDailyArrays['daily'] as Map<String, dynamic>)['time'] = 'not_a_list';
      expect(
        () => WeatherModel.fromJson(badDailyArrays),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('T5-SVC-01: WeatherApiService & GeocodingApiService edges & lifecycle', () {
    test('default constructors create owned client and dispose closes cleanly', () {
      final WeatherApiService weatherService = WeatherApiService();
      final GeocodingApiService geocodingService = GeocodingApiService();
      expect(weatherService.dispose, returnsNormally);
      expect(geocodingService.dispose, returnsNormally);
    });

    test('WeatherApiService handles non-Map roots, empty body, Latin-1 fallback, and error without reason', () async {
      for (final String body in <String>['[]', 'null', '123', '']) {
        final WeatherApiService service = WeatherApiService(
          client: MockClient((http.Request _) async => http.Response(body, 200)),
        );
        await expectLater(
          service.fetchWeather(latitude: -6.2, longitude: 106.8),
          throwsA(isA<FormatException>()),
        );
      }

      final WeatherApiService errorNoReason = WeatherApiService(
        client: MockClient(
          (http.Request _) async =>
              http.Response(jsonEncode(<String, dynamic>{'error': true}), 200),
        ),
      );
      await expectLater(
        errorNoReason.fetchWeather(latitude: -6.2, longitude: 106.8),
        throwsA(isA<Exception>()),
      );

      // Latin-1 encoded body (0xE3 = 'ã' in Latin-1, invalid UTF-8 sequence).
      final String latin1Json = jsonEncode(
        _validWeatherPayload()..['timezone'] = 'America/São_Paulo',
      );
      final List<int> latin1Bytes = latin1.encode(latin1Json);
      final WeatherApiService latin1Service = WeatherApiService(
        client: MockClient(
          (http.Request _) async => http.Response.bytes(
            latin1Bytes,
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=latin1',
            },
          ),
        ),
      );
      final WeatherModel parsed = await latin1Service.fetchWeather(
        latitude: -23.5,
        longitude: -46.6,
      );
      expect(parsed.timezone, equals('America/São_Paulo'));
    });

    test('GeocodingApiService handles non-Map roots, Latin-1 fallback, error flag, malformed results, and special chars', () async {
      for (final String body in <String>['[]', 'null', '123', '']) {
        final GeocodingApiService service = GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response(body, 200)),
        );
        await expectLater(
          service.searchCities('Jakarta'),
          throwsA(isA<FormatException>()),
        );
      }

      final GeocodingApiService errorWithReason = GeocodingApiService(
        client: MockClient(
          (http.Request _) async => http.Response(
            jsonEncode(<String, dynamic>{'error': true, 'reason': 'Bad query'}),
            200,
          ),
        ),
      );
      await expectLater(
        errorWithReason.searchCities('Jakarta'),
        throwsA(
          isA<Exception>().having(
            (Exception e) => e.toString(),
            'message',
            contains('Bad query'),
          ),
        ),
      );

      final GeocodingApiService errorNoReason = GeocodingApiService(
        client: MockClient(
          (http.Request _) async =>
              http.Response(jsonEncode(<String, dynamic>{'error': true}), 200),
        ),
      );
      await expectLater(
        errorNoReason.searchCities('Jakarta'),
        throwsA(isA<Exception>()),
      );

      final GeocodingApiService badResultsType = GeocodingApiService(
        client: MockClient(
          (http.Request _) async =>
              http.Response('{"results": "not_a_list"}', 200),
        ),
      );
      await expectLater(
        badResultsType.searchCities('Jakarta'),
        throwsA(isA<FormatException>()),
      );

      final GeocodingApiService badResultItem = GeocodingApiService(
        client: MockClient(
          (http.Request _) async => http.Response('{"results": [123]}', 200),
        ),
      );
      await expectLater(
        badResultItem.searchCities('Jakarta'),
        throwsA(isA<FormatException>()),
      );

      // Latin-1 bytes + special characters query encoding.
      late Uri capturedUri;
      final String latin1Payload = jsonEncode(<String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3448439,
            'name': 'São Paulo',
            'latitude': -23.5475,
            'longitude': -46.6361,
            'country': 'Brazil',
          },
        ],
      });
      final List<int> latin1Bytes = latin1.encode(latin1Payload);
      final GeocodingApiService specialService = GeocodingApiService(
        client: MockClient((http.Request request) async {
          capturedUri = request.url;
          return http.Response.bytes(
            latin1Bytes,
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=latin1',
            },
          );
        }),
      );

      const String specialQuery = 'São Paulo & a=1#b?c=100%';
      final List<LocationModel> results = await specialService.searchCities(
        specialQuery,
      );
      expect(capturedUri.queryParameters['name'], equals(specialQuery));
      expect(results.single.name, equals('São Paulo'));
    });
  });

  group('T5-SVC-02: LocalStorageService corruption, concurrency, and error recovery', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('getFavorites returns empty list when favoritesKey JSON root is a Map instead of List', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.favoritesKey: '{"not":"a list"}',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      expect(await storage.getFavorites(), isEmpty);
    });

    test('getters recover safely when SharedPreferences throws on read', () async {
      final LocalStorageService storage = LocalStorageService(
        _FaultInjectedPrefs(failOnGet: true),
      );

      expect(await storage.getFavorites(), isEmpty);
      expect(await storage.getSearchHistory(), isEmpty);
      expect(await storage.getSelectedLocation(), isNull);
    });

    test('concurrent addSearchHistory preserves all entries via serialized write queue', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);

      await Future.wait(<Future<void>>[
        storage.addSearchHistory('Jakarta'),
        storage.addSearchHistory('Bandung'),
        storage.addSearchHistory('Surabaya'),
      ]);

      final List<String> history = await storage.getSearchHistory();
      expect(history, hasLength(3));
      expect(history, containsAll(<String>['Jakarta', 'Bandung', 'Surabaya']));
    });

    test('concurrent saveFavorite and removeFavorite preserve consistent state', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      const LocationModel jakarta = LocationModel(
        id: 1,
        name: 'Jakarta',
        latitude: -6.2,
        longitude: 106.8,
      );
      const LocationModel bandung = LocationModel(
        id: 2,
        name: 'Bandung',
        latitude: -6.9,
        longitude: 107.6,
      );
      const LocationModel surabaya = LocationModel(
        id: 3,
        name: 'Surabaya',
        latitude: -7.25,
        longitude: 112.75,
      );

      await Future.wait(<Future<void>>[
        storage.saveFavorite(jakarta),
        storage.saveFavorite(bandung),
        storage.saveFavorite(surabaya),
        storage.removeFavorite(bandung.id),
      ]);

      final List<LocationModel> favorites = await storage.getFavorites();
      expect(
        favorites.map((LocationModel l) => l.id).toSet(),
        equals(<int>{1, 3}),
      );
    });

    test('write queue recovers cleanly after a transient write failure', () async {
      final _FaultInjectedPrefs prefs = _FaultInjectedPrefs(failSetCount: 1);
      final LocalStorageService storage = LocalStorageService(prefs);

      await expectLater(
        storage.addSearchHistory('Jakarta'),
        throwsA(isA<Exception>()),
      );
      await storage.addSearchHistory('Bandung');
      expect(await storage.getSearchHistory(), equals(<String>['Bandung']));
    });
  });
}
