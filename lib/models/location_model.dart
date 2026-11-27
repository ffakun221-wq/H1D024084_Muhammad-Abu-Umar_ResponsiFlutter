class LocationModel {
  const LocationModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.admin1,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? country;
  final String? admin1;

  factory LocationModel.fromGeocodingJson(Map<String, dynamic> json) {
    return _fromMap(json);
  }

  factory LocationModel.fromStorageJson(Map<String, dynamic> json) {
    return _fromMap(json);
  }

  static LocationModel _fromMap(Map<String, dynamic> json) {
    return LocationModel(
      id: _readInt(json, 'id'),
      name: _readRequiredString(json, 'name'),
      latitude: _readDouble(json, 'latitude'),
      longitude: _readDouble(json, 'longitude'),
      country: _readOptionalString(json, 'country'),
      admin1: _readOptionalString(json, 'admin1'),
    );
  }

  Map<String, dynamic> toStorageJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'country': country,
      'admin1': admin1,
    };
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! num || !value.isFinite) {
      throw FormatException(
        'Invalid or missing "$key" field: expected finite num',
      );
    }
    return value.round();
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! num || !value.isFinite) {
      throw FormatException(
        'Invalid or missing "$key" field: expected finite num',
      );
    }
    return value.toDouble();
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Invalid or missing "$key" field: expected non-empty String',
      );
    }
    return value;
  }

  static String? _readOptionalString(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('Invalid "$key" field: expected String or null');
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : value;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LocationModel &&
        other.id == id &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.country == country &&
        other.admin1 == admin1;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, latitude, longitude, country, admin1);

  @override
  String toString() {
    return 'LocationModel('
        'id: $id, '
        'name: $name, '
        'latitude: $latitude, '
        'longitude: $longitude, '
        'country: $country, '
        'admin1: $admin1'
        ')';
  }
}
