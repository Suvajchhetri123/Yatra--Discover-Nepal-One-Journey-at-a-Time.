import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/itinerary_booking.dart';
import '../models/travel_route_model.dart';
import 'booking_firestore_mapper.dart';
import 'booking_repository.dart';
import 'recommendation_service.dart';

/// Firestore persistence for tourist itinerary booking requests.
///
/// Current scope:
///
/// - create booking
/// - read current tourist's bookings
/// - read one owned booking
/// - cancel a pending owned booking
///
/// Admin operations are intentionally handled in a later backend phase.
class FirestoreBookingService implements BookingRepository {
  FirestoreBookingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  /// Creates an itinerary booking request for the currently authenticated
  /// tourist.
  ///
  /// Firestore document IDs and user-facing booking codes are deliberately
  /// different.
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
    final user = _requireUser();

    final document = _bookings.doc();

    final bookingCode = _buildBookingCode(document.id);

    final now = DateTime.now();

    final booking = ItineraryBooking(
      id: document.id,
      bookingCode: bookingCode,
      userId: user.uid,
      createdAt: now,
      updatedAt: now,
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
      tripDirection: route.tripDirection,
      route: route,
      dayPlans: List<DayPlan>.of(dayPlans),
    );

    final data = BookingFirestoreMapper.bookingToMap(booking);

    // Server timestamps are authoritative for database audit fields.
    data['createdAt'] = FieldValue.serverTimestamp();

    data['updatedAt'] = FieldValue.serverTimestamp();

    await document.set(data);

    // Read back the written document so server timestamps are reflected
    // in the model returned to the UI.
    final createdSnapshot = await document.get();

    final createdData = createdSnapshot.data();

    if (createdData == null) {
      throw StateError('Booking was created but could not be read back.');
    }

    return BookingFirestoreMapper.bookingFromMap(
      documentId: createdSnapshot.id,
      data: createdData,
    );
  }

  /// Returns all bookings owned by the currently authenticated tourist.
  ///
  /// Sorting is performed in Dart for now. This avoids requiring a composite
  /// Firestore index during the first backend phase.
  @override
  Future<List<ItineraryBooking>> getCurrentUserBookings() async {
    final user = _requireUser();

    final snapshot = await _bookings.where('userId', isEqualTo: user.uid).get();

    final bookings = snapshot.docs
        .map(
          (document) => BookingFirestoreMapper.bookingFromMap(
            documentId: document.id,
            data: document.data(),
          ),
        )
        .toList();

    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return bookings;
  }

  /// Reads a single booking only when it belongs to the authenticated user.
  ///
  /// Security Rules will enforce ownership server-side later; this client-side
  /// check is still useful for application correctness.
  @override
  Future<ItineraryBooking?> getBookingById(String bookingId) async {
    final user = _requireUser();

    final snapshot = await _bookings.doc(bookingId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    if (data['userId'] != user.uid) {
      return null;
    }

    return BookingFirestoreMapper.bookingFromMap(
      documentId: snapshot.id,
      data: data,
    );
  }

  /// Cancels one pending booking owned by the current user.
  ///
  /// It does NOT delete the booking. Historical booking records remain in
  /// Firestore with status = cancelled.
  @override
  Future<void> cancelBooking(String bookingId) async {
    final user = _requireUser();

    final reference = _bookings.doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Booking not found.');
      }

      final data = snapshot.data();

      if (data == null) {
        throw StateError('Booking data is unavailable.');
      }

      if (data['userId'] != user.uid) {
        throw StateError('You do not have access to this booking.');
      }

      final status = BookingFirestoreMapper.bookingStatusFromString(
        data['status'] as String?,
      );

      if (status != BookingStatus.pending) {
        throw StateError('Only pending bookings can be cancelled.');
      }

      transaction.update(reference, {
        'status': BookingStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Creates a readable reference without a global sequential counter.
  ///
  /// Example:
  /// YT-2026-A1B2C3
  ///
  /// The actual Firestore document ID remains the canonical unique record ID.
  String _buildBookingCode(String documentId) {
    final year = DateTime.now().year;

    final normalized = documentId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final suffix = normalized.length >= 6
        ? normalized.substring(0, 6)
        : normalized.padRight(6, 'X');

    return 'YT-$year-$suffix';
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user;
  }
}
