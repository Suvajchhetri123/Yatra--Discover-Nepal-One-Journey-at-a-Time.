import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/package_model.dart';
import 'package:yatra/models/place_model.dart';
import 'package:yatra/models/tourist_pricing.dart';
import 'package:yatra/screens/admin/admin_package_form_screen.dart';
import 'package:yatra/screens/admin/admin_package_list_screen.dart';
import 'package:yatra/screens/admin/admin_place_form_screen.dart';
import 'package:yatra/screens/admin/admin_place_list_screen.dart';

import 'support/fake_package_repository.dart';
import 'support/fake_place_repository.dart';

const _muktinath = Place(
  id: 'mustang-muktinath',
  name: 'Muktinath',
  location: 'Mustang',
  description: 'Ridge-top temple',
  imageUrl: 'https://example.test/muktinath.jpg',
  entryFee: 1000,
  openingHours: '6:00 AM - 6:00 PM',
  transportation: '3h drive from Pokhara',
  travelTrip: 'Pokhara - Muktinath',
  recommendedHours: 4,
);

const _boudhanath = Place(
  id: 'kathmandu-boudhanath',
  name: 'Boudhanath',
  location: 'Kathmandu',
  description: 'Stupa',
  imageUrl: '',
  entryFee: 400,
  touristEntryFee: TouristPricing(domestic: 300, international: 500),
  openingHours: '5:00 AM - 7:00 PM',
  transportation: 'Bus',
  travelTrip: 'Ring road',
  recommendedHours: 2,
);

const _removedPlace = Place(
  id: 'pokhara-phewa',
  name: 'Phewa Lake',
  location: 'Pokhara',
  description: 'Lake',
  imageUrl: '',
  entryFee: 0,
  openingHours: 'Always open',
  transportation: 'Walk',
  travelTrip: ' Lakeside',
  recommendedHours: 2,
  active: false,
);

const _valley = TourPackage(
  id: 'kathmandu-valley-classic',
  title: 'Kathmandu Valley Classic',
  region: 'Kathmandu Valley',
  summary: 'Three days around the valley.',
  description: 'Pashupatinath, Boudhanath and Nagarkot.',
  durationDays: 3,
  price: 12000,
  touristPrice: TouristPricing(domestic: 10000, international: 14000),
  difficulty: 'Easy',
  rating: 4.5,
  imageUrl: 'https://example.test/ktm.jpg',
  highlights: ['Pashupatinath', 'Boudhanath'],
  includedPlaces: ['Nagarkot'],
);

const _removedPackage = TourPackage(
  id: 'trek-abc',
  title: 'Everest Base Camp Trek',
  region: 'Khumbu',
  summary: 'Classic EBC trek.',
  description: 'Two weeks in the high Himalaya.',
  durationDays: 14,
  price: 65000,
  difficulty: 'Challenging',
  rating: 5,
  imageUrl: '',
  highlights: ['Lukla'],
  includedPlaces: ['Namche Bazaar'],
  active: false,
);

