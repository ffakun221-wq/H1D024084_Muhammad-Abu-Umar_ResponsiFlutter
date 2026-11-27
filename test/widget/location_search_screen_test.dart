import 'dart:async';
import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/geocoding_api_service.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:responsi_flutter/services/weather_api_service.dart';
import 'package:responsi_flutter/theme/app_theme.dart';
import 'package:responsi_flutter/viewmodels/search_viewmodel.dart';
import 'package:responsi_flutter/viewmodels/weather_viewmodel.dart';
import 'package:responsi_flutter/views/location_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildSearchTestHarness({
  required WeatherViewModel weatherViewModel,
  required SearchViewModel searchViewModel,
  bool wrapWithHomeRoute = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WeatherViewModel>.value(value: weatherViewModel),
      ChangeNotifierProvider<SearchViewModel>.value(value: searchViewModel),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: wrapWithHomeRoute
          ? Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('test_push_search'),
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext _) =>
                                const LocationSearchScreen(),
                          ),
                        );
                      },
                      child: const Text('Push'),
                    ),
                  ),
                );
              },
            )
          : const LocationSearchScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'initial state shows search controls, hides history when empty, and shows empty favorites hint',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final MockClient mockClient = MockClient(
        (_) async => http.Response('{}', 200),
      );

      final WeatherViewModel weatherVm = WeatherViewModel(
        weatherService: WeatherApiService(client: mockClient),
        storageService: storage,
      );
      final SearchViewModel searchVm = SearchViewModel(
        geocodingService: GeocodingApiService(client: mockClient),
        storageService: storage,
      );
      await searchVm.initialize();

      await tester.pumpWidget(
        _buildSearchTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_input_field')), findsOneWidget);
      expect(find.byKey(const Key('search_submit_button')), findsOneWidget);
      expect(find.text('Riwayat Pencarian'), findsNothing);
      expect(find.text('Belum ada lokasi favorit tersimpan.'), findsOneWidget);
    },
  );

  testWidgets(
    'submitting query displays results without literal null and allows history chip & favorite toggle',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final List<String> queriedNames = <String>[];
      final MockClient mockClient = MockClient((http.Request request) async {
        queriedNames.add(request.url.queryParameters['name'] ?? '');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 101,
                'name': 'Bandung',
                'latitude': -6.9,
                'longitude': 107.6,
                'admin1': 'Jawa Barat',
                'country': 'Indonesia',
              },
              <String, dynamic>{
                'id': 102,
                'name': 'Pulau Kosong',
                'latitude': 0.0,
                'longitude': 100.0,
                'admin1': null,
                'country': null,
              },
            ],
          }),
          200,
        );
      });

      final WeatherViewModel weatherVm = WeatherViewModel(
        weatherService: WeatherApiService(client: mockClient),
        storageService: storage,
      );
      final SearchViewModel searchVm = SearchViewModel(
        geocodingService: GeocodingApiService(client: mockClient),
        storageService: storage,
      );
      await searchVm.initialize();

      await tester.pumpWidget(
        _buildSearchTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('search_input_field')),
        'Bandung',
      );
      await tester.tap(find.byKey(const Key('search_submit_button')));
      await tester.pumpAndSettle();

      expect(queriedNames, <String>['Bandung']);
      expect(find.byKey(const Key('search_result_item_101')), findsOneWidget);
      expect(find.byKey(const Key('search_result_item_102')), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
      expect(find.text('Riwayat Pencarian'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('search_result_item_101')),
          matching: find.byKey(const Key('favorite_toggle_101')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('favorite_item_101')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('favorite_item_101')),
          matching: find.byKey(const Key('favorite_saved_toggle_101')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('favorite_toggle_101')), findsOneWidget);

      final List<LocationModel> savedFavorites = await storage.getFavorites();
      expect(savedFavorites.map((LocationModel l) => l.id), <int>[101]);

      await tester.tap(find.widgetWithText(ActionChip, 'Bandung'));
      await tester.pumpAndSettle();
      expect(queriedNames.length, 2);
    },
  );

  testWidgets(
    'loading keeps search_submit_button enabled and error shows retry_search_button',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final Completer<http.Response> pendingSearch = Completer<http.Response>();
      int requestCount = 0;

      final MockClient mockClient = MockClient((http.Request request) async {
        requestCount++;
        if (requestCount == 1) {
          return pendingSearch.future;
        }
        return http.Response('{"results": []}', 200);
      });

      final WeatherViewModel weatherVm = WeatherViewModel(
        weatherService: WeatherApiService(client: mockClient),
        storageService: storage,
      );
      final SearchViewModel searchVm = SearchViewModel(
        geocodingService: GeocodingApiService(client: mockClient),
        storageService: storage,
      );
      await searchVm.initialize();

      await tester.pumpWidget(
        _buildSearchTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('search_input_field')),
        'Malang',
      );
      await tester.tap(find.byKey(const Key('search_submit_button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final IconButton submitButton = tester.widget<IconButton>(
        find.byKey(const Key('search_submit_button')),
      );
      expect(submitButton.onPressed, isNotNull);

      pendingSearch.complete(http.Response('Server error', 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry_search_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('retry_search_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry_search_button')), findsNothing);
      expect(
        find.text('Kota tidak ditemukan. Coba kata kunci lain.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selecting result triggers weather load and pops immediately while forecast is pending',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final Completer<http.Response> weatherCompleter =
          Completer<http.Response>();

      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.host.contains('geocoding-api')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'results': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 501,
                  'name': 'Surabaya',
                  'latitude': -7.25,
                  'longitude': 112.75,
                  'admin1': 'Jawa Timur',
                  'country': 'Indonesia',
                },
              ],
            }),
            200,
          );
        }
        return weatherCompleter.future;
      });

      final WeatherViewModel weatherVm = WeatherViewModel(
        weatherService: WeatherApiService(client: mockClient),
        storageService: storage,
      );
      final SearchViewModel searchVm = SearchViewModel(
        geocodingService: GeocodingApiService(client: mockClient),
        storageService: storage,
      );
      await searchVm.initialize();

      await tester.pumpWidget(
        _buildSearchTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
          wrapWithHomeRoute: true,
        ),
      );

      await tester.tap(find.byKey(const Key('test_push_search')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('search_input_field')),
        'Surabaya',
      );
      await tester.tap(find.byKey(const Key('search_submit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_result_item_501')));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSearchScreen), findsNothing);
      expect(weatherVm.state, ViewState.loading);
      expect(weatherVm.selectedLocation?.id, 501);

      weatherCompleter.complete(
        http.Response(
          jsonEncode(<String, dynamic>{
            'latitude': -7.25,
            'longitude': 112.75,
            'timezone': 'Asia/Jakarta',
            'current': <String, dynamic>{
              'temperature_2m': 31.0,
              'relative_humidity_2m': 70,
              'apparent_temperature': 35.0,
              'precipitation': 0.0,
              'weather_code': 0,
              'wind_speed_10m': 10.0,
            },
            'daily': <String, dynamic>{
              'time': <String>['2026-11-26'],
              'temperature_2m_max': <double>[33.0],
              'temperature_2m_min': <double>[25.0],
              'precipitation_probability_max': <int>[10],
            },
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(weatherVm.state, ViewState.loaded);
    },
  );

  testWidgets(
    'renders without overflow at 320x568 with 1.5x text scale and long names',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      await storage.saveFavorite(
        const LocationModel(
          id: 777,
          name: 'Nama Kota Favorit Yang Sangat Panjang Sekali Untuk Uji Overflow',
          latitude: -6.2,
          longitude: 106.8,
          admin1: 'Wilayah Administrasi Panjang',
          country: 'Indonesia',
        ),
      );

      final MockClient mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 888,
                'name': 'Nama Kota Pencarian Yang Sangat Panjang Sekali Di Layar Kecil',
                'latitude': -7.0,
                'longitude': 110.0,
                'admin1': 'Jawa Tengah Yang Sangat Panjang',
                'country': 'Indonesia',
              },
            ],
          }),
          200,
        ),
      );

      final WeatherViewModel weatherVm = WeatherViewModel(
        weatherService: WeatherApiService(client: mockClient),
        storageService: storage,
      );
      final SearchViewModel searchVm = SearchViewModel(
        geocodingService: GeocodingApiService(client: mockClient),
        storageService: storage,
      );
      await searchVm.initialize();

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(
        _buildSearchTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('search_input_field')),
        'Semarang',
      );
      await tester.tap(find.byKey(const Key('search_submit_button')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
