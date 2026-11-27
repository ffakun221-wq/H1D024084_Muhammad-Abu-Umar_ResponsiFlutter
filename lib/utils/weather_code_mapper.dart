// ignore: deprecated_member_use
import 'package:flutter/material.dart';

class WeatherCodeInfo {
  const WeatherCodeInfo({
    required this.description,
    required this.icon,
  });

  final String description;
  final IconData icon;
}

abstract final class WeatherCodeMapper {
  static const WeatherCodeInfo _fallback = WeatherCodeInfo(
    description: 'Kondisi Cuaca Tidak Diketahui',
    icon: Icons.cloud_queue,
  );

  static const Map<int, WeatherCodeInfo> _codeMap = <int, WeatherCodeInfo>{
    0: WeatherCodeInfo(
      description: 'Cerah',
      icon: Icons.wb_sunny,
    ),
    1: WeatherCodeInfo(
      description: 'Sebagian Besar Cerah',
      icon: Icons.wb_sunny_outlined,
    ),
    2: WeatherCodeInfo(
      description: 'Berawan Sebagian',
      icon: Icons.wb_cloudy_outlined,
    ),
    3: WeatherCodeInfo(
      description: 'Mendung',
      icon: Icons.cloud,
    ),
    45: WeatherCodeInfo(
      description: 'Berkabut',
      icon: Icons.foggy,
    ),
    48: WeatherCodeInfo(
      description: 'Kabut Beku',
      icon: Icons.foggy,
    ),
    51: WeatherCodeInfo(
      description: 'Gerimis Ringan',
      icon: Icons.grain,
    ),
    53: WeatherCodeInfo(
      description: 'Gerimis Sedang',
      icon: Icons.grain,
    ),
    55: WeatherCodeInfo(
      description: 'Gerimis Lebat',
      icon: Icons.grain,
    ),
    56: WeatherCodeInfo(
      description: 'Gerimis Beku Ringan',
      icon: Icons.ac_unit,
    ),
    57: WeatherCodeInfo(
      description: 'Gerimis Beku Lebat',
      icon: Icons.ac_unit,
    ),
    61: WeatherCodeInfo(
      description: 'Hujan Ringan',
      icon: Icons.water_drop_outlined,
    ),
    63: WeatherCodeInfo(
      description: 'Hujan Sedang',
      icon: Icons.water_drop,
    ),
    65: WeatherCodeInfo(
      description: 'Hujan Lebat',
      icon: Icons.water_drop,
    ),
    66: WeatherCodeInfo(
      description: 'Hujan Beku Ringan',
      icon: Icons.ac_unit,
    ),
    67: WeatherCodeInfo(
      description: 'Hujan Beku Lebat',
      icon: Icons.ac_unit,
    ),
    71: WeatherCodeInfo(
      description: 'Salju Ringan',
      icon: Icons.ac_unit,
    ),
    73: WeatherCodeInfo(
      description: 'Salju Sedang',
      icon: Icons.ac_unit,
    ),
    75: WeatherCodeInfo(
      description: 'Salju Lebat',
      icon: Icons.ac_unit,
    ),
    77: WeatherCodeInfo(
      description: 'Butiran Salju',
      icon: Icons.ac_unit,
    ),
    80: WeatherCodeInfo(
      description: 'Hujan Deras Ringan',
      icon: Icons.umbrella_outlined,
    ),
    81: WeatherCodeInfo(
      description: 'Hujan Deras Sedang',
      icon: Icons.umbrella,
    ),
    82: WeatherCodeInfo(
      description: 'Hujan Deras Sangat Lebat',
      icon: Icons.umbrella,
    ),
    85: WeatherCodeInfo(
      description: 'Hujan Salju Ringan',
      icon: Icons.ac_unit,
    ),
    86: WeatherCodeInfo(
      description: 'Hujan Salju Lebat',
      icon: Icons.ac_unit,
    ),
    95: WeatherCodeInfo(
      description: 'Badai Petir',
      icon: Icons.thunderstorm,
    ),
    96: WeatherCodeInfo(
      description: 'Badai Petir dengan Hujan Es Ringan',
      icon: Icons.thunderstorm,
    ),
    99: WeatherCodeInfo(
      description: 'Badai Petir dengan Hujan Es Lebat',
      icon: Icons.thunderstorm,
    ),
  };

  static WeatherCodeInfo map(int weatherCode) {
    return _codeMap[weatherCode] ?? _fallback;
  }
}
