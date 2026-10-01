import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/itinerary_booking.dart';
import '../../navigation/app_entry_navigation.dart';
import '../../models/user_profile.dart';
import '../../services/admin_booking_repository.dart';
import '../../services/admin_user_actions.dart';
import '../../services/admin_user_repository.dart';
import '../../services/app_entry.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_seed_service.dart';
import '../../services/coordinator_repository.dart';
import '../../services/demo_profile_store.dart';
import '../../services/firestore_admin_booking_service.dart';
import '../../services/firestore_coordinator_service.dart';
import '../../services/firestore_package_service.dart';
import '../../services/firestore_place_service.dart';
import '../../services/firestore_service.dart';
import '../../services/functions_admin_user_actions.dart';
import '../../services/package_repository.dart';
import '../../services/preview_mode.dart';
import '../../services/place_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_booking_list_screen.dart';
import 'admin_content_messages.dart';
import 'admin_coordinator_list_screen.dart';
import 'admin_package_list_screen.dart';
import 'admin_place_list_screen.dart';
import 'admin_preview_host.dart';
import 'admin_settings_screen.dart';
import 'admin_user_list_screen.dart';

/// Shown when the admin booking collection could not be read.
///
/// The raw backend error is never surfaced to the administrator.
const String kAdminBookingsLoadFailureMessage =
    'Could not load bookings. Please try again.';

