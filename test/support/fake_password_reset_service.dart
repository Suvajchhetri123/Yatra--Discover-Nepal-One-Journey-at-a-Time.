import 'dart:async';

import 'package:yatra/services/password_reset_service.dart';

/// In-memory [PasswordResetService] for tests.
///
/// Records every address it was asked to reset so a test can assert *which*
/// user was targeted, and can be told to fail so the error path is exercised.
/// No test ever sends a real email or touches Firebase Authentication.
class FakePasswordResetService implements PasswordResetService {
  /// Every email a reset was requested for, in order.
  final List<String> emails = <String>[];

  /// Set to make every call throw. Used to verify the failure copy.
  Object? error;

  /// When true, every call waits for [pending] instead of completing, so a test
  /// can assert that duplicate taps are ignored while a send is in flight.
  CompleterGate? gate;

  int get sendCalls => emails.length;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (gate != null) await gate!.wait();

    if (error != null) throw error!;

    emails.add(email);
  }
}

/// Lets a test hold a reset "in flight" to check for duplicate taps.
class CompleterGate {
  final Completer<void> _completer = Completer<void>();

  bool get isReleased => _completer.isCompleted;

  Future<void> wait() => _completer.future;

  void release() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
