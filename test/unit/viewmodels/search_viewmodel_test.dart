import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/geocoding_api_service.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:responsi_flutter/viewmodels/search_viewmodel.dart';
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

  group('SearchViewModel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('starts in initial state with empty lists and null error', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: LocalStorageService(prefs),
      );

      expect(vm.state, equals(ViewState.initial));
      expect(vm.results, isEmpty);
      expect(vm.favorites, isEmpty);
      expect(vm.searchHistory, isEmpty);
      expect(vm.errorMessage, isNull);
    });

    test('initialize loads persisted favorites and searchHistory', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      await storage.saveFavorite(jakarta);
      await storage.addSearchHistory('Jakarta');

      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: storage,
      );

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      await vm.initialize();

      expect(notifyCount, equals(1));
      expect(vm.favorites, equals(<LocationModel>[jakarta]));
      expect(vm.searchHistory, equals(<String>['Jakarta']));
    });

    test('searchCities with whitespace resets state without HTTP call or history entry', () async {
      int httpCalls = 0;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);

      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async {
            httpCalls++;
            return http.Response('{}', 200);
          }),
        ),
        storageService: storage,
      );

      await vm.searchCities('   ');

      expect(vm.state, equals(ViewState.initial));
      expect(vm.results, isEmpty);
      expect(vm.errorMessage, isNull);
      expect(vm.searchHistory, isEmpty);
      expect(httpCalls, equals(0));
    });

    test('searchCities transitions loading -> loaded and persists search history on HTTP 200', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);

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
        storageService: storage,
      );

      final List<ViewState> states = <ViewState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.searchCities('  Jakarta  ');

      expect(states, equals(<ViewState>[ViewState.loading, ViewState.loaded]));
      expect(vm.results, equals(<LocationModel>[jakarta]));
      expect(vm.searchHistory, equals(<String>['Jakarta']));
      expect(await storage.getSearchHistory(), equals(<String>['Jakarta']));
      expect(vm.errorMessage, isNull);
    });

    test('searchCities transitions loading -> empty when results are empty', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient(
            (http.Request _) async => http.Response('{}', 200),
          ),
        ),
        storageService: LocalStorageService(prefs),
      );

      final List<ViewState> states = <ViewState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.searchCities('UnknownCity');

      expect(states, equals(<ViewState>[ViewState.loading, ViewState.empty]));
      expect(vm.results, isEmpty);
      expect(vm.errorMessage, isNull);
    });

    test('searchCities transitions loading -> error on HTTP 500', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient(
            (http.Request _) async => http.Response('error', 500),
          ),
        ),
        storageService: LocalStorageService(prefs),
      );

      final List<ViewState> states = <ViewState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.searchCities('Jakarta');

      expect(states, equals(<ViewState>[ViewState.loading, ViewState.error]));
      expect(vm.results, isEmpty);
      expect(vm.errorMessage, isNotNull);
    });

    test('toggleFavorite adds and removes favorites and persists to storage', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) async => http.Response('{}', 200)),
        ),
        storageService: storage,
      );

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      await vm.toggleFavorite(jakarta);
      expect(vm.isFavorite(jakarta.id), isTrue);
      expect(vm.favorites, equals(<LocationModel>[jakarta]));
      expect(await storage.getFavorites(), equals(<LocationModel>[jakarta]));
      expect(notifyCount, equals(1));

      await vm.toggleFavorite(jakarta);
      expect(vm.isFavorite(jakarta.id), isFalse);
      expect(vm.favorites, isEmpty);
      expect(await storage.getFavorites(), isEmpty);
      expect(notifyCount, equals(2));
    });

    test('dispose during pending search completes safely without throwing', () async {
      final Completer<http.Response> completer = Completer<http.Response>();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) => completer.future),
        ),
        storageService: LocalStorageService(prefs),
      );

      final Future<void> pending = vm.searchCities('Jakarta');
      await Future<void>.delayed(Duration.zero);
      vm.dispose();

      completer.complete(
        http.Response(
          jsonEncode(<String, dynamic>{
            'results': <dynamic>[jakarta.toStorageJson()],
          }),
          200,
        ),
      );
      await pending;
    });

    test('ignores stale response when newer search supersedes earlier one', () async {
      final Completer<http.Response> firstCompleter =
          Completer<http.Response>();
      final Completer<http.Response> secondCompleter =
          Completer<http.Response>();
      int callIndex = 0;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SearchViewModel vm = SearchViewModel(
        geocodingService: GeocodingApiService(
          client: MockClient((http.Request _) {
            callIndex++;
            return callIndex == 1
                ? firstCompleter.future
                : secondCompleter.future;
          }),
        ),
        storageService: LocalStorageService(prefs),
      );

      final Future<void> firstFuture = vm.searchCities('Jakarta');
      final Future<void> secondFuture = vm.searchCities('Bandung');

      secondCompleter.complete(
        http.Response(
          jsonEncode(<String, dynamic>{
            'results': <dynamic>[bandung.toStorageJson()],
          }),
          200,
        ),
      );
      await secondFuture;
      firstCompleter.complete(
        http.Response(
          jsonEncode(<String, dynamic>{
            'results': <dynamic>[jakarta.toStorageJson()],
          }),
          200,
        ),
      );
      await firstFuture;

      expect(vm.results, equals(<LocationModel>[bandung]));
      expect(vm.state, equals(ViewState.loaded));
    });
  });
}
