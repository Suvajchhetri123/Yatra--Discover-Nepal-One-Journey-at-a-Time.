import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/packages_data.dart';
import 'package:yatra/data/places_data.dart';
import 'package:yatra/models/package_model.dart';
import 'package:yatra/models/place_model.dart';
import 'package:yatra/screens/home/home_screen.dart';
import 'package:yatra/screens/package_details/package_details_screen.dart';
import 'package:yatra/services/tourist_catalog_controller.dart';

import 'support/fake_package_repository.dart';
import 'support/fake_place_repository.dart';

/// Marks the place that only exists so a test can prove inactive records are
/// filtered out.
const Place _inactivePokharaPlace = Place(
  id: 'inactive-pokhara',
  name: 'Retired Lakeside Walk',
  location: 'Pokhara',
  description: 'Deactivated by an admin and hidden from the tourist catalog.',
  entryFee: 100,
  openingHours: 'Always',
  transportation: 'None',
  travelTrip: 'None',
  recommendedHours: 1,
  active: false,
);

/// A second active place, so region counting has something to count.
const Place _pokharaCafe = Place(
  id: 'pokhara-cafe',
  name: 'Phewa Cafe',
  location: 'Pokhara',
  description: 'A lakeside cafe used as an itinerary attraction.',
  entryFee: 0,
  openingHours: '8:00 AM - 8:00 PM',
  transportation: 'Walk',
  travelTrip: 'None',
  recommendedHours: 1,
);

const TourPackage _kathmanduPackage = TourPackage(
  id: 'pkg-kathmandu-valley',
  title: 'Kathmandu Valley Circuit',
  region: 'Kathmandu',
  summary: 'Temples and heritage',
  description: 'Three days across the valley.',
  durationDays: 3,
  price: 18000,
  difficulty: 'Easy',
  rating: 4.8,
  imageUrl: 'https://example.test/kathmandu.jpg',
  highlights: ['Pashupatinath'],
  includedPlaces: ['Pashupatinath'],
);

const TourPackage _pokharaPackage = TourPackage(
  id: 'pkg-pokhara',
  title: 'Pokhara Lakeside',
  region: 'Pokhara',
  summary: 'Lakes and hills',
  description: 'Two days by the lake.',
  durationDays: 2,
  price: 12000,
  difficulty: 'Easy',
  rating: 4.6,
  imageUrl: 'https://example.test/pokhara.jpg',
  highlights: ['Phewa Lake'],
  includedPlaces: ['Phewa Cafe'],
);

const TourPackage _chitwanPackage = TourPackage(
  id: 'pkg-chitwan',
  title: 'Chitwan Safari',
  region: 'Chitwan',
  summary: 'Jungle safari',
  description: 'Two days in the lowlands.',
  durationDays: 2,
  price: 15000,
  difficulty: 'Easy',
  rating: 4.4,
  imageUrl: 'https://example.test/chitwan.jpg',
  highlights: ['Rhino Park'],
  includedPlaces: ['Sauraha'],
);

/// Builds a controller over fakes seeded with [places] and [packages].
TouristCatalogController _controller({
  List<Place> places = const [],
  List<TourPackage> packages = const [],
  Object? listError,
}) {
  return TouristCatalogController(
    placeRepository: FakePlaceRepository(places: places, listError: listError),
    packageRepository: FakePackageRepository(packages: packages),
  );
}

Future<void> _pumpHome(WidgetTester tester, TouristCatalogController catalog) {
  return tester.pumpWidget(MaterialApp(home: HomeScreen(catalog: catalog)));
}

