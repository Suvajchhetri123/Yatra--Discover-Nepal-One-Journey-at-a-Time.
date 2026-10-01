import 'package:flutter/material.dart';

import '../../services/preview_mode.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

/// The permanent preview label, exposed as a constant so the admin settings
/// screen, the banner and the tests all agree on the wording.
const String kAdminPreviewLabel = 'ADMIN PREVIEW';

/// Hosts the real tourist application inside admin preview.
///
/// Two requirements shape this widget:
///
///   1. The previewed UI must be the *actual* tourist experience, so the
///      tourist screens are reused verbatim rather than re-implemented.
///   2. The "ADMIN PREVIEW" indication must stay visible while browsing, so
///      the admin can never mistake a preview for their real session. Because a
///      pushed route would cover the host, the tourist app gets its own nested
///      [Navigator] and the banner sits above it.
class AdminPreviewHost extends StatefulWidget {
  const AdminPreviewHost({
    super.key,
    required this.controller,
    this.previewHome,
  });

  /// Shared with the admin area so entering and leaving preview agree.
  final PreviewModeController controller;

  /// The tourist entry point to preview. Defaults to the tourist [HomeScreen].
  final Widget? previewHome;

  @override
  State<AdminPreviewHost> createState() => _AdminPreviewHostState();
}

class _AdminPreviewHostState extends State<AdminPreviewHost> {
  final GlobalKey<NavigatorState> _previewNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Entering the host means preview is on. This is a local flag only.
    widget.controller.enter();
  }

  @override
  void dispose() {
    // Leaving the host (including a back gesture) always ends preview, so the
    // next tourist screen outside the host is unrestricted.
    widget.controller.exit();
    super.dispose();
  }

  void _exitPreview() {
    // Exit first so the tourist subtree is already unrestricted by the time the
    // route is popped, whatever the gesture does.
    widget.controller.exit();

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewHome = widget.previewHome ?? const HomeScreen();

    return PreviewModeScope(
      controller: widget.controller,
      child: Scaffold(
        body: Stack(
          children: [
            Navigator(
              key: _previewNavigatorKey,
              onGenerateRoute: (settings) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (context) => previewHome,
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: AdminPreviewBanner(onExit: _exitPreview),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The persistent "ADMIN PREVIEW" strip with its exit action.
///
/// Deliberately loud: it is the only thing standing between an admin and an
/// accidental tourist transaction.
class AdminPreviewBanner extends StatelessWidget {
  const AdminPreviewBanner({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  kAdminPreviewLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              TextButton(
                onPressed: onExit,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black26,
                ),
                child: const Text('Exit Preview'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
