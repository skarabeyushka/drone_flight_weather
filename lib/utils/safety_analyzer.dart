import '../models/weather_model.dart';

enum FlightStatus { safe, warning, danger }

/// Тип дрона
enum DroneType {
  mavic,   // DJI Mavic, Mini, Air — компактні квадрокоптери
  fpv,     // FPV-дрони (перегонові та ударні)
  fixedWing, // Літакового типу (fixed wing)
  agri,    // Аграрні дрони (гексакоптери/октокоптери з обприскувачем)
}

class DroneFlightResult {
  final DroneType type;
  final bool canFly;
  final String reason;
  final String warning;

  const DroneFlightResult({
    required this.type,
    required this.canFly,
    required this.reason,
    this.warning = '',
  });

  String get typeName {
    switch (type) {
      case DroneType.mavic:
        return '🚁 Мавік / Mini / Air';
      case DroneType.fpv:
        return '🎯 FPV-дрон';
      case DroneType.fixedWing:
        return '✈️ Літаковий тип';
      case DroneType.agri:
        return '🌾 Аграрний дрон';
    }
  }
}

class SafetyAnalyzer {
  // ─── Загальна оцінка безпеки польоту ───────────────────────────────────────
  static FlightStatus evaluateFlightSafety(WeatherModel weather) {
    // Критичні умови → Небезпечно
    if (weather.windGust > 10.0 ||
        weather.windSpeed > 8.0 ||
        weather.hasPrecipitation ||
        weather.visibility < 1000) {
      return FlightStatus.danger;
    }

    // Попереджувальні умови
    if (weather.windSpeed >= 6.0 ||
        weather.windGust > 7.0 ||
        weather.visibility < 3000 ||
        weather.temperature < -10 ||
        weather.temperature > 40) {
      return FlightStatus.warning;
    }

    return FlightStatus.safe;
  }

  static String getStatusText(FlightStatus status) {
    switch (status) {
      case FlightStatus.safe:
        return 'МОЖНА ЛІТАТИ';
      case FlightStatus.warning:
        return 'З ОБЕРЕЖНІСТЮ';
      case FlightStatus.danger:
        return 'НЕБЕЗПЕЧНО';
    }
  }

  // ─── Статус КОНКРЕТНОГО параметра (ігнорує інші) ───────────────────────────
  /// Повертає (статус, короткий опис) лише для одного показника.
  /// Використовується в тижневому графіку всередині плитки — щоб
  /// температурна плитка показувала зелений навіть коли вітер заборонений.
  static (FlightStatus, String) parameterStatus(String title, WeatherModel w) {
    switch (title) {
      case 'Вітер':
        if (w.windSpeed > 8.0) return (FlightStatus.danger, 'Сильний вітер');
        if (w.windSpeed >= 6.0) return (FlightStatus.warning, 'Підвищений');
        return (FlightStatus.safe, 'Норма');
      case 'Пориви':
        if (w.windGust > 10.0) return (FlightStatus.danger, 'Небезпечні');
        if (w.windGust > 7.0) return (FlightStatus.warning, 'Значні');
        return (FlightStatus.safe, 'Слабкі');
      case 'Температура':
        if (w.temperature < -10 || w.temperature > 40)
          return (FlightStatus.danger, 'Критична');
        if (w.temperature < 0 || w.temperature > 35)
          return (FlightStatus.warning, 'Гранична');
        return (FlightStatus.safe, 'Комфортна');
      case 'Тиск':
        if (w.pressure < 980 || w.pressure > 1045)
          return (FlightStatus.warning, 'Відхилення');
        return (FlightStatus.safe, 'Норма');
      case 'Опади':
        if (w.hasPrecipitation) return (FlightStatus.danger, 'Є опади');
        if (w.precipitationProbability > 0.5)
          return (FlightStatus.warning, 'Ймов. ${(w.precipitationProbability * 100).round()}%');
        return (FlightStatus.safe, 'Без опадів');
      case 'Видимість':
        if (w.visibility < 1000) return (FlightStatus.danger, 'Туман');
        if (w.visibility < 3000) return (FlightStatus.warning, 'Обмежена');
        return (FlightStatus.safe, 'Гарна');
      default:
        return (FlightStatus.safe, 'Норма');
    }
  }

  // ─── Перелік конкретних причин заборони польоту ────────────────────────────
  static List<String> getBlockingFactors(WeatherModel w) {
    final factors = <String>[];
    if (w.windSpeed > 8.0)
      factors.add('🌬 Вітер ${w.windSpeed.toStringAsFixed(1)} м/с (макс. 8)');
    if (w.windGust > 10.0)
      factors.add('💨 Пориви ${w.windGust.toStringAsFixed(1)} м/с (макс. 10)');
    if (w.hasPrecipitation)
      factors.add('🌧 ${w.precipitationTypeName}${w.precipitationMm > 0 ? " — ${w.precipitationIntensity}" : ""} ');
    if (w.visibility < 1000)
      factors.add('🌫 Видимість лише ${w.visibility} м (мін. 1000)');
    if (w.temperature < -10)
      factors.add('🥶 Мороз ${w.temperature.toStringAsFixed(0)}°C (мін. -10)');
    if (w.temperature > 40)
      factors.add('🔥 Спека ${w.temperature.toStringAsFixed(0)}°C (макс. 40)');
    return factors;
  }

  // ─── Оцінка по типах дронів ────────────────────────────────────────────────
  static List<DroneFlightResult> evaluateByDroneType(WeatherModel weather) {
    return [
      _evaluateMavic(weather),
      _evaluateFpv(weather),
      _evaluateFixedWing(weather),
      _evaluateAgri(weather),
    ];
  }

