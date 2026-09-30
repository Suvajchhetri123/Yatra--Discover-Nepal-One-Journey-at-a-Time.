import '../models/itinerary_booking.dart';
import '../models/travel_coordinator.dart';

/// Contract for admin-side itinerary booking persistence.
///
/// This is deliberately separate from [BookingRepository]: the tourist contract
/// is ownership-restricted (a traveller may only ever read and cancel their own
/// records), while this contract is the cross-user read/administer contract
/// used by the admin area. Keeping them apart makes it impossible for an admin
/// screen to accidentally reuse — and therefore weaken — the tourist
/// ownership filter.
///
/// Firestore Security Rules remain the real authorization boundary:
/// `isAdmin()` is derived from users/{uid}.role, and admin booking writes are
/// restricted to `status`, `assignedCoordinator` and `updatedAt`.
abstract class AdminBookingRepository {
  /// Returns every booking across all travellers, newest first.
  Future<List<ItineraryBooking>> getAllBookings();

  /// Reads one booking by its Firestore document ID, or returns `null` when it
  /// is missing.
  ///
  /// Unlike [BookingRepository.getBookingById] there is no tourist ownership
  /// filter: an admin is allowed to read any booking.
  Future<ItineraryBooking?> getBookingById(String bookingId);

  /// Persists a new booking status.
  ///
  /// Bookings are never deleted; history is preserved with its new status.
  Future<void> updateBookingStatus(String bookingId, BookingStatus status);

  /// Persists the assigned travel coordinator on the booking document.
  ///
  /// Passing `null` removes the current assignment. The coordinator itself is
  /// stored as a snapshot, and the pickable list comes from
  /// `CoordinatorRepository` (the Firestore `coordinators` collection).
  Future<void> assignCoordinator(
    String bookingId,
    TravelCoordinator? coordinator,
  );
}
