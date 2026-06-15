import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../utils/safety_analyzer.dart';

class WeatherState {
  final bool isLoading;

  /// 5 days × 24 hours = 120 hourly points
  final List<WeatherModel>? allHourlyForecasts;

  /// Which day is selected in the week strip (0 = today … 4)
  final int selectedDayIndex;

  /// Hour within the selected day (0 = 00:00 … 23 = 23:00)
  final int selectedHourIndex;

  final String? error;
  final bool useApi;

  // ─── Computed getters ──────────────────────────────────────────────────────

  /// 24 hourly points for the currently selected day
  List<WeatherModel> get forecasts {
    if (allHourlyForecasts == null || allHourlyForecasts!.isEmpty) return [];
    final start = selectedDayIndex * 24;
    if (start >= allHourlyForecasts!.length) return [];
    final end = (start + 24).clamp(0, allHourlyForecasts!.length);
    return allHourlyForecasts!.sublist(start, end);
  }

  WeatherModel? get currentWeather {
    final f = forecasts;
    if (f.isEmpty) return null;
    return f[selectedHourIndex.clamp(0, f.length - 1)];
  }

  FlightStatus? get currentStatus =>
      currentWeather != null
          ? SafetyAnalyzer.evaluateFlightSafety(currentWeather!)
          : null;

  /// Noon representative point for each day (for week strip)
  List<WeatherModel> get weekSummary {
    if (allHourlyForecasts == null || allHourlyForecasts!.isEmpty) return [];
    final result = <WeatherModel>[];
    for (int d = 0; d * 24 < allHourlyForecasts!.length; d++) {
      final noonIdx = d * 24 + 12;
      final idx = noonIdx < allHourlyForecasts!.length ? noonIdx : d * 24;
      result.add(allHourlyForecasts![idx]);
    }
    return result;
  }

  WeatherState({
    this.isLoading = false,
    this.allHourlyForecasts,
    this.selectedDayIndex = 0,
    this.selectedHourIndex = 0,
    this.error,
    this.useApi = false,
  });

  WeatherState copyWith({
    bool? isLoading,
    List<WeatherModel>? allHourlyForecasts,
    int? selectedDayIndex,
    int? selectedHourIndex,
    String? error,
    bool? useApi,
  }) {
    return WeatherState(
      isLoading: isLoading ?? this.isLoading,
      allHourlyForecasts: allHourlyForecasts ?? this.allHourlyForecasts,
      selectedDayIndex: selectedDayIndex ?? this.selectedDayIndex,
      selectedHourIndex: selectedHourIndex ?? this.selectedHourIndex,
      error: error ?? this.error,
      useApi: useApi ?? this.useApi,
    );
  }
}

class WeatherNotifier extends StateNotifier<WeatherState> {
  final WeatherService _weatherService = WeatherService();

  WeatherNotifier() : super(WeatherState());

  void toggleApiMode(bool value) {
    state = state.copyWith(useApi: value);
    fetchWeatherAndEvaluate();
  }

  /// Set hour within the currently selected day (0..23)
  void setHourIndex(int index) {
    state = state.copyWith(selectedHourIndex: index.clamp(0, 23));
  }

  /// Select a day in the week strip; preserves the selected hour
  void setSelectedDay(int dayIndex) {
    state = state.copyWith(
      selectedDayIndex: dayIndex.clamp(0, 4),
    );
  }

  Future<void> fetchWeatherAndEvaluate() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      List<WeatherModel> allHourly;

