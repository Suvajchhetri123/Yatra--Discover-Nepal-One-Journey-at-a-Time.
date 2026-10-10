import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yatra/models/package_model.dart';
import 'package:yatra/models/place_model.dart';
import 'package:yatra/models/route_config.dart';
import 'package:yatra/services/catalog_sync_service.dart';
import 'package:yatra/services/local_catalog_codec.dart';
import 'package:yatra/services/package_repository.dart';
import 'package:yatra/services/place_repository.dart';
import 'package:yatra/services/route_repository.dart';
import 'package:yatra/services/yatra_local_database.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late YatraLocalDatabase database;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'yatra_catalog_sync_test_',
    );

    database = YatraLocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: p.join(temporaryDirectory.path, 'catalog.db'),
    );
  });

  tearDown(() async {
    await database.close();

    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('sync stores typed places packages routes and timestamp', () async {
    final service = CatalogSyncService(
      placeRepository: _FakePlaceRepository(
        places: const <Place>[
          Place(
            id: 'ilam-tea-garden',
            name: 'Ilam Tea Garden',
            location: 'Ilam',
            description: 'Tea gardens.',
            entryFee: 100,
            openingHours: 'Daytime',
            transportation: 'Bus',
            travelTrip: 'Visit',
            recommendedHours: 3,
          ),
        ],
      ),
      packageRepository: _FakePackageRepository(
        packages: const <TourPackage>[
          TourPackage(
            id: 'ilam-package',
            title: 'Ilam Package',
            region: 'Ilam',
            summary: 'Tea trip',
            description: 'Explore Ilam.',
            durationDays: 3,
            price: 15000,
            difficulty: 'Easy',
            rating: 4.5,
            imageUrl: '',
            highlights: <String>['Tea'],
            includedPlaces: <String>['Ilam Tea Garden'],
          ),
        ],
      ),
      routeRepository: _FakeRouteRepository(
        routes: const <RouteConfig>[
          RouteConfig(
            id: 'kathmandu-birtamod',
            destination: 'Ilam',
            from: 'Kathmandu',
            to: 'Birtamod',
            transportModes: <String>['Bus'],
          ),
        ],
      ),
      database: database,
      now: () => DateTime.utc(2026, 10, 10, 15),
    );

    final result = await service.sync();

    expect(result.placeCount, 1);
    expect(result.packageCount, 1);
    expect(result.routeCount, 1);
    expect(result.syncedAt, DateTime.utc(2026, 10, 10, 15));

    final placeRecords = await database.readCatalog(LocalCatalogKind.place);
    final packageRecords = await database.readCatalog(LocalCatalogKind.package);
    final routeRecords = await database.readCatalog(LocalCatalogKind.route);

    expect(
      LocalCatalogCodec.placeFromRecord(placeRecords.single).name,
      'Ilam Tea Garden',
    );

    expect(
      LocalCatalogCodec.packageFromRecord(packageRecords.single).title,
      'Ilam Package',
    );

    expect(
      LocalCatalogCodec.routeFromRecord(routeRecords.single).to,
      'Birtamod',
    );

    expect(
      await database.readMetadata(
        CatalogSyncService.lastSuccessfulSyncMetadataKey,
      ),
      '2026-10-10T15:00:00.000Z',
    );
  });

  test('failed remote sync preserves the last good SQLite snapshot', () async {
    await database.replaceCatalog(LocalCatalogKind.place, <LocalCatalogRecord>[
      LocalCatalogCodec.placeToRecord(
        const Place(
          id: 'last-good-place',
          name: 'Last Good Place',
          location: 'Kathmandu',
          description: 'Previously synchronized.',
          entryFee: 0,
          openingHours: '',
          transportation: '',
          travelTrip: '',
          recommendedHours: 1,
        ),
      ),
    ]);

    final service = CatalogSyncService(
      placeRepository: _FakePlaceRepository(
        places: const <Place>[
          Place(
            id: 'new-place',
            name: 'New Place',
            location: 'Ilam',
            description: 'Should not partially replace the cache.',
            entryFee: 0,
            openingHours: '',
            transportation: '',
            travelTrip: '',
            recommendedHours: 1,
          ),
        ],
      ),
      packageRepository: _FakePackageRepository(
        error: StateError('network unavailable'),
      ),
      routeRepository: _FakeRouteRepository(routes: const <RouteConfig>[]),
      database: database,
    );

    await expectLater(service.sync(), throwsA(isA<StateError>()));

    final cached = await database.readCatalog(LocalCatalogKind.place);

    expect(cached, hasLength(1));
    expect(cached.single.id, 'last-good-place');

    expect(
      await database.readMetadata(
        CatalogSyncService.lastSuccessfulSyncMetadataKey,
      ),
      isNull,
    );
  });
}

class _FakePlaceRepository implements PlaceRepository {
  _FakePlaceRepository({this.places = const <Place>[], this.error});

  final List<Place> places;
  final Object? error;

  @override
  Future<List<Place>> getAllPlaces({bool includeInactive = false}) async {
    if (error != null) {
      throw error!;
    }

    return places.where((place) => includeInactive || place.active).toList();
  }

  @override
  Future<Place?> getPlaceById(String placeId) {
    throw UnimplementedError();
  }

  @override
  Future<Place> createPlace(Place place, {String? id}) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlace(Place place) {
    throw UnimplementedError();
  }

  @override
  Future<void> setPlaceActive(String placeId, bool active) {
    throw UnimplementedError();
  }
}

class _FakePackageRepository implements PackageRepository {
  _FakePackageRepository({this.packages = const <TourPackage>[], this.error});

  final List<TourPackage> packages;
  final Object? error;

  @override
  Future<List<TourPackage>> getAllPackages({
    bool includeInactive = false,
  }) async {
    if (error != null) {
      throw error!;
    }

    return packages
        .where((package) => includeInactive || package.active)
        .toList();
  }

  @override
  Future<TourPackage?> getPackageById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<TourPackage> createPackage(TourPackage package) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePackage(TourPackage package) {
    throw UnimplementedError();
  }

  @override
  Future<void> setPackageActive(String id, bool active) {
    throw UnimplementedError();
  }
}

class _FakeRouteRepository implements RouteRepository {
  _FakeRouteRepository({this.routes = const <RouteConfig>[], this.error});

  final List<RouteConfig> routes;
  final Object? error;

  @override
  Future<List<RouteConfig>> getAllRoutes({bool includeInactive = false}) async {
    if (error != null) {
      throw error!;
    }

    return routes.where((route) => includeInactive || route.active).toList();
  }

  @override
  Future<RouteConfig?> getRouteById(String routeId) {
    throw UnimplementedError();
  }

  @override
  Future<RouteConfig> createRoute(RouteConfig route, {String? id}) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateRoute(RouteConfig route) {
    throw UnimplementedError();
  }

  @override
  Future<void> setRouteActive(String routeId, bool active) {
    throw UnimplementedError();
  }
}
