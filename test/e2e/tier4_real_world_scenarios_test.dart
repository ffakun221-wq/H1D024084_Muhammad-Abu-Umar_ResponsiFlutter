import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'e2e_test_helpers.dart';

void main() {
  group('Tier 4 — Real-World Application Scenarios', () {
    testWidgets(
      'T4-01: Yogyakarta tropical rain afternoon — cold start to persisted favorite & restart',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(yogyakartaLocation),
            ]),
            200,
          ),
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: yogyakartaLocation.latitude,
              longitude: yogyakartaLocation.longitude,
              temperature2m: 26.4,
              relativeHumidity2m: 82,
              apparentTemperature: 42.1,
              precipitation: 6.2,
              weatherCode: 63,
              windSpeed10m: 13.3,
              dailyMax: const <double>[33, 34, 35, 36, 37, 38, 39],
              dailyMin: const <double>[24, 23, 22, 21, 19, 18, 17],
              dailyPrecipProbMax: const <int?>[65, 75, 85, 90, 80, 70, 60],
            ),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        expect(find.byKey(const Key('open_search_button')), findsOneWidget);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Yogyakarta');
        expectValidGeocodingGetRequest(
          router.geocodingRequests.last,
          expectedQuery: 'Yogyakarta',
        );

        await toggleFavoriteForResult(tester, yogyakartaLocation.id);
        await selectSearchResult(tester, yogyakartaLocation.id);

        expectValidWeatherGetRequest(
          router.weatherRequests.last,
          expectedLat: yogyakartaLocation.latitude,
          expectedLon: yogyakartaLocation.longitude,
        );
        expect(find.textContaining('Yogyakarta'), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'26([.,]4)?')), findsWidgets);
        expect(findDisplayedNumber('82'), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'42([.,]1)?')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'6([.,]2)?')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'13([.,]3)?')), findsWidgets);

        if (findVerticalScrollables().evaluate().isNotEmpty) {
          await scrollUntilTargetVisible(tester, findDisplayedNumber('39'));
        }
        expect(findDisplayedNumber('39'), findsWidgets);
        expect(findDisplayedNumber('17'), findsWidgets);
        expect(findDisplayedNumber('90'), findsWidgets);

        router.clearRequests();
        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );

        expect(router.weatherRequests, hasLength(1));
        expect(find.textContaining('Yogyakarta'), findsWidgets);
        await openSearchScreen(tester);
        expect(
          find.byKey(Key('favorite_item_${yogyakartaLocation.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T4-02: Jakarta humid thunderstorm easing to rain showers on manual refresh',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(jakartaLocation),
            ]),
            200,
          ),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: jakartaLocation.latitude,
              longitude: jakartaLocation.longitude,
              temperature2m: 31.8,
              relativeHumidity2m: 85,
              apparentTemperature: 37.5,
              precipitation: 14.6,
              weatherCode: 95,
              windSpeed10m: 22.4,
              dailyMax: const <double>[29, 30, 33, 34, 35, 36, 39],
              dailyMin: const <double>[24, 23, 21, 20, 19, 18, 17],
              dailyPrecipProbMax: const <int?>[95, 85, 75, 65, 55, 45, 35],
            ),
            200,
          ),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: jakartaLocation.latitude,
              longitude: jakartaLocation.longitude,
              temperature2m: 25.3,
              relativeHumidity2m: 78,
              apparentTemperature: 33.0,
              precipitation: 6.8,
              weatherCode: 80,
              windSpeed10m: 16.0,
              dailyMax: const <double>[29, 30, 31, 32, 33, 34, 35],
              dailyMin: const <double>[24, 23, 22, 21, 19, 18, 17],
              dailyPrecipProbMax: const <int?>[75, 65, 55, 45, 35, 20, 15],
            ),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Jakarta');
        await selectSearchResult(tester, jakartaLocation.id);

        expect(find.textContaining('Jakarta'), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'31([.,]8)?|32')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'37([.,]5)?|38')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'14([.,]6)?|15')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'22([.,]4)?')), findsWidgets);

        final Set<String> stormTexts = collectAllDisplayedTexts(tester);
        final Set<IconData> stormIcons = collectAllDisplayedIcons(tester);

        await tapByKey(tester, 'refresh_weather_button');

        expect(router.weatherRequests, hasLength(2));
        expect(findDisplayedPattern(RegExp(r'25([.,]3)?')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'6([.,]8)?|7')), findsWidgets);
        expect(findDisplayedNumber('16'), findsWidgets);

        final Set<String> showerTexts = collectAllDisplayedTexts(tester);
        final Set<IconData> showerIcons = collectAllDisplayedIcons(tester);
        expect(
          showerTexts.difference(stormTexts).isNotEmpty ||
              showerIcons.difference(stormIcons).isNotEmpty,
          isTrue,
        );
      },
    );

    testWidgets(
      'T4-03: Tokyo winter clear freezing morning on 360x640 mobile viewport',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(360, 640));
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(tokyoLocation),
            ]),
            200,
          ),
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: tokyoLocation.latitude,
              longitude: tokyoLocation.longitude,
              timezone: 'Asia/Tokyo',
              temperature2m: -1.5,
              relativeHumidity2m: 35,
              apparentTemperature: -6.0,
              precipitation: 0.0,
              weatherCode: 0,
              windSpeed10m: 18.5,
              dailyMax: const <double>[5.1, 6.2, 7.3, 8.4, 9.5, 10.6, 11.7],
              dailyMin: const <double>[
                -4.2,
                -3.5,
                -5.0,
                -7.2,
                0.0,
                1.1,
                2.2,
              ],
              dailyPrecipProbMax: const <int?>[0, 0, 5, 10, 0, 0, 5],
            ),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Tokyo');
        await toggleFavoriteForResult(tester, tokyoLocation.id);
        await selectSearchResult(tester, tokyoLocation.id);

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Tokyo'), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'-1([.,]5)?|-2')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'-6([.,]0)?')), findsWidgets);
        expect(findDisplayedNumber('35'), findsWidgets);
        if (findVerticalScrollables().evaluate().isNotEmpty) {
          await scrollUntilTargetVisible(
            tester,
            findDisplayedPattern(RegExp(r'-4([.,]2)?')),
          );
        }
        expect(findDisplayedPattern(RegExp(r'-4([.,]2)?')), findsWidgets);
        expect(findDisplayedNumber('0'), findsWidgets);
      },
    );

    testWidgets(
      'T4-04: London drizzly windy tablet session with integer JSON and null daily precip prob',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(1024, 768));
        final String londonWeatherJson = jsonEncode(<String, dynamic>{
          'latitude': 51.5085,
          'longitude': -0.1257,
          'timezone': 'Europe/London',
          'current': <String, dynamic>{
            'temperature_2m': 8,
            'relative_humidity_2m': 91,
            'apparent_temperature': 4,
            'precipitation': 5,
            'weather_code': 53,
            'wind_speed_10m': 24,
          },
          'daily': <String, dynamic>{
            'time': <String>[
              '2026-11-27',
              '2026-11-28',
              '2026-11-29',
              '2026-11-30',
              '2026-12-01',
              '2026-12-02',
              '2026-12-03',
            ],
            'temperature_2m_max': <int>[10, 11, 12, 13, 14, 15, 16],
            'temperature_2m_min': <int>[9, 7, 7, 7, 7, 7, 6],
            'precipitation_probability_max': <int?>[
              75,
              60,
              null,
              80,
              50,
              40,
              35,
            ],
          },
        });

        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(londonLocation),
            ]),
            200,
          ),
          onWeather: (http.Request req) async =>
              http.Response(londonWeatherJson, 200),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'London');
        await selectSearchResult(tester, londonLocation.id);

        expect(tester.takeException(), isNull);
        expect(find.textContaining('London'), findsWidgets);
        expect(findDisplayedNumber('8'), findsWidgets);
        expect(findDisplayedNumber('91'), findsWidgets);
        expect(findDisplayedNumber('4'), findsWidgets);
        expect(findDisplayedNumber('5'), findsWidgets);
        expect(findDisplayedNumber('24'), findsWidgets);

        if (findVerticalScrollables().evaluate().isNotEmpty) {
          await scrollUntilTargetVisible(tester, findDisplayedNumber('80'));
        }
        expect(findDisplayedNumber('0'), findsWidgets);
        expect(findDisplayedNumber('80'), findsWidgets);

        if (findVerticalScrollables().evaluate().isNotEmpty) {
          await scrollUntilTargetVisible(tester, findDisplayedNumber('16'));
        }
        expect(findDisplayedNumber('16'), findsWidgets);
        expect(findDisplayedNumber('6'), findsWidgets);
        expect(findDisplayedNumber('35'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T4-05: multi-city traveler offline boot recovery and favorite-driven city switch',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.weatherQueue.add(
          (http.Request req) async => throw http.ClientException('Offline'),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: jakartaLocation.latitude,
              longitude: jakartaLocation.longitude,
              temperature2m: 32.0,
              weatherCode: 1,
            ),
            200,
          ),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: bandungLocation.latitude,
              longitude: bandungLocation.longitude,
              temperature2m: 24.1,
              weatherCode: 2,
              dailyMin: const <double>[19, 18, 17, 16, 15, 14, 13],
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
            LocalStorageService.favoritesKey: jsonEncode(<Map<String, dynamic>>[
              jakartaLocation.toStorageJson(),
              bandungLocation.toStorageJson(),
            ]),
          },
        );

        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);

        await tapByKey(tester, 'retry_weather_button');
        expect(find.textContaining('Jakarta'), findsWidgets);
        expect(findDisplayedNumber('32'), findsWidgets);

        await openSearchScreen(tester);
        await selectFavoriteItem(tester, bandungLocation.id);

        expect(router.geocodingRequests, isEmpty);
        expect(find.textContaining('Bandung'), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'24([.,]1)?')), findsWidgets);
      },
    );

    testWidgets(
      'T4-06: typo search recovery, history persistence, and favorite cleanup across restart',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async {
            if (req.url.queryParameters['name'] == 'Surabyaa') {
              return http.Response('{"generationtime_ms": 0.5}', 200);
            }
            return http.Response(
              geocodingResponseBody(<Map<String, dynamic>>[
                locationModelToGeocodingMap(surabayaLocation),
              ]),
              200,
            );
          },
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: surabayaLocation.latitude,
              longitude: surabayaLocation.longitude,
              temperature2m: 42.0,
            ),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        await openSearchScreen(tester);

        await submitCitySearch(tester, 'Surabyaa');
        expect(findSearchResultItems(), findsNothing);
        expect(find.byKey(const Key('retry_search_button')), findsNothing);

        await submitCitySearch(tester, 'Surabaya');
        await toggleFavoriteForResult(tester, surabayaLocation.id);
        await selectSearchResult(tester, surabayaLocation.id);

        expect(find.textContaining('Surabaya'), findsWidgets);
        expect(findDisplayedNumber('42'), findsWidgets);

        await openSearchScreen(tester);
        expect(
          find.byKey(Key('favorite_item_${surabayaLocation.id}')),
          findsOneWidget,
        );
        await toggleFavoriteForResult(tester, surabayaLocation.id);
        expect(
          find.byKey(Key('favorite_item_${surabayaLocation.id}')),
          findsNothing,
        );

        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );
        expect(find.textContaining('Surabaya'), findsWidgets);

        await openSearchScreen(tester);
        expect(findFavoriteItems(), findsNothing);
        expect(
          await LocalStorageService(prefs).getSearchHistory(),
          equals(<String>['Surabaya', 'Surabyaa']),
        );
      },
    );
  });
}
