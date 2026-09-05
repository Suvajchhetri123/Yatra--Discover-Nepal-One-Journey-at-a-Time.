import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

/// Yatra Signup screen.
///
/// Uses the central design system. Email/password account creation is routed
/// through [AuthService]; social sign-up is available in the UI but will not
/// truly authenticate until Firebase is connected.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _auth = const AuthService();
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _showErrors = false;
  bool _submitting = false;
  bool _socialSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? get _nameError {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'Full name is required';
    if (name.length < 2) return 'Enter your full name';
    return null;
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

  String? get _confirmError {
    if (_confirmController.text.isEmpty) return 'Confirm your password';
    if (_confirmController.text != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  bool get _isValid =>
      _nameError == null &&
      _emailError == null &&
      _passwordError == null &&
      _confirmError == null;

  Future<void> _createAccount() async {
    setState(() => _showErrors = true);
    if (!_isValid || _submitting) return;

    setState(() => _submitting = true);

    try {
      await _auth.signUpWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await _firestore.createOrUpdateUserProfile(
        name: _nameController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'weak-password':
          message = 'The password is too weak.';
          break;
        default:
          message = e.message ?? 'Unable to create account.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
    // Route through the auth service. For now the service is a mock that
    // resolves successfully, matching the previous behaviour.
  }

  /// Handles a social sign-up attempt. Until Firebase is configured the
  /// service throws [UnsupportedError], which we surface as a friendly
  /// "configured soon" message.
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
        const SnackBar(content: Text('Social login will be configured soon.')),
      );
    } finally {
      if (mounted) setState(() => _socialSubmitting = false);
    }
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
                    'Create your account',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Join Yatra and start planning your journey.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      hintText: 'Your full name',
                      prefixIcon: const Icon(Icons.person_outline),
                      errorText: _showErrors ? _nameError : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),

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
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'At least 6 characters',
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
                  const SizedBox(height: AppSpacing.lg),

                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _createAccount(),
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      hintText: 'Re-enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      errorText: _showErrors ? _confirmError : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  YatraPrimaryButton(
                    label: 'Create Account',
                    icon: Icons.person_add_alt,
                    onPressed: _submitting || _socialSubmitting
                        ? null
                        : _createAccount,
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

                  const SizedBox(height: AppSpacing.xxl),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account?",
                        style: textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _submitting || _socialSubmitting
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                        child: const Text('Log in'),
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
