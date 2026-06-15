import 'package:dio/dio.dart';
import '../models/weather_model.dart';

class WeatherService {
  final Dio _dio = Dio();

  static const String _apiKey = 'cbee8dbe38d5b28aa5d9f4f4763d075a';
  // forecast — 5 днів з кроком 3 год = 40 інтервалів
  static const String _forecastUrl = 'https://api.openweathermap.org/data/2.5/forecast';

  /// Повертає прогноз на 5 днів (до 40 точок з кроком 3 год)
  Future<List<WeatherModel>> getForecast(double lat, double lon) async {
    try {
      final response = await _dio.get(
        _forecastUrl,
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'appid': _apiKey,
          'units': 'metric',
          'lang': 'ua',
          'cnt': 40, // максимум 5 днів × 8 точок/день
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = response.data['list'];
        return list.map((json) => WeatherModel.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Не вдалося отримати прогноз погоди (HTTP ${response.statusCode})');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Тайм-аут з\'єднання. Перевірте інтернет.');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Невірний API-ключ OpenWeatherMap.');
      }
      throw Exception('Помилка мережі: ${e.message}');
    } catch (e) {
      throw Exception('Невідома помилка: $e');
    }
  }
}
