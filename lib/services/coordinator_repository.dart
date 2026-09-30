import '../models/travel_coordinator.dart';

/// Registry of the coordinators admins can assign to bookings.
///
/// Backed by the Firestore `coordinators` collection. Authorization is not
/// decided by this contract — the Firestore Security Rules
/// (`isAdmin()`) are what protect the documents.
abstract class CoordinatorRepository {
  /// Coordinators for the admin registry, sorted by name.
  ///
  /// [includeInactive] is false by default, so a caller that offers a picker
  /// can never offer a deactivated coordinator for a new assignment.
  Future<List<TravelCoordinator>> getCoordinators({
    bool includeInactive = false,
  });

  /// One coordinator by registry id, or null when it does not exist.
  Future<TravelCoordinator?> getCoordinatorById(String id);

  /// Creates a coordinator and returns the stored record.
  ///
  /// [id] is optional: leave it null for a normal admin entry (Firestore
  /// generates the id) and pass one only when migrating existing data, so a
  /// repeated run cannot create duplicates.
  Future<TravelCoordinator> createCoordinator({
    required String name,
    required String phone,
    required String email,
    String? id,
  });

  /// Updates the editable fields of an existing coordinator.
  ///
  /// Deactivation is a separate operation ([setCoordinatorActive]) so a rename
  /// can never accidentally re-activate someone.
  Future<void> updateCoordinator({
    required String id,
    required String name,
    required String phone,
    required String email,
  });

  /// Soft-removes (`active: false`) or restores (`active: true`) a
  /// coordinator. Historic booking snapshots are never touched.
  Future<void> setCoordinatorActive(String id, bool active);
}
