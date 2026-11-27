import 'dart:async';
import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:responsi_flutter/main.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'e2e_test_helpers.dart';

void main() {
  group('Tier 1 — F1: Home / Weather Screen Data Display', () {
    testWidgets(
      'T1-F1-01: displays selected city name header on Home from saved location',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: yogyakartaLocation.latitude,
              longitude: yogyakartaLocation.longitude,
            ),
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

        expect(find.textContaining('Yogyakarta'), findsWidgets);
        expect(find.textContaining('Jakarta'), findsNothing);
        expect(router.weatherRequests, hasLength(1));
        expectValidWeatherGetRequest(
          router.weatherRequests.single,
          expectedLat: yogyakartaLocation.latitude,
          expectedLon: yogyakartaLocation.longitude,
        );
      },
    );

    testWidgets(
      'T1-F1-02: displays current temperature and differential WMO weather condition',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.weatherQueue.add((http.Request req) async {
          return http.Response(
            weatherResponseBody(
              latitude: bandungLocation.latitude,
              longitude: bandungLocation.longitude,
              temperature2m: 25.4,
              weatherCode: 1,
            ),
            200,
          );
        });
        router.weatherQueue.add((http.Request req) async {
          return http.Response(
            weatherResponseBody(
              latitude: bandungLocation.latitude,
              longitude: bandungLocation.longitude,
              temperature2m: 25.4,
              weatherCode: 95,
            ),
            200,
          );
        });

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              bandungLocation.toStorageJson(),
            ),
          },
        );

        expect(find.textContaining('Bandung'), findsWidgets);
        expect(
          findDisplayedPattern(RegExp(r'25([.,]4)?')),
          findsWidgets,
        );
        final Set<String> clearTexts = collectAllDisplayedTexts(tester);
        final Set<IconData> clearIcons = collectAllDisplayedIcons(tester);
        expect(clearIcons, isNotEmpty);

        await tapByKey(tester, 'refresh_weather_button');

        final Set<String> stormTexts = collectAllDisplayedTexts(tester);
        final Set<IconData> stormIcons = collectAllDisplayedIcons(tester);
        expect(
          stormTexts.difference(clearTexts).isNotEmpty ||
              stormIcons.difference(clearIcons).isNotEmpty,
          isTrue,
          reason:
              'Changing current.weather_code from 1 to 95 must update condition UI',
        );
      },
    );

    testWidgets(
      'T1-F1-03: displays all 6 current weather metrics from Forecast API',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: surabayaLocation.latitude,
              longitude: surabayaLocation.longitude,
              temperature2m: 33.2,
              relativeHumidity2m: 68,
              apparentTemperature: 38.4,
              precipitation: 6.7,
              weatherCode: 61,
              windSpeed10m: 14.3,
              dailyMax: const <double>[36, 37, 39, 41, 42, 43, 44],
              dailyMin: const <double>[21, 22, 23, 24, 19, 18, 17],
              dailyPrecipProbMax: const <int?>[55, 65, 75, 85, 95, 45, 50],
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

        expect(find.textContaining('Surabaya'), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'33([.,]2)?')), findsWidgets);
        expect(findDisplayedNumber('68'), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'38([.,]4)?')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'6([.,]7)?|7')), findsWidgets);
        expect(findDisplayedPattern(RegExp(r'14([.,]3)?')), findsWidgets);
        expect(find.byType(Icon), findsWidgets);
      },
    );

    testWidgets(
      'T1-F1-04: displays 7-day daily forecast with max, min, and precip probability',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: semarangLocation.latitude,
              longitude: semarangLocation.longitude,
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

        if (findVerticalScrollables().evaluate().isNotEmpty) {
          await scrollUntilTargetVisible(tester, findDisplayedNumber('41'));
        }

        expect(findDisplayedNumber('41'), findsWidgets);
        expect(findDisplayedNumber('17'), findsWidgets);
        expect(findDisplayedNumber('95'), findsWidgets);
      },
    );

    testWidgets(
      'T1-F1-05: manual refresh fetches live Forecast API and updates displayed data',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: medanLocation.latitude,
              longitude: medanLocation.longitude,
              temperature2m: 25.0,
              windSpeed10m: 14.0,
            ),
            200,
          ),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: medanLocation.latitude,
              longitude: medanLocation.longitude,
              temperature2m: 31.5,
              windSpeed10m: 26.0,
            ),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              medanLocation.toStorageJson(),
            ),
          },
        );

        expect(findDisplayedNumber('25'), findsWidgets);
        expect(router.weatherRequests, hasLength(1));

        await tapByKey(tester, 'refresh_weather_button');

        expect(router.weatherRequests, hasLength(2));
        expect(
          findDisplayedPattern(RegExp(r'31([.,]5)?|32')),
          findsWidgets,
        );
        expect(findDisplayedNumber('26'), findsWidgets);
      },
    );

    testWidgets(
      'T1-F1-06: displays thunderstorm condition and heavy rain metrics accurately',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: bogorLocation.latitude,
              longitude: bogorLocation.longitude,
              weatherCode: 95,
              precipitation: 18.5,
              dailyMin: const <double>[24, 23, 22, 21, 17, 16, 15],
              dailyPrecipProbMax: const <int?>[95, 85, 75, 65, 55, 45, 35],
            ),
            200,
          ),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: bogorLocation.latitude,
              longitude: bogorLocation.longitude,
              weatherCode: 0,
              precipitation: 18.5,
              dailyMin: const <double>[24, 23, 22, 21, 17, 16, 15],
              dailyPrecipProbMax: const <int?>[95, 85, 75, 65, 55, 45, 35],
            ),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.selectedLocationKey: jsonEncode(
              bogorLocation.toStorageJson(),
            ),
          },
        );

        expect(find.textContaining('Bogor'), findsWidgets);
        expect(
          findDisplayedPattern(RegExp(r'18([.,]5)?|19')),
          findsWidgets,
        );
        expect(findDisplayedNumber('95'), findsWidgets);
        final Set<String> stormTexts = collectAllDisplayedTexts(tester);
        final Set<IconData> stormIcons = collectAllDisplayedIcons(tester);
        expect(stormIcons, isNotEmpty);

        await tapByKey(tester, 'refresh_weather_button');
        final Set<String> clearTexts = collectAllDisplayedTexts(tester);
        final Set<IconData> clearIcons = collectAllDisplayedIcons(tester);
        expect(
          clearTexts.difference(stormTexts).isNotEmpty ||
              clearIcons.difference(stormIcons).isNotEmpty,
          isTrue,
          reason:
              'Thunderstorm weather_code 95 must render distinct condition UI vs weather_code 0',
        );
      },
    );
  });

  group('Tier 1 — F2: Search / Location Screen & Live Geocoding', () {
    testWidgets(
      'T1-F2-01: tapping open_search_button navigates from Home to LocationSearchScreen',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        await pumpWeatherApp(tester, httpClient: router.client);

        await openSearchScreen(tester);

        expect(find.byKey(const Key('search_input_field')), findsOneWidget);
        expect(find.byKey(const Key('search_submit_button')), findsOneWidget);
      },
    );

    testWidgets(
      'T1-F2-02: live Geocoding search returns single city and renders result item',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(malangLocation),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Malang');

        expect(router.geocodingRequests, isNotEmpty);
        expectValidGeocodingGetRequest(
          router.geocodingRequests.last,
          expectedQuery: 'Malang',
        );
        expect(
          find.byKey(Key('search_result_item_${malangLocation.id}')),
          findsOneWidget,
        );
        expect(find.textContaining('Malang'), findsWidgets);
      },
    );

    testWidgets(
      'T1-F2-03: live Geocoding search displays multiple homonymous cities with disambiguation',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationMap(
                id: 1650357,
                name: 'Bandung',
                latitude: -6.9222,
                longitude: 107.6069,
                country: 'Indonesia',
                admin1: 'Jawa Barat',
              ),
              locationMap(
                id: 1650358,
                name: 'Bandung',
                latitude: -8.1,
                longitude: 111.9,
                country: 'Indonesia',
                admin1: 'Jawa Timur',
              ),
              locationMap(
                id: 1650359,
                name: 'Bandung',
                latitude: -5.3,
                longitude: 105.2,
                country: 'Indonesia',
                admin1: 'Lampung',
              ),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Bandung');

        expect(
          find.byKey(const Key('search_result_item_1650357')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('search_result_item_1650358')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('search_result_item_1650359')),
          findsOneWidget,
        );
        expect(find.textContaining('Jawa Barat'), findsWidgets);
        expect(find.textContaining('Jawa Timur'), findsWidgets);
      },
    );

    testWidgets(
      'T1-F2-04: selecting search result pops to Home and fetches live weather for coordinates',
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

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Yogyakarta');
        await selectSearchResult(tester, yogyakartaLocation.id);

        expect(find.byKey(const Key('search_input_field')), findsNothing);
        expect(find.textContaining('Yogyakarta'), findsWidgets);
        expect(findDisplayedNumber('31'), findsWidgets);
        expect(router.weatherRequests, isNotEmpty);
        expectValidWeatherGetRequest(
          router.weatherRequests.last,
          expectedLat: yogyakartaLocation.latitude,
          expectedLon: yogyakartaLocation.longitude,
        );
      },
    );

    testWidgets(
      'T1-F2-05: Geocoding result with null admin1 and country renders without "null" string',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationMap(
                id: 1880252,
                name: 'Singapura',
                latitude: 1.2897,
                longitude: 103.8501,
                country: null,
                admin1: null,
                includeNullKeys: false,
              ),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Singapura');

        expect(
          find.byKey(const Key('search_result_item_1880252')),
          findsOneWidget,
        );
        expect(find.textContaining('Singapura'), findsWidgets);
        expect(find.textContaining('null'), findsNothing);
      },
    );

    testWidgets(
      'T1-F2-06: submitting city via keyboard IME action triggers live Geocoding search',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(denpasarLocation),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);

        await tester.enterText(
          find.byKey(const Key('search_input_field')),
          'Denpasar',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        if (router.geocodingRequests.isEmpty) {
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
        }
        if (router.geocodingRequests.isEmpty) {
          await tapByKey(tester, 'search_submit_button');
        }

        expect(router.geocodingRequests, isNotEmpty);
        expectValidGeocodingGetRequest(
          router.geocodingRequests.last,
          expectedQuery: 'Denpasar',
        );
        expect(
          find.byKey(Key('search_result_item_${denpasarLocation.id}')),
          findsOneWidget,
        );
      },
    );
  });

  group('Tier 1 — F3: Local Storage Persistence', () {
    testWidgets(
      'T1-F3-01: toggling favorite adds location to favorites UI and SharedPreferences',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(soloLocation),
            ]),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Surakarta');
        await toggleFavoriteForResult(tester, soloLocation.id);

        expect(
          find.byKey(Key('favorite_item_${soloLocation.id}')),
          findsOneWidget,
        );
        final List<LocationModel> saved =
            await LocalStorageService(prefs).getFavorites();
        expect(
          saved.map((LocationModel l) => l.id),
          contains(soloLocation.id),
        );
      },
    );

    testWidgets(
      'T1-F3-02: saved favorite persists across full app restart without calling Geocoding API',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(padangLocation),
            ]),
            200,
          ),
        );

        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
        );
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Padang');
        await toggleFavoriteForResult(tester, padangLocation.id);

        router.clearRequests();
        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );
        await openSearchScreen(tester);

        expect(router.geocodingRequests, isEmpty);
        expect(
          find.byKey(Key('favorite_item_${padangLocation.id}')),
          findsOneWidget,
        );
        expect(find.textContaining('Padang'), findsWidgets);
      },
    );

    testWidgets(
      'T1-F3-03: tapping persisted favorite loads live weather on Home',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: makassarLocation.latitude,
              longitude: makassarLocation.longitude,
              temperature2m: 31.0,
            ),
            200,
          ),
        );

        await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: jsonEncode(<Map<String, dynamic>>[
              makassarLocation.toStorageJson(),
            ]),
          },
        );
        await openSearchScreen(tester);
        await selectFavoriteItem(tester, makassarLocation.id);

        expect(find.textContaining('Makassar'), findsWidgets);
        expect(findDisplayedNumber('31'), findsWidgets);
        expectValidWeatherGetRequest(
          router.weatherRequests.last,
          expectedLat: makassarLocation.latitude,
          expectedLon: makassarLocation.longitude,
        );
      },
    );

    testWidgets(
      'T1-F3-04: unfavoriting removes location and persists removal across restart',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        final SharedPreferences prefs = await pumpWeatherApp(
          tester,
          httpClient: router.client,
          initialPrefs: <String, Object>{
            LocalStorageService.favoritesKey: jsonEncode(<Map<String, dynamic>>[
              bandungLocation.toStorageJson(),
            ]),
          },
        );

        await openSearchScreen(tester);
        expect(
          find.byKey(Key('favorite_item_${bandungLocation.id}')),
          findsOneWidget,
        );

        await toggleFavoriteForResult(tester, bandungLocation.id);
        expect(
          find.byKey(Key('favorite_item_${bandungLocation.id}')),
          findsNothing,
        );

        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );
        await openSearchScreen(tester);

        expect(
          find.byKey(Key('favorite_item_${bandungLocation.id}')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'T1-F3-05: last selected location automatically reloads live weather on app reopen',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(pontianakLocation),
            ]),
            200,
          ),
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: pontianakLocation.latitude,
              longitude: pontianakLocation.longitude,
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
        await submitCitySearch(tester, 'Pontianak');
        await selectSearchResult(tester, pontianakLocation.id);

        router.clearRequests();
        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );

        expect(find.textContaining('Pontianak'), findsWidgets);
        expect(findDisplayedNumber('31'), findsWidgets);
        expect(router.weatherRequests, hasLength(1));
        expectValidWeatherGetRequest(
          router.weatherRequests.single,
          expectedLat: pontianakLocation.latitude,
          expectedLon: pontianakLocation.longitude,
        );
      },
    );

    testWidgets(
      'T1-F3-06: search history is persisted in most-recent-first order across restart',
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
        await submitCitySearch(tester, 'Palembang');
        await submitCitySearch(tester, 'Balikpapan');

        await restartWeatherApp(
          tester,
          httpClient: router.client,
          sharedPreferences: prefs,
        );
        await openSearchScreen(tester);

        final List<String> persistedHistory =
            await LocalStorageService(prefs).getSearchHistory();
        expect(persistedHistory, equals(<String>['Balikpapan', 'Palembang']));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Tier 1 — F4: Networking (GET) & Loading / Empty / Error States', () {
    testWidgets(
      'T1-F4-01: Weather Forecast GET sends exact required params and excludes daily.weather_code',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: jakartaLocation.latitude,
              longitude: jakartaLocation.longitude,
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

        expect(router.weatherRequests, hasLength(1));
        expectValidWeatherGetRequest(
          router.weatherRequests.single,
          expectedLat: jakartaLocation.latitude,
          expectedLon: jakartaLocation.longitude,
        );
      },
    );

    testWidgets(
      'T1-F4-02: Geocoding GET sends exact Open-Meteo /v1/search query parameters',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onGeocoding: (http.Request req) async => http.Response(
            geocodingResponseBody(<Map<String, dynamic>>[
              locationModelToGeocodingMap(yogyakartaLocation),
            ]),
            200,
          ),
        );

        await pumpWeatherApp(tester, httpClient: router.client);
        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Yogyakarta');

        expect(router.geocodingRequests, isNotEmpty);
        expectValidGeocodingGetRequest(
          router.geocodingRequests.last,
          expectedQuery: 'Yogyakarta',
        );
      },
    );

    testWidgets(
      'T1-F4-03: displays ProgressIndicator while Weather GET is in-flight then shows data',
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
            await tester.pump();

            expect(findProgressIndicators(), findsOneWidget);

            completer.complete(
              http.Response(
                weatherResponseBody(
                  latitude: jakartaLocation.latitude,
                  longitude: jakartaLocation.longitude,
                  temperature2m: 31.0,
                ),
                200,
              ),
            );
            await tester.pumpAndSettle();

            expect(findProgressIndicators(), findsNothing);
            expect(findDisplayedNumber('31'), findsWidgets);
          },
        );
      },
    );

    testWidgets(
      'T1-F4-04: displays ProgressIndicator while Geocoding GET is in-flight then shows results',
      (WidgetTester tester) async {
        final Completer<http.Response> completer = Completer<http.Response>();
        await withCompleterCleanup(
          tester,
          <Completer<http.Response>>[completer],
          () async {
            final E2eMockHttpRouter router = E2eMockHttpRouter(
              onGeocoding: (http.Request req) => completer.future,
            );

            await pumpWeatherApp(tester, httpClient: router.client);
            await openSearchScreen(tester);
            await submitCitySearch(tester, 'Banda Aceh', settle: false);

            expect(findProgressIndicators(), findsOneWidget);

            completer.complete(
              http.Response(
                geocodingResponseBody(<Map<String, dynamic>>[
                  locationMap(
                    id: 1215502,
                    name: 'Banda Aceh',
                    latitude: 5.5483,
                    longitude: 95.3238,
                    country: 'Indonesia',
                    admin1: 'Aceh',
                  ),
                ]),
                200,
              ),
            );
            await tester.pumpAndSettle();

            expect(findProgressIndicators(), findsNothing);
            expect(
              find.byKey(const Key('search_result_item_1215502')),
              findsOneWidget,
            );
          },
        );
      },
    );

    testWidgets(
      'T1-F4-05: cold start with empty storage shows empty state with 0 HTTP calls and no hardcoded data',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();

        await pumpWeatherApp(tester, httpClient: router.client);

        expect(router.recordedRequests, isEmpty);
        expect(find.byKey(const Key('open_search_button')), findsOneWidget);
        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
        expect(findDisplayedNumber('31'), findsNothing);
      },
    );

    testWidgets(
      'T1-F4-06: Weather HTTP 503 shows retry_weather_button and recovers on retry',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        router.weatherQueue.add(
          (http.Request req) async => http.Response('Service Unavailable', 503),
        );
        router.weatherQueue.add(
          (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: jakartaLocation.latitude,
              longitude: jakartaLocation.longitude,
              temperature2m: 31.0,
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

        expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);
        expect(findDisplayedNumber('31'), findsNothing);

        await tapByKey(tester, 'retry_weather_button');

        expect(router.weatherRequests, hasLength(2));
        expect(find.byKey(const Key('retry_weather_button')), findsNothing);
        expect(findDisplayedNumber('31'), findsWidgets);
      },
    );
  });

  group('Tier 1 — F5: Material Design UI, Theme, Typography & Responsive Layout', () {
    testWidgets(
      'T1-F5-01: MaterialApp uses Material 3 ThemeData consistently on Home and Search',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        await pumpWeatherApp(tester, httpClient: router.client);

        final MaterialApp app = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(app.theme?.useMaterial3, isTrue);

        final ThemeData homeTheme = Theme.of(
          tester.element(find.byType(Scaffold).first),
        );
        expect(homeTheme.useMaterial3, isTrue);

        await openSearchScreen(tester);
        final ThemeData searchTheme = Theme.of(
          tester.element(find.byType(Scaffold).last),
        );
        expect(searchTheme.useMaterial3, isTrue);
        expect(searchTheme.colorScheme.primary, equals(homeTheme.colorScheme.primary));
      },
    );

    testWidgets(
      'T1-F5-02: Home Weather Screen establishes readable Typography hierarchy',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              latitude: yogyakartaLocation.latitude,
              longitude: yogyakartaLocation.longitude,
              temperature2m: 31.0,
            ),
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

        final List<double> fontSizes = <double>[];
        for (final Element el in find.byType(Text).evaluate()) {
          final TextStyle effective = DefaultTextStyle.of(
            el,
          ).style.merge((el.widget as Text).style);
          final double? size = effective.fontSize;
          if (size != null) {
            fontSizes.add(size);
          }
        }

        expect(fontSizes, isNotEmpty);
        final double maxSize = fontSizes.reduce(
          (double a, double b) => a > b ? a : b,
        );
        final double minSize = fontSizes.reduce(
          (double a, double b) => a < b ? a : b,
        );
        expect(maxSize, greaterThanOrEqualTo(24.0));
        expect(minSize, greaterThanOrEqualTo(11.0));
      },
    );

    testWidgets(
      'T1-F5-03: standard narrow phone viewport (390x844) renders Home & Search without overflow',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(390, 844));
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async =>
              http.Response(weatherResponseBody(), 200),
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
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
            LocalStorageService.favoritesKey: jsonEncode(<Map<String, dynamic>>[
              bandungLocation.toStorageJson(),
            ]),
          },
        );
        expect(tester.takeException(), isNull);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Jakarta');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T1-F5-04: wide tablet viewport (1024x768) renders Home & Search cleanly without overflow',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(1024, 768));
        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async =>
              http.Response(weatherResponseBody(), 200),
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
            LocalStorageService.selectedLocationKey: jsonEncode(
              jakartaLocation.toStorageJson(),
            ),
          },
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Jakarta'), findsWidgets);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Jakarta');
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(Key('search_result_item_${jakartaLocation.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T1-F5-05: mounted widget tree uses both StatelessWidget and StatefulWidget across screens',
      (WidgetTester tester) async {
        final E2eMockHttpRouter router = E2eMockHttpRouter();
        await pumpWeatherApp(tester, httpClient: router.client);

        expect(
          tester.widget(find.byType(ResponsiWeatherApp)),
          isA<StatelessWidget>(),
        );
        expect(collectAppScaffoldAncestors(tester), isNotEmpty);

        await openSearchScreen(tester);
        final List<Widget> appAncestors = collectAppScaffoldAncestors(tester);
        expect(
          appAncestors.whereType<StatelessWidget>().isNotEmpty ||
              tester.widget(find.byType(ResponsiWeatherApp)) is StatelessWidget,
          isTrue,
        );
        expect(
          appAncestors.whereType<StatefulWidget>(),
          isNotEmpty,
          reason:
              'App route hierarchy must include app-defined StatefulWidget beyond SDK scaffolding',
        );
      },
    );

    testWidgets(
      'T1-F5-06: 7-day forecast and 10 search results are scrollable on compact 375x667 phone',
      (WidgetTester tester) async {
        setViewportSize(tester, const Size(375, 667));
        final List<Map<String, dynamic>> tenCities = List<Map<String, dynamic>>.generate(
          10,
          (int i) => locationMap(
            id: 9000 + i,
            name: 'Kota Uji $i',
            latitude: -7.0 + i * 0.1,
            longitude: 110.0 + i * 0.1,
          ),
        );

        final E2eMockHttpRouter router = E2eMockHttpRouter(
          onWeather: (http.Request req) async => http.Response(
            weatherResponseBody(
              dailyMax: const <double>[33, 34, 36, 37, 38, 39, 41],
            ),
            200,
          ),
          onGeocoding: (http.Request req) async =>
              http.Response(geocodingResponseBody(tenCities), 200),
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

        await scrollUntilTargetVisible(tester, findDisplayedNumber('41'));
        expect(findDisplayedNumber('41'), findsWidgets);
        expect(tester.takeException(), isNull);

        await openSearchScreen(tester);
        await submitCitySearch(tester, 'Kota Uji');

        await scrollUntilTargetVisible(
          tester,
          find.byKey(const Key('search_result_item_9009')),
        );
        expect(
          find.byKey(const Key('search_result_item_9009')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
