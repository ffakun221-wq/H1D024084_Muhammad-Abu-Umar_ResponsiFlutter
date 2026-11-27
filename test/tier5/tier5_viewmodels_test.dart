import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/geocoding_api_service.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:responsi_flutter/services/weather_api_service.dart';
import 'package:responsi_flutter/viewmodels/search_viewmodel.dart';
import 'package:responsi_flutter/viewmodels/weather_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedStorageService extends LocalStorageService {
  _DelayedStorageService(
    super.prefs, {
    this.getFavoritesCompleter,
    this.getSelectedCompleter,
    this.saveSelectedCompleter,
    this.addHistoryCompleter,
    this.failFavoriteWrite = false,
    this.failHistoryWrite = false,
    this.failSaveSelected = false,
  });

  final Completer<void>? getFavoritesCompleter;
  final Completer<void>? getSelectedCompleter;
  final Completer<void>? saveSelectedCompleter;
  final Completer<void>? addHistoryCompleter;
  final bool failFavoriteWrite;
  final bool failHistoryWrite;
  final bool failSaveSelected;
  bool _consumedGetFavoritesDelay = false;

  @override
  Future<List<LocationModel>> getFavorites() async {
    if (!_consumedGetFavoritesDelay && getFavoritesCompleter != null) {
      _consumedGetFavoritesDelay = true;
      await getFavoritesCompleter!.future;
    }
    return super.getFavorites();
  }

  @override
  Future<LocationModel?> getSelectedLocation() async {
    if (getSelectedCompleter != null) {
      await getSelectedCompleter!.future;
    }
    return super.getSelectedLocation();
  }

  @override
  Future<void> saveSelectedLocation(LocationModel location) async {
    if (saveSelectedCompleter != null) {
      await saveSelectedCompleter!.future;
    }
    if (failSaveSelected) {
      throw Exception('Simulated selected location write failure');
    }
    return super.saveSelectedLocation(location);
  }

  @override
  Future<void> saveFavorite(LocationModel location) async {
    if (failFavoriteWrite) {
      throw Exception('Simulated favorite write failure');
    }
    return super.saveFavorite(location);
  }

  @override
  Future<void> removeFavorite(int locationId) async {
    if (failFavoriteWrite) {
      throw Exception('Simulated favorite remove failure');
    }
    return super.removeFavorite(locationId);
  }

  @override
  Future<void> addSearchHistory(String query) async {
    if (addHistoryCompleter != null) {
      await addHistoryCompleter!.future;
    }
    if (failHistoryWrite) {
      throw Exception('Simulated search history write failure');
    }
    return super.addSearchHistory(query);
  }
}

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

  String weatherJson({required double temp}) {
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

  group('T5-VM-01: SearchViewModel races, error isolation, & branch coverage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('slow initialize does not overwrite concurrent toggleFavorite or searchCities (PROBE-VM1)', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService seedStorage = LocalStorageService(prefs);
      await seedStorage.saveFavorite(jakarta);
      await seedStorage.addSearchHistory('Jakarta');

      final Completer<void> initFavGate = Completer<void>();
      final _DelayedStorageService delayedStorage = _DelayedStorageService(
        prefs,
        getFavoritesCompleter: initFavGate,
      );

      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient(
            (http.Request _) async => http.Response(
              jsonEncode(<String, dynamic>{
                'results': <dynamic>[bandung.toStorageJson()],
              }),
              200,
            ),
          ),
        ),
        storageService: delayedStorage,
      );

      final Future<void> initFuture = vm.initialize();
      await Future<void>.delayed(Duration.zero);

      // User toggles Bandung favorite and searches Bandung before initialize finishes.
      await vm.toggleFavorite(bandung);
      await vm.searchCities('Bandung');
      expect(
        vm.favorites.map((LocationModel l) => l.id).toList(),
        equals(<int>[bandung.id, jakarta.id]),
      );
      expect(vm.searchHistory, equals(<String>['Bandung', 'Jakarta']));

      // Now slow initialize completes; newer mutations must NOT be clobbered.
      initFavGate.complete();
      await initFuture;

      expect(
        vm.favorites.map((LocationModel l) => l.id).toList(),
        equals(<int>[bandung.id, jakarta.id]),
      );
      expect(vm.searchHistory, equals(<String>['Bandung', 'Jakarta']));
    });

    test('concurrent same-city double-tap toggleFavorite executes sequentially (PROBE-VM2)', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: LocalStorageService(prefs),
      );

      await Future.wait(<Future<void>>[
        vm.toggleFavorite(jakarta),
        vm.toggleFavorite(jakarta),
      ]);

      expect(vm.favorites, isEmpty);
      expect(vm.isFavorite(jakarta.id), isFalse);
    });

    test('concurrent multi-city toggleFavorite preserves both cities (T5-UI-05 / PROBE-09)', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: storage,
      );

      await Future.wait(<Future<void>>[
        vm.toggleFavorite(jakarta),
        vm.toggleFavorite(bandung),
      ]);

      expect(
        vm.favorites.map((LocationModel l) => l.id).toSet(),
        equals(<int>{jakarta.id, bandung.id}),
      );
      expect(
        (await storage.getFavorites()).map((LocationModel l) => l.id).toSet(),
        equals(<int>{jakarta.id, bandung.id}),
      );
    });

    test('storage write errors do not crash toggleFavorite or discard valid searchCities results (PROBE-S2)', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final _DelayedStorageService failingStorage = _DelayedStorageService(
        prefs,
        failFavoriteWrite: true,
        failHistoryWrite: true,
      );

      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient(
            (http.Request _) async => http.Response(
              jsonEncode(<String, dynamic>{
                'results': <dynamic>[jakarta.toStorageJson()],
              }),
              200,
            ),
          ),
        ),
        storageService: failingStorage,
      );

      // toggleFavorite must not leak unhandled exception and keeps state consistent.
      await vm.toggleFavorite(jakarta);
      expect(vm.favorites, isEmpty);

      // searchCities must still succeed with live HTTP 200 results despite history write failure.
      await vm.searchCities('Jakarta');
      expect(vm.state, equals(ViewState.loaded));
      expect(vm.results, equals(<LocationModel>[jakarta]));
      expect(vm.errorMessage, isNull);
    });

    test('lastQuery tracks trimmed query, retains on error, and clears on blank reset', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('err', 500)),
        ),
        storageService: LocalStorageService(prefs),
      );

      await vm.searchCities('  Jakarta  ');
      expect(vm.state, equals(ViewState.error));
      expect(vm.lastQuery, equals('Jakarta'));

      await vm.searchCities('   ');
      expect(vm.state, equals(ViewState.initial));
      expect(vm.lastQuery, isEmpty);
    });

    test('dispose during initialize/addSearchHistory/toggleFavorite and stale HTTP 500 ignored', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // 1. Dispose during initialize.
      final Completer<void> initGate = Completer<void>();
      final SearchViewModel vmInitDispose = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: _DelayedStorageService(
          prefs,
          getFavoritesCompleter: initGate,
        ),
      );
      final Future<void> initPending = vmInitDispose.initialize();
      await Future<void>.delayed(Duration.zero);
      vmInitDispose.dispose();
      initGate.complete();
      await initPending;

      // 2. Dispose during addSearchHistory inside searchCities.
      final Completer<void> historyGate = Completer<void>();
      final SearchViewModel vmHistDispose = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient(
            (http.Request _) async => http.Response(
              jsonEncode(<String, dynamic>{
                'results': <dynamic>[jakarta.toStorageJson()],
              }),
              200,
            ),
          ),
        ),
        storageService: _DelayedStorageService(
          prefs,
          addHistoryCompleter: historyGate,
        ),
      );
      final Future<void> histPending = vmHistDispose.searchCities('Jakarta');
      await Future<void>.delayed(Duration.zero);
      vmHistDispose.dispose();
      historyGate.complete();
      await histPending;

      // 3. Dispose during toggleFavorite.
      final Completer<void> favGate = Completer<void>();
      final SearchViewModel vmFavDispose = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: _DelayedStorageService(
          prefs,
          getFavoritesCompleter: favGate,
        ),
      );
      final Future<void> favPending = vmFavDispose.toggleFavorite(jakarta);
      await Future<void>.delayed(Duration.zero);
      vmFavDispose.dispose();
      favGate.complete();
      await favPending;

      // 4. Stale HTTP 500 ignored after blank reset.
      final Completer<http.Response> stale500 = Completer<http.Response>();
      final SearchViewModel vmStale = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) => stale500.future),
        ),
        storageService: LocalStorageService(prefs),
      );
      final Future<void> searchFuture = vmStale.searchCities('Jakarta');
      await Future<void>.delayed(Duration.zero);
      await vmStale.searchCities('   ');
      expect(vmStale.state, equals(ViewState.initial));

      stale500.complete(http.Response('Server Error', 500));
      await searchFuture;
      expect(vmStale.state, equals(ViewState.initial));
      expect(vmStale.errorMessage, isNull);

      // 5. Queued toggleFavorite is skipped cleanly if SearchViewModel is disposed before execution.
      final Completer<void> queuedFavGate = Completer<void>();
      final SearchViewModel vmQueuedDispose = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: _DelayedStorageService(
          prefs,
          getFavoritesCompleter: queuedFavGate,
        ),
      );
      final Future<void> firstQueued = vmQueuedDispose.toggleFavorite(jakarta);
      final Future<void> secondQueued = vmQueuedDispose.toggleFavorite(bandung);
      await Future<void>.delayed(Duration.zero);
      vmQueuedDispose.dispose();
      queuedFavGate.complete();
      await Future.wait(<Future<void>>[firstQueued, secondQueued]);
      expect(vmQueuedDispose.favorites, isEmpty);
    });
  });

  group('T5-VM-02: WeatherViewModel races & branch coverage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('dispose during initialize getSelectedLocation and during saveSelectedLocation completes safely', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final Completer<void> getSelectedGate = Completer<void>();
      final WeatherViewModel vm1 = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: _DelayedStorageService(
          prefs,
          getSelectedCompleter: getSelectedGate,
        ),
      );
      final Future<void> initFuture = vm1.initialize();
      await Future<void>.delayed(Duration.zero);
      vm1.dispose();
      getSelectedGate.complete();
      await initFuture;

      final Completer<void> saveSelectedGate = Completer<void>();
      final WeatherViewModel vm2 = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: _DelayedStorageService(
          prefs,
          saveSelectedCompleter: saveSelectedGate,
        ),
      );
      final Future<void> loadFuture = vm2.loadWeatherForLocation(jakarta);
      await Future<void>.delayed(Duration.zero);
      vm2.dispose();
      saveSelectedGate.complete();
      await loadFuture;
    });

    test('loadWeatherForLocation supersedes in-flight initialize', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await LocalStorageService(prefs).saveSelectedLocation(jakarta);

      final Completer<void> getSelectedGate = Completer<void>();
      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient(
            (http.Request _) async =>
                http.Response(weatherJson(temp: 24.5), 200),
          ),
        ),
        storageService: _DelayedStorageService(
          prefs,
          getSelectedCompleter: getSelectedGate,
        ),
      );

      final Future<void> initFuture = vm.initialize();
      await Future<void>.delayed(Duration.zero);

      await vm.loadWeatherForLocation(bandung);
      getSelectedGate.complete();
      await initFuture;

      expect(vm.selectedLocation, equals(bandung));
      expect(vm.state, equals(ViewState.loaded));
      expect(vm.weather?.current.temperature2m, equals(24.5));
    });

    test('stale older request failing with HTTP 500 does not overwrite newer loaded city', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Completer<http.Response> firstCompleter =
          Completer<http.Response>();
      final Completer<http.Response> secondCompleter =
          Completer<http.Response>();
      int call = 0;

      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) {
            call++;
            return call == 1 ? firstCompleter.future : secondCompleter.future;
          }),
        ),
        storageService: LocalStorageService(prefs),
      );

      final Future<void> firstFuture = vm.loadWeatherForLocation(jakarta);
      await Future<void>.delayed(Duration.zero);
      final Future<void> secondFuture = vm.loadWeatherForLocation(bandung);
      await Future<void>.delayed(Duration.zero);

      secondCompleter.complete(http.Response(weatherJson(temp: 23.0), 200));
      await secondFuture;

      firstCompleter.complete(http.Response('Server Error', 500));
      await firstFuture;

      expect(vm.selectedLocation, equals(bandung));
      expect(vm.state, equals(ViewState.loaded));
      expect(vm.weather?.current.temperature2m, equals(23.0));
      expect(vm.errorMessage, isNull);
    });

    test('refreshWeather transitions error -> loading -> loaded and initial -> empty', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int call = 0;
      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) async {
            call++;
            if (call == 1) {
              return http.Response('fail', 500);
            }
            return http.Response(weatherJson(temp: 29.0), 200);
          }),
        ),
        storageService: LocalStorageService(prefs),
      );

      // From initial (unselected) -> empty.
      await vm.refreshWeather();
      expect(vm.state, equals(ViewState.empty));

      // Load fails -> error.
      await vm.loadWeatherForLocation(jakarta);
      expect(vm.state, equals(ViewState.error));

      // Refresh from error -> loading -> loaded.
      final List<ViewState> states = <ViewState>[];
      vm.addListener(() => states.add(vm.state));
      await vm.refreshWeather();
      expect(states, equals(<ViewState>[ViewState.loading, ViewState.loaded]));
      expect(vm.weather?.current.temperature2m, equals(29.0));
    });

    test('loadWeatherForLocation still reaches ViewState.loaded when saveSelectedLocation fails (PROBE-R2-A)', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int weatherCalls = 0;
      final WeatherViewModel vm = WeatherViewModel(
        weatherService: WeatherApiService(
          client: MockClient((http.Request _) async {
            weatherCalls++;
            return http.Response(weatherJson(temp: 29.5), 200);
          }),
        ),
        storageService: _DelayedStorageService(
          prefs,
          failSaveSelected: true,
        ),
      );

      await vm.loadWeatherForLocation(jakarta);

      expect(weatherCalls, equals(1));
      expect(vm.state, equals(ViewState.loaded));
      expect(vm.selectedLocation, equals(jakarta));
      expect(vm.weather?.current.temperature2m, equals(29.5));
      expect(vm.errorMessage, isNull);
    });
  });
}
