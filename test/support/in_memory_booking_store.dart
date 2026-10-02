import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_coordinator.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/recommendation_service.dart';

/// An in-memory booking collection for tests.
///
/// This used to be production frontend state shared between the tourist and
/// admin apps. Bookings are now persisted through [BookingRepository], so this
/// lives in `test/support` as a fixture: it still models status transitions,
/// coordinator assignment and booking-number generation so flow tests can
/// assert on realistic objects, but no application code depends on it.
class InMemoryBookingStore {
  InMemoryBookingStore._();

  static final InMemoryBookingStore instance = InMemoryBookingStore._();

  final List<ItineraryBooking> _bookings = [];

  int _sequence = 0;

  /// Read-only view of all bookings, newest first.
  List<ItineraryBooking> get bookings =>
      List<ItineraryBooking>.unmodifiable(_bookings.reversed.toList());

  /// Bookings filtered by status (unfiltered when [status] is null).
  List<ItineraryBooking> bookingsWithStatus(BookingStatus? status) {
    if (status == null) return bookings;

    return bookings.where((booking) => booking.status == status).toList();
  }

  ItineraryBooking? byId(String id) {
    for (final booking in _bookings) {
      if (booking.id == id) return booking;
    }

    return null;
  }

  /// Creates a new Pending booking request and returns it.
  ItineraryBooking create({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String touristType,
    required int adultCount,
    required int childCount,
    required String travelType,
    required int groupSize,
    required String currency,
    required double estimatedCost,
    required int duration,
    String? packageTitle,
    required TripDirection tripDirection,
    required TravelRoute route,
    required List<DayPlan> dayPlans,
  }) {
    final booking = ItineraryBooking(
      id: _nextBookingId(),
      createdAt: DateTime.now(),
      status: BookingStatus.pending,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      touristType: touristType,
      adultCount: adultCount,
      childCount: childCount,
      travelType: travelType,
      groupSize: groupSize,
      currency: currency,
      estimatedCost: estimatedCost,
      duration: duration,
      packageTitle: packageTitle,
      tripDirection: tripDirection,
      route: route,
      dayPlans: List<DayPlan>.of(dayPlans),
    );

    _bookings.add(booking);

    return booking;
  }

  /// Updates the status of a booking. No-op when the id is unknown.
  void updateStatus(String id, BookingStatus status) {
    byId(id)?.status = status;
  }

  /// Assigns (or clears, when [coordinator] is null) a coordinator.
  void assignCoordinator(String id, TravelCoordinator? coordinator) {
    byId(id)?.assignedCoordinator = coordinator;
  }

  /// Test booking id in the form YT-2026-001, matching the shape the backend
  /// returns for a freshly created booking.
  String _nextBookingId() {
    _sequence += 1;
    final year = DateTime.now().year;

    return 'YT-$year-${_sequence.toString().padLeft(3, '0')}';
  }

  /// Clears all bookings and resets the id sequence, so each test starts from
  /// a known state.
  void clear() {
    _bookings.clear();
    _sequence = 0;
  }
}
