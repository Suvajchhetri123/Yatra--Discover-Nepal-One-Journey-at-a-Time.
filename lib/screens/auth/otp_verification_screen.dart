import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';

/// Second stage of Yatra phone authentication.
///
/// Collects the 6-digit code sent by Firebase (once connected) and verifies
/// it. Today [AuthService.verifyPhoneCode] and
///  [AuthService.resendPhoneVerificationCode] throw [UnsupportedError] because
/// Firebase is not configured, so the screen shows a clear message and never
/// fabricates a successful verification. The OTP is kept in local controllers
/// only — it is never logged or rendered as readable text.
class OtpVerificationScreen extends StatefulWidget {
  final String countryCode;
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.countryCode,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _resendSeconds = 30;

  final AuthService _auth = const AuthService();

  // Firebase is not connected, so there is no real verificationId yet. When
  // sendPhoneVerificationCode's `codeSent` callback runs, this holds the id
  // passed to verifyPhoneCode.
  final String _verificationId = '';

  String _code = '';
  bool _verifyLoading = false;
  bool _resendLoading = false;
  String? _verifyError;

  int _secondsRemaining = _resendSeconds;
  bool get _canResend => _secondsRemaining <= 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _cancelCountdown();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _secondsRemaining = _resendSeconds;
    _countdown = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_secondsRemaining <= 1) {
          timer.cancel();
          setState(() => _secondsRemaining = 0);
        } else {
          setState(() => _secondsRemaining -= 1);
        }
      },
    );
  }

  void _cancelCountdown() => _countdown?.cancel();

  Timer? _countdown;

  /// Masks all but the last four digits for on-screen display.
  String get _maskedPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return widget.phoneNumber;
    final shown = digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    final masked = '*' * (digits.length - shown.length);
    return '${widget.countryCode} $masked$shown';
  }

  bool get _canSubmit => _code.length == YatraOtpInput.length && !_verifyLoading;

  Future<void> _verify() async {
    if (!_canSubmit) return;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _verifyLoading = true;
      _verifyError = null;
    });

    try {
      // Firebase not connected yet: throws UnsupportedError. Replace inside
      // AuthService with a Firebase credential sign-in.
      await _auth.verifyPhoneCode(
        verificationId: _verificationId,
        code: _code,
      );

      // On success (once Firebase is wired) this is where we navigate to Home.
    } on UnsupportedError {
      if (!mounted) return;
      setState(() {
        _verifyError =
            'Firebase Phone Authentication needs to be configured before the '
            'code can be verified.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_verifyError ?? 'Verification unavailable.')),
      );
    } finally {
      if (mounted) setState(() => _verifyLoading = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend || _resendLoading) return;

    setState(() => _resendLoading = true);

    try {
      // Firebase not connected yet: throws UnsupportedError.
      await _auth.resendPhoneVerificationCode(
        countryCode: widget.countryCode,
        phoneNumber: widget.phoneNumber,
      );
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firebase Phone Authentication needs to be configured before the '
            'code can be resent.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resendLoading = false);
        _startCountdown();
      }
    }
  }

  void _changePhone() {
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Verify'),
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
                    'Verify your phone',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Enter the 6-digit code sent to $_maskedPhone',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  YatraOtpInput(
                    enabled: !_verifyLoading,
                    onChanged: (code) => setState(() {
                      _code = code;
                      _verifyError = null;
                    }),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  YatraPrimaryButton(
                    label: 'Verify',
                    icon: Icons.verified_outlined,
                    onPressed: _canSubmit ? _verify : null,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Resend row with countdown.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _canResend ? "Didn't get the code?" : 'Resend code in',
                        style: textTheme.bodyMedium,
                      ),
                      if (!_canResend)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: Text(
                            '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                            style: AppType.label.copyWith(color: scheme.primary),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _resendLoading ? null : _resend,
                          child: _resendLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Resend'),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  TextButton.icon(
                    onPressed: _verifyLoading ? null : _changePhone,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Change phone number'),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
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
