import 'dart:async';

import 'package:flutter/material.dart';

import '../../navigation/app_entry_navigation.dart';
import '../../services/app_entry.dart';
import '../../services/firestore_service.dart';
import '../../services/profile_session.dart';

/// First screen after launch.
///
/// It resolves the post-authentication destination through the single
/// [AppEntryResolver] instead of guessing, so an already-signed-in admin is sent
/// to the admin app on a cold start exactly as they are after a fresh login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.profileLoader, this.minimumDuration});

  /// Production leaves this null so Firestore is used. Tests inject a fake.
  final UserProfileLoader? profileLoader;

  /// How long the branding stays on screen. Tests shorten it.
  final Duration? minimumDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _defaultMinimumDuration = Duration(seconds: 3);

  /// The branding delay, held so it can be cancelled when the screen goes away.
  Timer? _brandingTimer;

  Completer<void>? _brandingDone;

  @override
  void initState() {
    super.initState();

    unawaited(_resolveAndLeaveSplash());
  }

  /// Waits out the branding delay, then routes by role.
  ///
  /// The role is resolved while the splash is still visible, so a slow profile
  /// read does not add a second blank screen.
  Future<void> _resolveAndLeaveSplash() async {
    final minimum = widget.minimumDuration ?? _defaultMinimumDuration;

    final done = Completer<void>();

    _brandingDone = done;
    _brandingTimer = Timer(minimum, done.complete);

    // Started before the wait, so the two overlap instead of adding up.
    final entry = await AppEntryResolver(
      profileLoader: widget.profileLoader,
    ).resolveCurrentEntry(session: _session);

    await done.future;

    if (!mounted) return;

    unawaited(AppEntryNavigation.goToAppEntry(context, entry));
  }

  @override
  void dispose() {
    // The delay is cancelled so no timer outlives the screen. The completer is
    // completed as well, so the suspended continuation finishes quietly instead
    // of being left dangling.
    _brandingTimer?.cancel();
    _brandingTimer = null;

    final done = _brandingDone;

    _brandingDone = null;

    if (done != null && !done.isCompleted) done.complete();

    super.dispose();
  }

  /// The app-wide profile session, or null in an isolated widget test.
  ProfileSession? get _session => ProfileSessionScope.maybeOf(context);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/yatra_logo.jpeg',
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.explore,
                          size: 96,
                          color: scheme.primary,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'YATRA',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 5,
                    color: scheme.primary,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Explore Nepal. Plan Your Journey.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
