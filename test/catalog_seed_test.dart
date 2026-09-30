import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/mock_coordinators.dart';
import 'package:yatra/data/packages_data.dart';
import 'package:yatra/data/places_data.dart';
import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/place_model.dart';
import 'package:yatra/models/travel_coordinator.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/models/user_profile.dart';
import 'package:yatra/screens/admin/admin_booking_list_screen.dart';
import 'package:yatra/screens/admin/admin_content_messages.dart';
import 'package:yatra/screens/admin/admin_coordinator_list_screen.dart';
import 'package:yatra/screens/admin/admin_package_list_screen.dart';
import 'package:yatra/screens/admin/admin_place_list_screen.dart';
import 'package:yatra/screens/admin/admin_screen.dart';
import 'package:yatra/services/catalog_seed_service.dart';
import 'package:yatra/services/recommendation_service.dart';

import 'support/fake_admin_booking_repository.dart';
import 'support/fake_coordinator_repository.dart';
import 'support/fake_package_repository.dart';
import 'support/fake_place_repository.dart';

/// A pending booking, so the dashboard renders its metric grid.
final _pendingBooking = ItineraryBooking(
  id: 'bk-1',
  bookingCode: 'YT-2026-BK1',
  userId: 'tourist-1',
  createdAt: DateTime(2026, 9, 1),
  status: BookingStatus.pending,
  destination: 'Pokhara',
  startDate: DateTime(2026, 9, 1),
  endDate: DateTime(2026, 9, 4),
  touristType: 'Domestic Tourist',
  adultCount: 2,
  childCount: 0,
  travelType: 'Family',
  groupSize: 2,
  currency: 'NPR',
  estimatedCost: 28000,
  duration: 3,
  tripDirection: TripDirection.oneWay,
  dayPlans: const [
    DayPlan(day: 1, items: [DayPlanItem.activity(activity: 'Sightseeing')]),
  ],
  route: const TravelRoute(
    boardingPoint: 'Kathmandu',
    destination: 'Pokhara',
    tripDirection: TripDirection.oneWay,
    segments: [
      RouteSegment(
        from: 'Kathmandu',
        to: 'Pokhara',
        transportation: 'Tourist Bus',
      ),
    ],
  ),
);

const _admin = UserProfile(
  uid: 'admin-1',
  name: 'Admin',
  email: 'admin@yatra.app',
  role: 'admin',
);

const _tourist = UserProfile(
  uid: 'tourist-1',
  name: 'Tourist',
  email: 'tourist@yatra.app',
  role: 'tourist',
);

CatalogSeedService _seedService({
  FakeCoordinatorRepository? coordinators,
  FakePlaceRepository? places,
  FakePackageRepository? packages,
}) {
  return CatalogSeedService(
    coordinators: coordinators ?? FakeCoordinatorRepository(),
    places: places ?? FakePlaceRepository(),
    packages: packages ?? FakePackageRepository(),
  );
}