  /// Мавік / Mini / Air — чутливі до вітру, не вологозахищені
  static DroneFlightResult _evaluateMavic(WeatherModel weather) {
    if (weather.hasPrecipitation) {
      return const DroneFlightResult(
        type: DroneType.mavic,
        canFly: false,
        reason: 'Опади пошкоджують електроніку',
      );
    }
    if (weather.windGust > 10.0 || weather.windSpeed > 8.0) {
      return const DroneFlightResult(
        type: DroneType.mavic,
        canFly: false,
        reason: 'Вітер / пориви перевищують норму (макс. 8 / 10 м/с)',
      );
    }
    if (weather.windSpeed > 6.0 || weather.windGust > 7.0) {
      return DroneFlightResult(
        type: DroneType.mavic,
        canFly: true,
        reason: 'Допустимо, але з обережністю',
        warning: 'Вітер ${weather.windSpeed.toStringAsFixed(1)} м/с — зменшити відстань від пілота',
      );
    }
    if (weather.temperature < -10) {
      return const DroneFlightResult(
        type: DroneType.mavic,
        canFly: false,
        reason: 'Мороз нижче -10°C — ризик замерзання батареї',
      );
    }
    return const DroneFlightResult(
      type: DroneType.mavic,
      canFly: true,
      reason: 'Умови сприятливі для польоту',
    );
  }

  /// FPV — більш маневрені, але без автостабілізації (ручне керування)
  static DroneFlightResult _evaluateFpv(WeatherModel weather) {
    if (weather.hasPrecipitation) {
      return const DroneFlightResult(
        type: DroneType.fpv,
        canFly: false,
        reason: 'Дощ/сніг — ризик КЗ в незахищеній електроніці',
      );
    }
    if (weather.windGust > 14.0 || weather.windSpeed > 12.0) {
      return const DroneFlightResult(
        type: DroneType.fpv,
        canFly: false,
        reason: 'Надмірний вітер — втрата керування в manual mode',
      );
    }
    if (weather.windSpeed > 9.0 || weather.windGust > 11.0) {
      return DroneFlightResult(
        type: DroneType.fpv,
        canFly: true,
        reason: 'Тільки для досвідчених пілотів у sheltered zone',
        warning: 'Пориви ${weather.windGust.toStringAsFixed(1)} м/с — висока турбулентність',
      );
    }
    if (weather.visibility < 500) {
      return const DroneFlightResult(
        type: DroneType.fpv,
        canFly: false,
        reason: 'Видимість < 500 м — втрата FPV-сигналу та орієнтації',
      );
    }
    return const DroneFlightResult(
      type: DroneType.fpv,
      canFly: true,
      reason: 'Умови прийнятні для FPV-польоту',
    );
  }

  /// Літаковий тип — потребує простору, чутливий до бокового вітру
  static DroneFlightResult _evaluateFixedWing(WeatherModel weather) {
    if (weather.hasPrecipitation) {
      return const DroneFlightResult(
        type: DroneType.fixedWing,
        canFly: false,
        reason: 'Дощ збільшує масу і погіршує аеродинаміку',
      );
    }
    if (weather.windSpeed > 15.0) {
      return const DroneFlightResult(
        type: DroneType.fixedWing,
        canFly: false,
        reason: 'Вітер > 15 м/с — небезпечна посадка',
      );
    }
    // Боковий вітер — особливо небезпечний для fixed wing
    final crosswindDeg = weather.windDirection % 90;
    final isCrosswind = crosswindDeg > 20 && crosswindDeg < 70;
    if (isCrosswind && weather.windSpeed > 8.0) {
      return DroneFlightResult(
        type: DroneType.fixedWing,
        canFly: true,
        reason: 'Сильний боковий вітер — ускладнена посадка',
        warning: 'Вітер ${weather.windFromDirection} — корегуйте траєкторію злету/посадки',
      );
    }
    if (weather.windSpeed > 10.0) {
      return DroneFlightResult(
        type: DroneType.fixedWing,
        canFly: true,
        reason: 'Вітер у межах допустимого для fixed wing',
        warning: 'Планируйте зліт/посадку проти вітру (${weather.windFromDirection})',
      );
    }
    return const DroneFlightResult(
      type: DroneType.fixedWing,
      canFly: true,
      reason: 'Сприятливі умови для польоту',
    );
  }

  /// Аграрні дрони — важкі, стабільні, але обмежені за вітром через балони з хімікатами
  static DroneFlightResult _evaluateAgri(WeatherModel weather) {
    if (weather.hasPrecipitation) {
      return const DroneFlightResult(
        type: DroneType.agri,
        canFly: false,
        reason: 'Дощ — неможливе рівномірне обприскування',
      );
    }
    if (weather.windSpeed > 5.0) {
      return DroneFlightResult(
        type: DroneType.agri,
        canFly: false,
        reason: 'Вітер > 5 м/с — хімікати зносить на сторонні ділянки',
        warning: 'Вітер дме на ${weather.windToDirection} — ризик дрейфу хімікатів',
      );
    }
    if (weather.windSpeed > 3.0) {
      return DroneFlightResult(
        type: DroneType.agri,
        canFly: true,
        reason: 'Вітер допустимий, але стежте за drift-ефектом',
        warning: 'Вітер із ${weather.windFromDirection} — контролюйте смугу обприскування',
      );
    }
    if (weather.temperature > 35) {
      return const DroneFlightResult(
        type: DroneType.agri,
        canFly: true,
        reason: 'Спека — хімікати випаровуються швидше',
        warning: 'Обприскування рано вранці або ввечері',
      );
    }
    return const DroneFlightResult(
      type: DroneType.agri,
      canFly: true,
      reason: 'Ідеальні умови для агрообприскування',
    );
  }
}
