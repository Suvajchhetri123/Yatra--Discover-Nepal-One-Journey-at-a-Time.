import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/catalog_slug.dart';
import '../models/travel_coordinator.dart';
import 'catalog_document_id.dart';
import 'catalog_firestore_mapper.dart';
import 'coordinator_repository.dart';

/// Firestore persistence for the coordinator registry
/// (`coordinators` collection).
///
/// Authorization is not decided here: the client only requires *an*
/// authenticated user so unauthenticated calls fail fast, and the
/// `isAdmin()` Security Rule is what actually permits writes. No admin email or
/// UID is hard-coded, and documents are never deleted — a coordinator is
/// deactivated with `active: false` so booking snapshots that reference them
/// stay meaningful.
class FirestoreCoordinatorService implements CoordinatorRepository {
  FirestoreCoordinatorService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('coordinators');

  /// Reads the registry, newest-first by name.
  ///
  /// The `active` filter is applied in Dart rather than as a Firestore
  /// `where` clause, so this needs no extra index and a document that predates
  /// the flag (and therefore has no `active` field) can still be listed.
  @override
  Future<List<TravelCoordinator>> getCoordinators({
    bool includeInactive = false,
  }) async {
    _requireUser();

    final snapshot = await _collection.get();

    final coordinators = snapshot.docs
        .map(
          (document) => CatalogFirestoreMapper.coordinatorDocumentFromMap(
            documentId: document.id,
            data: document.data(),
          ),
        )
        .where((coordinator) => includeInactive || coordinator.active)
        .toList();

    coordinators.sort((a, b) => a.name.compareTo(b.name));

    return coordinators;
  }

  @override
  Future<TravelCoordinator?> getCoordinatorById(String id) async {
    _requireUser();

    final snapshot = await _collection.doc(id).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return CatalogFirestoreMapper.coordinatorDocumentFromMap(
      documentId: snapshot.id,
      data: data,
    );
  }

  @override
  Future<TravelCoordinator> createCoordinator({
    required String name,
    required String phone,
    required String email,
    String? id,
  }) async {
    _requireUser();

    _validate(name: name, phone: phone, email: email);

    final documentId = id == null || id.trim().isEmpty
        ? await resolveCatalogDocumentId(
            collection: _collection,
            base: catalogSlug(name),
          )
        : id.trim();

    final coordinator = TravelCoordinator(
      id: documentId,
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      active: true,
    );

    await _collection
        .doc(documentId)
        .set(CatalogFirestoreMapper.coordinatorDocumentToMap(coordinator));

    return coordinator;
  }

  @override
  Future<void> updateCoordinator({
    required String id,
    required String name,
    required String phone,
    required String email,
  }) async {
    _requireUser();

    _validate(name: name, phone: phone, email: email);

    await _collection
        .doc(id)
        .set(
          CatalogFirestoreMapper.coordinatorUpdateToMap(
            TravelCoordinator(
              id: id,
              name: name.trim(),
              phone: phone.trim(),
              email: email.trim(),
            ),
          ),
          SetOptions(merge: true),
        );
  }

  /// Writes only `active` and `updatedAt`, which keeps a deactivation from
  /// clobbering a concurrent rename and leaves `createdAt` intact.
  @override
  Future<void> setCoordinatorActive(String id, bool active) async {
    _requireUser();

    await _collection.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _validate({
    required String name,
    required String phone,
    required String email,
  }) {
    if (name.trim().isEmpty || phone.trim().isEmpty || email.trim().isEmpty) {
      throw ArgumentError('Name, phone and email are all required.');
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
