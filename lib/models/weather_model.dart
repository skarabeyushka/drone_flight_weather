/// Тип опадів — для детальної інформації в плитці
enum PrecipitationType { none, fog, mist, drizzle, rain, heavyRain, snow, sleet, thunderstorm }

class WeatherModel {
  final double temperature;
  final int pressure;
  final double windSpeed;
  final double windGust;
  final int windDirection;
  final bool hasPrecipitation;
  final int visibility;
  final DateTime timestamp;
  final int weatherId;
  final String weatherDescription;
  final double humidity;

  /// Кількість опадів, мм/год (нормалізовано)
  final double precipitationMm;

  /// Ймовірність опадів 0.0..1.0 (POP від OWM)
  final double precipitationProbability;

  WeatherModel({
    required this.temperature,
    required this.pressure,
    required this.windSpeed,
    required this.windGust,
    required this.windDirection,
    required this.hasPrecipitation,
    required this.visibility,
    required this.timestamp,
    this.weatherId = 800,
    this.weatherDescription = '',
    this.humidity = 50,
    this.precipitationMm = 0.0,
    this.precipitationProbability = 0.0,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final main = json['main'];
    final wind = json['wind'];
    final weatherList = json['weather'] as List;
    final visibility = json['visibility'] as int? ?? 10000;

    bool precipitation = false;
    int wId = 800;
    String wDesc = '';

    if (weatherList.isNotEmpty) {
      wId = weatherList[0]['id'] as int;
      wDesc = weatherList[0]['description'] as String? ?? '';
      if (wId < 700) precipitation = true;
    }

    // Кількість опадів (rain/snow, 1h або 3h — беремо більше)
    double precipMm = 0.0;
    if (json['rain'] != null) {
      final rain = json['rain'] as Map<String, dynamic>;
      precipMm = ((rain['1h'] ?? rain['3h'] ?? 0.0) as num).toDouble();
    }
    if (json['snow'] != null) {
      final snow = json['snow'] as Map<String, dynamic>;
      precipMm += ((snow['1h'] ?? snow['3h'] ?? 0.0) as num).toDouble();
    }
    if (precipMm > 0) precipitation = true;

    // POP — ймовірність опадів
    final pop = (json['pop'] as num?)?.toDouble() ?? 0.0;

    DateTime time;
    if (json.containsKey('dt')) {
      time = DateTime.fromMillisecondsSinceEpoch(
        (json['dt'] as int) * 1000,
        isUtc: true,
      ).toLocal();
    } else {
      time = DateTime.now();
    }

    return WeatherModel(
      temperature: (main['temp'] as num).toDouble(),
      pressure: (main['pressure'] as num).toInt(),
      windSpeed: (wind['speed'] as num).toDouble(),
      windGust: (wind['gust'] as num?)?.toDouble() ??
          (wind['speed'] as num).toDouble(),
      windDirection: (wind['deg'] as num?)?.toInt() ?? 0,
      hasPrecipitation: precipitation,
      visibility: visibility,
      timestamp: time,
      weatherId: wId,
      weatherDescription: wDesc,
      humidity: (main['humidity'] as num?)?.toDouble() ?? 50,
      precipitationMm: precipMm,
      precipitationProbability: pop,
    );
  }

  // ─── Лінійна інтерполяція між двома точками (для погодинного прогнозу) ─────
  static WeatherModel interpolate(WeatherModel a, WeatherModel b, double t) {
    return WeatherModel(
      temperature: _lerp(a.temperature, b.temperature, t),
      pressure: _lerpInt(a.pressure, b.pressure, t),
      windSpeed: _lerp(a.windSpeed, b.windSpeed, t),
      windGust: _lerp(a.windGust, b.windGust, t),
      windDirection: _lerpAngle(a.windDirection, b.windDirection, t),
      hasPrecipitation: t < 0.5 ? a.hasPrecipitation : b.hasPrecipitation,
      visibility: _lerpInt(a.visibility, b.visibility, t),
      timestamp: a.timestamp.add(Duration(
          milliseconds:
              ((b.timestamp.millisecondsSinceEpoch -
                          a.timestamp.millisecondsSinceEpoch) *
                      t)
                  .round())),
      weatherId: t < 0.5 ? a.weatherId : b.weatherId,
      weatherDescription:
          t < 0.5 ? a.weatherDescription : b.weatherDescription,
      humidity: _lerp(a.humidity, b.humidity, t),
      precipitationMm: _lerp(a.precipitationMm, b.precipitationMm, t),
      precipitationProbability:
          _lerp(a.precipitationProbability, b.precipitationProbability, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
  static int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round();
  static int _lerpAngle(int a, int b, double t) {
    int diff = b - a;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return ((a + diff * t) % 360).round();
  }

  // ─── Тип опадів за weather ID ──────────────────────────────────────────────
  PrecipitationType get precipitationType {
    if (weatherId >= 200 && weatherId < 300) return PrecipitationType.thunderstorm;
    if (weatherId >= 300 && weatherId < 400) return PrecipitationType.drizzle;
    if (weatherId >= 500 && weatherId < 502) return PrecipitationType.rain;
    if (weatherId >= 502 && weatherId < 600) return PrecipitationType.heavyRain;
    if (weatherId >= 600 && weatherId < 620) return PrecipitationType.snow;
    if (weatherId >= 620 && weatherId < 700) return PrecipitationType.sleet;
    if (weatherId == 701 || weatherId == 741) return PrecipitationType.fog;
    if (weatherId >= 700 && weatherId < 800) return PrecipitationType.mist;
    return PrecipitationType.none;
  }

  /// Назва типу опадів для відображення
  String get precipitationTypeName {
    switch (precipitationType) {
      case PrecipitationType.none: return 'Без опадів';
      case PrecipitationType.fog: return 'Туман';
      case PrecipitationType.mist: return 'Імла / серпанок';
      case PrecipitationType.drizzle: return 'Мряка';
      case PrecipitationType.rain: return 'Дощ';
      case PrecipitationType.heavyRain: return 'Сильний дощ';
      case PrecipitationType.snow: return 'Сніг';
      case PrecipitationType.sleet: return 'Мокрий сніг';
      case PrecipitationType.thunderstorm: return 'Гроза';
    }
  }

  /// Інтенсивність за мм/год
  String get precipitationIntensity {
    if (precipitationMm == 0) return '';
    if (precipitationMm < 0.5) return 'слабка (${precipitationMm.toStringAsFixed(1)} мм/год)';
    if (precipitationMm < 2.0) return 'помірна (${precipitationMm.toStringAsFixed(1)} мм/год)';
    if (precipitationMm < 10.0) return 'сильна (${precipitationMm.toStringAsFixed(1)} мм/год)';
    return 'дуже сильна (${precipitationMm.toStringAsFixed(1)} мм/год)';
  }

  /// Ймовірність опадів у відсотках
  String get precipProbabilityStr =>
      '${(precipitationProbability * 100).round()}%';

  // ─── Напрям вітру ──────────────────────────────────────────────────────────
  String get windFromDirection => _degToDirection(windDirection);
  String get windToDirection => _degToDirection((windDirection + 180) % 360);

  static String _degToDirection(int deg) {
    const directions = [
      'Пн', 'Пн-Пн-Сх', 'Пн-Сх', 'Сх-Пн-Сх',
      'Сх', 'Сх-Пд-Сх', 'Пд-Сх', 'Пд-Пд-Сх',
      'Пд', 'Пд-Пд-Зх', 'Пд-Зх', 'Зх-Пд-Зх',
      'Зх', 'Зх-Пн-Зх', 'Пн-Зх', 'Пн-Пн-Зх',
    ];
    final index = ((deg % 360) / 22.5).round() % 16;
    return directions[index];
  }
}
