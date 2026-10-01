import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/tourist_type_setup_screen.dart';
import '../screens/home/home_screen.dart';
import '../services/app_entry.dart';
import '../services/firestore_service.dart';

/// The one place that turns an [AppEntry] into a screen.
///
/// Every post-authentication navigation in the app (splash, login, tourist-type
/// setup, signup and session expiry) routes through [goToAppEntry] so the
/// role rules live here and nowhere else.
///
/// The role decision itself is [resolveAppEntry]; this file only performs the
/// navigation, which is why it is the only file allowed to know that an admin
/// lands on the admin root.
class AppEntryNavigation {
  const AppEntryNavigation._();

  /// The screen that represents [entry].
  static Widget screenFor(AppEntry entry) {
    switch (entry) {
      case AppEntry.signedOut:
        return const LoginScreen();

      case AppEntry.touristOnboarding:
        return const TouristTypeSetupScreen();

      case AppEntry.touristHome:
        return const HomeScreen();

      case AppEntry.adminRoot:
        return const AdminScreen();
    }
  }

  /// Navigates to [entry].
  ///
  /// [replaceAll] clears the back stack, which is what authentication and
  /// session changes need: after signing in there must be no route that returns
  /// to the login screen.
  static Future<void> goToAppEntry(
    BuildContext context,
    AppEntry entry, {
    bool replaceAll = true,
  }) {
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute<void>(builder: (_) => screenFor(entry));

    if (replaceAll) {
      return navigator.pushAndRemoveUntil<void>(route, (route) => false);
    }

    return navigator.pushReplacement(route);
  }

  /// Resolves the current entry and navigates to it.
  ///
  /// This is the single call that answers "where does this user go now?", and
  /// is what the splash screen, the login screen and the tourist-type setup
  /// screen all use.
  static Future<AppEntry> resolveAndGo({
    required BuildContext context,
    UserProfileLoader? profileLoader,
    bool replaceAll = true,
  }) async {
    final entry = await AppEntryResolver(
      profileLoader: profileLoader,
    ).resolveCurrentEntry();

    if (!context.mounted) return entry;

    await goToAppEntry(context, entry, replaceAll: replaceAll);

    return entry;
  }
}

/// Convenience for screens that already hold a [UserProfile] and therefore
/// already know the destination without another Firestore read.
extension AppEntryNavigationOnContext on BuildContext {
  Future<void> goToEntryForProfile(
    UserProfile? profile, {
    bool replaceAll = true,
  }) {
    return AppEntryNavigation.goToAppEntry(
      this,
      resolveAppEntry(profile),
      replaceAll: replaceAll,
    );
  }
}
