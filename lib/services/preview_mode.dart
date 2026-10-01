import 'package:flutter/material.dart';

/// Central state for the admin's "Preview as Tourist" mode.
///
/// Preview is an *application* mode, not an identity change:
///
///   - the signed-in account keeps `role == admin` in Firestore;
///   - no second account is created and no other uid is impersonated;
///   - nothing about the stored profile is mutated.
///
/// Because the flag lives in one controller, the guard used by tourist screens
/// is a single call ([PreviewModeScope.guard]) rather than a check scattered
/// across screens, and no screen ever has to know an admin email or uid.
class PreviewModeController extends ChangeNotifier {
  bool _active = false;

  /// True while the admin is browsing the tourist experience.
  bool get isActive => _active;

  void enter() {
    if (_active) return;

    _active = true;
    notifyListeners();
  }

  void exit() {
    if (!_active) return;

    _active = false;
    notifyListeners();
  }
}

/// Shown when a transactional tourist action is attempted during preview.
const String kPreviewBlockedMessage =
    'Admin preview is on, so tourist changes are paused. '
    'Exit preview to continue.';

/// Exposes [PreviewModeController] to the whole tourist subtree and provides
/// the guard that transactional screens use.
class PreviewModeScope extends InheritedNotifier<PreviewModeController> {
  const PreviewModeScope({
    super.key,
    required PreviewModeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The nearest controller, or null when preview is not in scope (a normal
  /// tourist session is always "not in scope", which is never blocked).
  static PreviewModeController? controllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PreviewModeScope>()
        ?.notifier;
  }

  /// True when the calling screen is being rendered inside admin preview.
  static bool isActive(BuildContext context) {
    return controllerOf(context)?.isActive ?? false;
  }

  /// Blocks a transactional action when preview is active.
  ///
  /// Returns true when the caller must abort, having already explained why.
  /// Reading-only screens never call this.
  static bool guard(BuildContext context, {String? message}) {
    if (!isActive(context)) return false;

    final messenger = ScaffoldMessenger.maybeOf(context);

    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message ?? kPreviewBlockedMessage)),
      );

    return true;
  }
}
