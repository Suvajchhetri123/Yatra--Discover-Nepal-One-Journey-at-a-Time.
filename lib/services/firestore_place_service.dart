import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/place_model.dart';
import 'catalog_document_id.dart';
import 'catalog_firestore_mapper.dart';
import 'place_repository.dart';

/// Firestore persistence for the place registry (`places` collection).
///
/// Authorization is not decided here: the client only requires *an*
/// authenticated user, and the `isAdmin()` Security Rule is what permits
/// writes. Places are never deleted — a place is removed from the catalog with
/// `active: false` so booking snapshots and itineraries that reference it stay
/// resolvable.
class FirestorePlaceService implements PlaceRepository {
  FirestorePlaceService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('places');

  /// Reads the registry. [includeInactive] is false by default so an admin list
  /// or a tourist catalog read only ever surfaces live places.
  @override
  Future<List<Place>> getAllPlaces({bool includeInactive = false}) async {
    _requireUser();

    final snapshot = await _collection.get();

    final places = snapshot.docs
        .map(
          (document) => CatalogFirestoreMapper.placeDocumentFromMap(
            documentId: document.id,
            data: document.data(),
          ),
        )
        .where((place) => includeInactive || place.active)
        .toList();

    places.sort((a, b) => a.name.compareTo(b.name));

    return places;
  }

  @override
  Future<Place?> getPlaceById(String placeId) async {
    _requireUser();

    final snapshot = await _collection.doc(placeId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return CatalogFirestoreMapper.placeDocumentFromMap(
      documentId: snapshot.id,
      data: data,
    );
  }

  @override
  Future<Place> createPlace(Place place, {String? id}) async {
    _requireUser();

    _validate(place);

    final documentId = id == null || id.trim().isEmpty
        ? await resolveCatalogDocumentId(
            collection: _collection,
            base: Place.slugFor(place.location, place.name),
          )
        : id.trim();

    final stored = place.copyWith(id: documentId, active: true);

    await _collection
        .doc(documentId)
        .set(CatalogFirestoreMapper.placeDocumentToMap(stored));

    return stored;
  }

  @override
  Future<void> updatePlace(Place place) async {
    _requireUser();

    _validate(place);

    if (place.id.isEmpty) {
      throw ArgumentError('Cannot update a place without a registry id.');
    }

    await _collection
        .doc(place.id)
        .set(
          CatalogFirestoreMapper.placeUpdateToMap(place),
          SetOptions(merge: true),
        );
  }

  /// Writes only `active` and `updatedAt`.
  @override
  Future<void> setPlaceActive(String placeId, bool active) async {
    _requireUser();

    await _collection.doc(placeId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _validate(Place place) {
    if (place.name.trim().isEmpty || place.location.trim().isEmpty) {
      throw ArgumentError('A place needs both a name and a location.');
    }

    if (place.entryFee < 0 || place.recommendedHours < 0) {
      throw ArgumentError('Entry fee and hours must be zero or more.');
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user;
  }
}
