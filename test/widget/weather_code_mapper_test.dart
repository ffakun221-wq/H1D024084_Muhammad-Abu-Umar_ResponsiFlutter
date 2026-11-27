// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsi_flutter/utils/weather_code_mapper.dart';

void main() {
  const List<int> standardWmoCodes = <int>[
    0,
    1,
    2,
    3,
    45,
    48,
    51,
    53,
    55,
    56,
    57,
    61,
    63,
    65,
    66,
    67,
    71,
    73,
    75,
    77,
    80,
    81,
    82,
    85,
    86,
    95,
    96,
    99,
  ];

  group('WeatherCodeMapper', () {
    test('maps all 28 standard WMO codes to non-empty text and icon', () {
      for (final int code in standardWmoCodes) {
        final WeatherCodeInfo info = WeatherCodeMapper.map(code);
        expect(info.description.trim(), isNotEmpty);
        expect(info.icon, isA<IconData>());
      }
    });

    test('produces distinct descriptions and icons for 0, 1, 80, and 95', () {
      final List<WeatherCodeInfo> samples = <WeatherCodeInfo>[
        WeatherCodeMapper.map(0),
        WeatherCodeMapper.map(1),
        WeatherCodeMapper.map(80),
        WeatherCodeMapper.map(95),
      ];

      expect(samples.map((WeatherCodeInfo i) => i.description).toSet().length, 4);
      expect(samples.map((WeatherCodeInfo i) => i.icon).toSet().length, 4);
    });

    test('returns safe fallback for unknown WMO codes', () {
      final WeatherCodeInfo negativeInfo = WeatherCodeMapper.map(-1);
      final WeatherCodeInfo unknownInfo = WeatherCodeMapper.map(999);

      expect(negativeInfo.description, 'Kondisi Cuaca Tidak Diketahui');
      expect(negativeInfo.icon, Icons.cloud_queue);
      expect(unknownInfo.description, 'Kondisi Cuaca Tidak Diketahui');
      expect(unknownInfo.icon, Icons.cloud_queue);
    });
  });
}
