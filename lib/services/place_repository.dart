import '../models/place_model.dart';

/// Registry of the travel places admins curate.
///
/// Backed by the Firestore `places` collection. In this phase the tourist
/// planner still reads the static catalog; the registry exists so the content
/// has one admin-owned source of truth, with soft removal instead of deletes.
abstract class PlaceRepository {
  /// Places for the admin registry, sorted by name.
  Future<List<Place>> getAllPlaces({bool includeInactive = false});

  /// One place by registry id, or null when it does not exist.
  Future<Place?> getPlaceById(String placeId);

  /// Creates a place and returns the stored record.
  ///
  /// [id] is optional: leave it null for a normal admin entry (a stable slug of
  /// the location and name is generated, falling back to a generated id) and
  /// pass one only when migrating existing data.
  Future<Place> createPlace(Place place, {String? id});

  /// Updates every business field of an existing place.
  ///
  /// `active` is deliberately not part of an update: removal and restoration
  /// go through [setPlaceActive] so editing a place can never change whether it
  /// appears in the catalog.
  Future<void> updatePlace(Place place);

  /// Soft-removes (`active: false`) or restores (`active: true`) a place.
  Future<void> setPlaceActive(String placeId, bool active);
}
