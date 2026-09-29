import 'package:flutter/material.dart';

import '../../data/mock_coordinators.dart';
import '../../models/itinerary_booking.dart';
import '../../models/travel_coordinator.dart';
import '../../services/admin_booking_repository.dart';
import '../../services/firestore_admin_booking_service.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_status_chip.dart';
import '../../widgets/yatra_components.dart';

/// Shown when a single booking could not be read.
const String kAdminBookingDetailFailureMessage =
    'Could not load this booking. Please try again.';

/// Shown when a status or coordinator write fails.
///
/// The UI is never optimistically updated, so a failed write leaves the booking
/// exactly as Firestore still has it.
const String kAdminBookingActionFailureMessage =
    'Could not update this booking. Please try again.';

/// Admin view of a single booking: full trip details plus the two admin
/// actions — assign a coordinator and change the booking status.
///
/// Both actions are persisted to the booking document through
/// [AdminBookingRepository] and the booking is re-read afterwards, so the
/// screen only ever displays what the backend actually stored. The coordinator
/// *directory* is still the demo list.
class AdminBookingDetailsScreen extends StatefulWidget {
  final String bookingId;

  /// Booking persistence backend for the admin area.
  ///
  /// Defaults to [FirestoreAdminBookingService]. Tests inject a fake.
  final AdminBookingRepository? repository;

  const AdminBookingDetailsScreen({
    super.key,
    required this.bookingId,
    this.repository,
  });

  @override
  State<AdminBookingDetailsScreen> createState() =>
      _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState extends State<AdminBookingDetailsScreen> {
  ItineraryBooking? _booking;

  /// True until the first backend result arrives.
  bool _loading = true;

  /// Set when the read failed, or when the booking no longer exists.
  bool _missing = false;

  String? _error;

  /// True while an admin write is in flight. Blocks duplicate rapid writes.
  bool _saving = false;

  /// Guards against a stale read overwriting a newer one.
  int _loadToken = 0;

  /// Resolved lazily so an injected repository is never bypassed.
  late final AdminBookingRepository _repository =
      widget.repository ?? FirestoreAdminBookingService();

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  /// Reads the booking from the backend.
  Future<void> _loadBooking({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final token = ++_loadToken;

    try {
      final booking = await _repository.getBookingById(widget.bookingId);

      if (!mounted || token != _loadToken) return;

      setState(() {
        _booking = booking;
        _missing = booking == null;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;

      setState(() {
        _error = kAdminBookingDetailFailureMessage;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Persists one admin action, then re-reads the booking.
  ///
  /// The screen is only disabled while the write is in flight, so a double tap
  /// cannot produce two writes. A failure leaves the displayed booking
  /// untouched and reports a friendly message.
  Future<void> _runAdminAction({
    required Future<void> Function() write,
    required String successMessage,
  }) async {
    if (_saving) return;

    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      await write();
    } catch (_) {
      if (!mounted) return;

      setState(() => _saving = false);

      messenger.showSnackBar(
        const SnackBar(content: Text(kAdminBookingActionFailureMessage)),
      );

      return;
    }

    // Re-read instead of trusting local state: the backend is the source of
    // truth for both status and coordinator assignment.
    await _loadBooking(showLoader: false);

    if (!mounted) return;

    setState(() => _saving = false);

    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _assignCoordinator() async {
    final booking = _booking;

    if (booking == null || _saving) return;

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
    final reference = booking.bookingCode;

    await _runAdminAction(
      write: () => _repository.assignCoordinator(booking.id, coordinator),
      successMessage: coordinator == null
          ? 'Coordinator removed from $reference.'
          : '${coordinator.name} assigned to $reference.',
    );
  }

  Future<void> _changeStatus() async {
    final booking = _booking;

    if (booking == null || _saving) return;

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

    if (selected == null || !mounted) return;

    final reference = booking.bookingCode;

    await _runAdminAction(
      // The Firestore document ID is the write key.
      write: () => _repository.updateBookingStatus(booking.id, selected),
      successMessage: '$reference is now ${selected.label}.',
    );
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final error = _error;

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: Center(
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
                  onPressed: () => _loadBooking(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final booking = _booking;

    if (_missing || booking == null) {
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
                      'Booking Reference: ${booking.bookingCode}',
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
                onPressed: _saving ? null : _assignCoordinator,
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Status'),
              const SizedBox(height: AppSpacing.md),
              YatraSecondaryButton(
                label: 'Change Status',
                icon: Icons.swap_horiz,
                onPressed: _saving ? null : _changeStatus,
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
              'Choose who will look after this booking. The choice is saved to '
              'the booking, but the coordinator list is still demo data until '
              'the staff registry is migrated.',
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
