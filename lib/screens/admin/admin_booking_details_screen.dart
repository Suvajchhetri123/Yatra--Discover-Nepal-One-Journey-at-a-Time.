import 'package:flutter/material.dart';

import '../../data/mock_coordinators.dart';
import '../../models/itinerary_booking.dart';
import '../../models/travel_coordinator.dart';
import '../../services/demo_booking_store.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_status_chip.dart';
import '../../widgets/yatra_components.dart';

/// Admin view of a single booking: full trip details plus the two admin
/// actions — assign a coordinator and change the booking status.
///
/// Both actions write to the shared DemoBookingStore so the tourist-facing
/// My Bookings reflects them immediately in the same runtime session.
class AdminBookingDetailsScreen extends StatefulWidget {
  final String bookingId;

  const AdminBookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<AdminBookingDetailsScreen> createState() =>
      _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState extends State<AdminBookingDetailsScreen> {
  ItineraryBooking? _booking() {
    return DemoBookingStore.instance.byId(widget.bookingId);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _assignCoordinator() async {
    final booking = _booking();

    if (booking == null) return;

    final action = await showModalBottomSheet<_CoordinatorAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _CoordinatorPicker(
        current: booking.assignedCoordinator,
        coordinators: kMockCoordinators,
      ),
    );

    if (action == null || !mounted) return;

    final coordinator = action.coordinator;

    DemoBookingStore.instance.assignCoordinator(booking.id, coordinator);

    setState(() {});

    if (coordinator != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${coordinator.name} assigned to ${booking.id}.'),
        ),
      );
    }
  }

  Future<void> _changeStatus() async {
    final booking = _booking();

    if (booking == null) return;

    final selected = await showDialog<BookingStatus>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Change Booking Status'),
        children: [
          for (final status in BookingStatus.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, status),
              child: Row(
                children: [
                  Icon(
                    _statusIcon(status),
                    size: 20,
                    color: bookingStatusColor(status),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(status.label),
                ],
              ),
            ),
        ],
      ),
    );

    if (selected == null) return;

    DemoBookingStore.instance.updateStatus(booking.id, selected);

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${booking.id} is now ${selected.label}.')),
      );
    }
  }

  IconData _statusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.pending_actions;
      case BookingStatus.confirmed:
        return Icons.verified_outlined;
      case BookingStatus.cancelled:
        return Icons.cancel_outlined;
      case BookingStatus.completed:
        return Icons.task_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking();

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: Text('This booking is no longer available.')),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Booking Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Booking ID: ${booking.id}',
                      style: textTheme.titleMedium,
                    ),
                  ),
                  BookingStatusChip(status: booking.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Trip Details'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  children: [
                    YatraInfoRow(
                      label: 'Destination',
                      value: booking.destination,
                    ),
                    if (booking.packageTitle != null)
                      YatraInfoRow(
                        label: 'Package',
                        value: booking.packageTitle!,
                      ),
                    YatraInfoRow(
                      label: 'Trip Dates',
                      value:
                          '${_formatDate(booking.startDate)} – '
                          '${_formatDate(booking.endDate)}',
                    ),
                    YatraInfoRow(
                      label: 'Trip Type',
                      value: booking.tripTypeLabel,
                    ),
                    YatraInfoRow(
                      label: 'Estimated Trip Cost',
                      value: TripCostEstimator.formatInCurrency(
                        booking.estimatedCost,
                        booking.currency,
                      ),
                      emphasized: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Traveler Info'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  children: [
                    YatraInfoRow(
                      label: 'Tourist Type',
                      value: booking.touristType,
                    ),
                    YatraInfoRow(
                      label: 'Travel Type',
                      value: booking.travelType,
                    ),
                    YatraInfoRow(
                      label: 'Travelers',
                      value: '${booking.groupSize}',
                    ),
                    YatraInfoRow(
                      label: 'Adults',
                      value: '${booking.adultCount}',
                    ),
                    YatraInfoRow(
                      label: 'Children',
                      value: '${booking.childCount}',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Route & Itinerary'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _routeLine('Route', booking.route.completeRouteDescription),
                    const SizedBox(height: AppSpacing.md),
                    for (final day in booking.dayPlans)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'Day ${day.day} — '
                          '${day.items.map((item) => item.title).take(2).join(' • ')}',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(
                title: 'Coordinator',
                subtitle: booking.assignedCoordinator == null
                    ? 'No coordinator assigned yet.'
                    : 'Assigned to ${booking.assignedCoordinator!.name}.',
              ),
              const SizedBox(height: AppSpacing.md),
              YatraSecondaryButton(
                label: booking.assignedCoordinator == null
                    ? 'Assign Coordinator'
                    : 'Change Coordinator',
                icon: Icons.support_agent,
                onPressed: _assignCoordinator,
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Status'),
              const SizedBox(height: AppSpacing.md),
              YatraSecondaryButton(
                label: 'Change Status',
                icon: Icons.swap_horiz,
                onPressed: _changeStatus,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routeLine(String label, String value) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: textTheme.titleMedium),
        Expanded(child: Text(value, style: textTheme.bodyMedium)),
      ],
    );
  }
}

/// Result of the coordinator picker: either assign a specific coordinator,
/// remove the current one, or cancel (null).
class _CoordinatorAction {
  final TravelCoordinator? coordinator;

  const _CoordinatorAction._(this.coordinator);

  static const _remove = _CoordinatorAction._(null);
}

/// Bottom sheet listing mock coordinators (plus "Remove coordinator").
class _CoordinatorPicker extends StatelessWidget {
  final TravelCoordinator? current;
  final List<TravelCoordinator> coordinators;

  const _CoordinatorPicker({required this.current, required this.coordinators});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign Coordinator', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Choose who will look after this booking. Demo coordinators '
              'only — replace with the real staff registry in the backend.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (current != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Remove coordinator'),
                onTap: () => Navigator.pop(context, _CoordinatorAction._remove),
              ),
            for (final coordinator in coordinators)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.support_agent, color: scheme.primary),
                title: Text(coordinator.name),
                subtitle: Text('${coordinator.phone}\n${coordinator.email}'),
                trailing: current?.id == coordinator.id
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : null,
                onTap: () =>
                    Navigator.pop(context, _CoordinatorAction._(coordinator)),
              ),
            const SizedBox(height: AppSpacing.lg),
            YatraSecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