/// Scrolls the dashboard until [finder] is reachable.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAdmin(
  WidgetTester tester, {
  UserProfile? profile = _admin,
  List<ItineraryBooking> bookings = const [],
  FakeCoordinatorRepository? coordinators,
  FakePlaceRepository? places,
  FakePackageRepository? packages,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminScreen(
        profileLoader: () async => profile,
        bookingRepository: FakeAdminBookingRepository(bookings: bookings),
        coordinatorRepository: coordinators ?? FakeCoordinatorRepository(),
        placeRepository: places ?? FakePlaceRepository(),
        packageRepository: packages ?? FakePackageRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CatalogSeedService', () {
    test('migrates every bundled record into an empty Firestore', () async {
      final coordinators = FakeCoordinatorRepository();
      final places = FakePlaceRepository();
      final packages = FakePackageRepository();

      final report = await _seedService(
        coordinators: coordinators,
        places: places,
        packages: packages,
      ).seedMissingCatalogs();

      expect(report.createdCoordinators, kMockCoordinators.length);
      expect(report.createdPlaces, nepalPlaces.length);
      expect(report.createdPackages, tourPackages.length);
      expect(report.skippedTotal, 0);
      expect(report.failures, isEmpty);
      expect(report.hasFailures, isFalse);
      expect(report.createdTotal, kMockCoordinators.length + 20 + 6);
    });

    test('uses deterministic ids so a second run cannot duplicate', () async {
      final places = FakePlaceRepository();

      await _seedService(places: places).seedMissingCatalogs();

      expect(
        places.places.map((place) => place.id),
        nepalPlaces.map((place) => Place.slugFor(place.location, place.name)),
      );
      // Every migrated place is published as active.
      expect(places.places.every((place) => place.active), isTrue);

      // A package keeps the id it already has in the bundled data.
      final packages = FakePackageRepository();
      await _seedService(packages: packages).seedMissingCatalogs();
      expect(
        packages.packages.map((package) => package.id),
        tourPackages.map((package) => package.id),
      );

      // Coordinators keep their bundled ids.
      final coordinators = FakeCoordinatorRepository();
      await _seedService(coordinators: coordinators).seedMissingCatalogs();
      expect(
        coordinators.creates.map((create) => create.id),
        kMockCoordinators.map((coordinator) => coordinator.id),
      );
    });

    test('is idempotent: a second run creates nothing', () async {
      final coordinators = FakeCoordinatorRepository();
      final places = FakePlaceRepository();
      final packages = FakePackageRepository();

      final first = await _seedService(
        coordinators: coordinators,
        places: places,
        packages: packages,
      ).seedMissingCatalogs();

      final second = await _seedService(
        coordinators: coordinators,
        places: places,
        packages: packages,
      ).seedMissingCatalogs();

      expect(second.createdTotal, 0);
      expect(second.skippedTotal, first.createdTotal);
      expect(second.failures, isEmpty);
      expect(second.summary, 'Everything is already migrated. Nothing to do.');

      expect(coordinators.coordinators, hasLength(kMockCoordinators.length));
      expect(places.places, hasLength(nepalPlaces.length));
      expect(packages.packages, hasLength(tourPackages.length));
    });

    test('never overwrites or re-activates an existing record', () async {
      final existing = TravelCoordinator(
        id: kMockCoordinators.first.id,
        name: 'Renamed by the admin',
        phone: '+977 9800000000',
        email: 'renamed@yatra.app',
        active: false,
      );

      final coordinators = FakeCoordinatorRepository(coordinators: [existing]);

      final report = await _seedService(
        coordinators: coordinators,
      ).seedMissingCatalogs();

      expect(report.createdCoordinators, kMockCoordinators.length - 1);
      expect(report.skippedCoordinators, 1);

      // Untouched: same name, and still deactivated.
      expect(coordinators.coordinators.first, existing);
      expect(coordinators.coordinators.first.active, isFalse);
    });

    test('counts a single failed write and keeps going', () async {
      final places = FakePlaceRepository()
        ..createErrorFor = (name) => name == nepalPlaces.first.name
            ? Exception('PERMISSION_DENIED')
            : null;

      final report = await _seedService(places: places).seedMissingCatalogs();

      expect(report.createdPlaces, nepalPlaces.length - 1);
      expect(report.failures, ['Place ${nepalPlaces.first.name}']);
      expect(report.hasFailures, isTrue);
      expect(report.summary, 'Migrated 3 coordinators, 19 places, 6 packages.');
    });

    test('summarises a mixed run in one readable line', () {
      const report = CatalogSeedReport(
        createdCoordinators: 3,
        createdPlaces: 20,
        createdPackages: 5,
        skippedCoordinators: 0,
        skippedPlaces: 2,
        skippedPackages: 0,
        failures: ['Place X'],
      );

      expect(report.createdTotal, 28);
      expect(report.skippedTotal, 2);
      expect(
        report.summary,
        'Migrated 3 coordinators, 20 places, 5 packages, kept 2 existing.',
      );
    });

    test('writes nothing when the bundled data is already present', () async {
      final places = FakePlaceRepository(
        places: nepalPlaces
            .map(
              (place) =>
                  place.copyWith(id: Place.slugFor(place.location, place.name)),
            )
            .toList(),
      );

      final report = await _seedService(places: places).seedMissingCatalogs();

      expect(report.createdPlaces, 0);
      expect(report.skippedPlaces, 20);
      expect(places.createCalls, 0);
    });
  });

  group('admin content hub', () {
    testWidgets('is hidden from a non-admin profile', (tester) async {
      await _pumpAdmin(tester, profile: _tourist);

      expect(find.text('Admin access required.'), findsOneWidget);
      expect(find.text('Travel catalog'), findsNothing);
      expect(find.text('Coordinators'), findsNothing);
    });

    testWidgets('a failed role check keeps the hub closed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminScreen(
            profileLoader: () async => throw Exception('PERMISSION_DENIED'),
            bookingRepository: FakeAdminBookingRepository(),
            coordinatorRepository: FakeCoordinatorRepository(),
            placeRepository: FakePlaceRepository(),
            packageRepository: FakePackageRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not verify admin access. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Travel catalog'), findsNothing);
    });

    testWidgets('an admin sees the hub even with no bookings', (tester) async {
      await _pumpAdmin(tester);

      expect(find.text('No bookings yet'), findsOneWidget);
      expect(find.text('Travel catalog'), findsOneWidget);
      expect(find.text('Coordinators'), findsOneWidget);
      expect(find.text('Places'), findsOneWidget);
      expect(find.text('Packages'), findsOneWidget);
    });

    testWidgets('the hub entries open the Firestore-backed screens', (
      tester,
    ) async {
      final coordinators = FakeCoordinatorRepository(
        coordinators: const [
          TravelCoordinator(
            id: 'coord-1',
            name: 'Sushmita Shakya',
            phone: '+977 9841112233',
            email: 'sushmita@yatra.app',
          ),
        ],
      );

      await _pumpAdmin(tester, coordinators: coordinators);

      await tester.tap(find.text('Coordinators'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminCoordinatorListScreen), findsOneWidget);
      expect(find.text('Sushmita Shakya'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Places'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPlaceListScreen), findsOneWidget);
      expect(find.text('No places'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Packages'));
      await tester.tap(find.text('Packages'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPackageListScreen), findsOneWidget);
      expect(find.text('No packages'), findsOneWidget);
    });

    testWidgets('the booking list forwards the coordinator registry', (
      tester,
    ) async {
      final coordinators = FakeCoordinatorRepository(
        coordinators: const [
          TravelCoordinator(
            id: 'coord-1',
            name: 'Sushmita Shakya',
            phone: '+977 9841112233',
            email: 'sushmita@yatra.app',
          ),
        ],
      );

      await _pumpAdmin(
        tester,
        coordinators: coordinators,
        bookings: [_pendingBooking],
      );

      await tester.tap(find.text('Pending Bookings'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminBookingListScreen), findsOneWidget);
    });

    testWidgets('the migration asks for confirmation and reports the result', (
      tester,
    ) async {
      await _pumpAdmin(tester);

      await _scrollTo(tester, find.text('Migrate bundled catalog'));
      await tester.tap(find.text('Migrate bundled catalog'));
      await tester.pumpAndSettle();

      expect(find.text('Migrate travel catalog?'), findsOneWidget);

      // Cancelling must not write anything.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Migrate bundled catalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Migrate'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Migrated 3 coordinators, 20 places, 6 packages'),
        findsOneWidget,
      );
    });

    testWidgets('a failed migration is reported, not silently ignored', (
      tester,
    ) async {
      await _pumpAdmin(
        tester,
        places: FakePlaceRepository()
          ..listError = Exception('PERMISSION_DENIED'),
      );

      await _scrollTo(tester, find.text('Migrate bundled catalog'));
      await tester.tap(find.text('Migrate bundled catalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Migrate'));
      await tester.pumpAndSettle();

      expect(find.text(kAdminCatalogMigrationFailureMessage), findsOneWidget);
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
    });
  });
}
