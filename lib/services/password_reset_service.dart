import 'package:firebase_auth/firebase_auth.dart';

/// The action that sends a password-reset email to a specific user.
///
/// It is injected so tests can fake it. The service does not know about roles:
/// the caller is already the trusted backend through a callable function or the
/// UI is already gated by the admin area. Firebase Authentication is the
/// source of truth for the email delivery itself.
abstract class PasswordResetService {
  /// Sends a password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email);
}

/// The production implementation that uses Firebase Authentication.
///
/// Firebase Auth owns the actual email: the link is not exposed to the caller
/// and we never claim success unless the SDK call completes without throwing.
class FirebasePasswordResetService implements PasswordResetService {
  const FirebasePasswordResetService({this.auth});

  /// Tests may inject a fake; production uses the default instance.
  final FirebaseAuth? auth;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();

    if (trimmed.isEmpty) {
      // The backend prevents this, but defensive so tests can see the
      // semantics.
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Email address must not be empty.',
      );
    }

    await (auth ?? FirebaseAuth.instance).sendPasswordResetEmail(
      email: trimmed,
    );
  }
}
