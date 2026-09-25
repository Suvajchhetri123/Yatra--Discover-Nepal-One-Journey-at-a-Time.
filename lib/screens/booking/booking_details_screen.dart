import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../models/itinerary_booking.dart';
import '../../models/travel_coordinator.dart';
import '../../services/demo_booking_store.dart';
import '../../services/demo_profile_store.dart';
import '../../services/google_maps_launcher.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_status_chip.dart';
import '../../widgets/yatra_components.dart';

/// Full detail view of a single itinerary booking request.
///
/// Shows everything recorded at submit time plus the coordinator section:
/// until the admin frontend assigns a coordinator, the tourist sees a
/// clear "Not assigned yet" state; afterwards the coordinator's name, phone
/// and email are shown with Call / Email actions.
class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  ItineraryBooking? _booking() {
    return DemoBookingStore.instance.byId(widget.bookingId);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _openUrl(Uri uri) async {
    final opened = await launchUrl(uri);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this action on the device.'),
        ),
      );
    }
  }

  Future<void> _confirmCancel() async {
    final booking = _booking();

    if (booking == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Booking Request?'),
        content: const Text(
          'This removes the booking request from the demo list. No '
          'coordinator will be assigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      DemoBookingStore.instance.updateStatus(
        booking.id,
        BookingStatus.cancelled,
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking request cancelled.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking();
    final language = DemoProfileStore.instance.language;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: Text('This booking is no longer available.')),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    final hasReturn =
        booking.route.isRoundTrip && booking.route.returnSegments.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'bookings.detailsTitle')),
      ),
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

              YatraSectionTitle(title: 'Trip Summary'),
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
                      label: 'Duration',
                      value: '${booking.duration} days',
                    ),
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

              YatraSectionTitle(title: 'Trip Route'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _routeLine('Going', booking.route.routeDescription),
                    if (hasReturn) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _routeLine('Coming Back', _returnRouteDescription()),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _buildLegMapsButtons(context, booking),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Itinerary'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

              _buildCoordinatorSection(context, booking, language),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinatorSection(
    BuildContext context,
    ItineraryBooking booking,
    String language,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YatraSectionTitle(
          title: AppStrings.tr(language, 'bookings.coordinator'),
        ),
        const SizedBox(height: AppSpacing.md),
        YatraCard(
          child: booking.assignedCoordinator == null
              ? _NoCoordinator(
                  language: language,
                  booking: booking,
                  onCancel: _confirmCancel,
                )
              : _CoordinatorTile(
                  coordinator: booking.assignedCoordinator!,
                  onCall: () => _openUrl(
                    Uri(
                      scheme: 'tel',
                      path: booking.assignedCoordinator!.phone,
                    ),
                  ),
                  onEmail: () => _openUrl(
                    Uri(
                      scheme: 'mailto',
                      path: booking.assignedCoordinator!.email,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLegMapsButtons(BuildContext context, ItineraryBooking booking) {
    final textTheme = Theme.of(context).textTheme;
    final route = booking.route;

    if (route.isLocalExploration) {
      return const Text(
        'Local exploration: use the transportation you selected in the '
        'Route Builder.',
        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceHint),
      );
    }

    final segments = route.completeSegments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton.icon(
              onPressed: () => GoogleMapsLauncher.launch(
                context,
                from: segment.from,
                to: segment.to,
                transportation: segment.transportation,
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(
                'View in Google Maps: ${segment.from} → ${segment.to}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (booking.route.isRoundTrip &&
            booking.route.returnSegments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'View in Google Maps shows both your going and coming back legs.',
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  String _returnRouteDescription() {
    final segments = _booking()!.route.returnSegments;

    if (segments.isEmpty) return '';

    final points = <String>[segments.first.from, ...segments.map((s) => s.to)];

    return points.join(' → ');
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

class _NoCoordinator extends StatelessWidget {
  final String language;
  final ItineraryBooking booking;
  final VoidCallback onCancel;

  const _NoCoordinator({
    required this.language,
    required this.booking,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canCancel = booking.status == BookingStatus.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                AppStrings.tr(language, 'bookings.coordinatorNotAssigned'),
                style: AppType.bodyEmphasis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.tr(language, 'bookings.coordinatorPending'),
          style: textTheme.bodySmall,
        ),
        if (canCancel) ...[
          const SizedBox(height: AppSpacing.lg),
          YatraSecondaryButton(
            label: 'Cancel Booking Request',
            icon: Icons.close,
            onPressed: onCancel,
          ),
        ],
      ],
    );
  }
}

class _CoordinatorTile extends StatelessWidget {
  final TravelCoordinator coordinator;
  final VoidCallback onCall;
  final VoidCallback onEmail;

  const _CoordinatorTile({
    required this.coordinator,
    required this.onCall,
    required this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.support_agent, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(coordinator.name, style: textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        YatraInfoRow(label: 'Phone', value: coordinator.phone),
        YatraInfoRow(label: 'Email', value: coordinator.email),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: YatraSecondaryButton(
                label: 'Call',
                icon: Icons.call_outlined,
                expanded: false,
                onPressed: onCall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: YatraSecondaryButton(
                label: 'Email',
                icon: Icons.mail_outline,
                expanded: false,
                onPressed: onEmail,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
