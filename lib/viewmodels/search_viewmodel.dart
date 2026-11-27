import 'package:flutter/foundation.dart';

import '../models/location_model.dart';
import '../services/geocoding_api_service.dart';
import '../services/local_storage_service.dart';
import 'view_state.dart';

export 'view_state.dart';

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required this._geocodingService,
    required this._storageService,
  });

  final GeocodingApiService _geocodingService;
  final LocalStorageService _storageService;

  ViewState _state = ViewState.initial;
  ViewState get state => _state;

  List<LocationModel> _results = <LocationModel>[];
  List<LocationModel> get results =>
      List<LocationModel>.unmodifiable(_results);

  List<LocationModel> _favorites = <LocationModel>[];
  List<LocationModel> get favorites =>
      List<LocationModel>.unmodifiable(_favorites);

  List<String> _searchHistory = <String>[];
  List<String> get searchHistory =>
      List<String>.unmodifiable(_searchHistory);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _lastQuery = '';
  String get lastQuery => _lastQuery;

  bool _disposed = false;
  int _activeSearchId = 0;
  int _favoritesVersion = 0;
  int _historyVersion = 0;
  Future<void> _favoriteQueue = Future<void>.value();

  Future<void> initialize() async {
    final int initialFavVersion = _favoritesVersion;
    final int initialHistoryVersion = _historyVersion;
    final List<LocationModel> loadedFavorites = await _storageService
        .getFavorites();
    final List<String> loadedHistory = await _storageService
        .getSearchHistory();
    if (_disposed) {
      return;
    }

    bool changed = false;
    if (_favoritesVersion == initialFavVersion) {
      _favorites = loadedFavorites;
      changed = true;
    }
    if (_historyVersion == initialHistoryVersion) {
      _searchHistory = loadedHistory;
      changed = true;
    }
    if (changed) {
      _safeNotifyListeners();
    }
  }

  Future<void> searchCities(String query) async {
    final int requestId = ++_activeSearchId;
    final String trimmed = query.trim();

    if (trimmed.isEmpty) {
      _lastQuery = '';
      _results = <LocationModel>[];
      _errorMessage = null;
      _state = ViewState.initial;
      _safeNotifyListeners();
      return;
    }

    _lastQuery = trimmed;
    _errorMessage = null;
    _state = ViewState.loading;
    _safeNotifyListeners();

    try {
      final List<LocationModel> found = await _geocodingService.searchCities(
        trimmed,
      );
      if (_disposed || requestId != _activeSearchId) {
        return;
      }

      try {
        await _storageService.addSearchHistory(trimmed);
        final List<String> updatedHistory = await _storageService
            .getSearchHistory();
        if (_disposed || requestId != _activeSearchId) {
          return;
        }
        _historyVersion++;
        _searchHistory = updatedHistory;
      } catch (_) {
        // Keep valid search results even if local history persistence fails.
      }

      _results = found;
      _errorMessage = null;
      _state = found.isEmpty ? ViewState.empty : ViewState.loaded;
    } catch (_) {
      if (_disposed || requestId != _activeSearchId) {
        return;
      }

      _results = <LocationModel>[];
      _errorMessage = 'Gagal mencari lokasi. Silakan coba lagi.';
      _state = ViewState.error;
    }

    _safeNotifyListeners();
  }

  Future<void> toggleFavorite(LocationModel location) {
    final Future<void> next = _favoriteQueue.then((_) async {
      if (_disposed) {
        return;
      }
      final bool currentlyFavorite = isFavorite(location.id);
      try {
        if (currentlyFavorite) {
          await _storageService.removeFavorite(location.id);
        } else {
          await _storageService.saveFavorite(location);
        }

        final List<LocationModel> updatedFavorites = await _storageService
            .getFavorites();
        if (_disposed) {
          return;
        }

        _favoritesVersion++;
        _favorites = updatedFavorites;
        _safeNotifyListeners();
      } catch (_) {
        // Preserve consistent in-memory state if local storage write fails.
      }
    });
    _favoriteQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  bool isFavorite(int locationId) {
    return _favorites.any((LocationModel item) => item.id == locationId);
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
