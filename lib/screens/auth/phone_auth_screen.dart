import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'otp_verification_screen.dart';

/// First stage of Yatra phone authentication.
///
/// Collects a country code + phone number, then sends a verification code.
/// Because Firebase is not connected yet, [AuthService.sendPhoneVerificationCode]
/// throws [UnsupportedError]; the screen surfaces that message instead of
/// faking a sent code, while still preparing navigation to the OTP screen.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final AuthService _auth = const AuthService();
  final TextEditingController _phoneController = TextEditingController();

  String _countryCode = '+977';
  bool _showErrors = false;
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Digits only, without the leading country code.
  String get _digits => _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');

  String? get _phoneError {
    if (_digits.isEmpty) return 'Phone number is required';
    // Nepal mobile numbers are 10 digits and start with 9 (98/97/96...).
    final valid = _digits.length >= 7 && _digits.length <= 15;
    return valid ? null : 'Enter a valid phone number';
  }

  bool get _isValid => _phoneError == null;

  Future<void> _sendCode() async {
    setState(() => _showErrors = true);
    if (!_isValid || _submitting) return;

    setState(() => _submitting = true);

    try {
      // Firebase is not connected yet, so this throws UnsupportedError.
      // Replace (in AuthService) with FirebaseAuth.instance.verifyPhoneNumber.
      await _auth.sendPhoneVerificationCode(
        countryCode: _countryCode,
        phoneNumber: _digits,
      );

      if (!mounted) return;
      // If Firebase were connected and the code were sent, we would land here
      // with a real verificationId. Today we still preview the OTP screen to
      // prepare the flow.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            countryCode: _countryCode,
            phoneNumber: _digits,
          ),
        ),
      );
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firebase Phone Authentication needs to be configured before a '
            'code can be sent.',
          ),
        ),
      );
      // Still prepare the OTP flow so the screens are reachable once Firebase
      // is wired in.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            countryCode: _countryCode,
            phoneNumber: _digits,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Phone'),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
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
                  const _AuthBrand(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Sign in with your phone',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "We'll send you a verification code",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  YatraPhoneInput(
                    controller: _phoneController,
                    countryCode: _countryCode,
                    onCountryCodeChanged: (code) =>
                        setState(() => _countryCode = code),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _sendCode(),
                    autofocus: true,
                    errorText: _showErrors ? _phoneError : null,
                    helperText:
                        'Enter your 10-digit Nepali mobile number, e.g. 9812345678',
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  YatraPrimaryButton(
                    label: 'Send Verification Code',
                    icon: Icons.sms_outlined,
                    onPressed: _submitting ? null : _sendCode,
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

/// Small Yatra branding lockup for the auth screens.
class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Image.asset(
          'assets/images/yatra_logo.jpeg',
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.explore, size: 44, color: scheme.primary),
            );
          },
        ),
      ),
    );
  }
}
