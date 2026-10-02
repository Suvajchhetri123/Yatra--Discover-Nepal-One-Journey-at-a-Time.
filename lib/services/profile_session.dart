import 'package:flutter/widgets.dart';

import '../models/user_profile.dart';
import 'firestore_service.dart';

/// How the session obtains the signed-in user's profile.
///
/// Production uses [FirestoreService]; tests inject a fake so the session can
/// be exercised without booting Firebase.
typedef ProfileSessionLoader = Future<UserProfile?> Function();

/// Runtime profile state for the signed-in user.
///
/// This replaces the old `DemoProfileStore`. The important difference is the
/// source of truth: values here are *copied from* `users/{uid}` and never
/// authored locally. There is no `setProfile`/`setLanguage` path that writes
/// only in memory, so a value shown here always corresponds to something
/// Firestore has stored.
///
/// The session exists because several read-only screens need one or two
/// profile fields (mostly `language`, for `AppStrings`) and re-reading Firestore
/// in each of them would be wasteful. It holds a snapshot, not authority:
/// [ProfileSession.refresh] re-reads the document, and writes still go through
/// [FirestoreService] before the session is updated.
class ProfileSession extends ChangeNotifier {
  ProfileSession({ProfileSessionLoader? loader, FirestoreService? firestore}) {
    _loader = loader;
    _firestore = firestore;
  }

  ProfileSessionLoader? _loader;
  FirestoreService? _firestore;

  UserProfile? _profile;
  bool _loading = false;

  /// The last known profile, or null before the first successful load.
  UserProfile? get profile => _profile;

  /// True while a refresh is in flight.
  bool get isLoading => _loading;

  /// Language for UI strings.
  ///
  /// Falls back to English before the profile arrives so a screen never has to
  /// handle a null language; the session re-notifies once the real value
  /// lands, and subscribed screens rebuild.
  String get language =>
      _profile?.language.isNotEmpty == true ? _profile!.language : 'English';

  /// The Firestore profile of the signed-in user.
  Future<UserProfile?> _read() async {
    final loader = _loader;

    if (loader != null) return loader();

    final firestore = _firestore;

    if (firestore == null) return null;

    return firestore.getCurrentUserProfile();
  }

  /// Reads the profile and publishes it to subscribers.
  ///
  /// Safe to call repeatedly: while a load is in flight a second call is
  /// ignored, so several screens mounting at once cannot stampede Firestore.
  Future<void> refresh() async {
    if (_loading) return;

    _loading = true;
    notifyListeners();

    try {
      final loaded = await _read();

      _profile = loaded;
    } catch (_) {
      // Keep the previous snapshot. A failed refresh must not blank a screen
      // that is already showing correct data; the caller decides whether the
      // absence of data is worth reporting.
    }

    _loading = false;
    notifyListeners();
  }

  /// Publishes an already-persisted profile without re-reading Firestore.
  ///
  /// Called after a successful write so subscribers see the new value
  /// immediately. The caller is responsible for having saved it first.
  void publish(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  /// Clears the in-memory snapshot on sign-out.
  ///
  /// This drops cached state only. The user's Firestore profile is untouched,
  /// so the next sign-in restores the same language and contact details.
  void clear() {
    if (_profile == null) return;

    _profile = null;
    notifyListeners();
  }
}

/// Provides a [ProfileSession] to the subtree and exposes read helpers.
///
/// Used the same way as [PreviewModeScope]: one session for the app, read by
/// whichever screens need it, rather than a singleton each screen reaches into.
class ProfileSessionScope extends InheritedNotifier<ProfileSession> {
  const ProfileSessionScope({
    super.key,
    required ProfileSession session,
    required super.child,
  }) : super(notifier: session);

  /// The nearest session, subscribing the caller to its changes.
  static ProfileSession? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ProfileSessionScope>()
        ?.notifier;
  }

  /// The nearest session without subscribing.
  ///
  /// Safe from event handlers and plain getters; returns null outside a scope
  /// so an isolated widget test degrades to the default language.
  static ProfileSession? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<ProfileSessionScope>()
        ?.notifier;
  }

  /// Language in scope, defaulting to English when no session is available.
  static String languageOf(BuildContext context) {
    return maybeOf(context)?.language ?? 'English';
  }
}
