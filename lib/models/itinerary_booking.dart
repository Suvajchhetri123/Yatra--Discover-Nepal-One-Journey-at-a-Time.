import '../services/recommendation_service.dart';
import 'travel_coordinator.dart';
import 'travel_route_model.dart';

/// The lifecycle of an itinerary (trip) booking request.
///
/// Current Yatra version is an ITINERARY BOOKING REQUEST — not a real
/// ticket/seat/inventory booking. Status moves:
///
///   pending  -> confirmed | cancelled
///   pending  -> completed (admin marks the trip finished)
///
/// Central user-facing label lives on [BookingStatusLabel.label] so screens
/// never compare raw enum names or random status strings.
enum BookingStatus { pending, confirmed, cancelled, completed }

extension BookingStatusLabel on BookingStatus {
  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
    }
  }
}

/// A temporary frontend-only itinerary booking record.
///
/// Created when a tourist taps "Submit Booking Request" after reviewing their
/// generated itinerary. It keeps enough information to render the full
/// Booking Details screen: the trip summary, the built route and the
/// day-by-day plan.
///
/// NOTE: This is DEMO/FEMI state for the running app session. It will be
/// replaced by a Firestore-backed booking when the backend lands.
class ItineraryBooking {
  /// Readable demo id, e.g. `YT-2026-001`. NOT a server-guaranteed number.
  final String id;

  final DateTime createdAt;

  BookingStatus status;

  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String touristType;
  final int adultCount;
  final int childCount;
  final String travelType;
  final int groupSize;

  /// Currency the estimate was expressed in.
  final String currency;

  /// The estimated trip total in the estimate's currency (from the existing
  /// trip estimate — never re-priced at booking time).
  final double estimatedCost;

  final int duration;

  /// Package title when the itinerary was planned from a package.
  final String? packageTitle;

  final TripDirection tripDirection;
  final TravelRoute route;
  final List<DayPlan> dayPlans;

  /// Coordinator assigned by the admin frontend (null until reviewed).
  TravelCoordinator? assignedCoordinator;

  ItineraryBooking({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.touristType,
    required this.adultCount,
    required this.childCount,
    required this.travelType,
    required this.groupSize,
    required this.currency,
    required this.estimatedCost,
    required this.duration,
    this.packageTitle,
    required this.tripDirection,
    required this.route,
    required this.dayPlans,
    this.assignedCoordinator,
  });

  String get tripTypeLabel => route.tripDirectionDescription;

  String get goingRouteDescription => route.routeDescription;

  String get completeRouteDescription => route.completeRouteDescription;
}