/// Scrolls the page until [finder] is visible.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TouristCatalogController', () {
    test('starts idle and loads both catalogs', () async {
      final catalog = _controller(places: nepalPlaces, packages: tourPackages);

      expect(catalog.status, CatalogStatus.idle);

      await catalog.load();

      expect(catalog.status, CatalogStatus.ready);
      expect(catalog.places, isNotEmpty);
      expect(catalog.packages, isNotEmpty);
      expect(catalog.isReady, isTrue);
    });

    test('asks both repositories for active records only', () async {
      final placeRepository = FakePlaceRepository(places: nepalPlaces);
      final packageRepository = FakePackageRepository(packages: tourPackages);

      final catalog = TouristCatalogController(
        placeRepository: placeRepository,
        packageRepository: packageRepository,
      );

      await catalog.load();

      // The tourist catalog must never surface a removed record, so the
      // repositories' active-only default is deliberately not overridden.
      expect(placeRepository.listIncludeInactiveCalls, [false]);
      expect(packageRepository.listIncludeInactiveCalls, [false]);
    });

    test('an inactive place is filtered out of the tourist catalog', () async {
      final catalog = _controller(
        places: [_pokharaCafe, _inactivePokharaPlace],
      );

      await catalog.load();

      expect(catalog.places.map((place) => place.name), ['Phewa Cafe']);
      expect(catalog.findPlaceByName('Retired Lakeside Walk'), isNull);
    });

    test('reuses a cached result unless a refresh is forced', () async {
      final placeRepository = FakePlaceRepository(places: nepalPlaces);
      final packageRepository = FakePackageRepository(packages: tourPackages);
      final catalog = TouristCatalogController(
        placeRepository: placeRepository,
        packageRepository: packageRepository,
      );

      await catalog.load();
      await catalog.load();

      expect(placeRepository.listCalls, 1);

      await catalog.refresh();

      expect(placeRepository.listCalls, 2);
    });

    test('a first-load failure reports an error and no data', () async {
      final catalog = _controller(listError: StateError('offline'));

      await catalog.load();

      expect(catalog.status, CatalogStatus.error);
      expect(catalog.errorMessage, isNotNull);
      expect(catalog.isEmpty, isFalse);
      expect(catalog.places, isEmpty);
    });

    test('a failed refresh keeps the previously loaded catalog', () async {
      final placeRepository = FakePlaceRepository(places: nepalPlaces);
      final catalog = TouristCatalogController(
        placeRepository: placeRepository,
        packageRepository: FakePackageRepository(packages: tourPackages),
      );

      await catalog.load();
      expect(catalog.places, isNotEmpty);

      placeRepository.listError = StateError('offline');
      await catalog.refresh();

      // The user keeps seeing real content plus a retry affordance, rather
      // than an emptied screen.
      expect(catalog.status, CatalogStatus.ready);
      expect(catalog.errorMessage, isNotNull);
      expect(catalog.places, isNotEmpty);
    });

    test('a successful refresh clears a previous error', () async {
      final placeRepository = FakePlaceRepository(places: nepalPlaces);
      final catalog = TouristCatalogController(
        placeRepository: placeRepository,
        packageRepository: FakePackageRepository(packages: tourPackages),
      );

      await catalog.load();

      placeRepository.listError = StateError('offline');
      await catalog.refresh();
      expect(catalog.errorMessage, isNotNull);

      placeRepository.listError = null;
      await catalog.refresh();

      expect(catalog.errorMessage, isNull);
    });

    test('regions come from the loaded packages, not a static list', () async {
      final catalog = _controller(
        packages: [_chitwanPackage, _pokharaPackage, _kathmanduPackage],
      );

      await catalog.load();

      expect(catalog.regions, ['Chitwan', 'Kathmandu', 'Pokhara']);
      expect(catalog.packagesForRegion('Pokhara').map((p) => p.id), [
        'pkg-pokhara',
      ]);
    });

    test('an empty catalog is reported as ready and empty', () async {
      final catalog = _controller();

      await catalog.load();

      expect(catalog.status, CatalogStatus.ready);
      expect(catalog.isEmpty, isTrue);
      expect(catalog.regions, isEmpty);
    });

    test('name lookup is case- and whitespace-insensitive', () async {
      final catalog = _controller(places: [_pokharaCafe]);

      await catalog.load();

      expect(catalog.findPlaceByName('  phewa cafe ')?.id, 'pokhara-cafe');
      expect(catalog.findPlaceByName('nowhere'), isNull);
      expect(catalog.findPlaceByName('   '), isNull);
    });

    test('concurrent loads are collapsed into one read', () async {
      final gate = Completer<void>();
      final placeRepository = FakePlaceRepository(
        places: nepalPlaces,
        listGate: gate,
      );
      final catalog = TouristCatalogController(
        placeRepository: placeRepository,
        packageRepository: FakePackageRepository(packages: tourPackages),
      );

      final first = catalog.load();
      final second = catalog.load();

      gate.complete();
      await Future.wait([first, second]);

      expect(placeRepository.listCalls, 1);
    });
  });

  group('HomeScreen reads the admin-managed catalog', () {
    testWidgets('renders the packages it was given, not the seed list', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        _controller(packages: [_pokharaPackage, _chitwanPackage]),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Pokhara Lakeside'));
      expect(find.text('Pokhara Lakeside'), findsOneWidget);
      expect(find.text('Chitwan Safari'), findsOneWidget);

      // A package that only exists in the static seed file must not appear,
      // proving the screen no longer reads `packages_data.dart`.
      final seededOnly = tourPackages
          .firstWhere(
            (package) =>
                package.title != 'Pokhara Lakeside' &&
                package.title != 'Chitwan Safari',
          )
          .title;
      expect(find.text(seededOnly), findsNothing);
    });

    testWidgets('an empty catalog explains itself', (tester) async {
      await _pumpHome(tester, _controller());
      await tester.pumpAndSettle();

      await _scrollTo(
        tester,
        find.text('No destinations are available right now.'),
      );
      expect(
        find.text('No destinations are available right now.'),
        findsOneWidget,
      );

      await _scrollTo(tester, find.text('No packages in this region yet.'));
      expect(find.text('No packages in this region yet.'), findsOneWidget);
    });

    testWidgets('a load failure offers a retry that re-reads', (tester) async {
      final placeRepository = FakePlaceRepository(places: nepalPlaces);
      final catalog = TouristCatalogController(
        placeRepository: placeRepository,
        packageRepository: FakePackageRepository(packages: tourPackages),
      );
      placeRepository.listError = StateError('offline');

      await _pumpHome(tester, catalog);
      await tester.pumpAndSettle();

      // The banner sits above the scroll view, so it needs no scrolling.
      expect(find.text('Retry'), findsOneWidget);

      placeRepository.listError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(catalog.status, CatalogStatus.ready);
      expect(catalog.errorMessage, isNull);
      expect(catalog.packages, isNotEmpty);
      expect(placeRepository.listCalls, 2, reason: 'retry must re-read');
    });

    testWidgets('regions and destination counts follow the loaded data', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        _controller(
          packages: [_pokharaPackage, _chitwanPackage, _kathmanduPackage],
        ),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Explore Destinations'));
      expect(find.text('Chitwan'), findsWidgets);
      expect(find.text('Kathmandu'), findsWidgets);
      expect(find.text('Pokhara'), findsWidgets);

      // Filtering by a region narrows the package list to that region only.
      await tester.tap(find.text('Pokhara').first);
      await tester.pumpAndSettle();

      expect(find.text('Pokhara Lakeside'), findsOneWidget);
      expect(find.text('Chitwan Safari'), findsNothing);
    });

    testWidgets('publishes the catalog to descendants via a scope', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        _controller(places: nepalPlaces, packages: [_pokharaPackage]),
      );
      await tester.pumpAndSettle();

      // The scope is published below Home's own widget, so read it from a
      // descendant: a screen pushed from Home (planner, itinerary) then uses
      // the same catalog instead of issuing its own query.
      final context = tester.element(find.byType(Scaffold).first);

      expect(
        TouristCatalogScope.placesOf(context),
        isNotEmpty,
        reason: 'descendants must see the loaded places',
      );
      expect(TouristCatalogScope.packagesOf(context).map((p) => p.id), [
        'pkg-pokhara',
      ]);
    });
  });

  group('PackageDetailsScreen resolves chips against the catalog', () {
    testWidgets('an included place present in the catalog is tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PackageDetailsScreen(
            package: _pokharaPackage,
            places: const [_pokharaCafe],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Phewa Cafe'));
      expect(find.text('Phewa Cafe'), findsOneWidget);
    });

    testWidgets('a place missing from the catalog renders as unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PackageDetailsScreen(
            package: _pokharaPackage,
            places: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Phewa Cafe'));
      expect(find.text('Phewa Cafe'), findsOneWidget);

      // Still listed (the package names it), but no longer a link to content
      // the admin has removed.
      final chip = tester.widget<ActionChip>(
        find.ancestor(
          of: find.text('Phewa Cafe'),
          matching: find.byType(ActionChip),
        ),
      );
      expect(chip.onPressed, isNull);
    });
  });
}
