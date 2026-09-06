import 'package:firebase_auth/firebase_auth.dart';

/// Yatra authentication service.
///
/// Provides a simple abstraction over Firebase Authentication so that the
/// UI screens do not need to communicate with Firebase directly.
///
/// Email/password authentication is fully connected to Firebase.
/// Social login and phone authentication are currently placeholders and
/// will be connected when their respective Firebase/provider configuration
/// is completed.
class AuthService {
  const AuthService();

  /// Signs in an existing user using email and password.
  ///
  /// Throws [FirebaseAuthException] when authentication fails.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates a new Firebase Authentication account using email and password.
  ///
  /// The [name] parameter is accepted so the UI can pass the user's name.
  /// The name itself is stored separately in the user's Firestore profile.
  ///
  /// Throws [FirebaseAuthException] when account creation fails.
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Save the user's display name in Firebase Authentication as well.
    final user = credential.user;

    if (user != null && name.trim().isNotEmpty) {
      await user.updateDisplayName(name.trim());
    }
  }

  /// Signs in using Google.
  ///
  /// Google Authentication is not configured yet.
  Future<void> signInWithGoogle() async {
    throw UnsupportedError(
      'Google sign-in is not configured yet.',
    );
  }

  /// Signs in using Facebook.
  ///
  /// Facebook Authentication is not configured yet.
  Future<void> signInWithFacebook() async {
    throw UnsupportedError(
      'Facebook sign-in is not configured yet.',
    );
  }

  /// Signs in using Apple.
  ///
  /// Apple Authentication is not configured yet.
  Future<void> signInWithApple() async {
    throw UnsupportedError(
      'Apple sign-in is not configured yet.',
    );
  }

  /// Sends a phone verification code.
  ///
  /// Phone Authentication is not configured yet.
  Future<void> sendPhoneVerificationCode({
    required String countryCode,
    required String phoneNumber,
  }) async {
    throw UnsupportedError(
      'Firebase Phone Authentication needs to be configured before a '
      'verification code can be sent.',
    );
  }

  /// Verifies a phone authentication code.
  ///
  /// Phone Authentication is not configured yet.
  Future<void> verifyPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    throw UnsupportedError(
      'Firebase Phone Authentication needs to be configured before the '
      'verification code can be verified.',
    );
  }

  /// Resends a phone verification code.
  ///
  /// Phone Authentication is not configured yet.
  Future<void> resendPhoneVerificationCode({
    required String countryCode,
    required String phoneNumber,
  }) async {
    throw UnsupportedError(
      'Firebase Phone Authentication needs to be configured before the '
      'verification code can be resent.',
    );
  }

  /// Completes phone sign-in.
  ///
  /// Phone Authentication is not configured yet.
  Future<void> signInWithPhone() async {
    throw UnsupportedError(
      'Firebase Phone Authentication needs to be configured before phone '
      'sign-in can complete.',
    );
  }

  /// Signs out the currently authenticated Firebase user.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