      if (state.useApi) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Служби геолокації вимкнені. Увімкніть GPS.');
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Доступ до місцезнаходження заборонено.');
          }
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception(
              'Доступ назавжди заборонено. Відкрийте налаштування додатку.');
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final raw = await _weatherService.getForecast(
            position.latitude, position.longitude);
        allHourly = _interpolateAllDays(raw);
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        allHourly = _generateSimulation();
      }

      state = state.copyWith(
        isLoading: false,
        allHourlyForecasts: allHourly,
        selectedDayIndex: 0,
        selectedHourIndex: DateTime.now().hour,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── API: interpolate 3h points → 5 days × 24h ───────────────────────────
  List<WeatherModel> _interpolateAllDays(List<WeatherModel> raw) {
    if (raw.isEmpty) return [];
    final result = <WeatherModel>[];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (int h = 0; h < 120; h++) {
      final targetTime = today.add(Duration(hours: h));
      result.add(_interpolateForTime(raw, targetTime));
    }
    return result; // exactly 120 points (5 days * 24h)
  }

  WeatherModel _interpolateForTime(List<WeatherModel> raw, DateTime target) {
    if (target.isBefore(raw.first.timestamp) || target.isAtSameMomentAs(raw.first.timestamp)) {
      return _copyModelWithTime(raw.first, target);
    }
    if (target.isAfter(raw.last.timestamp) || target.isAtSameMomentAs(raw.last.timestamp)) {
      return _copyModelWithTime(raw.last, target);
    }
    
    for (int i = 0; i < raw.length - 1; i++) {
      final a = raw[i];
      final b = raw[i + 1];
      if (target.isAfter(a.timestamp) && target.isBefore(b.timestamp)) {
        final totalDiff = b.timestamp.difference(a.timestamp).inSeconds;
        final targetDiff = target.difference(a.timestamp).inSeconds;
        final t = targetDiff / totalDiff;
        final interpolated = WeatherModel.interpolate(a, b, t);
        return _copyModelWithTime(interpolated, target);
      } else if (target.isAtSameMomentAs(b.timestamp)) {
        return _copyModelWithTime(b, target);
      }
    }
    return _copyModelWithTime(raw.last, target);
  }

  WeatherModel _copyModelWithTime(WeatherModel m, DateTime t) {
    return WeatherModel(
      temperature: m.temperature,
      pressure: m.pressure,
      windSpeed: m.windSpeed,
      windGust: m.windGust,
      windDirection: m.windDirection,
      hasPrecipitation: m.hasPrecipitation,
      visibility: m.visibility,
      timestamp: t,
      weatherId: m.weatherId,
      weatherDescription: m.weatherDescription,
      humidity: m.humidity,
      precipitationMm: m.precipitationMm,
      precipitationProbability: m.precipitationProbability,
    );
  }

  // ─── Simulation: 5 days × 24h = 120 realistic hourly points ─────────────
  List<WeatherModel> _generateSimulation() {
    final random = Random();
    final today = () {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }();

    final models = <WeatherModel>[];
    double baseWind = random.nextDouble() * 5 + 1.5;
    double basePrecip = random.nextDouble() * 0.35;
    double baseTemp = 14 + random.nextDouble() * 14;

    for (int h = 0; h < 120; h++) {
      // Continuous drift every hour
      baseWind =
          (baseWind + (random.nextDouble() - 0.5) * 0.9).clamp(0.5, 15);
      basePrecip =
          (basePrecip + (random.nextDouble() - 0.5) * 0.07).clamp(0, 1);
      // Day-to-day temperature shift
      if (h % 24 == 0 && h > 0) {
        baseTemp += (random.nextDouble() - 0.5) * 4;
      }
      // Diurnal cycle: min ~04:00, max ~14:00
      final hourOfDay = h % 24;
      final tempCycle = 3.0 * cos(pi * (hourOfDay - 14) / 12);
      final temp = baseTemp + tempCycle;

      final windSpeed = baseWind;
      final windGust = windSpeed + random.nextDouble() * 2.8;
      final hasPrecip = basePrecip > 0.62;

      int wId;
      if (basePrecip > 0.88)
        wId = 200; // thunderstorm
      else if (basePrecip > 0.78)
        wId = 502; // heavy rain
      else if (hasPrecip)
        wId = 500; // light rain
      else if (basePrecip > 0.45)
        wId = 801; // cloudy
      else
        wId = 800; // clear

      final precipMm =
          hasPrecip ? (basePrecip - 0.62) * 18 * random.nextDouble() : 0.0;

      models.add(WeatherModel(
        temperature: temp,
        pressure: 1005 + random.nextInt(25),
        windSpeed: windSpeed,
        windGust: windGust,
        windDirection: (160 + random.nextInt(80) + h * 2) % 360,
        hasPrecipitation: hasPrecip,
        visibility: hasPrecip
            ? 1500 + random.nextInt(3000)
            : 6000 + random.nextInt(4000),
        timestamp: today.add(Duration(hours: h)),
        weatherId: wId,
        weatherDescription: _idToDesc(wId),
        humidity: (50 + random.nextInt(40)).toDouble(),
        precipitationMm: precipMm,
        precipitationProbability: basePrecip.clamp(0, 1),
      ));
    }
    return models;
  }

  static String _idToDesc(int id) {
    if (id >= 200 && id < 300) return 'гроза';
    if (id >= 300 && id < 400) return 'мряка';
    if (id >= 500 && id < 502) return 'слабкий дощ';
    if (id >= 502 && id < 600) return 'сильний дощ';
    if (id >= 600 && id < 700) return 'сніг';
    if (id >= 700 && id < 800) return 'туман';
    if (id == 800) return 'ясно';
    if (id == 801) return 'мало хмарно';
    return 'хмарно';
  }
}

final weatherProvider =
    StateNotifierProvider<WeatherNotifier, WeatherState>((ref) {
  return WeatherNotifier();
});