/// Role-protected admin dashboard backed by Firestore.
///
/// Role protection comes first: the screen re-reads users/{uid} and renders
/// nothing at all until the stored role is exactly 'admin'. Hiding the profile
/// entry is therefore convenience, not the protection — Firestore Security
/// Rules remain the real authorization boundary.
///
/// Only once authorized are bookings read through [AdminBookingRepository];
/// the dashboard counts are derived from those Firestore documents rather than
/// from a runtime demo store. The same gate fronts the travel-catalog hub
/// (coordinators, places and packages), which is served by the injected
/// repositories — Firestore by default, fakes in tests.
class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    this.profileLoader,
    this.bookingRepository,
    this.coordinatorRepository,
    this.placeRepository,
    this.packageRepository,
    this.userRepository,
    this.userActions,
    this.onSignOut,
  });

  /// Overrides how the authenticated profile is resolved.
  ///
  /// Production leaves this null so the screen uses
  /// [FirestoreService.getCurrentUserProfile]; widget tests inject a fake.
  final UserProfileLoader? profileLoader;

  /// Booking persistence backend for the admin area.
  ///
  /// Defaults to [FirestoreAdminBookingService]. Tests inject a fake.
  final AdminBookingRepository? bookingRepository;

  /// Coordinator registry backend. Defaults to [FirestoreCoordinatorService].
  final CoordinatorRepository? coordinatorRepository;

  /// Place catalog backend. Defaults to [FirestorePlaceService].
  final PlaceRepository? placeRepository;

  /// Package catalog backend. Defaults to [FirestorePackageService].
  final PackageRepository? packageRepository;

  /// User registry backend for the account-management area.
  ///
  /// Defaults to [FirestoreAdminUserRepository]. Tests inject a fake.
  final AdminUserRepository? userRepository;

  /// Privileged account operations, backed by callable Cloud Functions.
  ///
  /// Defaults to [FunctionsAdminUserActions]. Tests inject a fake.
  final AdminUserActions? userActions;

  /// Overrides signing out. Production leaves this null so [AuthService] is
  /// used; tests inject a callback to assert the admin root offers the action.
  final Future<void> Function()? onSignOut;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _verifying = true;
  bool _authorized = false;
  bool _verificationFailed = false;

  /// The verified admin, kept for the settings and user-management screens.
  UserProfile? _profile;

  List<ItineraryBooking> _bookings = <ItineraryBooking>[];

  /// True only for the first booking read, so an empty list is never shown for
  /// a request that is still in flight.
  bool _bookingsLoading = false;

  String? _bookingsError;

  /// Guards against a stale read overwriting a newer one.
  int _loadToken = 0;

  /// Resolved lazily so an injected repository is never bypassed.
  late final AdminBookingRepository _repository =
      widget.bookingRepository ?? FirestoreAdminBookingService();

  /// Resolved lazily so an injected repository is never bypassed.
  late final CoordinatorRepository _coordinatorRepository =
      widget.coordinatorRepository ?? FirestoreCoordinatorService();

  /// Resolved lazily so an injected repository is never bypassed.
  late final PlaceRepository _placeRepository =
      widget.placeRepository ?? FirestorePlaceService();

  /// Resolved lazily so an injected repository is never bypassed.
  late final PackageRepository _packageRepository =
      widget.packageRepository ?? FirestorePackageService();

  /// Resolved lazily so an injected repository is never bypassed.
  late final AdminUserRepository _userRepository =
      widget.userRepository ?? FirestoreAdminUserRepository();

  /// Resolved lazily so an injected fake is never bypassed.
  late final AdminUserActions _userActions =
      widget.userActions ?? FunctionsAdminUserActions();

  /// True while the one-off catalog migration is running.
  bool _seeding = false;

  /// Owned by the admin root so entering preview from the dashboard and leaving
  /// it again always agree on the same flag.
  final PreviewModeController _previewController = PreviewModeController();

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  /// Re-checks the stored role. Safe to call again to retry a failed lookup.
  Future<void> _verifyAccess() async {
    if (mounted) {
      setState(() {
        _verifying = true;
        _verificationFailed = false;
      });
    }

    try {
      final profile = await _loadProfile();

      if (!mounted) return;

      final authorized = profile?.isAdmin ?? false;

      setState(() {
        _authorized = authorized;
        _profile = authorized ? profile : null;
        _verifying = false;
      });

      // Bookings are only ever read for a verified admin.
      if (authorized) {
        await _loadBookings();
      }
    } catch (_) {
      if (!mounted) return;

      // Never surface the raw Firebase error to the user.
      setState(() {
        _authorized = false;
        _verifying = false;
        _verificationFailed = true;
      });
    }
  }

  Future<UserProfile?> _loadProfile() async {
    final loader = widget.profileLoader;

    if (loader != null) {
      return loader();
    }

    return FirestoreService().getCurrentUserProfile();
  }

  /// Reads the admin booking collection from the backend.
  Future<void> _loadBookings({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _bookingsLoading = true;
        _bookingsError = null;
      });
    }

    final token = ++_loadToken;

    try {
      final bookings = await _repository.getAllBookings();

      if (!mounted || token != _loadToken) return;

      setState(() {
        _bookings = List<ItineraryBooking>.of(bookings);
        _bookingsLoading = false;
        _bookingsError = null;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;

      // A failed background refresh keeps the metrics already on screen; the
      // empty state must never stand in for a failed request.
      if (_bookings.isNotEmpty) {
        setState(() => _bookingsLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kAdminBookingsLoadFailureMessage)),
        );

        return;
      }

      setState(() {
        _bookingsError = kAdminBookingsLoadFailureMessage;
        _bookingsLoading = false;
      });
    }
  }

  void _openList(BuildContext context, BookingStatus? status) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // The list screen gets the very same backend instance.
        builder: (context) => AdminBookingListScreen(
          initialStatus: status,
          repository: _repository,
          coordinatorRepository: _coordinatorRepository,
        ),
      ),
    );
  }

  void _openCoordinators() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminCoordinatorListScreen(repository: _coordinatorRepository),
      ),
    );
  }

  void _openPlaces() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminPlaceListScreen(repository: _placeRepository),
      ),
    );
  }

  void _openPackages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminPackageListScreen(repository: _packageRepository),
      ),
    );
  }

  /// Opens the account-management area.
  void _openUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminUserListScreen(
          repository: _userRepository,
          actions: _userActions,
          currentUid: _profile?.uid,
        ),
      ),
    );
  }

  /// Opens settings for the signed-in administrator.
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminSettingsScreen(
          // The profile was already verified by _verifyAccess, so it is reused
          // rather than read a second time.
          profile: _profile == null
              ? null
              : AdminUserSummary.fromProfile(_profile!),
          onOpenUserManagement: _openUsers,
          onOpenPreview: _openPreview,
          onSignOut: _signOut,
        ),
      ),
    );
  }

  /// Opens the tourist app inside the admin shell.
  ///
  /// The preview keeps the administrator's session, so the admin can inspect the
  /// traveller experience and leave again without signing out.
  void _openPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPreviewHost(controller: _previewController),
      ),
    );
  }

  /// Signs the administrator out and returns to the login screen.
  Future<void> _signOut() async {
    final signOut = widget.onSignOut;

    if (signOut != null) {
      await signOut();

      if (mounted) {
        unawaited(AppEntryNavigation.goToAppEntry(context, AppEntry.signedOut));
      }

      return;
    }

    await AuthService().signOut();

    if (!mounted) return;

    unawaited(AppEntryNavigation.goToAppEntry(context, AppEntry.signedOut));
  }

  /// Asks before running the one-off static-catalog migration.
  Future<void> _confirmSeed() async {
    if (_seeding) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Migrate travel catalog?'),
        content: const Text(
          'This copies the bundled coordinators, places and packages into '
          'Firestore. Records that already exist are left untouched, so it is '
          'safe to run more than once.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Migrate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runSeed();
  }

  /// Runs the idempotent migration and reports what changed.
  Future<void> _runSeed() async {
    setState(() => _seeding = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final report = await CatalogSeedService(
        coordinators: _coordinatorRepository,
        places: _placeRepository,
        packages: _packageRepository,
      ).seedMissingCatalogs();

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            report.hasFailures
                ? '${report.summary} ${report.failures.length} could not be '
                      'migrated.'
                : report.summary,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text(kAdminCatalogMigrationFailureMessage)),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = DemoProfileStore.instance.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'admin.title')),
        actions: [
          // Settings is reachable from the app bar so an admin is never trapped
          // on the dashboard, and signing out does not require the tourist app.
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _authorized ? _openSettings : null,
          ),
        ],
      ),
      body: SafeArea(
        child: _verifying
            ? const Center(child: CircularProgressIndicator())
            : _verificationFailed
            ? _AccessNotice(
                icon: Icons.cloud_off_outlined,
                message: 'Could not verify admin access. Please try again.',
                detail:
                    'We could not confirm your account role right now, so the '
                    'admin area stays closed.',
                actionLabel: 'Retry',
                actionIcon: Icons.refresh,
                onAction: _verifyAccess,
              )
            : !_authorized
            ? _AccessNotice(
                icon: Icons.lock_outline,
                message: 'Admin access required.',
                detail: 'This area is limited to Yatra administrators.',
                actionLabel: 'Back',
                actionIcon: Icons.arrow_back,
                // maybePop() is a no-op when there is nothing to pop, so the
                // screen can also be used as a test/route entry point.
                onAction: () => Navigator.of(context).maybePop(),
              )
            : _buildDashboard(context, language),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, String language) {
    if (_bookingsLoading && _bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      // Pull-to-refresh re-reads Firestore and keeps the metrics visible.
      onRefresh: () => _loadBookings(showLoader: false),
      child: _Dashboard(
        language: language,
        bookings: _bookings,
        bookingsError: _bookingsError,
        onRetryBookings: _loadBookings,
        onOpenList: (status) => _openList(context, status),
        onOpenCoordinators: _openCoordinators,
        onOpenPlaces: _openPlaces,
        onOpenPackages: _openPackages,
        onSeedCatalog: _confirmSeed,
        seeding: _seeding,
        onOpenUsers: _openUsers,
        onOpenSettings: _openSettings,
        onOpenPreview: _openPreview,
        onSignOut: _signOut,
      ),
    );
  }
}

