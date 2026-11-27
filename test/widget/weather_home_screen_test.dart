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
import 'package:responsi_flutter/views/weather_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _sampleForecastJson({
  double temperature2m = 29.4,
  double apparentTemperature = 33.2,
  int relativeHumidity2m = 76,
  double precipitation = 1.5,
  int weatherCode = 1,
  double windSpeed10m = 12.0,
}) {
  return <String, dynamic>{
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
      'time': <String>[
        '2026-11-26',
        '2026-11-27',
        '2026-11-28',
        '2026-11-29',
        '2026-11-30',
        '2026-12-01',
        '2026-12-02',
      ],
      'temperature_2m_max': <double>[33.0, 32.5, 31.0, 30.5, 32.0, 33.4, 34.0],
      'temperature_2m_min': <double>[24.0, 24.5, 23.8, 23.0, 24.2, 24.0, 25.1],
      'precipitation_probability_max': <int>[40, 65, 80, 20, 10, 30, 50],
    },
  };
}

Widget _buildHomeTestHarness({
  required WeatherViewModel weatherViewModel,
  required SearchViewModel searchViewModel,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WeatherViewModel>.value(value: weatherViewModel),
      ChangeNotifierProvider<SearchViewModel>.value(value: searchViewModel),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const WeatherHomeScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'empty state shows prompt, single open_search_button, and no retry button',
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

      await weatherVm.initialize();
      await searchVm.initialize();

      await tester.pumpWidget(
        _buildHomeTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada lokasi dipilih'), findsOneWidget);
      expect(find.byKey(const Key('open_search_button')), findsOneWidget);
      expect(find.byKey(const Key('retry_weather_button')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'loading state renders single ProgressIndicator and keeps open_search_button enabled',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final Completer<http.Response> completer = Completer<http.Response>();
      final MockClient mockClient = MockClient((_) => completer.future);
      final WeatherViewModel weatherVm = WeatherViewModel(
        weatherService: WeatherApiService(client: mockClient),
        storageService: storage,
      );
      final SearchViewModel searchVm = SearchViewModel(
        geocodingService: GeocodingApiService(client: mockClient),
        storageService: storage,
      );

      await tester.pumpWidget(
        _buildHomeTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );

      const LocationModel jakarta = LocationModel(
        id: 1,
        name: 'Jakarta',
        latitude: -6.2,
        longitude: 106.8,
      );
      unawaited(weatherVm.loadWeatherForLocation(jakarta));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final IconButton searchButton = tester.widget<IconButton>(
        find.byKey(const Key('open_search_button')),
      );
      expect(searchButton.onPressed, isNotNull);

      completer.complete(
        http.Response(jsonEncode(_sampleForecastJson()), 200),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'error state renders retry_weather_button and recovers on retry',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      int calls = 0;
      final MockClient mockClient = MockClient((_) async {
        calls++;
        if (calls == 1) {
          return http.Response('Server Error', 500);
        }
        return http.Response(jsonEncode(_sampleForecastJson()), 200);
      });

      final WeatherViewModel weatherVm = WeatherViewModel(
        weatherService: WeatherApiService(client: mockClient),
        storageService: storage,
      );
      final SearchViewModel searchVm = SearchViewModel(
        geocodingService: GeocodingApiService(client: mockClient),
        storageService: storage,
      );

      const LocationModel bandung = LocationModel(
        id: 2,
        name: 'Bandung',
        latitude: -6.9,
        longitude: 107.6,
        admin1: 'Jawa Barat',
        country: 'Indonesia',
      );

      await tester.pumpWidget(
        _buildHomeTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );

      await weatherVm.loadWeatherForLocation(bandung);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry_weather_button')), findsOneWidget);
      expect(find.text('Bandung'), findsNothing);

      await tester.tap(find.byKey(const Key('retry_weather_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry_weather_button')), findsNothing);
      expect(find.text('Bandung'), findsOneWidget);
      expect(find.text('29.4°C'), findsOneWidget);
    },
  );

  testWidgets(
    'loaded state displays all weather metrics, negative temps, and avoids literal null',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final MockClient mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode(
            _sampleForecastJson(
              temperature2m: -1.5,
              apparentTemperature: -6.0,
              relativeHumidity2m: 82,
              precipitation: 0.0,
              weatherCode: 95,
              windSpeed10m: 22.4,
            ),
          ),
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

      const LocationModel polarCity = LocationModel(
        id: 3,
        name: 'Oymyakon',
        latitude: 63.46,
        longitude: 142.78,
      );

      await tester.pumpWidget(
        _buildHomeTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );
      await weatherVm.loadWeatherForLocation(polarCity);
      await tester.pumpAndSettle();

      expect(find.text('Oymyakon'), findsOneWidget);
      expect(find.text('-1.5°C'), findsOneWidget);
      expect(find.text('Terasa seperti -6°C'), findsOneWidget);
      expect(find.text('Badai Petir'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('22.4 km/h'), findsOneWidget);
      expect(find.text('0 mm'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('24° / 33°'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    },
  );

  testWidgets(
    'loaded state renders without overflow at 320x568 with 1.5x text scale and 1024x768',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final MockClient mockClient = MockClient(
        (_) async => http.Response(jsonEncode(_sampleForecastJson()), 200),
      );

      final WeatherViewModel weatherVm = WeatherViewModel(
        weatherService: WeatherApiService(client: mockClient),
        storageService: storage,
      );
      final SearchViewModel searchVm = SearchViewModel(
        geocodingService: GeocodingApiService(client: mockClient),
        storageService: storage,
      );

      const LocationModel longCity = LocationModel(
        id: 4,
        name: 'Kota Dengan Nama Sangat Panjang Sekali Untuk Pengujian Responsif',
        latitude: -6.2,
        longitude: 106.8,
        admin1: 'Provinsi Yang Sangat Panjang Sekali',
        country: 'Indonesia',
      );
      await weatherVm.loadWeatherForLocation(longCity);

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(
        _buildHomeTestHarness(
          weatherViewModel: weatherVm,
          searchViewModel: searchVm,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1024, 768);
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
