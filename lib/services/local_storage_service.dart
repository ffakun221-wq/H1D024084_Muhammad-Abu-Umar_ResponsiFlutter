import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_model.dart';

class LocalStorageService {
  LocalStorageService(SharedPreferences prefs) : _prefs = prefs;

  static const String favoritesKey = 'favorite_locations';
  static const String searchHistoryKey = 'search_history';
  static const String selectedLocationKey = 'selected_location';
  static const int maxSearchHistoryItems = 10;

  final SharedPreferences _prefs;
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _enqueueWrite<T>(Future<T> Function() action) {
    final Future<T> next = _writeQueue.then((_) => action());
    _writeQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Future<List<LocationModel>> getFavorites() async {
    try {
      final String? raw = _prefs.getString(favoritesKey);
      if (raw == null || raw.trim().isEmpty) {
        return <LocationModel>[];
      }

      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return <LocationModel>[];
      }

      final List<LocationModel> favorites = <LocationModel>[];
      final Set<int> seenIds = <int>{};

      for (final Object? item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            final LocationModel location = LocationModel.fromStorageJson(item);
            if (seenIds.add(location.id)) {
              favorites.add(location);
            }
          } catch (_) {
            // Skip corrupted individual favorite entry.
          }
        }
      }
      return favorites;
    } catch (_) {
      return <LocationModel>[];
    }
  }

  Future<void> saveFavorite(LocationModel location) {
    return _enqueueWrite(() async {
      final List<LocationModel> current = await getFavorites();
      current.removeWhere((LocationModel item) => item.id == location.id);
      current.insert(0, location);

      final String encoded = jsonEncode(
        current.map((LocationModel item) => item.toStorageJson()).toList(),
      );
      await _prefs.setString(favoritesKey, encoded);
    });
  }

  Future<void> removeFavorite(int locationId) {
    return _enqueueWrite(() async {
      final List<LocationModel> current = await getFavorites();
      current.removeWhere((LocationModel item) => item.id == locationId);

      final String encoded = jsonEncode(
        current.map((LocationModel item) => item.toStorageJson()).toList(),
      );
      await _prefs.setString(favoritesKey, encoded);
    });
  }

  Future<List<String>> getSearchHistory() async {
    try {
      final String? raw = _prefs.getString(searchHistoryKey);
      if (raw == null || raw.trim().isEmpty) {
        return <String>[];
      }

      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return <String>[];
      }

      final List<String> history = <String>[];
      final Set<String> seenLower = <String>{};

      for (final Object? item in decoded) {
        if (item is String) {
          final String trimmed = item.trim();
          if (trimmed.isNotEmpty && seenLower.add(trimmed.toLowerCase())) {
            history.add(trimmed);
            if (history.length >= maxSearchHistoryItems) {
              break;
            }
          }
        }
      }
      return history;
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> addSearchHistory(String query) {
    return _enqueueWrite(() async {
      final String trimmed = query.trim();
      if (trimmed.isEmpty) {
        return;
      }

      final List<String> current = await getSearchHistory();
      current.removeWhere(
        (String item) => item.toLowerCase() == trimmed.toLowerCase(),
      );
      current.insert(0, trimmed);

      if (current.length > maxSearchHistoryItems) {
        current.removeRange(maxSearchHistoryItems, current.length);
      }

      await _prefs.setString(searchHistoryKey, jsonEncode(current));
    });
  }

  Future<LocationModel?> getSelectedLocation() async {
    try {
      final String? raw = _prefs.getString(selectedLocationKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }

      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return LocationModel.fromStorageJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSelectedLocation(LocationModel location) {
    return _enqueueWrite(() async {
      final String encoded = jsonEncode(location.toStorageJson());
      await _prefs.setString(selectedLocationKey, encoded);
    });
  }
}
