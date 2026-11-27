import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_model.dart';

class WeatherApiService {
  WeatherApiService({
    http.Client? client,
    this._timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const String _host = 'api.open-meteo.com';
  static const String _path = '/v1/forecast';
  static const String _currentVariables =
      'temperature_2m,'
      'relative_humidity_2m,'
      'apparent_temperature,'
      'precipitation,'
      'weather_code,'
      'wind_speed_10m';
  static const String _dailyVariables =
      'temperature_2m_max,'
      'temperature_2m_min,'
      'precipitation_probability_max';

  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;

  Future<WeatherModel> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final Uri uri = Uri.https(_host, _path, <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': _currentVariables,
      'daily': _dailyVariables,
      'timezone': 'auto',
    });

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Permintaan data cuaca melebihi batas waktu.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal mengambil data cuaca (HTTP ${response.statusCode}).',
      );
    }

    final Object? decoded = jsonDecode(_decodeResponseBody(response));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Format respons cuaca tidak valid: objek JSON diharapkan.',
      );
    }

    if (decoded['error'] == true) {
      throw Exception(
        decoded['reason']?.toString() ??
            'Terjadi kesalahan pada API cuaca Open-Meteo.',
      );
    }

    return WeatherModel.fromJson(decoded);
  }

  String _decodeResponseBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return response.body;
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
