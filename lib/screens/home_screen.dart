import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_model.dart';
import '../providers/weather_provider.dart';
import '../utils/safety_analyzer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.95, end: 1.05).animate(_pulseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(weatherProvider.notifier).fetchWeatherAndEvaluate();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Кольори статусу ───────────────────────────────────────────────────────
  Color _statusColor(FlightStatus s) {
    switch (s) {
      case FlightStatus.safe:
        return const Color(0xFF00C853);
      case FlightStatus.warning:
        return const Color(0xFFFF9800);
      case FlightStatus.danger:
        return const Color(0xFFFF1744);
    }
  }

  IconData _statusIcon(FlightStatus s) {
    switch (s) {
      case FlightStatus.safe:
        return Icons.check_circle_rounded;
      case FlightStatus.warning:
        return Icons.warning_amber_rounded;
      case FlightStatus.danger:
        return Icons.cancel_rounded;
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weatherProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(state),
      body: SafeArea(child: _buildBody(state)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00B4D8),
        onPressed: () =>
            ref.read(weatherProvider.notifier).fetchWeatherAndEvaluate(),
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }

  AppBar _buildAppBar(WeatherState state) {
    return AppBar(
      backgroundColor: const Color(0xFF161B22),
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.flight, color: Color(0xFF00B4D8), size: 22),
          const SizedBox(width: 8),
          const Text(
            'DroneWeather',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Text(
              state.useApi ? 'GPS' : 'SIM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: state.useApi
                    ? const Color(0xFF00C853)
                    : const Color(0xFFFF9800),
                letterSpacing: 1.2,
              ),
            ),
            Switch(
              value: state.useApi,
              activeColor: const Color(0xFF00C853),
              inactiveThumbColor: const Color(0xFFFF9800),
              onChanged: (v) =>
                  ref.read(weatherProvider.notifier).toggleApiMode(v),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(WeatherState state) {
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00B4D8)),
            const SizedBox(height: 16),
            Text(
              'Завантаження прогнозу...',
              style: TextStyle(color: Colors.grey[400], fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFF1744), size: 64),
              const SizedBox(height: 16),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                onPressed: () => ref
                    .read(weatherProvider.notifier)
                    .fetchWeatherAndEvaluate(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Спробувати ще раз'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.currentWeather == null) {
      return Center(
        child: Text(
          'Натисніть ↻ щоб отримати дані',
          style: TextStyle(color: Colors.grey[500], fontSize: 15),
        ),
      );
    }

    final weather = state.currentWeather!;
    final status = state.currentStatus!;

    return RefreshIndicator(
      color: const Color(0xFF00B4D8),
      onRefresh: () =>
          ref.read(weatherProvider.notifier).fetchWeatherAndEvaluate(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Симуляція банер
          if (!state.useApi) _buildSimBanner(),
          const SizedBox(height: 12),

          // Статус
          _buildStatusCard(status, weather),
          const SizedBox(height: 16),

          // Слайдер прогнозу
          _buildTimeSlider(state),
          const SizedBox(height: 16),

          // Метрики
          _buildMetricsGrid(context, weather, state),
          const SizedBox(height: 16),

          // Типи дронів
          _buildDroneTypesCard(weather),
          const SizedBox(height: 16),

          // Міні-прогноз на тиждень
          _buildWeekForecast(state),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─── Банер симуляції ───────────────────────────────────────────────────────
  Widget _buildSimBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 16),
          SizedBox(width: 8),
          Text(
            'Режим симуляції — увімкніть GPS для реальних даних',
            style: TextStyle(color: Color(0xFFFF9800), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── Статус-картка ─────────────────────────────────────────────────────────
  Widget _buildStatusCard(FlightStatus status, WeatherModel weather) {
    final color = _statusColor(status);
    final icon = _statusIcon(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Icon(icon, color: color, size: 56),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SafetyAnalyzer.getStatusText(status),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${weather.temperature.toStringAsFixed(1)}°C · ${weather.weatherDescription}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                Text(
                  'Вологість: ${weather.humidity.toInt()}% · Тиск: ${weather.pressure} гПа',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Слайдер години (для обраного дня, 00:00…23:00) ───────────────────────────────
  Widget _buildTimeSlider(WeatherState state) {
    final forecasts = state.forecasts;
    if (forecasts.isEmpty) return const SizedBox.shrink();

    final weather = state.currentWeather!;
    final hour = state.selectedHourIndex; // 0..23

    // Назва обраного дня
    final week = state.weekSummary;
    final dayData = (week.isNotEmpty && state.selectedDayIndex < week.length)
        ? week[state.selectedDayIndex]
        : null;
    final dayStr = dayData != null
        ? '${_dayName(dayData.timestamp.weekday)}, '
            '${dayData.timestamp.day.toString().padLeft(2, '0')}'
            '.${dayData.timestamp.month.toString().padLeft(2, '0')}'
        : '';

    final timeStr =
        '${weather.timestamp.hour.toString().padLeft(2, '0')}:00';
    final slotStatus = SafetyAnalyzer.evaluateFlightSafety(weather);
    final slotColor = _statusColor(slotStatus);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок: день + година
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: '$dayStr  ',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: timeStr,
                    style: TextStyle(
                        color: slotColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: slotColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: slotColor.withOpacity(0.5)),
                ),
                child: Text(
                  SafetyAnalyzer.getStatusText(slotStatus),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: slotColor),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00B4D8),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF00B4D8),
              overlayColor: const Color(0xFF00B4D8).withOpacity(0.15),
              trackHeight: 3,
              valueIndicatorColor: const Color(0xFF00B4D8),
              valueIndicatorTextStyle:
                  const TextStyle(color: Colors.white, fontSize: 11),
            ),
            child: Slider(
              value: hour.toDouble(),
              min: 0,
              max: 23,
              divisions: 23,
              label: '${hour.toString().padLeft(2, '0')}:00',
              onChanged: (v) =>
                  ref.read(weatherProvider.notifier).setHourIndex(v.round()),
            ),
          ),
          // Мітки годин
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('00:00',
                    style: TextStyle(color: Colors.white24, fontSize: 9)),
                Text('06:00',
                    style: TextStyle(color: Colors.white24, fontSize: 9)),
                Text('12:00',
                    style: TextStyle(color: Colors.white24, fontSize: 9)),
                Text('18:00',
                    style: TextStyle(color: Colors.white24, fontSize: 9)),
                Text('23:00',
                    style: TextStyle(color: Colors.white24, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Сітка метрик ─────────────────────────────────────────────────────────
  Widget _buildMetricsGrid(
      BuildContext context, WeatherModel weather, WeatherState state) {
    final items = [
      _MetricItem(
        title: 'Вітер',
        value: '${weather.windSpeed.toStringAsFixed(1)} м/с',
        sub: 'із ${weather.windFromDirection} → ${weather.windToDirection}',
        icon: Icons.air_rounded,
        color: const Color(0xFF00B4D8),
        highlight: weather.windSpeed >= 6.0,
        details: _windDetails(weather),
        weekData: state.weekSummary,
        weekMetric: (w) => w.windSpeed,
        weekUnit: 'м/с',
        weather: weather,
      ),
      _MetricItem(
        title: 'Пориви',
        value: '${weather.windGust.toStringAsFixed(1)} м/с',
        sub: 'макс. пориви',
        icon: Icons.storm_rounded,
        color: const Color(0xFFFF1744),
        highlight: weather.windGust > 10.0,
        details:
            'Пориви — найнебезпечніший фактор для дронів. Раптове збільшення швидкості вітру може '
            'призвести до втрати стабілізації та аварії.\n\n'
            '• До 7 м/с — безпечно\n'
            '• 7–10 м/с — обережно\n'
            '• Понад 10 м/с — НЕ ЛІТАТИ',
        weekData: state.weekSummary,
        weekMetric: (w) => w.windGust,
        weekUnit: 'м/с',
        weather: weather,
      ),
      _MetricItem(
        title: 'Температура',
        value: '${weather.temperature.toStringAsFixed(1)}°C',
        sub: weather.temperature < 0
            ? 'Мороз — підігрій батарею!'
            : weather.temperature > 35
                ? 'Спека — слідкуй за моторами'
                : 'Нормальний діапазон',
        icon: Icons.thermostat_rounded,
        color: const Color(0xFFFF9800),
        highlight: weather.temperature < -5 || weather.temperature > 35,
        details:
            'Температура критично впливає на ємність акумулятора:\n\n'
            '• Нижче -10°C: ємність -40%, ризик замерзання\n'
            '• 0–5°C: перед польотом прогрійте АКБ\n'
            '• 0–35°C: оптимальний діапазон\n'
            '• Вище 35°C: перегрів моторів та ESC',
        weekData: state.weekSummary,
        weekMetric: (w) => w.temperature,
        weekUnit: '°C',
        weather: weather,
      ),
      _MetricItem(
        title: 'Тиск',
        value: '${weather.pressure} гПа',
        sub: weather.pressure < 1000 ? 'Знижений — можливий дощ' : 'Норма',
        icon: Icons.speed_rounded,
        color: const Color(0xFF9C27B0),
        highlight: false,
        details:
            'Атмосферний тиск впливає на роботу барометра дрона (утримання висоти).\n\n'
            '• Норма: 1013 гПа\n'
            '• Знижений (<1000): перед дощем/грозою\n'
            '• Різкий перепад тиску → перекалібруйте барометр',
        weekData: state.weekSummary,
        weekMetric: (w) => w.pressure.toDouble(),
        weekUnit: 'гПа',
        weather: weather,
      ),
      _MetricItem(
        title: 'Опади',
        value: weather.hasPrecipitation ? '⚠ Є' : '✓ Нема',
        sub: weather.weatherDescription,
        icon: Icons.water_drop_rounded,
        color: weather.hasPrecipitation
            ? const Color(0xFFFF1744)
            : const Color(0xFF00B4D8),
        highlight: weather.hasPrecipitation,
        details:
            'Вологість (дощ, сніг, туман) руйнує незахищену електроніку дронів.\n\n'
            '• Без опадів: зелене світло\n'
            '• Туман (ID 7xx): знижена видимість FPV\n'
            '• Дощ / сніг: ЗАБОРОНЕНО (крім IP43+ дронів)\n'
            '• Гроза: абсолютна заборона',
        weekData: state.weekSummary,
        weekMetric: (w) => w.hasPrecipitation ? 1.0 : 0.0,
        weekUnit: '',
        weather: weather,
      ),
      _MetricItem(
        title: 'Видимість',
        value: weather.visibility >= 1000
            ? '${(weather.visibility / 1000).toStringAsFixed(1)} км'
            : '${weather.visibility} м',
        sub: weather.visibility < 1000
            ? 'Туман — не літати!'
            : weather.visibility < 3000
                ? 'Обмежена видимість'
                : 'Гарна видимість',
        icon: Icons.visibility_rounded,
        color: const Color(0xFF26C6DA),
        highlight: weather.visibility < 3000,
        details:
            'VLOS (Visual Line of Sight) — обов\'язкова умова польоту за більшістю регуляцій.\n\n'
            '• Понад 5 км: відмінно\n'
            '• 3–5 км: нормально\n'
            '• 1–3 км: обережно\n'
            '• Менше 1 км: заборонено (туман, смог)',
        weekData: state.weekSummary,
        weekMetric: (w) => w.visibility.toDouble(),
        weekUnit: 'м',
        weather: weather,
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        // Адаптивна кількість колонок
        final cols = w < 360 ? 1 : w < 640 ? 2 : w < 960 ? 3 : 4;
        // Чим більше колонок — плитка ширша (менший aspectRatio)
        final aspectRatio = cols == 1
            ? 3.4
            : cols == 2
                ? 1.35
                : cols == 3
                    ? 1.2
                    : 1.1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) => _buildMetricCard(ctx, items[i]),
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, _MetricItem item) {
    return GestureDetector(
      onTap: () => _showDetailDialog(context, item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.highlight
                ? item.color.withOpacity(0.6)
                : Colors.white10,
            width: item.highlight ? 1.5 : 1,
          ),
          boxShadow: item.highlight
              ? [
                  BoxShadow(
                    color: item.color.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(item.icon, color: item.color, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    item.title,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                  const Spacer(),
                  if (item.highlight)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.sub.isNotEmpty)
                    Text(
                      item.sub,
                      style: TextStyle(
                          color: item.highlight
                              ? item.color.withOpacity(0.8)
                              : Colors.white38,
                          fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Діалог з анімацією відкриття ─────────────────────────────────────────────────────────
  void _showDetailDialog(BuildContext context, _MetricItem item) {
    final blocking = SafetyAnalyzer.getBlockingFactors(item.weather);
    final overallStatus = SafetyAnalyzer.evaluateFlightSafety(item.weather);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрити',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) {
        return Dialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Заголовок ────────────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text(item.value,
                              style: TextStyle(
                                  color: item.color,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          if (item.sub.isNotEmpty)
                            Text(item.sub,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Чому не можна літати (конкретні причини) ───────────────────────────
                if (blocking.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFF1744).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⛔ Політ заборонено через:',
                            style: TextStyle(
                                color: Color(0xFFFF1744),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 6),
                        ...blocking.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text('• $f',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ] else if (overallStatus == FlightStatus.warning) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFF9800).withOpacity(0.3)),
                    ),
                    child: const Text(
                        '⚠️ Стан потребує підвищеної уваги — перевірте всі параметри',
                        style: TextStyle(
                            color: Color(0xFFFF9800), fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF00C853).withOpacity(0.3)),
                    ),
                    child: const Text('✅ Усі польотні параметри в нормі — політ дозволено',
                        style: TextStyle(
                            color: Color(0xFF00C853), fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                ],

                const SizedBox(height: 10),

                // ── Пояснення для цього параметра ──────────────────────────────────────────
                Text(
                  item.details,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13, height: 1.6),
                ),

                // ── Деталі опадів (extra block) ──────────────────────────────────────────
                if (item.title == 'Опади') ...[
                  const SizedBox(height: 14),
                  _buildPrecipitationDetails(item.weather),
                ],

                // ── Прогноз на тиждень ──────────────────────────────────────────────────────────
                if (item.weekData.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '📅 Прогноз на тиждень',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Колір показує стан саме ${item.title.toLowerCase()}, а не загальний статус',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  _buildWeekMiniChart(item),
                ],

                // ── Типи дронів ──────────────────────────────────────────────────────────────────
                if (item.title == 'Вітер' ||
                    item.title == 'Пориви' ||
                    item.title == 'Опади') ...[
                  const SizedBox(height: 20),
                  const Text(
                    '🚁 Типи дронів',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ..._droneResultWidgets(item.weather),
                ],

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: item.color,
                    ),
                    child: const Text('Зрозуміло',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
            parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: CurvedAnimation(
                parent: anim1, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  // ─── Детальна інформація по опадах ───────────────────────────────────────────────────
  Widget _buildPrecipitationDetails(WeatherModel w) {
    final type = w.precipitationType;
    final typeColor = _precipColor(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🗒 Детальна інформація',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),

        // Тип + інтенсивність
        _precipRow('🌧 Тип', w.precipitationTypeName, typeColor),
        if (w.precipitationMm > 0)
          _precipRow('💧 Інтенсивність',
              w.precipitationIntensity, Colors.white70),
        _precipRow('🌡 Ймовірність', w.precipProbabilityStr,
            w.precipitationProbability > 0.5
                ? const Color(0xFFFF9800)
                : Colors.white70),
        _precipRow('👁 Видимість',
            w.visibility >= 1000
                ? '${(w.visibility / 1000).toStringAsFixed(1)} км'
                : '${w.visibility} м',
            w.visibility < 1000
                ? const Color(0xFFFF1744)
                : Colors.white70),

        const SizedBox(height: 10),

        // Вплив на дрони
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: typeColor.withOpacity(0.25)),
          ),
          child: Text(
            _precipDroneImpact(type),
            style:
                const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _precipRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Color _precipColor(PrecipitationType type) {
    switch (type) {
      case PrecipitationType.none: return const Color(0xFF00C853);
      case PrecipitationType.fog:
      case PrecipitationType.mist: return const Color(0xFF90A4AE);
      case PrecipitationType.drizzle: return const Color(0xFF00B4D8);
      case PrecipitationType.rain: return const Color(0xFF1E90FF);
      case PrecipitationType.heavyRain: return const Color(0xFFFF1744);
      case PrecipitationType.snow: return const Color(0xFF90CAF9);
      case PrecipitationType.sleet: return const Color(0xFFB0BEC5);
      case PrecipitationType.thunderstorm: return const Color(0xFFFFD600);
    }
  }

  String _precipDroneImpact(PrecipitationType type) {
    switch (type) {
      case PrecipitationType.none:
        return 'Без опадів. Штатні умови з точки зору опадів.';
      case PrecipitationType.fog:
        return 'Туман не пошкоджує електроніку, але небезпечний через втрату FPV-сигналу та візуального контролю. VLOS неможливий. Не літати!';
      case PrecipitationType.mist:
        return 'Імла: видимість знижена, на лопатях дрона можуть осідати краплі вологі. Політ з обережністю або не рекомендується.';
      case PrecipitationType.drizzle:
        return 'Мряка: дрібні краплі потрапляються в мотори та електроніку. Навіть IP43 не гарантує захист при тривалому польоті. Політ не рекомендується.';
      case PrecipitationType.rain:
        return 'Дощ: волога потрапляє в розєми еск і моторів, викликає корозію. Без IP67 — заборонено. DJI Mini/Air рекомендує не літати.';
      case PrecipitationType.heavyRain:
        return 'Сильний дощ: абсолютна заборона. Велика кількість води може спричинити коротке замикання навіть на зачищених дронах.';
      case PrecipitationType.snow:
        return 'Сніг: накопичується на пропелерах і збільшує вагу. Дрейфує на зорі камери. Обладнання від снігу — загроза моторам. Заборонено.';
      case PrecipitationType.sleet:
        return 'Мокрий сніг: найнебезпечніше поєднання вологи і льоду. Намерзають лопаті, блокують сенсори. Цілковита заборона.';
      case PrecipitationType.thunderstorm:
        return 'Гроза: обов’язкова заборона! Блискавиця вбиває в дрон. Сильні вітрові пориви, сильний дощ, іонізація повітря. Не вилітайте за жоних обставин!';
    }
  }

  Widget _buildWeekMiniChart(_MetricItem item) {
    return Column(
      children: item.weekData.map((w) {
        final val = item.weekMetric(w);

        // Колір залежить від статусу конкретного параметра, а не загального
        final (paramSt, paramDesc) =
            SafetyAnalyzer.parameterStatus(item.title, w);
        final dotColor = _statusColor(paramSt);

        // Загальний статус для додаткового індикатора
        final overallSt = SafetyAnalyzer.evaluateFlightSafety(w);
        final overallColor = _statusColor(overallSt);

        final dayName = _dayName(w.timestamp.weekday);
        final dateStr =
            '${w.timestamp.day.toString().padLeft(2, '0')}.${w.timestamp.month.toString().padLeft(2, '0')}';

        String valStr;
        if (item.weekUnit == '') {
          valStr = val > 0 ? 'є' : 'ні';
        } else if (item.weekUnit == 'м' && val >= 1000) {
          valStr = '${(val / 1000).toStringAsFixed(1)} км';
        } else {
          valStr = '${val.toStringAsFixed(1)} ${item.weekUnit}';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(dayName,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                width: 38,
                child: Text(dateStr,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
              ),
              // Індикатор цього параметра
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(valStr,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
              const SizedBox(width: 6),
              // Desc цього параметра
              Text(paramDesc,
                  style: TextStyle(
                      color: dotColor.withOpacity(0.8), fontSize: 10)),
              const Spacer(),
              // Загальний статус польоту (дробні цятки)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: overallColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  overallSt == FlightStatus.safe
                      ? 'літати'
                      : overallSt == FlightStatus.warning
                          ? 'увага'
                          : 'не літати',
                  style: TextStyle(
                      color: overallColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _droneResultWidgets(WeatherModel weather) {
    final results = SafetyAnalyzer.evaluateByDroneType(weather);
    return results.map((r) {
      final color =
          r.canFly ? const Color(0xFF00C853) : const Color(0xFFFF1744);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  r.canFly ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.typeName,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(r.reason,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (r.warning.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('⚠ ${r.warning}',
                  style: const TextStyle(
                      color: Color(0xFFFF9800), fontSize: 11)),
            ],
          ],
        ),
      );
    }).toList();
  }

  // ─── Карта типів дронів (окремий блок) ────────────────────────────────────
  Widget _buildDroneTypesCard(WeatherModel weather) {
    final results = SafetyAnalyzer.evaluateByDroneType(weather);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.airplanemode_active_rounded,
                  color: Color(0xFF00B4D8), size: 20),
              SizedBox(width: 8),
              Text(
                'Які дрони можуть літати',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...results.map((r) {
            final color = r.canFly
                ? const Color(0xFF00C853)
                : const Color(0xFFFF1744);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r.canFly
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.typeName,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                        Text(
                          r.reason,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        if (r.warning.isNotEmpty)
                          Text(
                            '⚠ ${r.warning}',
                            style: const TextStyle(
                                color: Color(0xFFFF9800), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Прогноз на тиждень — тап на день для слайдера ───────────────────────
  Widget _buildWeekForecast(WeatherState state) {
    final week = state.weekSummary;
    if (week.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: Color(0xFF00B4D8), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Прогноз на тиждень',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              const SizedBox(width: 6),
              Text(
                '· тап — перегляд дня',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Адаптивний рядок плиток
          LayoutBuilder(
            builder: (ctx, constraints) {
              final avail = constraints.maxWidth;
              final count = week.length;
              const gap = 8.0;
              final computed = (avail - gap * (count - 1)) / count;
              final tileW = computed.clamp(78.0, 120.0);
              final totalW = tileW * count + gap * (count - 1);
              final needsScroll = totalW > avail + 1;

              final row = Row(
                mainAxisSize: MainAxisSize.min,
                children: week.asMap().entries.map((entry) {
                  final i = entry.key;
                  final w = entry.value;
                  final isSelected = i == state.selectedDayIndex;
                  final status = SafetyAnalyzer.evaluateFlightSafety(w);
                  final color = _statusColor(status);
                  final day = _dayName(w.timestamp.weekday);
                  final date =
                      '${w.timestamp.day}.${w.timestamp.month.toString().padLeft(2, '0')}';

                  return GestureDetector(
                    onTap: () =>
                        ref.read(weatherProvider.notifier).setSelectedDay(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: tileW,
                      height: 150,
                      margin: EdgeInsets.only(
                          right: i < week.length - 1 ? gap : 0),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSelected
                              ? [
                                  color.withOpacity(0.30),
                                  color.withOpacity(0.10),
                                ]
                              : [
                                  color.withOpacity(0.12),
                                  color.withOpacity(0.03),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? color.withOpacity(0.85)
                              : color.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.22),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // День + дата
                          Column(
                            children: [
                              Text(day,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                              Text(date,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 9)),
                            ],
                          ),
                          // Іконка статусу
                          Icon(_statusIcon(status), color: color, size: 24),
                          // Температура + вітер
                          Column(
                            children: [
                              Text(
                                '${w.temperature.toStringAsFixed(0)}°',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                              ),
                              Text(
                                '${w.windSpeed.toStringAsFixed(1)}м/с',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                              Text(
                                'із ${w.windFromDirection}',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 9),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          // Статус бейдж
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(isSelected ? 0.30 : 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status == FlightStatus.safe
                                  ? 'літати'
                                  : status == FlightStatus.warning
                                      ? 'увага'
                                      : 'не літати',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );

              return needsScroll
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal, child: row)
                  : row;
            },
          ),
        ],
      ),
    );
  }



  // ─── Хелпери ───────────────────────────────────────────────────────────────
  String _dayName(int weekday) {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
    return days[weekday % 7 == 0 ? 7 : weekday % 7];
  }

  String _windDetails(WeatherModel weather) {
    return 'Вітер дме ІЗ ${weather.windFromDirection} (${weather.windDirection}°) '
        'НА ${weather.windToDirection}.\n\n'
        'Для дрона важливо знати звідки дує вітер, щоб:\n'
        '• Планувати зліт/посадку проти вітру\n'
        '• Враховувати знесення при місіях\n'
        '• Розраховувати запас батареї (проти вітру витрата вища)\n\n'
        'Поточна швидкість: ${weather.windSpeed.toStringAsFixed(1)} м/с\n'
        '• До 6 м/с: безпечно для більшості дронів\n'
        '• 6–8 м/с: з обережністю (лише Mavic/FPV)\n'
        '• Понад 8 м/с: заборонено для споживацьких дронів';
  }
}

// ─── Допоміжний клас для метрик ───────────────────────────────────────────────
class _MetricItem {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final bool highlight;
  final String details;
  final List<WeatherModel> weekData;
  final double Function(WeatherModel) weekMetric;
  final String weekUnit;
  final WeatherModel weather;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.highlight,
    required this.details,
    required this.weekData,
    required this.weekMetric,
    required this.weekUnit,
    required this.weather,
  });
}
