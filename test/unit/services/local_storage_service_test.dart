import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:responsi_flutter/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalStorageService', () {
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

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('cold start returns empty favorites, empty history, and null selected location', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);

      expect(await storage.getFavorites(), isEmpty);
      expect(await storage.getSearchHistory(), isEmpty);
      expect(await storage.getSelectedLocation(), isNull);
    });

    test('saveFavorite persists across instances, deduplicates by id, and removeFavorite deletes', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage1 = LocalStorageService(prefs);

      await storage1.saveFavorite(jakarta);
      await storage1.saveFavorite(bandung);

      const LocationModel updatedJakarta = LocationModel(
        id: 1642911,
        name: 'DKI Jakarta',
        latitude: -6.21462,
        longitude: 106.84513,
        country: 'Indonesia',
        admin1: 'Jakarta Raya',
      );
      await storage1.saveFavorite(updatedJakarta);

      final LocalStorageService storage2 = LocalStorageService(prefs);
      final List<LocationModel> favorites = await storage2.getFavorites();
      expect(favorites, hasLength(2));
      expect(favorites[0], equals(updatedJakarta));
      expect(favorites[1], equals(bandung));

      await storage2.removeFavorite(999999);
      expect(await storage2.getFavorites(), hasLength(2));

      await storage2.removeFavorite(bandung.id);
      final List<LocationModel> remaining = await storage2.getFavorites();
      expect(remaining, hasLength(1));
      expect(remaining.first, equals(updatedJakarta));
    });

    test('addSearchHistory trims, deduplicates case-insensitively, and caps at 10', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage = LocalStorageService(prefs);

      await storage.addSearchHistory('');
      await storage.addSearchHistory('   ');
      expect(await storage.getSearchHistory(), isEmpty);

      for (int i = 1; i <= 11; i++) {
        await storage.addSearchHistory('Kota $i');
      }
      await storage.addSearchHistory('  kota 3  ');

      final List<String> history = await storage.getSearchHistory();
      expect(history, hasLength(LocalStorageService.maxSearchHistoryItems));
      expect(history.first, equals('kota 3'));
      expect(history.contains('Kota 1'), isFalse);
      expect(
        history.where((String item) => item.toLowerCase() == 'kota 3'),
        hasLength(1),
      );
    });

    test('saveSelectedLocation and getSelectedLocation roundtrip persists', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalStorageService storage1 = LocalStorageService(prefs);

      await storage1.saveSelectedLocation(jakarta);

      final LocalStorageService storage2 = LocalStorageService(prefs);
      expect(await storage2.getSelectedLocation(), equals(jakarta));
    });

    test('recovers safely from corrupted JSON, wrong root types, and wrong pref value types', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.favoritesKey: '{not valid json',
        LocalStorageService.searchHistoryKey: '{"not":"a list"}',
        LocalStorageService.selectedLocationKey: '["not","an object"]',
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      LocalStorageService storage = LocalStorageService(prefs);

      expect(await storage.getFavorites(), isEmpty);
      expect(await storage.getSearchHistory(), isEmpty);
      expect(await storage.getSelectedLocation(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.favoritesKey: 12345,
        LocalStorageService.searchHistoryKey: <String>['raw_list_type'],
        LocalStorageService.selectedLocationKey: true,
      });
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);

      expect(await storage.getFavorites(), isEmpty);
      expect(await storage.getSearchHistory(), isEmpty);
      expect(await storage.getSelectedLocation(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalStorageService.favoritesKey: jsonEncode(<dynamic>[
          'bad_item',
          <String, dynamic>{'id': 'invalid'},
          jakarta.toStorageJson(),
        ]),
      });
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);

      final List<LocationModel> recovered = await storage.getFavorites();
      expect(recovered, hasLength(1));
      expect(recovered.first, equals(jakarta));
    });
  });
}
