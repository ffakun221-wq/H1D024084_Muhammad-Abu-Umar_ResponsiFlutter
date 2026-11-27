import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:responsi_flutter/services/weather_api_service.dart';
import 'package:responsi_flutter/viewmodels/weather_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const LocationModel jakarta = LocationModel(
    id: 1642911,
    name: 'Jakarta',
    latitude: -6.21462,
    longitude: 106.84513,
    country: 'Indonesia',
    admin1: 'Jakarta Raya',
  );
  const LocationModel bandung = LocationModel(
    id: 1650357,
    name: 'Bandung',
    latitude: -6.92222,
    longitude: 107.60694,
    country: 'Indonesia',
    admin1: 'Jawa Barat',
  );

  String buildWeatherJson({required double temp}) {
    return jsonEncode(<String, dynamic>{
      'latitude': -6.25,
      'longitude': 106.875,
      'timezone': 'Asia/Jakarta',
      'current': <String, dynamic>{
        'temperature_2m': temp,
        'relative_humidity_2m': 75,
        'apparent_temperature': temp + 2.0,
        'precipitation': 0.0,
        'weather_code': 1,
        'wind_speed_10m': 8.0,
      },
      'daily': <String, dynamic>{
        'time': <dynamic>['2026-11-26'],
        'temperature_2m_max': <dynamic>[temp + 2.0],
        'temperature_2m_min': <dynamic>[temp - 5.0],
        'precipitation_probability_max': <dynamic>[30],
      },
    });
  }

  group('WeatherViewModel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('starts in initial state with null weather, location, and error', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: LocalStorageService(prefs),
      );

      expect(vm.state, equals(ViewState.initial));
      expect(vm.weather, isNull);
      expect(vm.selectedLocation, isNull);
      expect(vm.errorMessage, isNull);
    });

    test('initialize on empty storage transitions to empty with zero HTTP calls', () async {
      int httpCalls = 0;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) async {
            httpCalls++;
            return http.Response('{}', 200);
          }),
        ),
        storageService: LocalStorageService(prefs),
      );

      await vm.initialize();

      expect(vm.state, equals(ViewState.empty));
      expect(vm.selectedLocation, isNull);
      expect(vm.weather, isNull);
      expect(vm.errorMessage, isNull);
      expect(httpCalls, equals(0));
    });

    test('initialize with saved location loads live weather and emits loading -> loaded', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      await storage.saveSelectedLocation(jakarta);

      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient(
            (http.Request _) async =>
                http.Response(buildWeatherJson(temp: 31.0), 200),
          ),
        ),
        storageService: storage,
      );

      final List<ViewState> states = <ViewState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.initialize();

      expect(states, equals(<ViewState>[ViewState.loading, ViewState.loaded]));
      expect(vm.selectedLocation, equals(jakarta));
      expect(vm.weather?.current.temperature2m, equals(31.0));
      expect(vm.errorMessage, isNull);
    });

    test('initialize with saved location transitions to error on HTTP 500', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      await storage.saveSelectedLocation(jakarta);

      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient(
            (http.Request _) async => http.Response('server error', 500),
          ),
        ),
        storageService: storage,
      );

      final List<ViewState> states = <ViewState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.initialize();

      expect(states, equals(<ViewState>[ViewState.loading, ViewState.error]));
      expect(vm.weather, isNull);
      expect(vm.errorMessage, isNotNull);
    });

    test('loadWeatherForLocation persists selection and clears stale weather on city switch or error', () async {
      bool shouldFail = false;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);

      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) async {
            if (shouldFail) {
              return http.Response('fail', 500);
            }
            return http.Response(buildWeatherJson(temp: 29.5), 200);
          }),
        ),
        storageService: storage,
      );

      await vm.loadWeatherForLocation(jakarta);
      expect(vm.state, equals(ViewState.loaded));
      expect(vm.weather?.current.temperature2m, equals(29.5));
      expect(await storage.getSelectedLocation(), equals(jakarta));

      shouldFail = true;
      WeatherViewModel? observedWeatherDuringLoading;
      vm.addListener(() {
        if (vm.state == ViewState.loading) {
          observedWeatherDuringLoading = vm;
        }
      });

      await vm.loadWeatherForLocation(bandung);
      expect(observedWeatherDuringLoading?.weather, isNull);
      expect(vm.state, equals(ViewState.error));
      expect(vm.weather, isNull);
      expect(vm.selectedLocation, equals(bandung));
      expect(await storage.getSelectedLocation(), equals(bandung));
    });

    test('refreshWeather sets empty when unselected and refetches when selected', () async {
      int fetchCount = 0;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);

      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) async {
            fetchCount++;
            return http.Response(
              buildWeatherJson(temp: 25.0 + fetchCount),
              200,
            );
          }),
        ),
        storageService: storage,
      );

      await vm.refreshWeather();
      expect(vm.state, equals(ViewState.empty));
      expect(fetchCount, equals(0));

      await vm.loadWeatherForLocation(jakarta);
      expect(vm.weather?.current.temperature2m, equals(26.0));

      await vm.refreshWeather();
      expect(vm.state, equals(ViewState.loaded));
      expect(vm.weather?.current.temperature2m, equals(27.0));
      expect(fetchCount, equals(2));
    });

    test('dispose during pending request does not throw when request completes', () async {
      final Completer<http.Response> completer = Completer<http.Response>();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) => completer.future),
        ),
        storageService: LocalStorageService(prefs),
      );

      final Future<void> pending = vm.loadWeatherForLocation(jakarta);
      await Future<void>.delayed(Duration.zero);
      vm.dispose();

      completer.complete(http.Response(buildWeatherJson(temp: 28.0), 200));
      await pending;
    });

    test('ignores stale response when a newer location request supersedes an older one', () async {
      final Completer<http.Response> firstCompleter =
          Completer<http.Response>();
      final Completer<http.Response> secondCompleter =
          Completer<http.Response>();
      int callIndex = 0;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) {
            callIndex++;
            return callIndex == 1
                ? firstCompleter.future
                : secondCompleter.future;
          }),
        ),
        storageService: LocalStorageService(prefs),
      );

      final Future<void> firstFuture = vm.loadWeatherForLocation(jakarta);
      await Future<void>.delayed(Duration.zero);
      final Future<void> secondFuture = vm.loadWeatherForLocation(bandung);
      await Future<void>.delayed(Duration.zero);

      secondCompleter.complete(http.Response(buildWeatherJson(temp: 22.0), 200));
      await secondFuture;
      firstCompleter.complete(http.Response(buildWeatherJson(temp: 33.0), 200));
      await firstFuture;

      expect(vm.selectedLocation, equals(bandung));
      expect(vm.weather?.current.temperature2m, equals(22.0));
      expect(vm.state, equals(ViewState.loaded));
    });
  });
}
