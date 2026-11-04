import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const CarDoctorApp());

class CarDoctorApp extends StatelessWidget {
  const CarDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF16A085);
    return MaterialApp(
      title: 'AI Car Doctor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF101820),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: const Color(0xFF1A2732),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
