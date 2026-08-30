import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import '../home/home_screen.dart';
import 'phone_auth_screen.dart';
import 'signup_screen.dart';

/// Yatra Login screen.
///
/// Uses the central design system. Email/password authentication is routed
/// through [AuthService]; social sign-in is available in the UI but will not
/// truly authenticate until Firebase is connected.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = const AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showErrors = false;
  bool _submitting = false;
  bool _socialSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? get _emailError {
    final email = _emailController.text.trim();
    if (email.isEmpty) return 'Email is required';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return valid ? null : 'Enter a valid email address';
  }

  String? get _passwordError {
    final password = _passwordController.text;
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  bool get _isValid => _emailError == null && _passwordError == null;

  void _login() {
    setState(() => _showErrors = true);
    if (!_isValid || _submitting) return;

    setState(() => _submitting = true);

    // Route through the auth service. For now the service is a mock that
    // resolves successfully, matching the previous behaviour. Replace with
    // real authentication once Firebase is connected.
    _auth
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        )
        .whenComplete(() {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  /// Handles a social sign-in attempt. Until Firebase is configured the
  /// service throws [UnsupportedError], which we surface as a friendly
  /// "configured soon" message rather than pretending login succeeded.
  Future<void> _socialLogin(Future<void> Function() action) async {
    if (_socialSubmitting) return;

    setState(() => _socialSubmitting = true);

    try {
      await action();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Social login will be configured soon.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _socialSubmitting = false);
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
                    label: 'Login',
                    icon: Icons.login,
                    onPressed: _submitting || _socialSubmitting
                        ? null
                        : _login,
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
                      Text(
                        "Don't have an account?",
                        style: textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _submitting || _socialSubmitting
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SignupScreen(),
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
