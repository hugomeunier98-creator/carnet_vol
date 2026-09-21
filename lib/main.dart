import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const CarnetVolApp());
}

class CarnetVolApp extends StatelessWidget {
  const CarnetVolApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF1E6FA8);
    return MaterialApp(
      title: 'Carnet de vol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
