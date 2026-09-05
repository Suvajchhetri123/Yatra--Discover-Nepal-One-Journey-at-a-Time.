import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'services/session_manager.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SessionManager.instance.initialize(navigatorKey);

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
      navigatorKey: navigatorKey,

      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            SessionManager.instance.userActivity();
          },
          onPointerMove: (_) {
            SessionManager.instance.userActivity();
          },
          onPointerUp: (_) {
            SessionManager.instance.userActivity();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const SplashScreen(),
    );
  }
}