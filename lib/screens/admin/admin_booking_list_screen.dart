import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/itinerary_booking.dart';
import '../../services/demo_booking_store.dart';
import '../../services/demo_profile_store.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_status_chip.dart';
import '../../widgets/yatra_components.dart';
import 'admin_booking_details_screen.dart';

/// Admin list of booking requests with status filter chips.
class AdminBookingListScreen extends StatefulWidget {
  final BookingStatus? initialStatus;

  const AdminBookingListScreen({super.key, this.initialStatus});

  @override
  State<AdminBookingListScreen> createState() => _AdminBookingListScreenState();
}

class _AdminBookingListScreenState extends State<AdminBookingListScreen> {
  late BookingStatus? _filter = widget.initialStatus;

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openDetails(ItineraryBooking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminBookingDetailsScreen(bookingId: booking.id),
      ),
    ).then((_) {
      if (mounted) setState(() {}); // status/coordinator may have changed
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = DemoProfileStore.instance.language;
    final store = DemoBookingStore.instance;
    final bookings = store.bookingsWithStatus(_filter);

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
            Expanded(
              child: bookings.isEmpty
                  ? YatraEmptyState(
                      icon: Icons.inbox_outlined,
                      message: 'No bookings',
                      hint: 'No bookings match this status filter.',
                    )
                  : ListView(
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
            ),
          ],
        ),
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
              Expanded(child: Text(booking.id, style: textTheme.titleMedium)),
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
