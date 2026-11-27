import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_model.dart';

class GeocodingApiService {
  GeocodingApiService({
    http.Client? client,
    this._timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const String _host = 'geocoding-api.open-meteo.com';
  static const String _path = '/v1/search';

  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;

  Future<List<LocationModel>> searchCities(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return <LocationModel>[];
    }

    final Uri uri = Uri.https(_host, _path, <String, String>{
      'name': trimmed,
      'count': '10',
      'language': 'id',
      'format': 'json',
    });

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Permintaan pencarian lokasi melebihi batas waktu.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal mencari lokasi (HTTP ${response.statusCode}).',
      );
    }

    final Object? decoded = jsonDecode(_decodeResponseBody(response));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Format respons pencarian lokasi tidak valid: objek JSON diharapkan.',
      );
    }

    if (decoded['error'] == true) {
      throw Exception(
        decoded['reason']?.toString() ??
            'Terjadi kesalahan pada API geocoding Open-Meteo.',
      );
    }

    final Object? resultsRaw = decoded['results'];
    if (resultsRaw == null) {
      return <LocationModel>[];
    }

    if (resultsRaw is! List<dynamic>) {
      throw const FormatException(
        'Format respons pencarian lokasi tidak valid: daftar results diharapkan.',
      );
    }

    if (resultsRaw.isEmpty) {
      return <LocationModel>[];
    }

    final List<LocationModel> locations = <LocationModel>[];
    for (final Object? item in resultsRaw) {
      if (item is! Map) {
        throw const FormatException(
          'Format item lokasi tidak valid: objek JSON diharapkan.',
        );
      }
      final Map<String, dynamic> itemMap;
      if (item is Map<String, dynamic>) {
        itemMap = item;
      } else {
        if (!item.keys.every((Object? k) => k is String)) {
          throw const FormatException(
            'Format item lokasi tidak valid: kunci String diharapkan.',
          );
        }
        itemMap = Map<String, dynamic>.from(item);
      }
      locations.add(LocationModel.fromGeocodingJson(itemMap));
    }

    return locations;
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
