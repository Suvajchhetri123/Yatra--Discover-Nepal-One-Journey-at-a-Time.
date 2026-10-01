import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_profile.dart';
import '../../navigation/app_entry_navigation.dart';
import '../../services/app_entry.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'phone_auth_screen.dart';
import 'signup_screen.dart';

/// Yatra Login screen.
///
/// Uses the central design system. Email/password authentication is routed
/// through [AuthService]. After successful login, the user's tourist type
/// is checked from Firestore before deciding where to navigate.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.profileLoader, this.authenticate});

  /// Overrides how the signed-in profile is read.
  ///
  /// Production leaves this null so Firestore is used; widget tests inject a
  /// fake so no live Firebase app is required.
  final UserProfileLoader? profileLoader;

  /// Overrides the actual sign-in call.
  ///
  /// Production leaves this null so [AuthService] is used; tests inject a fake
  /// so the post-login *routing* can be verified without Firebase Auth. The
  /// routing is the part this screen is responsible for, and it is the part
  /// that must never send an admin to the tourist home.
  final Future<void> Function(String email, String password)? authenticate;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = const AuthService();

  /// Resolved lazily so a screen that was given a profile loader never
  /// constructs a Firestore client, which keeps widget tests off Firebase.
  late final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showErrors = false;
  bool _submitting = false;
  bool _socialSubmitting = false;

  UserProfileLoader? get _profileLoader => widget.profileLoader;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? get _emailError {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      return 'Email is required';
    }

    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

    return valid ? null : 'Enter a valid email address';
  }

  String? get _passwordError {
    final password = _passwordController.text;

    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  bool get _isValid => _emailError == null && _passwordError == null;

  /// Decides where the user should go after successful authentication.
  ///
  /// The decision is delegated to [AppEntryNavigation], which is the same code
  /// the splash screen and the tourist-type setup use. That is what keeps the
  /// role rules in a single place: an admin goes to the admin app, a tourist
  /// without a tourist type finishes onboarding, and a complete tourist goes
  /// home. This screen has no role logic of its own.
  Future<void> _goAfterLogin() async {
    final entry = await AppEntryResolver(
      profileLoader: _loadProfile,
    ).resolveCurrentEntry();

    if (!mounted) return;

    if (entry == AppEntry.signedOut) {
      debugPrint('Login succeeded but the profile could not be read.');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login successful, but your profile could not be loaded.',
          ),
        ),
      );

      return;
    }

    // Not awaited: the future completes only when the pushed route is
    // popped, so awaiting it would leave `_submitting` stuck in its
    // finally block.
    unawaited(AppEntryNavigation.goToAppEntry(context, entry));
  }

  /// Reads the profile through an injected loader when one is available, so a
  /// widget test never needs Firebase.
  Future<UserProfile?> _loadProfile() {
    final loader = _profileLoader;

    if (loader != null) return loader();

    return _firestoreService.getCurrentUserProfile();
  }

  Future<void> _login() async {
    setState(() => _showErrors = true);

    if (!_isValid || _submitting) return;

    setState(() => _submitting = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final authenticate = widget.authenticate;

      if (authenticate != null) {
        await authenticate(email, password);
      } else {
        await _auth.signInWithEmail(email: email, password: password);
      }

      if (!mounted) return;

      await _goAfterLogin();
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error Code: ${e.code}');
      debugPrint('Firebase Auth Error Message: ${e.message}');

      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = e.message ?? 'Unable to log in.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  /// Handles a social sign-in attempt.
  Future<void> _socialLogin(Future<void> Function() action) async {
    if (_socialSubmitting) return;

    setState(() => _socialSubmitting = true);

    try {
      await action();

      if (!mounted) return;

      await _goAfterLogin();
    } on UnsupportedError {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Social login will be configured soon.')),
      );
    } finally {
      if (mounted) {
        setState(() => _socialSubmitting = false);
      }
    }
  }

  /// Opens the phone-number + OTP sign-in flow.
  void _openPhoneAuth() {
    if (_submitting || _socialSubmitting) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhoneAuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screen,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BrandLogo(scheme: scheme),

                  const SizedBox(height: AppSpacing.lg),

                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Text(
                    'Sign in to continue planning your journey.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(Icons.mail_outline),
                      errorText: _showErrors ? _emailError : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      errorText: _showErrors ? _passwordError : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showForgotPassword(context),
                      child: const Text('Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  YatraPrimaryButton(
                    label: _submitting ? 'Logging in...' : 'Login',
                    icon: Icons.login,
                    onPressed: _submitting || _socialSubmitting ? null : _login,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  const YatraDivider(label: 'or continue with'),

                  const SizedBox(height: AppSpacing.xl),

                  YatraSocialButton(
                    icon: Icons.g_mobiledata,
                    label: 'Continue with Google',
                    loading: _socialSubmitting,
                    enabled: !_submitting,
                    onPressed: () => _socialLogin(_auth.signInWithGoogle),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  YatraSocialButton(
                    icon: Icons.facebook,
                    label: 'Continue with Facebook',
                    loading: _socialSubmitting,
                    enabled: !_submitting,
                    onPressed: () => _socialLogin(_auth.signInWithFacebook),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  YatraSocialButton(
                    icon: Icons.apple,
                    label: 'Continue with Apple',
                    loading: _socialSubmitting,
                    enabled: !_submitting,
                    onPressed: () => _socialLogin(_auth.signInWithApple),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  YatraSocialButton(
                    icon: Icons.phone_iphone,
                    label: 'Continue with Phone',
                    loading: _socialSubmitting,
                    enabled: !_submitting,
                    onPressed: _openPhoneAuth,
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flexible so the row can shrink on a narrow device
                      // instead of overflowing.
                      Flexible(
                        child: Text(
                          "Don't have an account?",
                          style: textTheme.bodyMedium,
                          textAlign: TextAlign.end,
                        ),
                      ),
                      TextButton(
                        onPressed: _submitting || _socialSubmitting
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupScreen(),
                                  ),
                                );
                              },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPassword(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset is not set up yet. Try again soon!'),
      ),
    );
  }
}

/// Shared Yatra branding block used by the auth screens.
class _BrandLogo extends StatelessWidget {
  final ColorScheme scheme;

  const _BrandLogo({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Image.asset(
        'assets/images/yatra_logo.jpeg',
        width: 96,
        height: 96,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.explore, size: 48, color: scheme.primary),
          );
        },
      ),
    );
  }
}
