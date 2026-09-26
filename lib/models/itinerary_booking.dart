import '../services/recommendation_service.dart';
import 'travel_coordinator.dart';
import 'travel_route_model.dart';

/// Lifecycle of an itinerary booking request.
///
/// This is an itinerary/trip booking request, not a real ticket,
/// hotel inventory, seat reservation, or payment record.
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

/// Snapshot of a trip at the moment the tourist submits a booking request.
///
/// [id] is the internal record identifier.
/// - DemoBookingStore may still use a readable YT-* value.
/// - Firestore uses the Firestore document ID.
///
/// [bookingCode] is the user-facing booking reference.
///
/// [userId] is the Firebase Authentication UID of the booking owner.
class ItineraryBooking {
  final String id;

  /// Human-readable booking reference, e.g. YT-2026-A1B2C3.
  ///
  /// During the temporary demo-store period this defaults to [id].
  final String bookingCode;

  /// Firebase UID of the tourist who owns the booking.
  ///
  /// Empty only for legacy/demo bookings created before Firestore migration.
  final String userId;

  final DateTime createdAt;
  final DateTime? updatedAt;

  BookingStatus status;

  final String destination;

  final DateTime startDate;
  final DateTime endDate;

  final String touristType;

  final int adultCount;
  final int childCount;

  final String travelType;
  final int groupSize;

  final String currency;

  /// Snapshot of the estimate shown when the booking was submitted.
  ///
  /// Historical bookings must not be repriced from newer application data.
  final double estimatedCost;

  final int duration;

  final String? packageTitle;

  final TripDirection tripDirection;

  /// Route snapshot at booking time.
  final TravelRoute route;

  /// Itinerary snapshot at booking time.
  final List<DayPlan> dayPlans;

  /// Null until an admin assigns a travel coordinator.
  TravelCoordinator? assignedCoordinator;

  ItineraryBooking({
    required this.id,
    String? bookingCode,
    this.userId = '',
    required this.createdAt,
    this.updatedAt,
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
  }) : bookingCode = bookingCode ?? id;

  String get tripTypeLabel => route.tripDirectionDescription;

  String get goingRouteDescription => route.routeDescription;

  String get completeRouteDescription => route.completeRouteDescription;
}
