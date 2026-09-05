import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  // Change this value if you want a different inactivity period.
  static const Duration inactivityDuration = Duration(minutes: 30);

  Timer? _timer;
  GlobalKey<NavigatorState>? _navigatorKey;

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        startTimer();
      } else {
        stopTimer();
      }
    });
  }

  void userActivity() {
    if (FirebaseAuth.instance.currentUser != null) {
      startTimer();
    }
  }

  void startTimer() {
    _timer?.cancel();

    _timer = Timer(inactivityDuration, () async {
      await logout();
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> logout() async {
    stopTimer();

    await FirebaseAuth.instance.signOut();

    final navigator = _navigatorKey?.currentState;

    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void dispose() {
    stopTimer();
  }
}