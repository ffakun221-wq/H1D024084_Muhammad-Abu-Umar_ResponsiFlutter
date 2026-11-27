import 'package:flutter_test/flutter_test.dart';
import 'package:responsi_flutter/models/weather_model.dart';

void main() {
  group('WeatherModel', () {
    test('fromJson parses all required current and daily fields', () {
      final WeatherModel weather = WeatherModel.fromJson(<String, dynamic>{
        'latitude': -6.25,
        'longitude': 106.875,
        'timezone': 'Asia/Jakarta',
        'current': <String, dynamic>{
          'temperature_2m': 30.4,
          'relative_humidity_2m': 72,
          'apparent_temperature': 34.1,
          'precipitation': 1.2,
          'weather_code': 61,
          'wind_speed_10m': 11.5,
        },
        'daily': <String, dynamic>{
          'time': <dynamic>['2026-11-26', '2026-11-27'],
          'temperature_2m_max': <dynamic>[32.5, 31.8],
          'temperature_2m_min': <dynamic>[24.2, 23.9],
          'precipitation_probability_max': <dynamic>[80, 45],
        },
      });

      expect(weather.latitude, equals(-6.25));
      expect(weather.longitude, equals(106.875));
      expect(weather.timezone, equals('Asia/Jakarta'));
      expect(weather.current.temperature2m, equals(30.4));
      expect(weather.current.relativeHumidity2m, equals(72));
      expect(weather.current.apparentTemperature, equals(34.1));
      expect(weather.current.precipitation, equals(1.2));
      expect(weather.current.weatherCode, equals(61));
      expect(weather.current.windSpeed10m, equals(11.5));

      expect(weather.daily, hasLength(2));
      expect(weather.daily[0].date, equals('2026-11-26'));
      expect(weather.daily[0].temperature2mMax, equals(32.5));
      expect(weather.daily[0].temperature2mMin, equals(24.2));
      expect(weather.daily[0].precipitationProbabilityMax, equals(80));
      expect(weather.daily[1].date, equals('2026-11-27'));
      expect(weather.daily[1].precipitationProbabilityMax, equals(45));
    });

    test('fromJson handles mixed int and double numeric values via num', () {
      final WeatherModel weather = WeatherModel.fromJson(<String, dynamic>{
        'latitude': -6,
        'longitude': 107,
        'timezone': 'Asia/Jakarta',
        'current': <String, dynamic>{
          'temperature_2m': 28,
          'relative_humidity_2m': 78.6,
          'apparent_temperature': 30,
          'precipitation': 0,
          'weather_code': 3.0,
          'wind_speed_10m': 10,
        },
        'daily': <String, dynamic>{
          'time': <dynamic>['2026-11-26'],
          'temperature_2m_max': <dynamic>[31],
          'temperature_2m_min': <dynamic>[24],
          'precipitation_probability_max': <dynamic>[60.4],
        },
      });

      expect(weather.latitude, equals(-6.0));
      expect(weather.longitude, equals(107.0));
      expect(weather.current.temperature2m, equals(28.0));
      expect(weather.current.relativeHumidity2m, equals(79));
      expect(weather.current.apparentTemperature, equals(30.0));
      expect(weather.current.precipitation, equals(0.0));
      expect(weather.current.weatherCode, equals(3));
      expect(weather.current.windSpeed10m, equals(10.0));
      expect(weather.daily[0].temperature2mMax, equals(31.0));
      expect(weather.daily[0].temperature2mMin, equals(24.0));
      expect(weather.daily[0].precipitationProbabilityMax, equals(60));
    });

    test('fromJson maps null precipitation_probability_max elements to 0', () {
      final WeatherModel weather = WeatherModel.fromJson(<String, dynamic>{
        'latitude': -6.2,
        'longitude': 106.8,
        'timezone': 'Asia/Jakarta',
        'current': <String, dynamic>{
          'temperature_2m': 29,
          'relative_humidity_2m': 70,
          'apparent_temperature': 32,
          'precipitation': 0,
          'weather_code': 1,
          'wind_speed_10m': 5,
        },
        'daily': <String, dynamic>{
          'time': <dynamic>['2026-11-26', '2026-11-27', '2026-11-28'],
          'temperature_2m_max': <dynamic>[32, 33, 31],
          'temperature_2m_min': <dynamic>[24, 24, 23],
          'precipitation_probability_max': <dynamic>[80, null, 25],
        },
      });

      expect(weather.daily, hasLength(3));
      expect(weather.daily[0].precipitationProbabilityMax, equals(80));
      expect(weather.daily[1].precipitationProbabilityMax, equals(0));
      expect(weather.daily[2].precipitationProbabilityMax, equals(25));
    });

    test('fromJson aligns unequal daily array lengths to shortest list', () {
      final WeatherModel weather = WeatherModel.fromJson(<String, dynamic>{
        'latitude': -6.2,
        'longitude': 106.8,
        'timezone': 'Asia/Jakarta',
        'current': <String, dynamic>{
          'temperature_2m': 29,
          'relative_humidity_2m': 70,
          'apparent_temperature': 32,
          'precipitation': 0,
          'weather_code': 0,
          'wind_speed_10m': 6,
        },
        'daily': <String, dynamic>{
          'time': <dynamic>['2026-11-26', '2026-11-27', '2026-11-28'],
          'temperature_2m_max': <dynamic>[32, 33],
          'temperature_2m_min': <dynamic>[24, 25, 26, 27],
          'precipitation_probability_max': <dynamic>[10, 20, 30],
        },
      });

      expect(weather.daily, hasLength(2));
      expect(weather.daily[0].date, equals('2026-11-26'));
      expect(weather.daily[1].date, equals('2026-11-27'));
    });

    test('fromJson throws FormatException on missing or malformed sections', () {
      expect(
        () => WeatherModel.fromJson(<String, dynamic>{
          'latitude': -6.2,
          'longitude': 106.8,
          'timezone': 'Asia/Jakarta',
          'daily': <String, dynamic>{
            'time': <dynamic>[],
            'temperature_2m_max': <dynamic>[],
            'temperature_2m_min': <dynamic>[],
            'precipitation_probability_max': <dynamic>[],
          },
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => WeatherModel.fromJson(<String, dynamic>{
          'latitude': -6.2,
          'longitude': 106.8,
          'timezone': 'Asia/Jakarta',
          'current': <String, dynamic>{
            'temperature_2m': 29,
            'relative_humidity_2m': 70,
            'apparent_temperature': 32,
            'precipitation': 0,
            'weather_code': 0,
            'wind_speed_10m': 6,
          },
          'daily': 'invalid',
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => WeatherModel.fromJson(<String, dynamic>{
          'longitude': 106.8,
          'timezone': 'Asia/Jakarta',
          'current': <String, dynamic>{},
          'daily': <String, dynamic>{},
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
