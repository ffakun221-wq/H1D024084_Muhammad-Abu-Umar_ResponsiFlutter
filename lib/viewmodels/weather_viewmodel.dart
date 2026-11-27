import 'package:flutter/foundation.dart';

import '../models/location_model.dart';
import '../models/weather_model.dart';
import '../services/local_storage_service.dart';
import '../services/weather_api_service.dart';
import 'view_state.dart';

export 'view_state.dart';

class WeatherViewModel extends ChangeNotifier {
  WeatherViewModel({
    required this._weatherService,
    required this._storageService,
  });

  final WeatherApiService _weatherService;
  final LocalStorageService _storageService;

  ViewState _state = ViewState.initial;
  ViewState get state => _state;

  LocationModel? _selectedLocation;
  LocationModel? get selectedLocation => _selectedLocation;

  WeatherModel? _weather;
  WeatherModel? get weather => _weather;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _disposed = false;
  int _activeRequestId = 0;

  Future<void> initialize() async {
    final int initRequestId = ++_activeRequestId;
    final LocationModel? savedLocation = await _storageService
        .getSelectedLocation();
    if (_disposed || initRequestId != _activeRequestId) {
      return;
    }

    if (savedLocation == null) {
      _selectedLocation = null;
      _weather = null;
      _errorMessage = null;
      _state = ViewState.empty;
      _safeNotifyListeners();
      return;
    }

    await _fetchWeatherForLocation(savedLocation, persistSelection: false);
  }

  Future<void> loadWeatherForLocation(LocationModel location) async {
    await _fetchWeatherForLocation(location, persistSelection: true);
  }

  Future<void> refreshWeather() async {
    final LocationModel? current = _selectedLocation;
    if (current == null) {
      _weather = null;
      _errorMessage = null;
      _state = ViewState.empty;
      _safeNotifyListeners();
      return;
    }

    await _fetchWeatherForLocation(current, persistSelection: false);
  }

  Future<void> _fetchWeatherForLocation(
    LocationModel location, {
    required bool persistSelection,
  }) async {
    final int requestId = ++_activeRequestId;
    final bool isDifferentLocation = _selectedLocation?.id != location.id;

    _selectedLocation = location;
    if (isDifferentLocation) {
      _weather = null;
    }
    _errorMessage = null;
    _state = ViewState.loading;
    _safeNotifyListeners();

    if (persistSelection) {
      try {
        await _storageService.saveSelectedLocation(location);
      } catch (_) {
        // Keep loading live weather even if local selection persistence fails.
      }
      if (_disposed || requestId != _activeRequestId) {
        return;
      }
    }

    try {
      final WeatherModel fetchedWeather = await _weatherService.fetchWeather(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (_disposed || requestId != _activeRequestId) {
        return;
      }

      _weather = fetchedWeather;
      _errorMessage = null;
      _state = ViewState.loaded;
    } catch (_) {
      if (_disposed || requestId != _activeRequestId) {
        return;
      }

      _weather = null;
      _errorMessage = 'Gagal memuat data cuaca. Silakan coba lagi.';
      _state = ViewState.error;
    }

    _safeNotifyListeners();
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
