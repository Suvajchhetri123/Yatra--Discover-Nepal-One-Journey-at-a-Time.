import 'dart:async';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/booking_repository.dart';
import 'package:yatra/services/recommendation_service.dart';

/// In-memory [BookingRepository] used by widget and unit tests.
///
/// It records every call so tests can assert how many backend operations a
/// screen performed, and it can be made to fail or to hold a request open to
/// model a slow network. No test ever talks to Firestore.
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    this.createdBooking,
    this.fetchedBooking,
    this.createError,
    this.fetchError,
    this.cancelError,
    this.createGate,
    this.fetchGate,
    this.listError,
    this.listGate,
    List<ItineraryBooking>? bookings,
  }) : bookings = List<ItineraryBooking>.of(bookings ?? const []);

  /// Booking returned by a successful [createBooking].
  final ItineraryBooking? createdBooking;

  /// Booking returned by [getBookingById].
  ///
  /// `null` models a booking that is missing or not owned by this user.
  ///
  /// Deliberately mutable: [cancelBooking] flips the status so a subsequent
  /// read models Firestore returning the persisted cancellation.
  ItineraryBooking? fetchedBooking;

  /// When set, [createBooking] throws this instead of persisting.
  ///
  /// Mutable so a retry test can clear the failure.
  Object? createError;

  /// When set, [getBookingById] throws this instead of returning a booking.
  Object? fetchError;

  /// When set, [cancelBooking] throws this instead of cancelling.
  Object? cancelError;

  /// Holds [createBooking] open until completed.
  final Completer<void>? createGate;

  /// Holds [getBookingById] open until completed.
  final Completer<void>? fetchGate;

  /// Bookings returned by [getCurrentUserBookings].
  ///
  /// Defaults to empty. It is mutable so a test can model a backend whose
  /// contents changed between two reads (e.g. a cancellation made elsewhere).
  final List<ItineraryBooking> bookings;

  /// When set, [getCurrentUserBookings] throws this.
  ///
  /// Mutable so a retry test can clear the failure.
  Object? listError;

  /// Holds [getCurrentUserBookings] open until completed.
  Completer<void>? listGate;

  int createCalls = 0;
  int fetchCalls = 0;
  int cancelCalls = 0;
  int listCalls = 0;

  /// Booking IDs passed to [cancelBooking], in call order.
  final List<String> cancelledBookingIds = <String>[];

  /// The arguments of the most recent [createBooking] call.
  String? lastDestination;
  DateTime? lastStartDate;
  DateTime? lastEndDate;
  String? lastTouristType;
  int? lastAdultCount;
  int? lastChildCount;
  String? lastTravelType;
  int? lastGroupSize;
  String? lastCurrency;
  double? lastEstimatedCost;
  int? lastDuration;
  String? lastPackageTitle;
  TravelRoute? lastRoute;
  List<DayPlan>? lastDayPlans;

  @override
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
  }) async {
    createCalls += 1;

    lastDestination = destination;
    lastStartDate = startDate;
    lastEndDate = endDate;
    lastTouristType = touristType;
    lastAdultCount = adultCount;
    lastChildCount = childCount;
    lastTravelType = travelType;
    lastGroupSize = groupSize;
    lastCurrency = currency;
    lastEstimatedCost = estimatedCost;
    lastDuration = duration;
    lastPackageTitle = packageTitle;
    lastRoute = route;
    lastDayPlans = dayPlans;

    final gate = createGate;

    if (gate != null) {
      await gate.future;
    }

    if (createError != null) {
      throw createError!;
    }

    final booking = createdBooking;

    if (booking == null) {
      throw StateError(
        'FakeBookingRepository has no createdBooking to return.',
      );
    }

    return booking;
  }

  @override
  Future<List<ItineraryBooking>> getCurrentUserBookings() async {
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

    final gate = fetchGate;

    if (gate != null) {
      await gate.future;
    }

    if (fetchError != null) {
      throw fetchError!;
    }

    return fetchedBooking;
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    cancelCalls += 1;
    cancelledBookingIds.add(bookingId);

    if (cancelError != null) {
      throw cancelError!;
    }

    // Firestore keeps the document and only changes its status.
    final booking = fetchedBooking;

    if (booking != null) {
      booking.status = BookingStatus.cancelled;
    }
  }
}
