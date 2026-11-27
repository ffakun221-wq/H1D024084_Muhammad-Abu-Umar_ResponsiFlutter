import 'dart:math' as math;

class CurrentWeather {
  const CurrentWeather({
    required this.temperature2m,
    required this.relativeHumidity2m,
    required this.apparentTemperature,
    required this.precipitation,
    required this.weatherCode,
    required this.windSpeed10m,
  });

  final double temperature2m;
  final int relativeHumidity2m;
  final double apparentTemperature;
  final double precipitation;
  final int weatherCode;
  final double windSpeed10m;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature2m: _readDouble(json, 'temperature_2m'),
      relativeHumidity2m: _readInt(json, 'relative_humidity_2m'),
      apparentTemperature: _readDouble(json, 'apparent_temperature'),
      precipitation: _readDouble(json, 'precipitation'),
      weatherCode: _readInt(json, 'weather_code'),
      windSpeed10m: _readDouble(json, 'wind_speed_10m'),
    );
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! num || !value.isFinite) {
      throw FormatException(
        'Invalid or missing "current.$key": expected finite num',
      );
    }
    return value.toDouble();
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! num || !value.isFinite) {
      throw FormatException(
        'Invalid or missing "current.$key": expected finite num',
      );
    }
    return value.round();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CurrentWeather &&
        other.temperature2m == temperature2m &&
        other.relativeHumidity2m == relativeHumidity2m &&
        other.apparentTemperature == apparentTemperature &&
        other.precipitation == precipitation &&
        other.weatherCode == weatherCode &&
        other.windSpeed10m == windSpeed10m;
  }

  @override
  int get hashCode => Object.hash(
    temperature2m,
    relativeHumidity2m,
    apparentTemperature,
    precipitation,
    weatherCode,
    windSpeed10m,
  );

  @override
  String toString() {
    return 'CurrentWeather('
        'temperature2m: $temperature2m, '
        'relativeHumidity2m: $relativeHumidity2m, '
        'apparentTemperature: $apparentTemperature, '
        'precipitation: $precipitation, '
        'weatherCode: $weatherCode, '
        'windSpeed10m: $windSpeed10m'
        ')';
  }
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.temperature2mMax,
    required this.temperature2mMin,
    required this.precipitationProbabilityMax,
  });

  final String date;
  final double temperature2mMax;
  final double temperature2mMin;
  final int precipitationProbabilityMax;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DailyForecast &&
        other.date == date &&
        other.temperature2mMax == temperature2mMax &&
        other.temperature2mMin == temperature2mMin &&
        other.precipitationProbabilityMax == precipitationProbabilityMax;
  }

  @override
  int get hashCode => Object.hash(
    date,
    temperature2mMax,
    temperature2mMin,
    precipitationProbabilityMax,
  );

  @override
  String toString() {
    return 'DailyForecast('
        'date: $date, '
        'temperature2mMax: $temperature2mMax, '
        'temperature2mMin: $temperature2mMin, '
        'precipitationProbabilityMax: $precipitationProbabilityMax'
        ')';
  }
}

class WeatherModel {
  const WeatherModel({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.current,
    required this.daily,
  });

  final double latitude;
  final double longitude;
  final String timezone;
  final CurrentWeather current;
  final List<DailyForecast> daily;

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final Object? latRaw = json['latitude'];
    if (latRaw is! num || !latRaw.isFinite) {
      throw const FormatException(
        'Invalid or missing "latitude" field in weather response',
      );
    }

    final Object? lonRaw = json['longitude'];
    if (lonRaw is! num || !lonRaw.isFinite) {
      throw const FormatException(
        'Invalid or missing "longitude" field in weather response',
      );
    }

    final Object? timezoneRaw = json['timezone'];
    if (timezoneRaw is! String || timezoneRaw.trim().isEmpty) {
      throw const FormatException(
        'Invalid or missing "timezone" field in weather response',
      );
    }

    final Object? currentRaw = json['current'];
    if (currentRaw is! Map) {
      throw const FormatException(
        'Invalid or missing "current" object in weather response',
      );
    }
    final Map<String, dynamic> currentMap = _toStringKeyedMap(
      currentRaw,
      'Invalid or missing "current" object in weather response',
    );

    final Object? dailyRaw = json['daily'];
    if (dailyRaw is! Map) {
      throw const FormatException(
        'Invalid or missing "daily" object in weather response',
      );
    }
    final Map<String, dynamic> dailyMap = _toStringKeyedMap(
      dailyRaw,
      'Invalid or missing "daily" object in weather response',
    );

    final Object? timesRaw = dailyMap['time'];
    final Object? maxRaw = dailyMap['temperature_2m_max'];
    final Object? minRaw = dailyMap['temperature_2m_min'];
    final Object? probRaw = dailyMap['precipitation_probability_max'];

    if (timesRaw is! List<dynamic> ||
        maxRaw is! List<dynamic> ||
        minRaw is! List<dynamic> ||
        probRaw is! List<dynamic>) {
      throw const FormatException(
        'Invalid or missing daily forecast arrays in weather response',
      );
    }

    final int count = <int>[
      timesRaw.length,
      maxRaw.length,
      minRaw.length,
      probRaw.length,
    ].reduce(math.min);

    final List<DailyForecast> dailyForecasts = List<DailyForecast>.generate(
      count,
      (int i) {
        final Object? dateVal = timesRaw[i];
        if (dateVal is! String || dateVal.trim().isEmpty) {
          throw FormatException('Invalid daily.time at index $i');
        }

        final Object? maxVal = maxRaw[i];
        if (maxVal is! num || !maxVal.isFinite) {
          throw FormatException('Invalid daily.temperature_2m_max at index $i');
        }

        final Object? minVal = minRaw[i];
        if (minVal is! num || !minVal.isFinite) {
          throw FormatException('Invalid daily.temperature_2m_min at index $i');
        }

        final Object? probVal = probRaw[i];
        final int precipProb;
        if (probVal == null) {
          precipProb = 0;
        } else if (probVal is num && probVal.isFinite) {
          precipProb = probVal.round();
        } else {
          throw FormatException(
            'Invalid daily.precipitation_probability_max at index $i',
          );
        }

        return DailyForecast(
          date: dateVal,
          temperature2mMax: maxVal.toDouble(),
          temperature2mMin: minVal.toDouble(),
          precipitationProbabilityMax: precipProb,
        );
      },
      growable: false,
    );

    return WeatherModel(
      latitude: latRaw.toDouble(),
      longitude: lonRaw.toDouble(),
      timezone: timezoneRaw,
      current: CurrentWeather.fromJson(currentMap),
      daily: List<DailyForecast>.unmodifiable(dailyForecasts),
    );
  }

  static Map<String, dynamic> _toStringKeyedMap(
    Map<dynamic, dynamic> raw,
    String errorMessage,
  ) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (!raw.keys.every((Object? k) => k is String)) {
      throw FormatException(errorMessage);
    }
    return Map<String, dynamic>.from(raw);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! WeatherModel ||
        other.latitude != latitude ||
        other.longitude != longitude ||
        other.timezone != timezone ||
        other.current != current ||
        other.daily.length != daily.length) {
      return false;
    }
    for (int i = 0; i < daily.length; i++) {
      if (other.daily[i] != daily[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    timezone,
    current,
    Object.hashAll(daily),
  );

  @override
  String toString() {
    return 'WeatherModel('
        'latitude: $latitude, '
        'longitude: $longitude, '
        'timezone: $timezone, '
        'current: $current, '
        'daily: $daily'
        ')';
  }
}
