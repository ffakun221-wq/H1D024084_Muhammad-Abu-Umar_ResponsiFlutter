import 'package:flutter_test/flutter_test.dart';
import 'package:responsi_flutter/models/location_model.dart';

void main() {
  group('LocationModel', () {
    test('fromGeocodingJson parses full payload accurately', () {
      final LocationModel location = LocationModel.fromGeocodingJson(
        <String, dynamic>{
          'id': 1642911,
          'name': 'Jakarta',
          'latitude': -6.21462,
          'longitude': 106.84513,
          'country': 'Indonesia',
          'admin1': 'Jakarta Raya',
        },
      );

      expect(location.id, equals(1642911));
      expect(location.name, equals('Jakarta'));
      expect(location.latitude, equals(-6.21462));
      expect(location.longitude, equals(106.84513));
      expect(location.country, equals('Indonesia'));
      expect(location.admin1, equals('Jakarta Raya'));
    });

    test('fromGeocodingJson accepts absent, null, or blank country and admin1', () {
      final LocationModel absentOptional = LocationModel.fromGeocodingJson(
        <String, dynamic>{
          'id': 1,
          'name': 'Kepulauan Seribu',
          'latitude': -5.6,
          'longitude': 106.5,
        },
      );
      expect(absentOptional.country, isNull);
      expect(absentOptional.admin1, isNull);

      final LocationModel blankOptional = LocationModel.fromGeocodingJson(
        <String, dynamic>{
          'id': 2,
          'name': 'Sabang',
          'latitude': 5.89,
          'longitude': 95.32,
          'country': null,
          'admin1': '   ',
        },
      );
      expect(blankOptional.country, isNull);
      expect(blankOptional.admin1, isNull);
    });

    test('fromGeocodingJson casts integer numeric fields via num', () {
      final LocationModel location = LocationModel.fromGeocodingJson(
        <String, dynamic>{
          'id': 100.0,
          'name': 'Pontianak',
          'latitude': 0,
          'longitude': 109,
          'country': 'Indonesia',
        },
      );

      expect(location.id, equals(100));
      expect(location.latitude, equals(0.0));
      expect(location.longitude, equals(109.0));
    });

    test('fromGeocodingJson throws FormatException on missing or invalid fields', () {
      expect(
        () => LocationModel.fromGeocodingJson(<String, dynamic>{
          'name': 'Jakarta',
          'latitude': -6.2,
          'longitude': 106.8,
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LocationModel.fromGeocodingJson(<String, dynamic>{
          'id': 1,
          'name': '   ',
          'latitude': -6.2,
          'longitude': 106.8,
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LocationModel.fromGeocodingJson(<String, dynamic>{
          'id': 1,
          'name': 'Jakarta',
          'latitude': 'invalid',
          'longitude': 106.8,
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => LocationModel.fromGeocodingJson(<String, dynamic>{
          'id': 1,
          'name': 'Jakarta',
          'latitude': -6.2,
          'longitude': 106.8,
          'country': 123,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('toStorageJson and fromStorageJson roundtrip preserves all fields', () {
      const LocationModel full = LocationModel(
        id: 1650357,
        name: 'Bandung',
        latitude: -6.92222,
        longitude: 107.60694,
        country: 'Indonesia',
        admin1: 'Jawa Barat',
      );
      final LocationModel roundtripFull = LocationModel.fromStorageJson(
        full.toStorageJson(),
      );
      expect(roundtripFull, equals(full));
      expect(roundtripFull.hashCode, equals(full.hashCode));

      const LocationModel minimal = LocationModel(
        id: 99,
        name: 'Pulau Contoh',
        latitude: 0.0,
        longitude: 100.0,
      );
      final LocationModel roundtripMinimal = LocationModel.fromStorageJson(
        minimal.toStorageJson(),
      );
      expect(roundtripMinimal, equals(minimal));
      expect(roundtripMinimal.country, isNull);
      expect(roundtripMinimal.admin1, isNull);

      final LocationModel coerced = LocationModel.fromStorageJson(
        <String, dynamic>{
          'id': 50,
          'name': 'Solo',
          'latitude': -7,
          'longitude': 110,
          'country': 'Indonesia',
          'admin1': null,
        },
      );
      expect(coerced.latitude, equals(-7.0));
      expect(coerced.longitude, equals(110.0));
    });
  });
}
