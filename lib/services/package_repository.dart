import '../models/package_model.dart';

/// Registry of the bookable tour packages admins curate.
///
/// Backed by the Firestore `packages` collection, where the document id is the
/// package id. Soft removal keeps packages that historic bookings and
/// itineraries already reference.
abstract class PackageRepository {
  /// Packages for the admin registry, sorted by title.
  Future<List<TourPackage>> getAllPackages({bool includeInactive = false});

  /// One package by id, or null when it does not exist.
  Future<TourPackage?> getPackageById(String id);

  /// Creates a package and returns the stored record.
  ///
  /// When [TourPackage.id] is empty the service derives a stable slug from the
  /// title, falling back to a generated id if the slug is taken.
  Future<TourPackage> createPackage(TourPackage package);

  /// Updates every business field of an existing package.
  ///
  /// `active` is deliberately not part of an update: removal and restoration go
  /// through [setPackageActive] so editing a package can never change whether
  /// it appears in the catalog.
  Future<void> updatePackage(TourPackage package);

  /// Soft-removes (`active: false`) or restores (`active: true`) a package.
  Future<void> setPackageActive(String id, bool active);
}
