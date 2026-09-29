import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/itinerary_booking.dart';
import '../models/travel_coordinator.dart';
import 'admin_booking_repository.dart';
import 'booking_firestore_mapper.dart';

/// Firestore persistence for the admin booking area.
///
/// Differences from the tourist-facing FirestoreBookingService:
///
/// - reads across ALL travellers, not just the current user
/// - reads a single booking without an ownership filter
/// - writes admin-only fields (status, assignedCoordinator)
///
/// Authorization is not decided here. The client only requires *an*
/// authenticated user so unauthenticated calls fail fast and safely; the
/// `isAdmin()` Security Rule (users/{uid}.role == 'admin') is what actually
/// permits these reads and writes. No admin email or UID is hard-coded, and
/// bookings are never deleted.
class FirestoreAdminBookingService implements AdminBookingRepository {
  FirestoreAdminBookingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  /// Reads every booking request from every traveller, newest first.
  ///
  /// No `where` clause is applied: an admin sees the whole collection. Sorting
  /// is done in Dart so this does not require a composite Firestore index.
  @override
  Future<List<ItineraryBooking>> getAllBookings() async {
    _requireUser();

    final snapshot = await _bookings.get();

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

  /// Reads one booking by document ID.
  ///
  /// There is deliberately no `userId` comparison here — that ownership check
  /// belongs to the tourist repository only.
  @override
  Future<ItineraryBooking?> getBookingById(String bookingId) async {
    _requireUser();

    final snapshot = await _bookings.doc(bookingId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return BookingFirestoreMapper.bookingFromMap(
      documentId: snapshot.id,
      data: data,
    );
  }

  /// Writes only `status` and `updatedAt`.
  ///
  /// Nothing else on the document is touched, which keeps the write inside the
  /// admin `hasOnly(['status', 'assignedCoordinator', 'updatedAt'])` rule and
  /// avoids clobbering concurrent tourist-owned fields.
  @override
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    _requireUser();

    await _bookings.doc(bookingId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Writes only `assignedCoordinator` and `updatedAt`.
  ///
  /// The coordinator is stored as a snapshot map so a booking keeps the contact
  /// details that were actually assigned. `null` is persisted explicitly when
  /// the assignment is removed.
  @override
  Future<void> assignCoordinator(
    String bookingId,
    TravelCoordinator? coordinator,
  ) async {
    _requireUser();

    await _bookings.doc(bookingId).update({
      'assignedCoordinator': coordinator == null
          ? null
          : BookingFirestoreMapper.coordinatorToMap(coordinator),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user;
  }
}
