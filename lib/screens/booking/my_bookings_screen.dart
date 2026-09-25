import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/itinerary_booking.dart';
import '../../services/demo_booking_store.dart';
import '../../services/demo_profile_store.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_status_chip.dart';
import '../../widgets/sos_action.dart';
import '../../widgets/yatra_components.dart';
import '../plan_trip/plan_trip_screen.dart';
import 'booking_details_screen.dart';

/// The tourist's list of itinerary booking requests for the current session.
///
/// Reads the in-memory DemoBookingStore so admin status changes are visible
/// immediately within the same runtime.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openDetails(ItineraryBooking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(bookingId: booking.id),
      ),
    ).then((_) {
      // Refresh in case the booking was cancelled inside details.
      if (mounted) setState(() {});
    });
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
    final bookings = DemoBookingStore.instance.bookings;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'bookings.title')),
        actions: const [YatraSosAction()],
      ),
      body: SafeArea(
        child: bookings.isEmpty
            ? _EmptyState(language: language, onPlanTrip: _openPlanTrip)
            : RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    Text(
                      '${bookings.length} booking'
                      '${bookings.length == 1 ? '' : 's'} in this session',
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
              ),
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
            '${booking.id} • ${formatDate(booking.startDate)} – '
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