/// The admin dashboard: Firestore booking metrics plus the travel-catalog hub.
///
/// The hub is always rendered for a verified admin, so content can still be
/// curated on a project that has not received its first booking yet.
class _Dashboard extends StatelessWidget {
  final String language;
  final List<ItineraryBooking> bookings;
  final String? bookingsError;
  final Future<void> Function({bool showLoader}) onRetryBookings;
  final void Function(BookingStatus? status) onOpenList;
  final VoidCallback onOpenCoordinators;
  final VoidCallback onOpenPlaces;
  final VoidCallback onOpenPackages;
  final VoidCallback onSeedCatalog;
  final bool seeding;
  final VoidCallback onOpenUsers;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPreview;
  final VoidCallback onSignOut;

  const _Dashboard({
    required this.language,
    required this.bookings,
    required this.bookingsError,
    required this.onRetryBookings,
    required this.onOpenList,
    required this.onOpenCoordinators,
    required this.onOpenPlaces,
    required this.onOpenPackages,
    required this.onSeedCatalog,
    required this.seeding,
    required this.onOpenUsers,
    required this.onOpenSettings,
    required this.onOpenPreview,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final total = bookings.length;
    final pending = bookings
        .where((booking) => booking.status == BookingStatus.pending)
        .length;
    final confirmed = bookings
        .where((booking) => booking.status == BookingStatus.confirmed)
        .length;
    final travellers = bookings.fold<int>(0, (sum, b) => sum + b.groupSize);
    final error = bookingsError;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Text(
          'Live booking requests from Firestore.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),

        YatraSectionTitle(title: AppStrings.tr(language, 'admin.dashboard')),
        const SizedBox(height: AppSpacing.md),

        if (error != null)
          YatraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                YatraEmptyState(icon: Icons.cloud_off_outlined, message: error),
                const SizedBox(height: AppSpacing.md),
                YatraSecondaryButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: onRetryBookings,
                ),
              ],
            ),
          )
        else if (bookings.isEmpty)
          const YatraEmptyState(
            icon: Icons.inbox_outlined,
            message: 'No bookings yet',
            hint: 'Tourist booking requests will appear here.',
          )
        else ...[
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.4,
            ),
            children: [
              _MetricCard(
                label: 'Pending Bookings',
                value: '$pending',
                icon: Icons.pending_actions,
                color: AppColors.warning,
                onTap: () => onOpenList(BookingStatus.pending),
              ),
              _MetricCard(
                label: 'Confirmed Bookings',
                value: '$confirmed',
                icon: Icons.verified_outlined,
                color: AppColors.success,
                onTap: () => onOpenList(BookingStatus.confirmed),
              ),
              _MetricCard(
                label: 'Total Bookings',
                value: '$total',
                icon: Icons.event_note_outlined,
                color: AppColors.primary,
                onTap: () => onOpenList(null),
              ),
              _MetricCard(
                label: 'Travelers in Bookings',
                value: '$travellers',
                icon: Icons.people_outline,
                color: AppColors.accent,
                onTap: () => onOpenList(null),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          YatraPrimaryButton(
            label: AppStrings.tr(language, 'admin.bookings'),
            icon: Icons.list_alt_outlined,
            onPressed: () => onOpenList(null),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        YatraSectionTitle(
          title: 'Travel catalog',
          subtitle: 'Manage the content the app shows travellers.',
        ),
        const SizedBox(height: AppSpacing.md),
        _ContentHubCard(
          icon: Icons.support_agent,
          label: 'Coordinators',
          description: 'Staff available for booking assignments',
          onTap: onOpenCoordinators,
        ),
        _ContentHubCard(
          icon: Icons.place_outlined,
          label: 'Places',
          description: 'Destinations, entry fees and details',
          onTap: onOpenPlaces,
        ),
        _ContentHubCard(
          icon: Icons.luggage_outlined,
          label: 'Packages',
          description: 'Tour packages, prices and itineraries',
          onTap: onOpenPackages,
        ),
        const SizedBox(height: AppSpacing.xl),

        YatraSectionTitle(
          title: 'People and access',
          subtitle: 'Your account, Yatra administrators and the tourist app.',
        ),
        const SizedBox(height: AppSpacing.md),
        _ContentHubCard(
          icon: Icons.group_outlined,
          label: 'Users',
          description: 'Grant and revoke administrator access from Yatra',
          onTap: onOpenUsers,
        ),
        _ContentHubCard(
          icon: Icons.settings_outlined,
          label: 'Settings',
          description: 'Your administrator account and sign out',
          onTap: onOpenSettings,
        ),
        _ContentHubCard(
          icon: Icons.visibility_outlined,
          label: 'Preview tourist app',
          description: 'See Yatra exactly as a traveller does',
          onTap: onOpenPreview,
        ),
        const SizedBox(height: AppSpacing.md),
        YatraSecondaryButton(
          label: 'Sign out',
          icon: Icons.logout,
          onPressed: onSignOut,
        ),
        const SizedBox(height: AppSpacing.xl),

        YatraSectionTitle(title: 'Setup'),
        const SizedBox(height: AppSpacing.md),
        YatraSecondaryButton(
          label: 'Migrate bundled catalog',
          icon: Icons.download_done,
          onPressed: seeding ? null : onSeedCatalog,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          seeding
              ? 'Migrating…'
              : 'One-off: copies the bundled records into Firestore, keeping '
                    'anything you have already edited.',
          style: AppType.caption,
        ),
      ],
    );
  }
}

/// Safe placeholder shown when the dashboard must stay closed.
class _AccessNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final String detail;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _AccessNotice({
    required this.icon,
    required this.message,
    required this.detail,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.bodyEmphasis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(detail, textAlign: TextAlign.center, style: AppType.caption),
            const SizedBox(height: AppSpacing.lg),
            YatraSecondaryButton(
              label: actionLabel,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry in the travel-catalog hub.
class _ContentHubCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ContentHubCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: YatraCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppType.bodyEmphasis),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return YatraCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const Spacer(),
          Text(value, style: AppType.display.copyWith(fontSize: 26)),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
