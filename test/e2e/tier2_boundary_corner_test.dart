import 'dart:async';
import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'e2e_test_helpers.dart';

void main() {
  group('Tier 2 — F1: Home / Weather Screen Boundaries & Corner Cases', () {
    testWidgets(
      'T2-F1-01: renders zero and negative sub-zero temperatures accurately',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: tokyoLocation.latitude,
              longitude: tokyoLocation.longitude,
              temperature2m: -32.5,
              apparentTemperature: -40.0,
              dailyMax: const <double>[0, 1, 2, 3, 4, 5, 6],
              dailyMin: const <double>[-35, -30, -28, -26, -24, -22, -20],
              dailyPrecipProbMax: const <int?>[0, 5, 10, 15, 20, 25, 30],
            ),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              tokyoLocation.toStorageJson(),
            ),
          },
        );

        expect(findDisplayedPattern(RegExp(r'-32([.,]5)?|-33')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'-40')), findsWidgets);
        if (findVerticalScrollables().evaluate().isNotEmpty) {
          await scrollUntilTargetVisible(
            tester,
            findDisplayedPattern(RegExp(r'-35')),
          );
        }
        expect(findDisplayedPattern(RegExp(r'-35')), findsWidgets);
        expect(findDisplayedNumber('0'), findsWidgets);
      },
    );

    testWidgets(
      'T2-F1-02: renders extreme heat (49.8), 100% humidity, 0.0 precip, and 0.0 wind',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: surabayaLocation.latitude,
              longitude: surabayaLocation.longitude,
              temperature2m: 49.8,
              relativeHumidity2m: 100,
              apparentTemperature: 54.2,
              precipitation: 0.0,
              windSpeed10m: 0.0,
            ),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              surabayaLocation.toStorageJson(),
            ),
          },
        );

        expect(findDisplayedPattern(RegExp(r'49([.,]8)?|50')), findsWidgets);
        expect(findDisplayedNumber('100'), findsWidgets);
        expect(findDisplayedNumber('0'), findsWidgets);
      },
    );

    testWidgets(
      'T2-F1-03: parses integer-typed JSON fields via as num without TypeError',
      (WidgetTester tester) async {
        final String intOnlyJson = jsonEncode(<String, dynamic>{
          'latitude': -7,
          'longitude': 110,
          'timezone': 'Asia/Jakarta',
          'current': <String, dynamic>{
            'temperature_2m': 25,
            'relative_humidity_2m': 78,
            'apparent_temperature': 35,
            'precipitation': 0,
            'weather_code': 2,
            'wind_speed_10m': 14,
          },
          'daily': <String, dynamic>{
            'time': <String>['2026-11-27'],
            'temperature_2m_max': <int>[33],
            'temperature_2m_min': <int>[24],
            'precipitation_probability_max': <int>[65],
          },
        });

        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(intOnlyJson, 200),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              yogyakartaLocation.toStorageJson(),
            ),
          },
        );

        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
        expect(findDisplayedNumber('25'), findsWidgets);
        expect(findDisplayedNumber('35'), findsWidgets);
        expect(findDisplayedNumber('78'), findsWidgets);
        expect(findDisplayedNumber('14'), findsWidgets);
      },
    );

    testWidgets(
      'T2-F1-04: handles null elements inside daily.precipitation_probability_max as 0%',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              dailyMax: const <double>[33, 34, 36, 37, 38, 39, 41],
              dailyMin: const <double>[24, 23, 22, 21, 19, 18, 17],
              dailyPrecipProbMax: const <int?>[
                null,
                40,
                null,
                80,
                25,
                null,
                15,
              ],
            ),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );

        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
        expect(findDisplayedNumber('0'), findsWidgets);
        if (findVerticalScrollables().evaluate().isNotEmpty) {
          await scrollUntilTargetVisible(tester, findDisplayedNumber('41'));
        }
        expect(findDisplayedNumber('41'), findsWidgets);
        expect(findDisplayedNumber('15'), findsWidgets);
      },
    );

    testWidgets(
      'T2-F1-05: handles mismatched daily parallel array lengths safely without RangeError',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              dailyTime: const <String>[
                '2026-11-27',
                '2026-11-28',
                '2026-11-29',
                '2026-11-30',
                '2026-12-01',
                '2026-12-02',
                '2026-12-03',
              ],
              dailyMax: const <double>[33, 34, 36, 41],
              dailyMin: const <double>[24, 23, 22, 17, 16],
              dailyPrecipProbMax: const <int?>[65, 55, 45, 75, 85, 95],
            ),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              semarangLocation.toStorageJson(),
            ),
          },
        );

        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
        if (findVerticalScrollables().evaluate().isNotEmpty) {
          await scrollUntilTargetVisible(tester, findDisplayedNumber('41'));
        }
        expect(findDisplayedNumber('41'), findsWidgets);
        expect(findDisplayedNumber('95'), findsNothing);
      },
    );

    testWidgets(
      'T2-F1-06: renders safe fallback text and icon for unmapped WMO weather_code (999)',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(weatherCode: 999, temperature2m: 31.0),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );

        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
        expect(findDisplayedNumber('31'), findsWidgets);
        expect(find.byType(Icon), findsWidgets);
        expect(collectAllDisplayedTexts(tester), isNotEmpty);
      },
    );
  });

  group('Tier 2 — F2: Search / Location Screen Boundaries & Corner Cases', () {
    testWidgets(
      'T2-F2-01: whitespace-only search sends zero HTTP requests and skips search_history',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );

        await openSearchScreen(tester);
        await submitCitySearch(tester, '   \t\n  ');

        expect(router.geocodingRequests, isEmpty);
        expect(findSearchResultItems(), findsNothing);
        expect(
          await LocalStorageService(prefs).getSearchHistory(),
          isEmpty,
        );
      },
    );

    testWidgets(
      'T2-F2-02: Geocoding 200 without results key renders clean Search empty state',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async =>
              http.Response('{"generationtime_ms": 0.42}', 200),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'KotaTidakAdaZzz');

        expect(router.geocodingRequests, isNotEmpty);
        expect(findSearchResultItems(), findsNothing);
        expect(find.byKey(const Key('retry_search_button')), findsNothing);
      },
    );

    testWidgets(
      'T2-F2-03: Geocoding empty results list clears prior results and shows empty state',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.geocodingQueue.add(
          (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(bandungLocation),
            ]),
            200,
          ),
        );
        router.geocodingQueue.add(
          (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Bandung');
        expect(
          find.byKey(Key('search_result_item_${bandungLocation.id}')),
          findsOneWidget,
        );

        await submitCitySearch(tester, 'XyzEmpty999');
        expect(findSearchResultItems(), findsNothing);
        expect(find.byKey(const Key('retry_search_button')), findsNothing);
      },
    );

    testWidgets(
      'T2-F2-04: long Unicode city names render cleanly without layout overflow',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(360, 640));
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationMap(
                id: 2644032,
                name:
                    'Llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch',
                latitude: 53.2248,
                longitude: -4.2035,
                country: 'Inggris Raya',
                admin1: 'Wales',
              ),
              locationMap(
                id: 3448439,
                name: 'São Paulo',
                latitude: -23.5475,
                longitude: -46.6361,
                country: 'Brasil',
                admin1: 'São Paulo',
              ),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'São Paulo');

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('search_result_item_2644032')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('search_result_item_3448439')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2-F2-05: 10 Geocoding results with integer coordinates (0, 0) render and remain selectable',
      (WidgetTester tester) async {
        final List<Map<String, dynamic>> tenCities =
            List<Map<String, dynamic>>.generate(
              10,
              (int i) => <String, dynamic>{
                'id': 8000 + i,
                'name': 'ZeroPoint $i',
                'latitude': 0,
                'longitude': 0,
                'country': 'Samudra',
                'admin1': 'Wilayah $i',
              },
            );

        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async =>
              http.Response(geocodingResponseBody(tenCities), 200),
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(latitude: 0.0, longitude: 0.0, temperature2m: 31),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'ZeroPoint');

        await selectSearchResult(tester, 8009);
        expect(find.textContaining('ZeroPoint 9'), findsWidgets);
        expectValidWeatherGetRequest(
          router.weatherRequests.last,
          expectedLat: 0.0,
          expectedLon: 0.0,
        );
      },
    );

    testWidgets(
      'T2-F2-06: new search after HTTP 500 error clears error state and displays new results',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.geocodingQueue.add(
          (http.Request req) async => http.Response('Server Error', 500),
        );
        router.geocodingQueue.add(
          (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(bandungLocation),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'BadNet');

        expect(find.byKey(const Key('retry_search_button')), findsOneWidget);

        await submitCitySearch(tester, 'Bandung');
        expect(find.byKey(const Key('retry_search_button')), findsNothing);
        expect(
          find.byKey(Key('search_result_item_${bandungLocation.id}')),
          findsOneWidget,
        );
      },
    );
  });

  group('Tier 2 — F3: Local Storage Boundaries & Corruption Recovery', () {
    testWidgets(
      'T2-F3-01: recovers gracefully from malformed favorite_locations JSON string',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(jakartaLocation),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: '{not_valid_json',
          },
        );
        expect(tester.takeException(), isNull);

        await openSearchScreen(tester);
        expect(findFavoriteItems(), findsNothing);

        await submitCitySearch(tester, 'Jakarta');
        await toggleFavoriteForResult(tester, jakartaLocation.id);
        expect(
          find.byKey(Key('favorite_item_${jakartaLocation.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2-F3-02: preserves valid favorites while skipping corrupted items and wrong-type history',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: jsonEncode(<Object>[
              <String, dynamic>{'bad': 1},
              jakartaLocation.toStorageJson(),
            ]),
            LocalStorageService.searchHistoryKey: '{}',
          },
        );

        await openSearchScreen(tester);
        expect(findFavoriteItems(), findsOneWidget);
        expect(
          find.byKey(Key('favorite_item_${jakartaLocation.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2-F3-03: corrupted selected_location JSON falls back safely to Home empty state',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: '{"name":"Broken"}',
          },
        );

        expect(tester.takeException(), isNull);
        expect(router.weatherRequests, isEmpty);
        expect(find.byKey(const Key('open_search_button')), findsOneWidget);
        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
      },
    );

    testWidgets(
      'T2-F3-04: duplicate favorites are deduplicated by location id',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(jakartaLocation),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: jsonEncode(<Map<String, dynamic>>[
              jakartaLocation.toStorageJson(),
              jakartaLocation.toStorageJson(),
            ]),
          },
        );

        await openSearchScreen(tester);
        expect(
          find.byKey(Key('favorite_item_${jakartaLocation.id}')),
          findsOneWidget,
        );

        await toggleFavoriteForResult(tester, jakartaLocation.id);
        expect(
          find.byKey(Key('favorite_item_${jakartaLocation.id}')),
          findsNothing,
        );

        await submitCitySearch(tester, 'Jakarta');
        await toggleFavoriteForResult(tester, jakartaLocation.id);
        expect(
          find.byKey(Key('favorite_item_${jakartaLocation.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2-F3-05: search_history enforces case-insensitive deduplication and 10-item cap',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(jakartaLocation),
            ]),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        await openSearchScreen(tester);

        await submitCitySearch(tester, 'Jakarta');
        for (int i = 1; i <= 10; i++) {
          await submitCitySearch(tester, 'Kota $i');
        }
        await submitCitySearch(tester, 'jakarta');

        final List<String> history =
            await LocalStorageService(prefs).getSearchHistory();
        expect(history, hasLength(10));
        expect(history.first, equals('jakarta'));
        expect(
          history.where((String s) => s.toLowerCase() == 'jakarta'),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'T2-F3-06: corrupted search_history JSON with mixed invalid elements skips bad items safely',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.searchHistoryKey: jsonEncode(<Object?>[
              123,
              null,
              '   ',
              'Malang',
            ]),
          },
        );

        await openSearchScreen(tester);
        expect(tester.takeException(), isNull);
        expect(
          await LocalStorageService(prefs).getSearchHistory(),
          equals(<String>['Malang']),
        );
      },
    );
  });

  group('Tier 2 — F4: Networking & Error Handling Boundaries', () {
    testWidgets(
      'T2-F4-01: Weather HTTP 500 and API error=true JSON trigger error state with retry button',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.weatherQueue.add(
          (http.Request req) async => http.Response('Internal Server Error', 500),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            jsonEncode(<String, dynamic>{
              'error': true,
              'reason': 'Invalid coordinate parameters',
            }),
            200,
          ),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(temperature2m: 31.0),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );

        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);
        expect(findDisplayedNumber('31'), findsNothing);

        await tapByKey(tester, 'retry_weather_button');
        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);
        expect(findDisplayedNumber('31'), findsNothing);

        await tapByKey(tester, 'retry_weather_button');
        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
        expect(findDisplayedNumber('31'), findsWidgets);
      },
    );

    testWidgets(
      'T2-F4-02: Geocoding HTTP 500 shows retry_search_button and retry re-submits query',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.geocodingQueue.add(
          (http.Request req) async => http.Response('Error', 500),
        );
        router.geocodingQueue.add(
          (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(medanLocation),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Medan');

        expect(find.byKey(const Key('retry_search_button')), findsOneWidget);
        expect(findSearchResultItems(), findsNothing);

        await tapByKey(tester, 'retry_search_button');

        expect(router.geocodingRequests, hasLength(2));
        expectValidGeocodingGetRequest(
          router.geocodingRequests.last,
          expectedQuery: 'Medan',
        );
        expect(find.byKey(const Key('retry_search_button')), findsNothing);
        expect(
          find.byKey(Key('search_result_item_${medanLocation.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2-F4-03: http.ClientException handled gracefully on both Home and Search screens',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async =>
              throw http.ClientException('No internet connection'),
          onGeocoding: (http.Request req) async =>
              throw http.ClientException('No internet connection'),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Bandung');

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('retry_search_button')), findsOneWidget);
      },
    );

    testWidgets(
      'T2-F4-04: malformed Weather JSON body or missing objects triggers error state cleanly',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.weatherQueue.add(
          (http.Request req) async => http.Response('not valid json', 200),
        );
        router.weatherQueue.add(
          (http.Request req) async =>
              http.Response('{"latitude": -6.2, "longitude": 106.8}', 200),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);

        await tapByKey(tester, 'retry_weather_button');
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);
      },
    );

    testWidgets(
      'T2-F4-05: TimeoutException transitions to error state with retry button without hanging',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async =>
              throw TimeoutException('Request timed out'),
          onGeocoding: (http.Request req) async =>
              throw TimeoutException('Request timed out'),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );

        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);
        expect(findProgressIndicators(), findsNothing);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Surabaya');

        expect(find.byKey(const Key('retry_search_button')), findsOneWidget);
        expect(findProgressIndicators(), findsNothing);
      },
    );

    testWidgets(
      'T2-F4-06: slow API loading indicator remains visible across frames until response completes',
      (WidgetTester tester) async {
        final Completer<http.Response> completer = Completer<http.Response>();
        await withCompleterCleanup(
          tester,
          <Completer<http.Response>>[completer],
          () async {
            final E2eMockHttpRouter router = E2eMockHttpRouter(
              onWeather: (http.Request req) => completer.future,
            );

            await pumpWeatherApp(
              tester,
              httpClient: router.client,
              initialPrefs: <String, Object>{
                LocalStorageService.selectedLocationKey: jsonEncode(
                  jakartaLocation.toStorageJson(),
                ),
              },
              settle: false,
            );

            await tester.pump(const Duration(seconds: 2));
            expect(findProgressIndicators(), findsOneWidget);
            await tester.pump(const Duration(seconds: 2));
            expect(findProgressIndicators(), findsOneWidget);

            completer.complete(
              http.Response(weatherResponseBody(temperature2m: 31.0), 200),
            );
            await tester.pumpAndSettle();

            expect(findProgressIndicators(), findsNothing);
            expect(findDisplayedNumber('31'), findsWidgets);
          },
        );
      },
    );
  });

  group('Tier 2 — F5: Responsive Layout & Accessibility Boundaries', () {
    testWidgets(
      'T2-F5-01: ultra-narrow 320x568 viewport renders Home & Search without overflow',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(320, 568));
        final LocationModel longCity = const LocationModel(
          id: 7001,
          name: 'Bandar Seri Begawan Darussalam',
          latitude: 4.9403,
          longitude: 114.9481,
          country: 'Brunei Darussalam',
          admin1: 'Brunei-Muara District',
        );

        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async =>
              http.Response(weatherResponseBody(), 200),
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(longCity),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              longCity.toStorageJson(),
            ),
          },
        );
        expect(tester.takeException(), isNull);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Bandar');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T2-F5-02: layout transitions smoothly across 600px and 601px responsive breakpoint',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async =>
              http.Response(weatherResponseBody(), 200),
        );

        setViewportSize(tester, const Size(600, 800));
        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(601, 800);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Jakarta'), findsWidgets);
      },
    );

    testWidgets(
      'T2-F5-03: wide desktop (1440x900) and landscape phone (667x375) render without overflow',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async =>
              http.Response(weatherResponseBody(), 200),
        );

        setViewportSize(tester, const Size(1440, 900));
        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(667, 375);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await scrollUntilTargetVisible(
          tester,
          findDisplayedNumber('41'),
          delta: 150.0,
        );
        expect(findDisplayedNumber('41'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T2-F5-04: large accessibility text scale (1.5x) on 360x640 phone renders without overflow',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(360, 640));
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async =>
              http.Response(weatherResponseBody(), 200),
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(yogyakartaLocation),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              yogyakartaLocation.toStorageJson(),
            ),
          },
        );
        expect(tester.takeException(), isNull);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Yogyakarta');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T2-F5-05: short 360x480 viewport renders empty, loading, and error states without overflow',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(360, 480));
        final Completer<http.Response> completer = Completer<http.Response>();
        await withCompleterCleanup(
          tester,
          <Completer<http.Response>>[completer],
          () async {
            final E2eMockHttpRouter router = E2eMockHttpRouter(
              onGeocoding: (http.Request req) => completer.future,
            );

            await pumpWeatherApp(tester, httpClient: router.client);
            expect(tester.takeException(), isNull);
            expect(find.byKey(const Key('open_search_button')), findsOneWidget);

            await openSearchScreen(tester);
            await submitCitySearch(tester, 'Jakarta', settle: false);
            expect(tester.takeException(), isNull);
            expect(findProgressIndicators(), findsOneWidget);

            completer.complete(http.Response('Error', 500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const Key('retry_search_button')),
              findsOneWidget,
            );
          },
        );
      },
    );

    testWidgets(
      'T2-F5-06: narrow 320x568 Search Screen keeps favorite_toggle within viewport bounds',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(320, 568));
        final List<Map<String, dynamic>> longCities =
            List<Map<String, dynamic>>.generate(
              10,
              (int i) => locationMap(
                id: 7500 + i,
                name: 'Kota Dengan Nama Sangat Panjang Sekali $i',
                latitude: -7.0 + i * 0.1,
                longitude: 110.0 + i * 0.1,
                country: 'Indonesia',
                admin1: 'Provinsi Sangat Panjang $i',
              ),
            );

        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async =>
              http.Response(geocodingResponseBody(longCities), 200),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: jsonEncode(<Map<String, dynamic>>[
              jakartaLocation.toStorageJson(),
            ]),
          },
        );
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Kota');
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(findFavoriteToggle(7500));
        await tester.pump();
        final Rect toggleRect = tester.getRect(findFavoriteToggle(7500));
        expect(toggleRect.right, lessThanOrEqualTo(320.0));
        expect(toggleRect.left, greaterThanOrEqualTo(0.0));
      },
    );
  });
}
