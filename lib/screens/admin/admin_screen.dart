import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/itinerary_booking.dart';
import '../../models/user_profile.dart';
import '../../services/admin_booking_repository.dart';
import '../../services/demo_profile_store.dart';
import '../../services/firestore_admin_booking_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_booking_list_screen.dart';

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
/// from a runtime demo store. The coordinator *directory* is still demo data.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.profileLoader, this.bookingRepository});

  /// Overrides how the authenticated profile is resolved.
  ///
  /// Production leaves this null so the screen uses
  /// [FirestoreService.getCurrentUserProfile]; widget tests inject a fake.
  final UserProfileLoader? profileLoader;

  /// Booking persistence backend for the admin area.
  ///
  /// Defaults to [FirestoreAdminBookingService]. Tests inject a fake.
  final AdminBookingRepository? bookingRepository;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _verifying = true;
  bool _authorized = false;
  bool _verificationFailed = false;

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

  @override
  void initState() {
    super.initState();
    _verifyAccess();
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = DemoProfileStore.instance.language;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr(language, 'admin.title'))),
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

    final error = _bookingsError;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              YatraEmptyState(icon: Icons.cloud_off_outlined, message: error),
              const SizedBox(height: AppSpacing.lg),
              YatraPrimaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: () => _loadBookings(),
              ),
            ],
          ),
        ),
      );
    }

    final bookings = _bookings;

    if (bookings.isEmpty) {
      return const YatraEmptyState(
        icon: Icons.inbox_outlined,
        message: 'No bookings yet',
        hint: 'Tourist booking requests will appear here.',
      );
    }

    return RefreshIndicator(
      // Pull-to-refresh re-reads Firestore and keeps the metrics visible.
      onRefresh: () => _loadBookings(showLoader: false),
      child: _Dashboard(
        language: language,
        bookings: bookings,
        onOpenList: (status) => _openList(context, status),
      ),
    );
  }
}

/// The admin dashboard, derived entirely from the loaded Firestore bookings.
class _Dashboard extends StatelessWidget {
  final String language;
  final List<ItineraryBooking> bookings;
  final void Function(BookingStatus? status) onOpenList;

  const _Dashboard({
    required this.language,
    required this.bookings,
    required this.onOpenList,
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

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Text(
          'Live booking requests from Firestore. The coordinator directory is '
          'still demo data until the staff registry is migrated.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),

        YatraSectionTitle(title: AppStrings.tr(language, 'admin.dashboard')),
        const SizedBox(height: AppSpacing.md),

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

        const SizedBox(height: AppSpacing.xl),

        YatraPrimaryButton(
          label: AppStrings.tr(language, 'admin.bookings'),
          icon: Icons.list_alt_outlined,
          onPressed: () => onOpenList(null),
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
