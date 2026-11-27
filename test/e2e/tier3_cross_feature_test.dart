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
  group('Tier 3 — Cross-Feature Pairwise Combinations (All 10 Pairs)', () {
    testWidgets(
      'T3-01 [F2+F1+F3]: search -> select -> fetch -> persist -> reopen auto-loads city',
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
              temperature2m: 31.0,
            ),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Yogyakarta');
        await selectSearchResult(tester, yogyakartaLocation.id);

        expect(find.textContaining('Yogyakarta'), findsWidgets);
        expect(findDisplayedNumber('31'), findsWidgets);

        router.clearRequests();
        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );

        expect(router.weatherRequests, hasLength(1));
        expectValidWeatherGetRequest(
          router.weatherRequests.single,
          expectedLat: yogyakartaLocation.latitude,
          expectedLon: yogyakartaLocation.longitude,
        );
        expect(find.textContaining('Yogyakarta'), findsWidgets);
        expect(findDisplayedNumber('31'), findsWidgets);
      },
    );

    testWidgets(
      'T3-02 [F3+F2+F1]: favorite toggle -> restart -> tap favorite -> loads live weather',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(bandungLocation),
            ]),
            200,
          ),
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: bandungLocation.latitude,
              longitude: bandungLocation.longitude,
              temperature2m: 25.0,
            ),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Bandung');
        await toggleFavoriteForResult(tester, bandungLocation.id);

        router.clearRequests();
        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );

        await openSearchScreen(tester);
        expect(router.geocodingRequests, isEmpty);
        await selectFavoriteItem(tester, bandungLocation.id);

        expect(find.textContaining('Bandung'), findsWidgets);
        expect(findDisplayedNumber('25'), findsWidgets);
        expectValidWeatherGetRequest(
          router.weatherRequests.last,
          expectedLat: bandungLocation.latitude,
          expectedLon: bandungLocation.longitude,
        );
      },
    );

    testWidgets(
      'T3-03 [F4+F2+F1]: failed Home weather -> open search -> select healthy city -> recovers',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(denpasarLocation),
            ]),
            200,
          ),
          onWeather: (http.Request req) async {
            if (req.url.queryParameters['latitude'] ==
                jakartaLocation.latitude.toString()) {
              return http.Response('Forecast unavailable', 500);
            }
            return http.Response(
              weatherResponseBody(
                latitude: denpasarLocation.latitude,
                longitude: denpasarLocation.longitude,
                temperature2m: 31.0,
              ),
              200,
            );
          },
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

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Denpasar');
        await selectSearchResult(tester, denpasarLocation.id);

        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
        expect(find.textContaining('Denpasar'), findsWidgets);
        expect(findDisplayedNumber('31'), findsWidgets);
      },
    );

    testWidgets(
      'T3-04 [F2+F4]: rapid consecutive searches suppress stale slower response',
      (WidgetTester tester) async {
        final Completer<http.Response> slowJakarta = Completer<http.Response>();
        await withCompleterCleanup(
          tester,
          <Completer<http.Response>>[slowJakarta],
          () async {
            final E2eMockHttpRouter router = E2eMockHttpRouter(
              onGeocoding: (http.Request req) {
                final String? name = req.url.queryParameters['name'];
                if (name == 'Jakarta') {
                  return slowJakarta.future;
                }
                return Future<http.Response>.value(
                  http.Response(
                    geocodingResponseBody(<Map<String, dynamic>>[
                      locationModelToGeocodingMap(surabayaLocation),
                    ]),
                    200,
                  ),
                );
              },
            );

            await pumpWeatherApp(tester, httpClient: router.client);
            await openSearchScreen(tester);

            await submitCitySearch(tester, 'Jakarta', settle: false);
            await submitCitySearch(tester, 'Surabaya');

            expect(
              find.byKey(Key('search_result_item_${surabayaLocation.id}')),
              findsOneWidget,
            );

            slowJakarta.complete(
              http.Response(
                geocodingResponseBody(<Map<String, dynamic>>[
                  locationModelToGeocodingMap(jakartaLocation),
                ]),
                200,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.byKey(Key('search_result_item_${surabayaLocation.id}')),
              findsOneWidget,
            );
            expect(
              find.byKey(Key('search_result_item_${jakartaLocation.id}')),
              findsNothing,
            );
          },
        );
      },
    );

    testWidgets(
      'T3-05 [F1+F4]: rapid consecutive location selections suppress stale weather response',
      (WidgetTester tester) async {
        final Completer<http.Response> slowJakartaWeather =
            Completer<http.Response>();
        await withCompleterCleanup(
          tester,
          <Completer<http.Response>>[slowJakartaWeather],
          () async {
            final E2eMockHttpRouter router = E2eMockHttpRouter(
              onGeocoding: (http.Request req) async {
                final String name = req.url.queryParameters['name'] ?? '';
                if (name == 'Jakarta') {
                  return http.Response(
                    geocodingResponseBody(<Map<String, dynamic>>[
                      locationModelToGeocodingMap(jakartaLocation),
                    ]),
                    200,
                  );
                }
                return http.Response(
                  geocodingResponseBody(<Map<String, dynamic>>[
                    locationModelToGeocodingMap(bandungLocation),
                  ]),
                  200,
                );
              },
              onWeather: (http.Request req) {
                if (req.url.queryParameters['latitude'] ==
                    jakartaLocation.latitude.toString()) {
                  return slowJakartaWeather.future;
                }
                return Future<http.Response>.value(
                  http.Response(
                    weatherResponseBody(
                      latitude: bandungLocation.latitude,
                      longitude: bandungLocation.longitude,
                      temperature2m: 26.0,
                    ),
                    200,
                  ),
                );
              },
            );

            await pumpWeatherApp(tester, httpClient: router.client);
            await openSearchScreen(tester);
            await submitCitySearch(tester, 'Jakarta');
            await selectSearchResult(tester, jakartaLocation.id, settle: false);
            for (int i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }

            await openSearchScreen(tester, settle: false);
            for (int i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            await submitCitySearch(tester, 'Bandung');
            await selectSearchResult(tester, bandungLocation.id);

            expect(find.textContaining('Bandung'), findsWidgets);
            expect(findDisplayedNumber('26'), findsWidgets);

            slowJakartaWeather.complete(
              http.Response(
                weatherResponseBody(
                  latitude: jakartaLocation.latitude,
                  longitude: jakartaLocation.longitude,
                  temperature2m: 47.0,
                ),
                200,
              ),
            );
            await tester.pumpAndSettle();

            expect(find.textContaining('Bandung'), findsWidgets);
            expect(findDisplayedNumber('26'), findsWidgets);
            expect(findDisplayedNumber('47'), findsNothing);
          },
        );
      },
    );

    testWidgets(
      'T3-06 [F3+F2]: unfavoriting one persisted favorite keeps remaining favorite across restart',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: jsonEncode(<Map<String, dynamic>>[
              medanLocation.toStorageJson(),
              soloLocation.toStorageJson(),
            ]),
          },
        );

        await openSearchScreen(tester);
        expect(
          find.byKey(Key('favorite_item_${medanLocation.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('favorite_item_${soloLocation.id}')),
          findsOneWidget,
        );

        await toggleFavoriteForResult(tester, medanLocation.id);

        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );
        await openSearchScreen(tester);

        expect(
          find.byKey(Key('favorite_item_${medanLocation.id}')),
          findsNothing,
        );
        expect(
          find.byKey(Key('favorite_item_${soloLocation.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T3-07 [F3+F1]: switching selected city updates persisted selected_location across restart',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(surabayaLocation),
            ]),
            200,
          ),
          onWeather: (http.Request req) async {
            if (req.url.queryParameters['latitude'] ==
                jakartaLocation.latitude.toString()) {
              return http.Response(
                weatherResponseBody(
                  latitude: jakartaLocation.latitude,
                  longitude: jakartaLocation.longitude,
                  temperature2m: 31.0,
                ),
                200,
              );
            }
            return http.Response(
              weatherResponseBody(
                latitude: surabayaLocation.latitude,
                longitude: surabayaLocation.longitude,
                temperature2m: 42.0,
              ),
              200,
            );
          },
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );
        expect(find.textContaining('Jakarta'), findsWidgets);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Surabaya');
        await selectSearchResult(tester, surabayaLocation.id);
        expect(find.textContaining('Surabaya'), findsWidgets);
        expect(findDisplayedNumber('42'), findsWidgets);

        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );

        expect(find.textContaining('Surabaya'), findsWidgets);
        expect(findDisplayedNumber('42'), findsWidgets);
        expect(find.textContaining('Jakarta'), findsNothing);
      },
    );

    testWidgets(
      'T3-08 [F1+F5]: all 9 weather fields render cleanly across narrow (320x568) and wide (1024x768) viewports',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(320, 568));
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: semarangLocation.latitude,
              longitude: semarangLocation.longitude,
              temperature2m: 31.0,
              relativeHumidity2m: 78,
              apparentTemperature: 35.0,
              precipitation: 4.0,
              weatherCode: 61,
              windSpeed10m: 14.0,
              dailyMax: const <double>[33, 34, 36, 37, 38, 39, 41],
              dailyMin: const <double>[24, 23, 22, 21, 19, 18, 17],
              dailyPrecipProbMax: const <int?>[65, 55, 45, 75, 85, 95, 15],
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
        expect(tester.takeException(), isNull);
        expect(findDisplayedNumber('31'), findsWidgets);
        expect(findDisplayedNumber('78'), findsWidgets);
        expect(findDisplayedNumber('35'), findsWidgets);
        expect(findDisplayedNumber('4'), findsWidgets);
        expect(findDisplayedNumber('14'), findsWidgets);

        tester.view.physicalSize = const Size(1024, 768);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(findDisplayedNumber('33'), findsWidgets);
        expect(findDisplayedNumber('24'), findsWidgets);
        expect(findDisplayedNumber('65'), findsWidgets);
      },
    );

    testWidgets(
      'T3-09 [F2+F5]: Search bar, favorites, and 10 results adapt across narrow (320x568) and wide (1024x768)',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(320, 568));
        final List<Map<String, dynamic>> tenCities =
            List<Map<String, dynamic>>.generate(
              10,
              (int i) => locationMap(
                id: 6000 + i,
                name: 'Kota Pairwise $i',
                latitude: -6.9 + i * 0.05,
                longitude: 107.6 + i * 0.05,
              ),
            );

        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async =>
              http.Response(geocodingResponseBody(tenCities), 200),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: jsonEncode(<Map<String, dynamic>>[
              jakartaLocation.toStorageJson(),
              bandungLocation.toStorageJson(),
              surabayaLocation.toStorageJson(),
            ]),
          },
        );

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Kota Pairwise');
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(1024, 768);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('search_input_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('favorite_item_${jakartaLocation.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T3-10 [F3+F5]: restart with 5 persisted favorites & 10 history items renders cleanly on wide and narrow viewports',
      (WidgetTester tester) async {
        final List<LocationModel> fiveFavs = <LocationModel>[
          jakartaLocation,
          bandungLocation,
          yogyakartaLocation,
          surabayaLocation,
          medanLocation,
        ];
        final List<String> tenHistory = List<String>.generate(
          10,
          (int i) => 'Riwayat $i',
        );

        setViewportSize(tester, const Size(1024, 768));
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: jsonEncode(
              fiveFavs
                  .map((LocationModel l) => l.toStorageJson())
                  .toList(growable: false),
            ),
            LocalStorageService.searchHistoryKey: jsonEncode(tenHistory),
          },
        );

        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );
        await openSearchScreen(tester);
        expect(tester.takeException(), isNull);
        for (final LocationModel fav in fiveFavs) {
          expect(find.byKey(Key('favorite_item_${fav.id}')), findsOneWidget);
        }

        tester.view.physicalSize = const Size(360, 640);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T3-11 [F4+F5]: empty, loading, error, and recovered states render overflow-free on narrow and wide viewports',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(320, 568));
        final Completer<http.Response> loadingCompleter =
            Completer<http.Response>();
        await withCompleterCleanup(
          tester,
          <Completer<http.Response>>[loadingCompleter],
          () async {
            final E2eMockHttpRouter router = E2eMockHttpRouter(
              onGeocoding: (http.Request req) async => http.Response(
                geocodingResponseBody(<Map<String, dynamic>>[
                  locationModelToGeocodingMap(jakartaLocation),
                ]),
                200,
              ),
            );
            router.weatherQueue.add(
              (http.Request req) => loadingCompleter.future,
            );
            router.weatherQueue.add(
              (http.Request req) async =>
                  http.Response(weatherResponseBody(), 200),
            );

            await pumpWeatherApp(tester, httpClient: router.client);
            expect(tester.takeException(), isNull);

            await openSearchScreen(tester);
            await submitCitySearch(tester, 'Jakarta');
            await selectSearchResult(tester, jakartaLocation.id, settle: false);
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(findProgressIndicators(), findsOneWidget);

            loadingCompleter.complete(http.Response('Server Error', 500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const Key('retry_weather_button')),
              findsOneWidget,
            );

            tester.view.physicalSize = const Size(1024, 768);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            await tapByKey(tester, 'retry_weather_button');
            expect(tester.takeException(), isNull);
            expect(findDisplayedNumber('31'), findsWidgets);
          },
        );
      },
    );

    testWidgets(
      'T3-12 [F3+F4]: corrupted favorites storage + initial Forecast 500 recovers cleanly on retry',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.weatherQueue.add(
          (http.Request req) async => http.Response('Error', 500),
        );
        router.weatherQueue.add(
          (http.Request req) async =>
              http.Response(weatherResponseBody(temperature2m: 31.0), 200),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: 'corrupted_json[[[',
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);

        await tapByKey(tester, 'retry_weather_button');
        expect(findDisplayedNumber('31'), findsWidgets);

        await openSearchScreen(tester);
        expect(findFavoriteItems(), findsNothing);
      },
    );

    testWidgets(
      'T3-13 [F1+F2+F4]: Search HTTP 500 error does not corrupt already-loaded Home city state',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: jakartaLocation.latitude,
              longitude: jakartaLocation.longitude,
              temperature2m: 31.0,
            ),
            200,
          ),
          onGeocoding: (http.Request req) async =>
              http.Response('Geocoding failed', 500),
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
        expect(find.textContaining('Jakarta'), findsWidgets);
        expect(findDisplayedNumber('31'), findsWidgets);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'ErrorCity');
        expect(find.byKey(const Key('retry_search_button')), findsOneWidget);

        await navigateBackToHome(tester);

        expect(find.textContaining('Jakarta'), findsWidgets);
        expect(findDisplayedNumber('31'), findsWidgets);
        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
      },
    );

    testWidgets(
      'T3-14 [F2+F3+F4]: Search succeeds, records history, selected weather fails 500 -> retry loads without re-searching',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(bogorLocation),
            ]),
            200,
          ),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response('Error', 500),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: bogorLocation.latitude,
              longitude: bogorLocation.longitude,
              temperature2m: 25.0,
            ),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Bogor');
        await selectSearchResult(tester, bogorLocation.id);

        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);
        expect(
          await LocalStorageService(prefs).getSearchHistory(),
          contains('Bogor'),
        );
        expect(
          (await LocalStorageService(prefs).getSelectedLocation())?.id,
          equals(bogorLocation.id),
        );

        final int geocodingCountBeforeRetry = router.geocodingRequests.length;
        await tapByKey(tester, 'retry_weather_button');

        expect(router.geocodingRequests.length, equals(geocodingCountBeforeRetry));
        expect(find.textContaining('Bogor'), findsWidgets);
        expect(findDisplayedNumber('25'), findsWidgets);
      },
    );

    testWidgets(
      'T3-15 [F1+F3+F4]: favoriting a city on Search without selecting it leaves Home in empty state',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(malangLocation),
            ]),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Malang');
        await toggleFavoriteForResult(tester, malangLocation.id);
        await navigateBackToHome(tester);

        expect(router.weatherRequests, isEmpty);
        expect(find.byKey(const Key('open_search_button')), findsOneWidget);
        expect(findDisplayedNumber('31'), findsNothing);
        expect(
          (await LocalStorageService(prefs).getFavorites())
              .map((LocationModel l) => l.id),
          contains(malangLocation.id),
        );
      },
    );
  });
}
