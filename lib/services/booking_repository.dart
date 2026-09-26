import '../models/itinerary_booking.dart';
import '../models/travel_route_model.dart';
import 'recommendation_service.dart';

/// Contract for itinerary booking persistence.
///
/// Screens depend on this interface instead of a concrete backend so the
/// Firestore implementation can be swapped for a test double without any
/// screen importing Firebase.
abstract class BookingRepository {
  /// Creates a pending booking request owned by the current user.
  ///
  /// The returned [ItineraryBooking.id] is the backend record identifier used
  /// for every later lookup; [ItineraryBooking.bookingCode] is the
  /// user-facing reference.
  Future<ItineraryBooking> createBooking({
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
    required TravelRoute route,
    required List<DayPlan> dayPlans,
  });

  /// Returns every booking owned by the current user, newest first.
  Future<List<ItineraryBooking>> getCurrentUserBookings();

  /// Reads one booking, or returns `null` when it is missing or not owned by
  /// the current user.
  Future<ItineraryBooking?> getBookingById(String bookingId);

  /// Cancels one pending booking owned by the current user.
  ///
  /// Implementations must not delete the underlying record: booking history
  /// is preserved with a cancelled status.
  Future<void> cancelBooking(String bookingId);
}
