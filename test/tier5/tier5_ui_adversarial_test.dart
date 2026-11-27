import 'dart:async';
import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:responsi_flutter/main.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:responsi_flutter/utils/weather_code_mapper.dart';
import 'package:responsi_flutter/viewmodels/search_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const LocationModel _jakarta = LocationModel(
  id: 1642911,
  name: 'Jakarta',
  latitude: -6.2146,
  longitude: 106.8451,
  country: 'Indonesia',
  admin1: 'Daerah Khusus Ibukota Jakarta',
);

const LocationModel _bandung = LocationModel(
  id: 1650357,
  name: 'Bandung',
  latitude: -6.9222,
  longitude: 107.6069,
  country: 'Indonesia',
  admin1: 'Jawa Barat',
);

String _geocodingPayload(List<LocationModel> locations) {
  return jsonEncode(<String, dynamic>{
    'results': locations
        .map((LocationModel l) => l.toStorageJson())
        .toList(growable: false),
  });
}

String _weatherPayload({
  double temperature2m = 30.0,
  double apparentTemperature = 33.0,
  int relativeHumidity2m = 75,
  double precipitation = 1.0,
  int weatherCode = 1,
  double windSpeed10m = 10.0,
  List<String> dailyTime = const <String>['2026-11-26', '2026-11-27'],
  List<double> dailyMax = const <double>[33.0, 32.0],
  List<double> dailyMin = const <double>[24.0, 23.0],
  List<int> dailyProb = const <int>[50, 70],
}) {
  return jsonEncode(<String, dynamic>{
    'latitude': -6.2,
    'longitude': 106.8,
    'timezone': 'Asia/Jakarta',
    'current': <String, dynamic>{
      'temperature_2m': temperature2m,
      'relative_humidity_2m': relativeHumidity2m,
      'apparent_temperature': apparentTemperature,
      'precipitation': precipitation,
      'weather_code': weatherCode,
      'wind_speed_10m': windSpeed10m,
    },
    'daily': <String, dynamic>{
      'time': dailyTime,
      'temperature_2m_max': dailyMax,
      'temperature_2m_min': dailyMin,
      'precipitation_probability_max': dailyProb,
    },
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('T5-UI Lifecycle & DI Startup', () {
    testWidgets('T5-UI-01: unmounting ResponsiWeatherApp during pending initialize GET completes safely', (WidgetTester tester) async {
      final Completer<http.Response> weatherCompleter =
          Completer<http.Response>();
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.selectedLocationKey: jsonEncode(
          _jakarta.toStorageJson(),
        ),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'api.open-meteo.com') {
          return weatherCompleter.future;
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      weatherCompleter.complete(http.Response(_weatherPayload(), 200));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('T5-UI-02: popping LocationSearchScreen via BackButton while search GET is pending completes safely', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.selectedLocationKey: jsonEncode(
          _jakarta.toStorageJson(),
        ),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      for (final int statusCode in <int>[200, 500]) {
        final Completer<http.Response> searchCompleter =
            Completer<http.Response>();
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.host == 'geocoding-api.open-meteo.com') {
            return searchCompleter.future;
          }
          return http.Response(_weatherPayload(temperature2m: 31.0), 200);
        });

        try {
          await tester.pumpWidget(
            ResponsiWeatherApp(
              key: UniqueKey(),
              httpClient: client,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Jakarta'), findsOneWidget);

          await tester.tap(find.byKey(const Key('open_search_button')));
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const Key('search_input_field')),
            'Bandung',
          );
          await tester.tap(find.byKey(const Key('search_submit_button')));
          await tester.pump();

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();

          searchCompleter.complete(
            http.Response(
              statusCode == 200 ? _geocodingPayload(<LocationModel>[_bandung]) : 'err',
              statusCode,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Jakarta'), findsOneWidget);
          expect(find.text('31°C'), findsOneWidget);
        } finally {
          if (!searchCompleter.isCompleted) {
            searchCompleter.complete(http.Response('{}', 500));
          }
        }
      }
    });

    testWidgets('T5-UI-03: ResponsiWeatherApp resolves FutureBuilder, disposes default services, and handles FutureBuilder error', (WidgetTester tester) async {
      final MockClient mockClient = MockClient(
        (http.Request _) async => http.Response('{}', 200),
      );
      await tester.pumpWidget(ResponsiWeatherApp(httpClient: mockClient));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada lokasi dipilih'), findsOneWidget);

      // Default services (httpClient: null) unmount & dispose cleanly on empty storage.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ResponsiWeatherApp(sharedPreferences: prefs));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);

      // FutureBuilder error fallback renders clean Material error message.
      await tester.pumpWidget(
        ResponsiWeatherApp(
          sharedPreferencesLoader: () =>
              Future<SharedPreferences>.error(Exception('Prefs failure')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Gagal memuat penyimpanan lokal. Silakan muat ulang aplikasi.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Parent rebuilds while loading and after loaded must NOT re-invoke sharedPreferencesLoader.
      int loaderCalls = 0;
      final Completer<SharedPreferences> delayedPrefs =
          Completer<SharedPreferences>();
      Future<SharedPreferences> stableLoader() {
        loaderCalls++;
        return delayedPrefs.future;
      }

      Future<SharedPreferences> Function() activeLoader = stableLoader;
      late StateSetter hostSetState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            hostSetState = setState;
            return ResponsiWeatherApp(
              httpClient: mockClient,
              sharedPreferencesLoader: activeLoader,
            );
          },
        ),
      );
      await tester.pump();
      expect(loaderCalls, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Rebuild parent while still loading.
      hostSetState(() {});
      await tester.pump();
      expect(loaderCalls, equals(1));

      delayedPrefs.complete(prefs);
      await tester.pumpAndSettle();
      expect(find.text('Belum ada lokasi dipilih'), findsOneWidget);

      // Rebuild parent after loaded.
      hostSetState(() {});
      await tester.pump();
      expect(loaderCalls, equals(1));
      expect(find.text('Belum ada lokasi dipilih'), findsOneWidget);

      // Swapping to a new loader instance triggers a fresh load in didUpdateWidget.
      int secondLoaderCalls = 0;
      Future<SharedPreferences> secondLoader() async {
        secondLoaderCalls++;
        return prefs;
      }

      hostSetState(() {
        activeLoader = secondLoader;
      });
      await tester.pumpAndSettle();
      expect(secondLoaderCalls, equals(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('T5-UI Regressions & Interactions', () {
    testWidgets('T5-UI-04: retry_search_button still retries last query after pop and reopen (PROBE-05)', (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> queries = <String>[];
      int call = 0;

      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          call++;
          queries.add(request.url.queryParameters['name'] ?? '');
          if (call == 1) {
            return http.Response('Server Error', 500);
          }
          return http.Response(
            _geocodingPayload(<LocationModel>[_jakarta]),
            200,
          );
        }
        return http.Response(_weatherPayload(), 200);
      });

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_search_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('search_input_field')),
        'Jakarta',
      );
      await tester.tap(find.byKey(const Key('search_submit_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retry_search_button')), findsOneWidget);

      // Pop back to Home, then reopen Search.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_search_button')));
      await tester.pumpAndSettle();

      // Input starts empty, retry_search_button is shown and retries 'Jakarta'.
      final TextField inputField = tester.widget<TextField>(
        find.byKey(const Key('search_input_field')),
      );
      expect(inputField.controller?.text, isEmpty);
      expect(find.byKey(const Key('retry_search_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('retry_search_button')));
      await tester.pumpAndSettle();

      expect(queries, equals(<String>['Jakarta', 'Jakarta']));
      expect(
        find.byKey(Key('search_result_item_${_jakarta.id}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('retry_search_button')), findsNothing);
    });

    testWidgets('T5-UI-04b: same-screen retry_search_button uses _lastSubmittedQuery fallback when input cleared without popping', (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> queries = <String>[];
      int call = 0;

      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          call++;
          queries.add(request.url.queryParameters['name'] ?? '');
          if (call == 1) {
            return http.Response('Server Error', 500);
          }
          return http.Response(
            _geocodingPayload(<LocationModel>[_jakarta]),
            200,
          );
        }
        return http.Response(_weatherPayload(), 200);
      });

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_search_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('search_input_field')),
        'Jakarta',
      );
      await tester.tap(find.byKey(const Key('search_submit_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retry_search_button')), findsOneWidget);

      // Clear text field without popping and tap retry on the same screen.
      await tester.enterText(find.byKey(const Key('search_input_field')), '');
      await tester.pump();
      await tester.tap(find.byKey(const Key('retry_search_button')));
      await tester.pumpAndSettle();

      expect(queries, equals(<String>['Jakarta', 'Jakarta']));
      expect(
        find.byKey(Key('search_result_item_${_jakarta.id}')),
        findsOneWidget,
      );
    });

    testWidgets('T5-UI-05: concurrent SearchViewModel.toggleFavorite from widget tree preserves both cities', (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final MockClient client = MockClient(
        (http.Request _) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_search_button')));
      await tester.pumpAndSettle();

      final BuildContext searchContext = tester.element(
        find.byKey(const Key('search_input_field')),
      );
      final SearchViewModel vm = searchContext.read<SearchViewModel>();

      await Future.wait(<Future<void>>[
        vm.toggleFavorite(_jakarta),
        vm.toggleFavorite(_bandung),
      ]);
      await tester.pumpAndSettle();

      expect(find.byKey(Key('favorite_item_${_jakarta.id}')), findsOneWidget);
      expect(find.byKey(Key('favorite_item_${_bandung.id}')), findsOneWidget);
    });

    testWidgets('T5-UI-06: duplicate favorite_toggle key resolved & toggling saved favorite syncs search result icon (PROBE-08)', (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          return http.Response(
            _geocodingPayload(<LocationModel>[_jakarta]),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_search_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('search_input_field')),
        'Jakarta',
      );
      await tester.tap(find.byKey(const Key('search_submit_button')));
      await tester.pumpAndSettle();

      // Favorite from search result.
      await tester.tap(find.byKey(Key('favorite_toggle_${_jakarta.id}')));
      await tester.pumpAndSettle();

      // Global favorite_toggle_<id> stays unique; duplicate in favorites uses favorite_saved_toggle_<id>.
      expect(
        find.byKey(Key('favorite_toggle_${_jakarta.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('favorite_saved_toggle_${_jakarta.id}')),
        findsOneWidget,
      );
      expect(find.byKey(Key('favorite_item_${_jakarta.id}')), findsOneWidget);

      // Tap toggle inside favorite_item_<id> -> removes favorite_item and updates search result icon.
      await tester.tap(find.byKey(Key('favorite_saved_toggle_${_jakarta.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('favorite_item_${_jakarta.id}')), findsNothing);
      final IconButton resultToggle = tester.widget<IconButton>(
        find.byKey(Key('favorite_toggle_${_jakarta.id}')),
      );
      expect((resultToggle.icon as Icon).icon, equals(Icons.favorite_border));
    });

    testWidgets('T5-UI-07 & T5-UI-HOME-01: interactive Home/Search buttons, IME search, history chip, BackButton', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.searchHistoryKey: jsonEncode(<String>['Bandung']),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Completer<http.Response> pendingWeather =
          Completer<http.Response>();
      final List<String> geocodingQueries = <String>[];
      int weatherCalls = 0;

      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          final String name = request.url.queryParameters['name'] ?? '';
          geocodingQueries.add(name);
          final LocationModel loc = name == 'Bandung' ? _bandung : _jakarta;
          return http.Response(_geocodingPayload(<LocationModel>[loc]), 200);
        }
        weatherCalls++;
        if (weatherCalls == 1) {
          return pendingWeather.future;
        }
        return http.Response(_weatherPayload(temperature2m: 28.0), 200);
      });

      try {
        await tester.pumpWidget(
          ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
        );
        await tester.pumpAndSettle();

        // Empty state: refresh_weather_button disabled.
        final IconButton refreshEmpty = tester.widget<IconButton>(
          find.byKey(const Key('refresh_weather_button')),
        );
        expect(refreshEmpty.onPressed, isNull);

        // Tap 'Cari Lokasi' button in _EmptyWeatherView (T5-UI-HOME-01).
        await tester.tap(find.text('Cari Lokasi'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('search_input_field')), findsOneWidget);

        // Direct IME TextInputAction.search triggers Geocoding GET.
        await tester.enterText(
          find.byKey(const Key('search_input_field')),
          'Jakarta',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(geocodingQueries, equals(<String>['Jakarta']));

        // History chip updates controller text AND triggers Geocoding GET.
        await tester.tap(find.widgetWithText(ActionChip, 'Bandung'));
        await tester.pumpAndSettle();
        final TextField searchField = tester.widget<TextField>(
          find.byKey(const Key('search_input_field')),
        );
        expect(searchField.controller?.text, equals('Bandung'));
        expect(geocodingQueries, equals(<String>['Jakarta', 'Bandung']));

        // Select Bandung -> weather pending (loading state).
        await tester.tap(find.byKey(Key('search_result_item_${_bandung.id}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final IconButton refreshLoading = tester.widget<IconButton>(
          find.byKey(const Key('refresh_weather_button')),
        );
        expect(refreshLoading.onPressed, isNull);

        // First weather fails (500) -> error state, refresh enabled.
        pendingWeather.complete(http.Response('Server error', 500));
        await tester.pumpAndSettle();

        final IconButton refreshError = tester.widget<IconButton>(
          find.byKey(const Key('refresh_weather_button')),
        );
        expect(refreshError.onPressed, isNotNull);

        // Tap refresh_weather_button in error state -> recovers to loaded (28°C).
        await tester.tap(find.byKey(const Key('refresh_weather_button')));
        await tester.pumpAndSettle();
        expect(find.text('Bandung'), findsOneWidget);
        expect(find.text('28°C'), findsOneWidget);

        // BackButton on Search preserves prior Home state.
        await tester.tap(find.byKey(const Key('open_search_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Bandung'), findsOneWidget);
        expect(find.text('28°C'), findsOneWidget);

        // Trigger error on refresh, then test 'Ganti Lokasi' button in _ErrorWeatherView.
        // Force an error via a new WeatherApp instance with saved location + 500 weather.
      } finally {
        if (!pendingWeather.isCompleted) {
          pendingWeather.complete(http.Response('{}', 500));
        }
      }
    });

    testWidgets('T5-UI-HOME-01: Ganti Lokasi button in _ErrorWeatherView opens LocationSearchScreen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.selectedLocationKey: jsonEncode(
          _jakarta.toStorageJson(),
        ),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final MockClient client = MockClient(
        (http.Request _) async => http.Response('err', 500),
      );

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ganti Lokasi'), findsOneWidget);
      await tester.tap(find.text('Ganti Lokasi'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_input_field')), findsOneWidget);
    });
  });

  group('T5-UI-08: Extreme Overflow & Soft Keyboard Responsiveness', () {
    testWidgets('Home and Search render cleanly across 280x500, 601x500, 1200x800 @ 2.0x textScale and soft keyboard viewInsets', (WidgetTester tester) async {
      final List<LocationModel> twentyFavs = List<LocationModel>.generate(
        20,
        (int i) => LocationModel(
          id: 9000 + i,
          name: 'Kota Favorit Super Panjang Nomor $i Tanpa Masalah Layout',
          latitude: -6.2,
          longitude: 106.8,
          admin1: 'Provinsi Sangat Panjang',
          country: 'Indonesia',
        ),
      );
      final List<LocationModel> tenResults = List<LocationModel>.generate(
        10,
        (int i) => LocationModel(
          id: 8000 + i,
          name: 'Hasil Pencarian Panjang $i',
          latitude: -7.0,
          longitude: 110.0,
          admin1: 'Wilayah Panjang',
          country: 'Indonesia',
        ),
      );
      final String longChip = List<String>.filled(80, 'x').join();

      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.selectedLocationKey: jsonEncode(
          const LocationModel(
            id: 7001,
            name: 'NamaKotaUltraPanjangTanpaSpasiUntukUjiOverflowDiLayarEkstrem280px',
            latitude: -6.2,
            longitude: 106.8,
            admin1: 'AdministrasiPanjangSekali',
            country: 'RepublikIndonesia',
          ).toStorageJson(),
        ),
        LocalStorageService.favoritesKey: jsonEncode(
          twentyFavs.map((LocationModel l) => l.toStorageJson()).toList(),
        ),
        LocalStorageService.searchHistoryKey: jsonEncode(<String>[longChip]),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      bool failWeather = false;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          return http.Response(_geocodingPayload(tenResults), 200);
        }
        if (failWeather) {
          return http.Response('err', 500);
        }
        return http.Response(
          _weatherPayload(
            temperature2m: -12.5,
            apparentTemperature: -18.0,
          ),
          200,
        );
      });

      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      // 1. 280x500 @ 2.0x textScaleFactor on Home (loaded + error) and Search.
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      failWeather = true;
      await tester.tap(find.byKey(const Key('refresh_weather_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('open_search_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('search_input_field')),
        'Kota',
      );
      await tester.tap(find.byKey(const Key('search_submit_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2. 601x500 @ 2.0x on Search and Home.
      tester.view.physicalSize = const Size(601, 500);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      failWeather = false;
      await tester.tap(find.byKey(const Key('retry_weather_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 3. 1200x800 @ 2.0x on Home and Search.
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('open_search_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 4. Soft keyboard open: 320x568 @ 2.0x + viewInsets.bottom = 300.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 5. Soft keyboard open landscape (realistic non-zero-height constraints):
      //    480x320 @ 2.0x + kb=180, 601x320 @ 2.0x + kb=180,
      //    640x360 @ 1.0x + kb=230, 667x375 @ 1.0x + kb=240, and 480x320 @ 2.0x + kb=260.
      tester.view.physicalSize = const Size(480, 320);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(601, 320);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      tester.view.physicalSize = const Size(640, 360);
      tester.view.viewInsets = const FakeViewPadding(bottom: 230.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(667, 375);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      tester.view.physicalSize = const Size(480, 320);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('T5-UI-09: Empty Daily Substate & Formatter/Mapper Edges', () {
    testWidgets('empty daily hides Peluang Hujan, renders empty fallback, formats -0.0 as 0°C, and formats non-ISO date', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.selectedLocationKey: jsonEncode(
          _jakarta.toStorageJson(),
        ),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      int call = 0;
      final MockClient client = MockClient((http.Request _) async {
        call++;
        if (call == 1) {
          return http.Response(
            _weatherPayload(
              temperature2m: -0.0,
              dailyTime: const <String>[],
              dailyMax: const <double>[],
              dailyMin: const <double>[],
              dailyProb: const <int>[],
            ),
            200,
          );
        }
        return http.Response(
          _weatherPayload(
            temperature2m: 25.0,
            dailyTime: const <String>['26/11/2026'],
            dailyMax: const <double>[31.0],
            dailyMin: const <double>[22.0],
            dailyProb: const <int>[20],
          ),
          200,
        );
      });

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('0°C'), findsOneWidget);
      expect(find.text('-0°C'), findsNothing);
      expect(find.text('Peluang Hujan'), findsNothing);
      expect(find.text('Perkiraan Cuaca Harian'), findsOneWidget);
      expect(
        find.text('Data perkiraan harian tidak tersedia.'),
        findsOneWidget,
      );

      // Refresh with non-ISO date string ('26/11/2026') exercises _formatForecastDate fallback (T5-UI-HOME-01).
      await tester.tap(find.byKey(const Key('refresh_weather_button')));
      await tester.pumpAndSettle();
      expect(find.text('26/11/2026'), findsOneWidget);
    });

    testWidgets('formats small negative -0.04 temperature as 0°C without -0.0°C (PROBE-R2-05)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.selectedLocationKey: jsonEncode(
          _jakarta.toStorageJson(),
        ),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final MockClient client = MockClient(
        (http.Request _) async => http.Response(
          _weatherPayload(
            temperature2m: -0.04,
            apparentTemperature: 0.04,
            precipitation: 0.0,
            windSpeed10m: 0.0,
          ),
          200,
        ),
      );

      await tester.pumpWidget(
        ResponsiWeatherApp(httpClient: client, sharedPreferences: prefs),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('0°C'), findsOneWidget);
      expect(find.text('-0.0°C'), findsNothing);
      expect(find.text('Terasa seperti 0°C'), findsOneWidget);
    });

    test('WeatherCodeMapper handles boundary and extreme unknown codes safely', () {
      for (final int code in <int>[-999, -1, 4, 44, 50, 100, 0x7fffffff]) {
        final WeatherCodeInfo info = WeatherCodeMapper.map(code);
        expect(info.description, equals('Kondisi Cuaca Tidak Diketahui'));
        expect(info.icon, equals(Icons.cloud_queue));
      }
    });
  });
}
