import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/catalog_slug.dart';
import '../models/package_model.dart';
import 'catalog_document_id.dart';
import 'catalog_firestore_mapper.dart';
import 'package_repository.dart';

/// Firestore persistence for the tour package registry (`packages`
/// collection), where the document id is the package id.
///
/// Authorization is not decided here: the client only requires *an*
/// authenticated user, and the `isAdmin()` Security Rule is what permits
/// writes. Packages are never deleted — a package leaves the catalog with
/// `active: false` so historic bookings and itineraries stay resolvable.
class FirestorePackageService implements PackageRepository {
  FirestorePackageService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('packages');

  @override
  Future<List<TourPackage>> getAllPackages({
    bool includeInactive = false,
  }) async {
    _requireUser();

    final snapshot = await _collection.get();

    final packages = snapshot.docs
        .map(
          (document) => CatalogFirestoreMapper.packageDocumentFromMap(
            documentId: document.id,
            data: document.data(),
          ),
        )
        .where((package) => includeInactive || package.active)
        .toList();

    packages.sort((a, b) => a.title.compareTo(b.title));

    return packages;
  }

  @override
  Future<TourPackage?> getPackageById(String id) async {
    _requireUser();

    final snapshot = await _collection.doc(id).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return CatalogFirestoreMapper.packageDocumentFromMap(
      documentId: snapshot.id,
      data: data,
    );
  }

  @override
  Future<TourPackage> createPackage(TourPackage package) async {
    _requireUser();

    _validate(package);

    final documentId = package.id.trim().isEmpty
        ? await resolveCatalogDocumentId(
            collection: _collection,
            base: catalogSlug(package.title),
          )
        : await resolveCatalogDocumentId(
            collection: _collection,
            base: catalogSlug(package.id),
          );

    final stored = package.copyWith(id: documentId, active: true);

    await _collection
        .doc(documentId)
        .set(CatalogFirestoreMapper.packageDocumentToMap(stored));

    return stored;
  }

  @override
  Future<void> updatePackage(TourPackage package) async {
    _requireUser();

    _validate(package);

    if (package.id.isEmpty) {
      throw ArgumentError('Cannot update a package without an id.');
    }

    await _collection
        .doc(package.id)
        .set(
          CatalogFirestoreMapper.packageUpdateToMap(package),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> setPackageActive(String id, bool active) async {
    _requireUser();

    await _collection.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _validate(TourPackage package) {
    if (package.title.trim().isEmpty || package.region.trim().isEmpty) {
      throw ArgumentError('A package needs both a title and a region.');
    }

    if (package.price < 0) {
      throw ArgumentError('Package price must be zero or more.');
    }

    if (package.durationDays < 1) {
      throw ArgumentError('A package must last at least one day.');
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
