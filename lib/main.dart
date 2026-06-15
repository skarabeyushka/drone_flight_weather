import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    const ProviderScope(
      child: DroneFlightWeatherApp(),
    ),
  );
}

class DroneFlightWeatherApp extends StatelessWidget {
  const DroneFlightWeatherApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DroneWeather — Погода для дрона',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00B4D8),
          secondary: Color(0xFF00C853),
          surface: Color(0xFF161B22),
          error: Color(0xFFFF1744),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