Future<void> _pumpPlaceList(
  WidgetTester tester,
  FakePlaceRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: AdminPlaceListScreen(repository: repository)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPlaceForm(
  WidgetTester tester,
  FakePlaceRepository repository, {
  Place? place,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminPlaceFormScreen(place: place, repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPackageList(
  WidgetTester tester,
  FakePackageRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: AdminPackageListScreen(repository: repository)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPackageForm(
  WidgetTester tester,
  FakePackageRepository repository, {
  TourPackage? package,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminPackageFormScreen(package: package, repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the form until [finder] is on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Scrolls the first scrollable back to the top.
Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
}

void main() {
  group('place registry list', () {
    testWidgets('shows the universal price and the segment overrides', (
      tester,
    ) async {
      await _pumpPlaceList(
        tester,
        FakePlaceRepository(places: const [_muktinath, _boudhanath]),
      );

      expect(find.text('Muktinath'), findsOneWidget);
      expect(find.text('Mustang'), findsOneWidget);
      expect(find.text('NPR 1000 for every tourist'), findsOneWidget);

      expect(find.text('Boudhanath'), findsOneWidget);
      expect(
        find.text('Domestic NPR 300 · International NPR 500'),
        findsOneWidget,
      );
      expect(find.text('2 places'), findsOneWidget);
    });

    testWidgets('removing a place is a soft deactivation', (tester) async {
      final repository = FakePlaceRepository(places: const [_muktinath]);

      await _pumpPlaceList(tester, repository);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(repository.activeWrites, [
        (id: 'mustang-muktinath', active: false),
      ]);
      expect(find.text('Muktinath'), findsNothing);
      // The record is still there, just inactive.
      expect(repository.places.single.active, isFalse);
    });

    testWidgets('a removed place can be restored from the All filter', (
      tester,
    ) async {
      final repository = FakePlaceRepository(
        places: const [_muktinath, _removedPlace],
      );

      await _pumpPlaceList(tester, repository);
      expect(find.text('Phewa Lake'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();

      expect(repository.listIncludeInactiveCalls, [false, true]);
      expect(find.text('Phewa Lake'), findsOneWidget);
    });

    testWidgets('a load failure offers a retry', (tester) async {
      final repository = FakePlaceRepository(
        places: const [_muktinath],
        listError: Exception('PERMISSION_DENIED'),
      );

      await _pumpPlaceList(tester, repository);

      expect(
        find.text(
          'Could not load the travel catalog. Check your connection and try '
          'again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);

      repository.listError = null;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Muktinath'), findsOneWidget);
    });

    testWidgets('an empty catalog explains what to do', (tester) async {
      await _pumpPlaceList(tester, FakePlaceRepository());

      expect(find.text('No places'), findsOneWidget);
      expect(
        find.text('No active places. Switch to "All" to see deactivated ones.'),
        findsOneWidget,
      );
    });
  });

  group('place form', () {
    testWidgets('requires a name and a location', (tester) async {
      final repository = FakePlaceRepository();

      await _pumpPlaceForm(tester, repository);
      await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      expect(find.text('Please fill in the required fields.'), findsOneWidget);

      await _scrollToTop(tester);
      expect(find.text('Enter a place name.'), findsOneWidget);
      expect(find.text('Enter a location.'), findsOneWidget);
    });

    testWidgets('requires the universal entry fee to be a number', (
      tester,
    ) async {
      final repository = FakePlaceRepository();

      await _pumpPlaceForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Muktinath');
      await tester.enterText(find.byType(TextField).at(1), 'Mustang');
      await tester.enterText(find.byType(TextField).at(4), 'free');
      await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      await _scrollTo(
        tester,
        find.widgetWithText(TextField, 'Universal entry fee (NPR)'),
      );
      expect(find.text('Enter a valid number of 0 or more.'), findsOneWidget);
    });

    testWidgets('rejects an image value that is not a full URL', (
      tester,
    ) async {
      final repository = FakePlaceRepository();

      await _pumpPlaceForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Muktinath');
      await tester.enterText(find.byType(TextField).at(1), 'Mustang');
      await tester.enterText(
        find.byType(TextField).at(3),
        'assets/muktinath.png',
      );
      await tester.enterText(find.byType(TextField).at(4), '1000');
      await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      await _scrollTo(tester, find.widgetWithText(TextField, 'Image URL'));
      expect(find.text('Use a full http:// or https:// link.'), findsOneWidget);
    });

    testWidgets('an empty image URL is allowed', (tester) async {
      final repository = FakePlaceRepository();

      await _pumpPlaceForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Phewa Lake');
      await tester.enterText(find.byType(TextField).at(1), 'Pokhara');
      await tester.enterText(find.byType(TextField).at(4), '0');
      await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.places.single.imageUrl, isEmpty);
      expect(repository.places.single.entryFee, 0);
      expect(
        repository.places.single.id,
        Place.slugFor('Pokhara', 'Phewa Lake'),
      );
    });

    testWidgets('saves explicit domestic and international rates', (
      tester,
    ) async {
      final repository = FakePlaceRepository();

      await _pumpPlaceForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Boudhanath');
      await tester.enterText(find.byType(TextField).at(1), 'Kathmandu');
      await tester.enterText(find.byType(TextField).at(4), '400');

      await _scrollTo(tester, find.text('Domestic / international rates'));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // The switch reveals the two override fields.
      expect(find.text('Domestic price'), findsOneWidget);
      expect(find.text('International price'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Domestic price'),
        '300',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'International price'),
        '500',
      );

      await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);

      final stored = repository.places.single;
      expect(stored.entryFee, 400);
      expect(stored.touristEntryFee?.domestic, 300);
      expect(stored.touristEntryFee?.international, 500);
      expect(stored.entryFeeFor('International Tourist'), 500);
    });

    testWidgets('requires at least one rate when the override is on', (
      tester,
    ) async {
      final repository = FakePlaceRepository();

      await _pumpPlaceForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Boudhanath');
      await tester.enterText(find.byType(TextField).at(1), 'Kathmandu');
      await tester.enterText(find.byType(TextField).at(4), '400');
      await _scrollTo(tester, find.text('Domestic / international rates'));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      await _scrollTo(tester, find.text('Domestic price'));
      expect(find.text('Enter at least one segment rate.'), findsOneWidget);
    });

    testWidgets('editing a place keeps its id and never clears the flag', (
      tester,
    ) async {
      final repository = FakePlaceRepository(places: const [_removedPlace]);

      await _pumpPlaceForm(tester, repository, place: _removedPlace);
      expect(find.text('Edit place'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Phewa Lake (renamed)',
      );
      await _scrollTo(
        tester,
        find.widgetWithText(ElevatedButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.places.single.id, 'pokhara-phewa');
      expect(repository.places.single.name, 'Phewa Lake (renamed)');

      // A deactivated place stays deactivated after an edit.
      expect(repository.places.single.active, isFalse);
    });

    testWidgets('turning the override off removes the stored rates', (
      tester,
    ) async {
      final repository = FakePlaceRepository(places: const [_boudhanath]);

      await _pumpPlaceForm(tester, repository, place: _boudhanath);

      // The switch starts on because the record has overrides.
      expect(repository.places.single.touristEntryFee, isNotNull);

      await _scrollTo(tester, find.text('Domestic / international rates'));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await _scrollTo(
        tester,
        find.widgetWithText(ElevatedButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.places.single.touristEntryFee, isNull);
      expect(repository.places.single.entryFee, 400);
      expect(repository.places.single.active, isTrue);
    });

    testWidgets('a failed save keeps the form open with a safe message', (
      tester,
    ) async {
      final repository = FakePlaceRepository()
        ..createError = Exception('PERMISSION_DENIED: rules');

      await _pumpPlaceForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Phewa Lake');
      await tester.enterText(find.byType(TextField).at(1), 'Pokhara');
      await tester.enterText(find.byType(TextField).at(4), '0');
      await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add place'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save your changes. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
    });
  });

  group('package registry list', () {
    testWidgets('shows the region, duration and price breakdown', (
      tester,
    ) async {
      await _pumpPackageList(
        tester,
        FakePackageRepository(packages: const [_valley]),
      );

      expect(find.text('Kathmandu Valley Classic'), findsOneWidget);
      expect(find.text('Kathmandu Valley · 3 days · Easy'), findsOneWidget);
      expect(
        find.text('Domestic NPR 10000 · International NPR 14000'),
        findsOneWidget,
      );
      expect(find.text('1 package'), findsOneWidget);
    });

    testWidgets('removing a package is a soft deactivation', (tester) async {
      final repository = FakePackageRepository(packages: const [_valley]);

      await _pumpPackageList(tester, repository);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(repository.activeWrites, [
        (id: 'kathmandu-valley-classic', active: false),
      ]);
      expect(repository.packages.single.active, isFalse);
      expect(find.text('Kathmandu Valley Classic'), findsNothing);
    });

    testWidgets('a removed package is listed under All', (tester) async {
      await _pumpPackageList(
        tester,
        FakePackageRepository(packages: const [_valley, _removedPackage]),
      );

      expect(find.text('Everest Base Camp Trek'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();

      expect(find.text('Everest Base Camp Trek'), findsOneWidget);
      expect(find.text('2 packages'), findsOneWidget);
    });

    testWidgets('an empty catalog explains what to do', (tester) async {
      await _pumpPackageList(tester, FakePackageRepository());

      expect(find.text('No packages'), findsOneWidget);
      expect(
        find.text('No active packages. Switch to "All" to see removed ones.'),
        findsOneWidget,
      );
    });
  });

  group('package form', () {
    testWidgets('requires a title, a region and at least one day', (
      tester,
    ) async {
      final repository = FakePackageRepository();

      await _pumpPackageForm(tester, repository);
      await _scrollTo(
        tester,
        find.widgetWithText(ElevatedButton, 'Add package'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add package'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      expect(find.text('Please fill in the required fields.'), findsOneWidget);

      await _scrollToTop(tester);
      expect(find.text('Enter a package title.'), findsOneWidget);
      expect(find.text('Enter a region.'), findsOneWidget);
      await _scrollTo(
        tester,
        find.widgetWithText(TextField, 'Duration (days)'),
      );
      expect(find.text('Enter at least 1 day.'), findsOneWidget);
    });

    testWidgets('rejects a rating above five', (tester) async {
      final repository = FakePackageRepository();

      await _pumpPackageForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Weekend Escape');
      await tester.enterText(find.byType(TextField).at(1), 'Pokhara');
      await tester.enterText(find.byType(TextField).at(4), '2');
      await tester.enterText(find.byType(TextField).at(5), '5000');
      await _scrollTo(tester, find.widgetWithText(TextField, 'Rating (0 - 5)'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Rating (0 - 5)'),
        '9',
      );

      await _scrollTo(
        tester,
        find.widgetWithText(ElevatedButton, 'Add package'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add package'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      await _scrollTo(tester, find.widgetWithText(TextField, 'Rating (0 - 5)'));
      expect(find.text('Enter a rating between 0 and 5.'), findsOneWidget);
    });

    testWidgets('stores a multi-line highlight list as separate entries', (
      tester,
    ) async {
      final repository = FakePackageRepository();

      await _pumpPackageForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Weekend Escape');
      await tester.enterText(find.byType(TextField).at(1), 'Pokhara');
      await tester.enterText(find.byType(TextField).at(4), '2');
      await tester.enterText(find.byType(TextField).at(5), '5000');
      await _scrollTo(tester, find.widgetWithText(TextField, 'Highlights'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Highlights'),
        'Phewa Lake\n\nSarangkot sunrise',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Included places'),
        'Phewa Lake\nSarangkot',
      );

      await _scrollTo(
        tester,
        find.widgetWithText(ElevatedButton, 'Add package'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add package'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);

      final stored = repository.packages.single;
      expect(stored.highlights, ['Phewa Lake', 'Sarangkot sunrise']);
      expect(stored.includedPlaces, ['Phewa Lake', 'Sarangkot']);
      expect(stored.durationDays, 2);
      expect(stored.difficulty, 'Easy');
      expect(stored.rating, 0);
      // An id is derived from the title, never typed by the admin.
      expect(stored.id, 'weekend-escape');
    });

    testWidgets('offers the three catalog difficulty levels', (tester) async {
      await _pumpPackageForm(tester, FakePackageRepository());

      expect(kPackageDifficultyOptions, ['Easy', 'Moderate', 'Challenging']);
      await _scrollTo(
        tester,
        find.widgetWithText(DropdownButtonFormField<String>, 'Difficulty'),
      );
      // The default level is the first catalog option.
      expect(find.text('Easy'), findsOneWidget);
    });

    testWidgets('editing keeps the id and the pricing override', (
      tester,
    ) async {
      final repository = FakePackageRepository(packages: const [_valley]);

      await _pumpPackageForm(tester, repository, package: _valley);
      expect(find.text('Edit package'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Kathmandu Valley Classic (2027)',
      );
      await _scrollTo(
        tester,
        find.widgetWithText(ElevatedButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.packages.single.id, 'kathmandu-valley-classic');
      expect(repository.packages.single.touristPrice?.domestic, 10000);
      expect(repository.packages.single.active, isTrue);
    });

    testWidgets('turning the price override off removes the rates', (
      tester,
    ) async {
      final repository = FakePackageRepository(packages: const [_valley]);

      await _pumpPackageForm(tester, repository, package: _valley);
      await _scrollTo(tester, find.text('Domestic / international rates'));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await _scrollTo(
        tester,
        find.widgetWithText(ElevatedButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.packages.single.touristPrice, isNull);
      expect(repository.packages.single.price, 12000);
    });

    testWidgets('a save failure is reported without a fake success', (
      tester,
    ) async {
      final repository = FakePackageRepository()
        ..createError = Exception('PERMISSION_DENIED: rules');

      await _pumpPackageForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Weekend Escape');
      await tester.enterText(find.byType(TextField).at(1), 'Pokhara');
      await tester.enterText(find.byType(TextField).at(4), '2');
      await tester.enterText(find.byType(TextField).at(5), '5000');
      await _scrollTo(
        tester,
        find.widgetWithText(ElevatedButton, 'Add package'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add package'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save your changes. Please try again.'),
        findsOneWidget,
      );
      expect(repository.packages, isEmpty);
    });
  });
}
