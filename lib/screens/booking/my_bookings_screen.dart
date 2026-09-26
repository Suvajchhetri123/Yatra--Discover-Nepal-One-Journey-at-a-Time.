import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/itinerary_booking.dart';
import '../../services/booking_repository.dart';
import '../../services/demo_profile_store.dart';
import '../../services/firestore_booking_service.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_status_chip.dart';
import '../../widgets/sos_action.dart';
import '../../widgets/yatra_components.dart';
import '../plan_trip/plan_trip_screen.dart';
import 'booking_details_screen.dart';

/// Shown when the booking history could not be read.
///
/// The raw backend error is never surfaced to the tourist.
const String kMyBookingsLoadFailureMessage =
    'Could not load your bookings. Please try again.';

/// The tourist's persistent list of itinerary booking requests.
///
/// Reads the authenticated tourist's bookings from the backend
/// ([BookingRepository.getCurrentUserBookings]), so the list survives app
/// restarts instead of living in one runtime session.
///
/// This is still an itinerary booking *request* system: nothing here is ticket
/// inventory, seat reservation or payment processing.
class MyBookingsScreen extends StatefulWidget {
  /// Booking persistence backend.
  ///
  /// Defaults to [FirestoreBookingService]. Tests inject a fake so no widget
  /// test ever touches Firestore.
  final BookingRepository? repository;

  const MyBookingsScreen({super.key, this.repository});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<ItineraryBooking> _bookings = <ItineraryBooking>[];

  /// True until the first backend result arrives, so the empty state is never
  /// shown for a still-pending request.
  bool _loading = true;

  String? _error;

  /// Guards against a stale read overwriting a newer one.
  int _loadToken = 0;

  /// Resolved lazily so an injected repository is never bypassed.
  late final BookingRepository _repository =
      widget.repository ?? FirestoreBookingService();

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  /// Reads the tourist's booking history from the backend.
  ///
  /// The screen never queries Firestore itself, and never duplicates the
  /// ownership filter or ordering: [BookingRepository] owns that.
  Future<void> _loadBookings({bool showLoader = true}) async {
    if (showLoader && mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final token = ++_loadToken;

    try {
      final bookings = await _repository.getCurrentUserBookings();

      if (!mounted || token != _loadToken) return;

      setState(() {
        _bookings = List<ItineraryBooking>.of(bookings);
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;

      // Keep an already-rendered list when a background refresh fails; only a
      // failed first load switches to the full error state. The empty state
      // must never stand in for a failed request.
      if (_bookings.isNotEmpty) {
        setState(() => _loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kMyBookingsLoadFailureMessage)),
        );

        return;
      }

      setState(() {
        _error = kMyBookingsLoadFailureMessage;
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
        builder: (context) => BookingDetailsScreen(
          // The Firestore document ID is the lookup key; the booking code is
          // only ever shown to the tourist.
          bookingId: booking.id,
          repository: _repository,
        ),
      ),
    );

    if (!mounted) return;

    // The booking may have been cancelled inside the details screen, so the
    // list is re-read from the backend instead of trusting local state.
    await _loadBookings(showLoader: false);
  }

  void _openPlanTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlanTripScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = DemoProfileStore.instance.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'bookings.title')),
        actions: const [YatraSosAction()],
      ),
      body: SafeArea(child: _buildBody(context, language)),
    );
  }

  Widget _buildBody(BuildContext context, String language) {
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
                label: 'Try Again',
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
      return _EmptyState(language: language, onPlanTrip: _openPlanTrip);
    }

    return RefreshIndicator(
      // Pull-to-refresh re-reads Firestore. The existing list stays visible
      // while the refresh runs.
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
            _BookingCard(
              booking: booking,
              formatDate: _formatDate,
              onTap: () => _openDetails(booking),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String language;
  final VoidCallback onPlanTrip;

  const _EmptyState({required this.language, required this.onPlanTrip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Column(
        children: [
          YatraEmptyState(
            icon: Icons.event_available_outlined,
            message: AppStrings.tr(language, 'bookings.emptyTitle'),
            hint: AppStrings.tr(language, 'bookings.emptyHint'),
          ),
          const Spacer(),
          YatraPrimaryButton(
            label: AppStrings.tr(language, 'bookings.planTripCta'),
            icon: Icons.rocket_launch_outlined,
            onPressed: onPlanTrip,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final ItineraryBooking booking;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _BookingCard({
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
                  booking.destination,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              BookingStatusChip(status: booking.status),
            ],
          ),
          if (booking.packageTitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(booking.packageTitle!, style: textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            // The user-facing reference is the booking code. The Firestore
            // document ID is never shown.
            '${booking.bookingCode} • ${formatDate(booking.startDate)} – '
            '${formatDate(booking.endDate)}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${booking.groupSize} travelers',
                style: textTheme.bodySmall,
              ),
              const Spacer(),
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
