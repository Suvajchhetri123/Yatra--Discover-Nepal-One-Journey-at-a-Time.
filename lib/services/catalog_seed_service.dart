import '../data/mock_coordinators.dart';
import '../data/packages_data.dart';
import '../data/places_data.dart';
import '../models/place_model.dart';
import 'coordinator_repository.dart';
import 'package_repository.dart';
import 'place_repository.dart';

/// What a [CatalogSeedService] run did.
///
/// [created*] counts records written, [skipped*] counts records that already
/// existed (and were therefore left untouched), and [failures] records anything
/// that could not be written.
class CatalogSeedReport {
  const CatalogSeedReport({
    required this.createdCoordinators,
    required this.createdPlaces,
    required this.createdPackages,
    required this.skippedCoordinators,
    required this.skippedPlaces,
    required this.skippedPackages,
    required this.failures,
  });

  final int createdCoordinators;
  final int createdPlaces;
  final int createdPackages;
  final int skippedCoordinators;
  final int skippedPlaces;
  final int skippedPackages;
  final List<String> failures;

  int get createdTotal => createdCoordinators + createdPlaces + createdPackages;

  int get skippedTotal => skippedCoordinators + skippedPlaces + skippedPackages;

  bool get hasFailures => failures.isNotEmpty;

  /// One-line summary suitable for a snack bar.
  String get summary {
    final parts = <String>[
      if (createdCoordinators > 0)
        '$createdCoordinators coordinator${createdCoordinators == 1 ? '' : 's'}',
      if (createdPlaces > 0)
        '$createdPlaces place${createdPlaces == 1 ? '' : 's'}',
      if (createdPackages > 0)
        '$createdPackages package${createdPackages == 1 ? '' : 's'}',
    ];

    if (parts.isEmpty) {
      return 'Everything is already migrated. Nothing to do.';
    }

    final created = parts.join(', ');

    if (skippedTotal == 0) {
      return 'Migrated $created.';
    }

    return 'Migrated $created, kept $skippedTotal existing.';
  }
}

/// One-time migration of the app's static travel data into Firestore.
///
/// Properties this service guarantees:
///
/// - **Idempotent.** Every record has a deterministic document id
///   (`coord-001`, `mustang-muktinath`, the package's own id) and an existing
///   document is always skipped, so running it twice cannot create duplicates.
/// - **Non-destructive.** Nothing is ever overwritten, and a deactivated
///   (`active: false`) record is left deactivated instead of being restored.
/// - **Not automatic.** It is only reachable from the admin content hub, and
///   the writes themselves require the `isAdmin()` Security Rule, so it can
///   never run at app start-up or by a tourist.
class CatalogSeedService {
  CatalogSeedService({
    required this.coordinators,
    required this.places,
    required this.packages,
  });

  final CoordinatorRepository coordinators;
  final PlaceRepository places;
  final PackageRepository packages;

  /// Creates only the records that are missing from Firestore.
  Future<CatalogSeedReport> seedMissingCatalogs() async {
    final failures = <String>[];

    var createdCoordinators = 0;
    var createdPlaces = 0;
    var createdPackages = 0;
    var skippedCoordinators = 0;
    var skippedPlaces = 0;
    var skippedPackages = 0;

    // includeInactive: true — an existing deactivated record must still be
    // recognised as "already migrated" so we skip it instead of duplicating it.
    final existingCoordinatorIds = (await coordinators.getCoordinators(
      includeInactive: true,
    )).map((coordinator) => coordinator.id).toSet();

    for (final coordinator in kMockCoordinators) {
      if (existingCoordinatorIds.contains(coordinator.id)) {
        skippedCoordinators++;
        continue;
      }

      try {
        await coordinators.createCoordinator(
          id: coordinator.id,
          name: coordinator.name,
          phone: coordinator.phone,
          email: coordinator.email,
        );
        existingCoordinatorIds.add(coordinator.id);
        createdCoordinators++;
      } catch (_) {
        failures.add('Coordinator ${coordinator.name}');
      }
    }

    final existingPlaceIds = (await places.getAllPlaces(
      includeInactive: true,
    )).map((place) => place.id).toSet();

    for (final place in nepalPlaces) {
      final placeId = Place.slugFor(place.location, place.name);

      if (existingPlaceIds.contains(placeId)) {
        skippedPlaces++;
        continue;
      }

      try {
        await places.createPlace(place, id: placeId);
        existingPlaceIds.add(placeId);
        createdPlaces++;
      } catch (_) {
        failures.add('Place ${place.name}');
      }
    }

    final existingPackageIds = (await packages.getAllPackages(
      includeInactive: true,
    )).map((package) => package.id).toSet();

    for (final package in tourPackages) {
      if (existingPackageIds.contains(package.id)) {
        skippedPackages++;
        continue;
      }

      try {
        await packages.createPackage(package);
        existingPackageIds.add(package.id);
        createdPackages++;
      } catch (_) {
        failures.add('Package ${package.title}');
      }
    }

    return CatalogSeedReport(
      createdCoordinators: createdCoordinators,
      createdPlaces: createdPlaces,
      createdPackages: createdPackages,
      skippedCoordinators: skippedCoordinators,
      skippedPlaces: skippedPlaces,
      skippedPackages: skippedPackages,
      failures: failures,
    );
  }
}
