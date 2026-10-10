import '../models/package_model.dart';
import '../models/place_model.dart';
import '../models/route_config.dart';
import 'local_catalog_codec.dart';
import 'package_repository.dart';
import 'place_repository.dart';
import 'route_repository.dart';
import 'yatra_local_database.dart';

class CatalogSyncResult {
  final DateTime syncedAt;
  final int placeCount;
  final int packageCount;
  final int routeCount;

  const CatalogSyncResult({
    required this.syncedAt,
    required this.placeCount,
    required this.packageCount,
    required this.routeCount,
  });
}

/// Downloads the current tourist catalog and replaces the local SQLite
/// snapshot only after every remote catalog has loaded successfully.
///
/// Important: normal tourist reads intentionally use the repository defaults
/// (`includeInactive: false`). A tourist is not authorized to query inactive
/// Firestore records, and inactive remote entries disappear locally because
/// [YatraLocalDatabase.replaceSnapshot] replaces each complete active snapshot.
class CatalogSyncService {
  CatalogSyncService({
    required PlaceRepository placeRepository,
    required PackageRepository packageRepository,
    required RouteRepository routeRepository,
    required YatraLocalDatabase database,
    DateTime Function()? now,
  }) : _places = placeRepository,
       _packages = packageRepository,
       _routes = routeRepository,
       _database = database,
       _now = now ?? DateTime.now;

  static const String lastSuccessfulSyncMetadataKey =
      'lastSuccessfulCatalogSyncUtc';

  final PlaceRepository _places;
  final PackageRepository _packages;
  final RouteRepository _routes;
  final YatraLocalDatabase _database;
  final DateTime Function() _now;

  Future<CatalogSyncResult> sync() async {
    // Do every remote read before touching the existing SQLite snapshot.
    // If any remote request fails, the last good offline data remains intact.
    final List<Place> places = await _places.getAllPlaces();
    final List<TourPackage> packages = await _packages.getAllPackages();
    final List<RouteConfig> routes = await _routes.getAllRoutes();

    // Encode everything before beginning SQLite replacement. An invalid id or
    // codec problem therefore cannot partially refresh the local database.
    final placeRecords = places
        .map(LocalCatalogCodec.placeToRecord)
        .toList(growable: false);

    final packageRecords = packages
        .map(LocalCatalogCodec.packageToRecord)
        .toList(growable: false);

    final routeRecords = routes
        .map(LocalCatalogCodec.routeToRecord)
        .toList(growable: false);

    await _database
        .replaceSnapshot(<LocalCatalogKind, Iterable<LocalCatalogRecord>>{
          LocalCatalogKind.place: placeRecords,
          LocalCatalogKind.package: packageRecords,
          LocalCatalogKind.route: routeRecords,
        });

    final syncedAt = _now().toUtc();

    await _database.writeMetadata(
      lastSuccessfulSyncMetadataKey,
      syncedAt.toIso8601String(),
    );

    return CatalogSyncResult(
      syncedAt: syncedAt,
      placeCount: places.length,
      packageCount: packages.length,
      routeCount: routes.length,
    );
  }
}
