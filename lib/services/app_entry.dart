import '../models/user_profile.dart';
import 'firestore_service.dart';
import 'profile_session.dart';

/// Where the application should take a user once authentication is resolved.
///
/// This is the single vocabulary for post-authentication navigation. Screens
/// never decide "tourist or admin?" on their own; they ask for an [AppEntry]
/// and let one navigation helper do the routing.
enum AppEntry {
  /// Nobody is signed in, or the profile could not be read.
  signedOut,

  /// A signed-in tourist that has not chosen a tourist type yet.
  ///
  /// Admins are deliberately never routed here: the tourist type is a tourist
  /// concept, so an admin must not be forced through it.
  touristOnboarding,

  /// A signed-in tourist with a complete profile.
  touristHome,

  /// A signed-in user whose stored role is exactly `admin`.
  adminRoot,
}

/// Resolves the post-authentication destination from a profile.
///
/// Deliberately a pure function so the routing decision is unit-testable
/// without Firebase, timers or a widget tree.
///
/// The order of the checks is the whole point of this function:
///
///   1. no profile            -> signed out
///   2. role == admin         -> admin root (bypasses tourist onboarding)
///   3. touristType missing   -> tourist onboarding
///   4. otherwise             -> tourist home
AppEntry resolveAppEntry(UserProfile? profile) {
  if (profile == null) {
    return AppEntry.signedOut;
  }

  // The admin check comes first and is an exact role match. It never depends on
  // touristType, so an admin account without one still lands in the admin app.
  if (profile.isAdmin) {
    return AppEntry.adminRoot;
  }

  final touristType = profile.touristType;

  if (touristType == null || touristType.trim().isEmpty) {
    return AppEntry.touristOnboarding;
  }

  return AppEntry.touristHome;
}

/// Resolves the [AppEntry] for the currently authenticated user.
///
/// The profile loader is injectable so splash, login and tests all share one
/// implementation. A failed profile read resolves to [AppEntry.signedOut],
/// which fails closed: an unreadable profile must never be treated as an
/// admin, and must never drop a signed-in user into the tourist app.
class AppEntryResolver {
  const AppEntryResolver({this.profileLoader});

  /// Production leaves this null so [FirestoreService] is used.
  final UserProfileLoader? profileLoader;

  ///
  /// [session] is updated with the profile that was read, so entry points do
  /// not need a second Firestore round trip to populate [ProfileSession]. The
  /// routing decision and the session snapshot always come from the same read,
  /// so they cannot disagree.
  Future<AppEntry> resolveCurrentEntry({ProfileSession? session}) async {
    try {
      final loader = profileLoader;

      final profile = loader == null
          ? await FirestoreService().getCurrentUserProfile()
          : await loader();

      final entry = resolveAppEntry(profile);

      if (profile != null) {
        session?.publish(profile);
      } else {
        // A signed-out user must not keep the previous account's language in
        // memory after a sign-out and cold start.
        session?.clear();
      }

      return entry;
    } catch (_) {
      return AppEntry.signedOut;
    }
  }
}
