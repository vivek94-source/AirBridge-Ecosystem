import 'package:airbridge/ui/home_screen.dart';
import 'package:flutter/material.dart';

class AirBridgeApp extends StatelessWidget {
  const AirBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00D4FF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF070B14),
      fontFamily: 'Segoe UI',
    );

    return MaterialApp(
      title: 'AirBridge',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const HomeScreen(),
    );
  }
}

