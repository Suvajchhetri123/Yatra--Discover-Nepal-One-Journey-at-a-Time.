import 'dart:async';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_coordinator.dart';
import 'package:yatra/services/admin_booking_repository.dart';

/// A recorded admin write, used by tests to assert exactly what was persisted.
typedef AdminStatusUpdate = ({String bookingId, BookingStatus status});

/// A recorded coordinator write. [coordinator] is null for a removal.
typedef AdminCoordinatorAssignment = ({
  String bookingId,
  TravelCoordinator? coordinator,
});

/// In-memory [AdminBookingRepository] used by admin widget and unit tests.
///
/// It records every call, can be made to fail or to hold a request open to model
/// a slow network, and applies successful writes to its in-memory bookings so a
/// later read reflects the "persisted" state the way Firestore would. No admin
/// test ever talks to Firestore.
class FakeAdminBookingRepository implements AdminBookingRepository {
  FakeAdminBookingRepository({
    List<ItineraryBooking>? bookings,
    this.fetchedBooking,
    this.listError,
    this.fetchError,
    this.statusError,
    this.coordinatorError,
    this.listGate,
    this.fetchGate,
    this.statusGate,
    this.coordinatorGate,
  }) : bookings = List<ItineraryBooking>.of(bookings ?? const []);

  /// Bookings returned by [getAllBookings] and looked up by [getBookingById].
  ///
  /// Mutable so a test can model a backend whose contents changed between two
  /// reads, and so admin writes can be observed on the next read.
  final List<ItineraryBooking> bookings;

  /// Fallback booking returned by [getBookingById] when the id is not in
  /// [bookings]. `null` models a booking that no longer exists.
  final ItineraryBooking? fetchedBooking;

  Object? listError;
  Object? fetchError;
  Object? statusError;
  Object? coordinatorError;

  Completer<void>? listGate;
  Completer<void>? fetchGate;
  Completer<void>? statusGate;
  Completer<void>? coordinatorGate;

  int listCalls = 0;
  int fetchCalls = 0;
  int statusCalls = 0;
  int coordinatorCalls = 0;

  /// Booking IDs passed to [getBookingById], in call order.
  final List<String> fetchedBookingIds = <String>[];

  final List<AdminStatusUpdate> statusUpdates = <AdminStatusUpdate>[];

  final List<AdminCoordinatorAssignment> coordinatorAssignments =
      <AdminCoordinatorAssignment>[];

  @override
  Future<List<ItineraryBooking>> getAllBookings() async {
    listCalls += 1;

    final gate = listGate;

    if (gate != null) {
      await gate.future;
    }

    if (listError != null) {
      throw listError!;
    }

    return List<ItineraryBooking>.of(bookings);
  }

  @override
  Future<ItineraryBooking?> getBookingById(String bookingId) async {
    fetchCalls += 1;
    fetchedBookingIds.add(bookingId);

    final gate = fetchGate;

    if (gate != null) {
      await gate.future;
    }

    if (fetchError != null) {
      throw fetchError!;
    }

    for (final booking in bookings) {
      if (booking.id == bookingId) return booking;
    }

    return fetchedBooking;
  }

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    statusCalls += 1;
    statusUpdates.add((bookingId: bookingId, status: status));

    final gate = statusGate;

    if (gate != null) {
      await gate.future;
    }

    if (statusError != null) {
      throw statusError!;
    }

    _mutate(bookingId, (booking) => booking.status = status);
  }

  @override
  Future<void> assignCoordinator(
    String bookingId,
    TravelCoordinator? coordinator,
  ) async {
    coordinatorCalls += 1;
    coordinatorAssignments.add((
      bookingId: bookingId,
      coordinator: coordinator,
    ));

    final gate = coordinatorGate;

    if (gate != null) {
      await gate.future;
    }

    if (coordinatorError != null) {
      throw coordinatorError!;
    }

    _mutate(bookingId, (booking) => booking.assignedCoordinator = coordinator);
  }

  void _mutate(
    String bookingId,
    void Function(ItineraryBooking booking) apply,
  ) {
    for (final booking in bookings) {
      if (booking.id == bookingId) {
        apply(booking);
        return;
      }
    }
  }
}
