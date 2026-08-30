import 'package:flutter/material.dart';

import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const YatraApp());
}

class YatraApp extends StatelessWidget {
  const YatraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yatra',
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}