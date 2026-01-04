import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveERP',
      theme: AppTheme.darkTheme,
      home: const LandingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
