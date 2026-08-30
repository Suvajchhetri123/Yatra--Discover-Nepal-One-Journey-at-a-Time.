/// Yatra authentication service.
///
/// A thin abstraction over authentication so the UI never talks directly to
/// a backend. Today the email/password methods are mock implementations that
/// always succeed (matching the app's prior behaviour, where a non-empty
/// email + password navigates to Home). Social logins and phone authentication
/// are placeholders that throw [UnsupportedError] until Firebase Authentication
/// is connected.
///
/// ## Connecting Firebase later
///
/// To wire real authentication, implement the bodies of these methods using
/// `firebase_auth` (and `google_sign_in` / `facebook_login` /
/// `sign_in_with_apple` for the provider flows). For phone sign-in use
/// `FirebaseAuth.instance.verifyPhoneNumber(...)` from
/// [sendPhoneVerificationCode]. The screens only depend on this service, so
/// the UI will not need to change.
///
/// No Firebase packages are added to `pubspec.yaml` yet.
class AuthService {
  const AuthService();

  /// Email/password sign-in.
  ///
  /// Mock for now: resolves successfully for any valid-looking credentials so
  /// the existing Login UX (validation + navigation to Home) is preserved.
  ///
  /// Replace with a `FirebaseAuth.instance.signInWithEmailAndPassword` call.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // TODO(firebase): replace with real email/password authentication.
    // Ignore the inputs for now — validation is handled by the UI.
    return;
  }

  /// Email/password account creation.
  ///
  /// Mock for now: resolves successfully so the existing Signup UX
  /// (validation + navigation to Home) is preserved.
  ///
  /// Replace with a `FirebaseAuth.instance.createUserWithEmailAndPassword` call.
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    // TODO(firebase): replace with real account creation.
    return;
  }

  /// Sign in with Google.
  ///
  /// Not implemented yet. Throws [UnsupportedError] so callers can show a
  /// "configured soon" message instead of pretending login succeeded.
  Future<void> signInWithGoogle() async {
    throw UnsupportedError('Google sign-in is not configured yet.');
  }

  /// Sign in with Facebook.
  ///
  /// Not implemented yet. See [signInWithGoogle].
  Future<void> signInWithFacebook() async {
    throw UnsupportedError('Facebook sign-in is not configured yet.');
  }

  /// Sign in with Apple.
  ///
  /// Not implemented yet. See [signInWithGoogle].
  Future<void> signInWithApple() async {
    throw UnsupportedError('Apple sign-in is not configured yet.');
  }

  /// Sends a 6-digit verification code to a phone number for sign-in.
  ///
  /// Not implemented yet. This is where Firebase's native phone flow would
  /// begin:
  ///
  /// ```dart
  /// await FirebaseAuth.instance.verifyPhoneNumber(
  ///   phoneNumber: '$countryCode$phoneNumber',
  ///   verificationCompleted: (credential) { /* auto-verify */ },
  ///   verificationFailed: (error) { /* surface error */ },
  ///   codeSent: (verificationId, resendToken) { /* show OTP screen */ },
  ///   codeAutoRetrievalTimeout: (verificationId) { /* timeout */ },
  /// );
  /// ```
  ///
  /// Until Firebase is configured this throws so callers can show a clear
  /// "not configured" message instead of faking a sent code.
  Future<void> sendPhoneVerificationCode({
    required String countryCode,
    required String phoneNumber,
  }) async {
    throw UnsupportedError(
      'Firebase Phone Authentication needs to be configured before a '
      'verification code can be sent.',
    );
  }

  /// Verifies the 6-digit code the user entered against Firebase.
  ///
  /// Replace with `FirebaseAuth.instance.signInWithCredential(PhoneAuthProvider
  /// .credential(verificationId: ..., smsCode: ...))` once Firebase is wired in.
  ///
  /// [verificationId] comes from the `codeSent` callback of
  /// [sendPhoneVerificationCode].
  Future<void> verifyPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    throw UnsupportedError(
      'Firebase Phone Authentication needs to be configured before the '
      'code can be verified.',
    );
  }

  /// Re-sends the verification code after the countdown expires.
  ///
  /// Replace with a call to `FirebaseAuth.instance.verifyPhoneNumber` using
  /// the stored `resendToken` from the original `codeSent` callback.
  Future<void> resendPhoneVerificationCode({
    required String countryCode,
    required String phoneNumber,
  }) async {
    throw UnsupportedError(
      'Firebase Phone Authentication needs to be configured before the '
      'code can be resent.',
    );
  }

  /// Completes phone-sign-in. For now this is grouped with the OTP flow;
  /// it will be driven internally by Firebase once `verifyPhoneNumber` is used.
  Future<void> signInWithPhone() async {
    throw UnsupportedError(
      'Firebase Phone Authentication needs to be configured before phone '
      'sign-in can complete.',
    );
  }

  /// Sign the current user out.
  ///
  /// Mock for now: does nothing. Replace with a `FirebaseAuth.instance.signOut`
  /// call once Firebase is connected.
  Future<void> signOut() async {
    // TODO(firebase): replace with a real sign-out.
    return;
  }
}
