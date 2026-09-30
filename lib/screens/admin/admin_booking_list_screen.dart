import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/itinerary_booking.dart';
import '../../services/admin_booking_repository.dart';
import '../../services/coordinator_repository.dart';
import '../../services/demo_profile_store.dart';
import '../../services/firestore_admin_booking_service.dart';
import '../../services/firestore_coordinator_service.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_status_chip.dart';
import '../../widgets/yatra_components.dart';
import 'admin_booking_details_screen.dart';

/// Shown when the admin booking list could not be read.
const String kAdminBookingListFailureMessage =
    'Could not load bookings. Please try again.';

/// Admin list of booking requests with status filter chips.
///
/// Bookings come from [AdminBookingRepository.getAllBookings], i.e. Firestore,
/// so the list covers every traveller. The status filter is applied locally on
/// the already-loaded collection instead of re-querying the backend.
class AdminBookingListScreen extends StatefulWidget {
  final BookingStatus? initialStatus;

  /// Booking persistence backend for the admin area.
  ///
  /// Defaults to [FirestoreAdminBookingService]. Tests inject a fake.
  final AdminBookingRepository? repository;

  /// Source of the assignable coordinator list on the details screen.
  ///
  /// Defaults to [FirestoreCoordinatorService]. Tests inject a fake.
  final CoordinatorRepository? coordinatorRepository;

  const AdminBookingListScreen({
    super.key,
    this.initialStatus,
    this.repository,
    this.coordinatorRepository,
  });

  @override
  State<AdminBookingListScreen> createState() => _AdminBookingListScreenState();
}

class _AdminBookingListScreenState extends State<AdminBookingListScreen> {
  late BookingStatus? _filter = widget.initialStatus;

  List<ItineraryBooking> _bookings = <ItineraryBooking>[];

  /// True until the first backend result arrives, so the empty state is never
  /// shown for a still-pending request.
  bool _loading = true;

  String? _error;

  /// Guards against a stale read overwriting a newer one.
  int _loadToken = 0;

  /// Resolved lazily so an injected repository is never bypassed.
  late final AdminBookingRepository _repository =
      widget.repository ?? FirestoreAdminBookingService();

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  /// Reads every booking from the backend.
  Future<void> _loadBookings({bool showLoader = true}) async {
    if (showLoader && mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final token = ++_loadToken;

    try {
      final bookings = await _repository.getAllBookings();

      if (!mounted || token != _loadToken) return;

      setState(() {
        _bookings = List<ItineraryBooking>.of(bookings);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;

      // Keep an already-rendered list when a background refresh fails.
      if (_bookings.isNotEmpty) {
        setState(() => _loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kAdminBookingListFailureMessage)),
        );

        return;
      }

      setState(() {
        _error = kAdminBookingListFailureMessage;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _openDetails(ItineraryBooking booking) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminBookingDetailsScreen(
          // The Firestore document ID is the lookup key; the booking code is
          // what the administrator sees.
          bookingId: booking.id,
          repository: _repository,
          coordinatorRepository: widget.coordinatorRepository,
        ),
      ),
    );

    if (!mounted) return;

    // Status or coordinator may have changed, so re-read the backend instead of
    // trusting the list loaded before the details screen opened.
    await _loadBookings(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    final language = DemoProfileStore.instance.language;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr(language, 'admin.bookings'))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.sm,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All', null),
                    for (final status in BookingStatus.values)
                      _filterChip(status.label, status),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;

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

    // Status filtering stays local: the whole collection is already loaded.
    final bookings = _bookings
        .where((booking) => _filter == null || booking.status == _filter)
        .toList();

    if (bookings.isEmpty) {
      return YatraEmptyState(
        icon: Icons.inbox_outlined,
        message: 'No bookings',
        hint: 'No bookings match this status filter.',
      );
    }

    return RefreshIndicator(
      // Pull-to-refresh re-reads Firestore and keeps the list visible.
      onRefresh: () => _loadBookings(showLoader: false),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text(
            '${bookings.length} booking'
            '${bookings.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final booking in bookings)
            _AdminBookingCard(
              booking: booking,
              formatDate: _formatDate,
              onTap: () => _openDetails(booking),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, BookingStatus? status) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: YatraChip(
        label: label,
        selected: _filter == status,
        onSelected: (_) => setState(() => _filter = status),
        isFilter: true,
      ),
    );
  }
}

class _AdminBookingCard extends StatelessWidget {
  final ItineraryBooking booking;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _AdminBookingCard({
    required this.booking,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return YatraCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // The user-facing reference is the booking code. The
                  // Firestore document ID is never rendered.
                  booking.bookingCode,
                  style: textTheme.titleMedium,
                ),
              ),
              BookingStatusChip(status: booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(booking.destination, style: AppType.bodyEmphasis),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatDate(booking.startDate)} – '
            '${formatDate(booking.endDate)} · '
            '${booking.groupSize} traveler'
            '${booking.groupSize == 1 ? '' : 's'}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                booking.assignedCoordinator == null
                    ? Icons.person_outline
                    : Icons.support_agent,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  booking.assignedCoordinator == null
                      ? 'No coordinator'
                      : booking.assignedCoordinator!.name,
                  style: textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                TripCostEstimator.formatInCurrency(
                  booking.estimatedCost,
                  booking.currency,
                ),
                style: AppType.label,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
