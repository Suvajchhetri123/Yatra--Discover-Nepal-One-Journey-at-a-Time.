import 'package:flutter/material.dart';

import '../../models/itinerary_booking.dart';
import '../../models/travel_route_model.dart';
import '../../services/demo_booking_store.dart';
import '../../services/recommendation_service.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'booking_details_screen.dart';

/// Review step shown before an itinerary booking request is submitted.
///
/// Protects the user from accidental submissions: everything already known
/// about the trip (destination, dates, route, travelers, estimate) is shown,
/// and the single action — "Submit Booking Request" — creates a Pending
/// booking in the demo store. NO payment happens here.
class BookingReviewScreen extends StatefulWidget {
  final String touristType;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String currency;
  final TripCostEstimate estimate;
  final int duration;
  final String travelType;
  final int adultCount;
  final int childCount;
  final int groupSize;
  final String? packageTitle;
  final TravelRoute route;
  final List<DayPlan> dayPlans;

  const BookingReviewScreen({
    super.key,
    required this.touristType,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.estimate,
    required this.duration,
    required this.travelType,
    required this.adultCount,
    required this.childCount,
    required this.groupSize,
    this.packageTitle,
    required this.route,
    required this.dayPlans,
  });

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _currency(double nprAmount) {
    return TripCostEstimator.formatInCurrency(nprAmount, widget.currency);
  }

  Future<void> _submit() async {
    final booking = DemoBookingStore.instance.create(
      destination: widget.destination,
      startDate: widget.startDate,
      endDate: widget.endDate,
      touristType: widget.touristType,
      adultCount: widget.adultCount,
      childCount: widget.childCount,
      travelType: widget.travelType,
      groupSize: widget.groupSize,
      currency: widget.currency,
      estimatedCost: widget.estimate.total,
      duration: widget.duration,
      packageTitle: widget.packageTitle,
      tripDirection: widget.route.tripDirection,
      route: widget.route,
      dayPlans: widget.dayPlans,
    );

    // Confirmation shown immediately. No payment, no backend.
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Booking request submitted.'),
          content: Text(
            'Status: ${BookingStatus.pending.label}\n\n'
            'A travel coordinator will be assigned after the booking is '
            'reviewed.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BookingDetailsScreen(bookingId: booking.id),
                  ),
                );
              },
              child: const Text('View Booking'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Your Trip')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm the details below before submitting your trip '
                'booking request.',
                style: textTheme.bodyLarge,
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Trip Summary'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  children: [
                    YatraInfoRow(
                      label: 'Destination',
                      value: widget.destination,
                    ),
                    YatraInfoRow(
                      label: 'Trip Dates',
                      value:
                          '${_formatDate(widget.startDate)} – '
                          '${_formatDate(widget.endDate)}',
                    ),
                    YatraInfoRow(
                      label: 'Trip Type',
                      value: widget.route.tripDirectionDescription,
                    ),
                    YatraInfoRow(
                      label: 'Duration',
                      value: '${widget.duration} days',
                    ),
                    YatraInfoRow(
                      label: 'Traveler Count',
                      value: '${widget.groupSize}',
                    ),
                    YatraInfoRow(
                      label: 'Adults',
                      value: '${widget.adultCount}',
                    ),
                    YatraInfoRow(
                      label: 'Children',
                      value: '${widget.childCount}',
                    ),
                    YatraInfoRow(
                      label: 'Tourist Type',
                      value: widget.touristType,
                    ),
                    YatraInfoRow(
                      label: 'Travel Type',
                      value: widget.travelType,
                    ),
                    if (widget.packageTitle != null)
                      YatraInfoRow(
                        label: 'Package',
                        value: widget.packageTitle!,
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
                    _routeLine('Going', widget.route.routeDescription),
                    if (widget.route.isRoundTrip &&
                        widget.route.returnSegments.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _routeLine('Coming Back', _returnRouteDescription()),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Estimated Trip Cost'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This is an estimate based on the trip you planned. No '
                'payment is taken when you submit a booking request.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  children: [
                    YatraInfoRow(
                      label: 'Transport',
                      value: _currency(widget.estimate.transport),
                    ),
                    YatraInfoRow(
                      label: 'Stay',
                      value: _currency(widget.estimate.stay),
                    ),
                    YatraInfoRow(
                      label: 'Activities',
                      value: _currency(widget.estimate.activity),
                    ),
                    if (widget.estimate.packagePrice > 0)
                      YatraInfoRow(
                        label: 'Package',
                        value: _currency(widget.estimate.packagePrice),
                      ),
                    const Divider(height: AppSpacing.xl),
                    YatraInfoRow(
                      label: 'Estimated Trip Cost',
                      value: _currency(widget.estimate.total),
                      emphasized: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Selected Itinerary'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final day in widget.dayPlans)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'Day ${day.day} — ${_daySummary(day)}',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              YatraPrimaryButton(
                label: 'Submit Booking Request',
                icon: Icons.event_available_outlined,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  String _returnRouteDescription() {
    final points = <String>[
      widget.route.returnSegments.first.from,
      ...widget.route.returnSegments.map((s) => s.to),
    ];

    return points.join(' → ');
  }

  String _daySummary(DayPlan day) {
    if (day.items.isEmpty) return 'Rest / free time';

    return day.items.map((item) => item.title).take(2).join(' • ');
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
