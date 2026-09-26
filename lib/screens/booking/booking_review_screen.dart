import 'package:flutter/material.dart';

import '../../models/itinerary_booking.dart';
import '../../models/travel_route_model.dart';
import '../../services/booking_repository.dart';
import '../../services/firestore_booking_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'booking_details_screen.dart';

/// Shown when the booking could not be written to the backend.
///
/// The raw backend exception is never surfaced to the tourist.
const String kBookingSubmitFailureMessage =
    'Could not submit your booking request. Please check your connection and '
    'try again.';

/// Review step shown before an itinerary booking request is submitted.
///
/// Protects the user from accidental submissions: everything already known
/// about the trip (destination, dates, route, travelers, estimate) is shown,
/// and the single action — "Submit Booking Request" — persists a Pending
/// booking in Firestore. NO payment happens here.
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

  /// Booking persistence backend.
  ///
  /// Defaults to [FirestoreBookingService]. Tests inject a fake so no widget
  /// test ever touches Firestore.
  final BookingRepository? repository;

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
    this.repository,
  });

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  /// True while the Firestore write is in flight.
  ///
  /// Guards the submit action so repeated taps can never create two booking
  /// documents.
  bool _submitting = false;

  /// Resolved lazily so an injected repository is never bypassed.
  late final BookingRepository _repository =
      widget.repository ?? FirestoreBookingService();

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _currency(double nprAmount) {
    return TripCostEstimator.formatInCurrency(nprAmount, widget.currency);
  }

  Future<void> _submit() async {
    // Synchronous guard: the flag is set before the first await, so a second
    // tap in the same frame cannot start a second write.
    if (_submitting) return;

    setState(() => _submitting = true);

    ItineraryBooking? created;

    try {
      // The trip snapshots supplied to this screen are persisted verbatim.
      // Pricing, routing and itinerary are never recomputed here.
      created = await _repository.createBooking(
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
        route: widget.route,
        dayPlans: widget.dayPlans,
      );
    } catch (_) {
      // Firestore is the source of truth: no silent local fallback.
      created = null;
    }

    if (!mounted) return;

    setState(() => _submitting = false);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kBookingSubmitFailureMessage)),
      );

      return;
    }

    await _showConfirmation(created);
  }

  Future<void> _showConfirmation(ItineraryBooking booking) async {
    await showDialog<void>(
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

                // booking.id is the Firestore document ID used for lookups.
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailsScreen(
                      bookingId: booking.id,
                      repository: _repository,
                    ),
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
                loading: _submitting,
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
