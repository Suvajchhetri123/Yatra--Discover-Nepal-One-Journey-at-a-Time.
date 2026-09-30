import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/destination_cost_profiles.dart';
import 'package:yatra/data/mock_coordinators.dart';
import 'package:yatra/data/packages_data.dart';
import 'package:yatra/data/places_data.dart';
import 'package:yatra/models/package_model.dart';
import 'package:yatra/models/place_model.dart';
import 'package:yatra/models/tourist_pricing.dart';
import 'package:yatra/models/travel_coordinator.dart';
import 'package:yatra/services/booking_firestore_mapper.dart';
import 'package:yatra/services/catalog_firestore_mapper.dart';

const _coordinator = TravelCoordinator(
  id: 'coord-1',
  name: 'Sushmita Gurung',
  phone: '+977 9800000000',
  email: 'sushmita@yatra.app',
);

const _place = Place(
  id: 'mustang-muktinath',
  name: 'Muktinath',
  location: 'Mustang',
  description: 'Ridge-top temple on the Annapurna circuit.',
  imageUrl: 'https://example.test/muktinath.jpg',
  entryFee: 1000,
  touristEntryFee: TouristPricing(domestic: 800, international: 1200),
  openingHours: '6:00 AM - 6:00 PM',
  transportation: '3h drive from Pokhara',
  travelTrip: 'Pokhara - Muktinath - Jomsom',
  recommendedHours: 4,
);

const _package = TourPackage(
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
  includedPlaces: ['Kathmandu Durbar Square', 'Pashupatinath'],
);

String _libSource(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

Map<String, String> _libSources(String directory) {
  final sources = <String, String>{};

  for (final entity in Directory(directory).listSync()) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final key = 'lib/${entity.path.replaceFirst('lib/', '')}';

    sources[key] = _libSource(entity.path);
  }

  return sources;
}

void main() {
  group('coordinator documents', () {
    test(
      'a create writes the business fields, the flag and both timestamps',
      () {
        final map = CatalogFirestoreMapper.coordinatorDocumentToMap(
          _coordinator,
        );

        expect(map['name'], 'Sushmita Gurung');
        expect(map['phone'], '+977 9800000000');
        expect(map['email'], 'sushmita@yatra.app');
        expect(map['active'], isTrue);
        expect(map.containsKey('createdAt'), isTrue);
        expect(map.containsKey('updatedAt'), isTrue);

        // Timestamps are server-side so every device agrees on them.
        expect(map['createdAt'], isA<FieldValue>());
        expect(map['updatedAt'], isA<FieldValue>());
      },
    );

    test('an update never rewrites createdAt or the active flag', () {
      final map = CatalogFirestoreMapper.coordinatorUpdateToMap(
        _coordinator.copyWith(active: false),
      );

      expect(map['name'], 'Sushmita Gurung');
      expect(map.containsKey('updatedAt'), isTrue);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('active'), isFalse);
    });

    test('the document id becomes the coordinator id', () {
      final parsed = CatalogFirestoreMapper.coordinatorDocumentFromMap(
        documentId: 'coord-abc',
        data: const {
          'name': 'Bikash Thapa',
          'phone': '+977 9811111111',
          'email': 'bikash@yatra.app',
          'active': false,
        },
      );

      expect(parsed.id, 'coord-abc');
      expect(parsed.name, 'Bikash Thapa');
      expect(parsed.active, isFalse);
    });

    test('a document without the active flag is treated as active', () {
      final parsed = CatalogFirestoreMapper.coordinatorDocumentFromMap(
        documentId: 'coord-legacy',
        data: const {'name': 'Legacy', 'phone': '1', 'email': 'a@b.c'},
      );

      expect(parsed.active, isTrue);
    });

    test('malformed documents degrade instead of throwing', () {
      final parsed = CatalogFirestoreMapper.coordinatorDocumentFromMap(
        documentId: 'coord-broken',
        data: const {'name': 42, 'phone': null, 'active': 'yes'},
      );

      expect(parsed.name, isEmpty);
      expect(parsed.phone, isEmpty);
      expect(parsed.email, isEmpty);
      expect(parsed.active, isTrue);
    });
  });

  group('place documents', () {
    test('the catalog document carries every booking-snapshot field', () {
      final map = CatalogFirestoreMapper.placeDocumentToMap(_place);

      // Same business keys the day-plan snapshot uses, so the two can never
      // drift apart.
      final snapshotKeys = BookingFirestoreMapper.placeToMap(_place).keys;

      for (final key in snapshotKeys) {
        expect(map.containsKey(key), isTrue, reason: key);
      }

      expect(map['entryFee'], 1000);
      expect(map['touristEntryFee'], isA<Map<String, dynamic>>());
      expect((map['touristEntryFee'] as Map<String, dynamic>)['domestic'], 800);
      expect(
        (map['touristEntryFee'] as Map<String, dynamic>)['international'],
        1200,
      );
      expect(map['active'], isTrue);
    });

    test('an update never rewrites createdAt or the active flag', () {
      final map = CatalogFirestoreMapper.placeUpdateToMap(
        _place.copyWith(active: false),
      );

      expect(map['name'], 'Muktinath');
      expect(map.containsKey('updatedAt'), isTrue);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('active'), isFalse);
    });

    test('the document id becomes the place id and the flag is restored', () {
      final parsed = CatalogFirestoreMapper.placeDocumentFromMap(
        documentId: 'kathmandu-boudhanath',
        data: const {
          'name': 'Boudhanath',
          'location': 'Kathmandu',
          'description': 'Stupa',
          'imageUrl': 'https://example.test/boudha.jpg',
          'entryFee': 400,
          'touristEntryFee': {'domestic': 300, 'international': 500},
          'openingHours': '5:00 AM - 7:00 PM',
          'transportation': 'Bus',
          'travelTrip': 'Ring road',
          'recommendedHours': 2,
          'active': false,
        },
      );

      expect(parsed.id, 'kathmandu-boudhanath');
      expect(parsed.active, isFalse);
      expect(parsed.touristEntryFee?.domestic, 300);
      expect(parsed.touristEntryFee?.international, 500);
      expect(parsed.entryFeeFor('International Tourist'), 500);
    });

    test('a place without overrides falls back to the universal fee', () {
      final parsed = CatalogFirestoreMapper.placeDocumentFromMap(
        documentId: 'p',
        data: const {
          'name': 'Nagarkot',
          'location': 'Bhaktapur',
          'entryFee': 500,
          // Explicit null: no per-segment rates.
          'touristEntryFee': null,
          'active': true,
        },
      );

      expect(parsed.touristEntryFee, isNull);
      expect(parsed.entryFeeFor('Domestic Tourist'), 500);
      expect(parsed.entryFeeFor('International Tourist'), 500);
    });

    test('an empty pricing object is treated as no overrides', () {
      final parsed = CatalogFirestoreMapper.placeDocumentFromMap(
        documentId: 'p',
        data: const {
          'name': 'Nagarkot',
          'location': 'Bhaktapur',
          'entryFee': 500,
          'touristEntryFee': <String, dynamic>{},
        },
      );

      expect(parsed.touristEntryFee, isNull);
    });

    test('rates are explicit values, never a global multiplier', () {
      expect(_place.entryFeeFor('Domestic Tourist'), 800);
      expect(_place.entryFeeFor('International Tourist'), 1200);

      // An unknown segment is not guessed at.
      expect(_place.entryFeeFor('Group'), 1000);
    });

    test('a malformed place document degrades instead of throwing', () {
      final parsed = CatalogFirestoreMapper.placeDocumentFromMap(
        documentId: 'broken',
        data: const {
          'name': 'X',
          'location': 'Y',
          'entryFee': 'free',
          'recommendedHours': null,
          'highlights': 'not-a-list',
        },
      );

      expect(parsed.entryFee, 0);
      expect(parsed.recommendedHours, 0);
    });

    test('the seed slug is stable and readable', () {
      expect(Place.slugFor('Mustang', 'Muktinath'), 'mustang-muktinath');
      expect(
        Place.slugFor('Kathmandu Valley', 'Boudhanath Stupa'),
        'kathmandu-valley-boudhanath-stupa',
      );
      // The location is part of the id so two places with the same name in
      // different regions never collide.
      expect(Place.slugFor('Pokhara', 'Phewa  Lake!'), 'pokhara-phewa-lake');
    });
  });

  group('package documents', () {
    test('nested domestic/international pricing is stored explicitly', () {
      final map = CatalogFirestoreMapper.packageDocumentToMap(_package);

      expect(map['title'], 'Kathmandu Valley Classic');
      expect(map['durationDays'], 3);
      expect(map['price'], 12000);
      expect(map['touristPrice'], isA<Map<String, dynamic>>());
      expect((map['touristPrice'] as Map<String, dynamic>)['domestic'], 10000);
      expect(
        (map['touristPrice'] as Map<String, dynamic>)['international'],
        14000,
      );
      expect(map['highlights'], ['Pashupatinath', 'Boudhanath']);
      expect(map['includedPlaces'], [
        'Kathmandu Durbar Square',
        'Pashupatinath',
      ]);
      expect(map['active'], isTrue);
    });

    test('no overrides are stored as an explicit null', () {
      final map = CatalogFirestoreMapper.packageDocumentToMap(
        _package.copyWith(clearTouristPrice: true),
      );

      expect(map.containsKey('touristPrice'), isTrue);
      expect(map['touristPrice'], isNull);
    });

    test('an update never rewrites createdAt or the active flag', () {
      final map = CatalogFirestoreMapper.packageUpdateToMap(
        _package.copyWith(active: false),
      );

      expect(map['title'], 'Kathmandu Valley Classic');
      expect(map.containsKey('updatedAt'), isTrue);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('active'), isFalse);
    });

    test('a round trip preserves every field and the document id', () {
      final parsed = CatalogFirestoreMapper.packageDocumentFromMap(
        documentId: _package.id,
        data: Map<String, dynamic>.from(
          CatalogFirestoreMapper.packageDocumentToMap(_package)
            ..remove('createdAt')
            ..remove('updatedAt'),
        ),
      );

      expect(parsed.id, 'kathmandu-valley-classic');
      expect(parsed.title, _package.title);
      expect(parsed.region, _package.region);
      expect(parsed.summary, _package.summary);
      expect(parsed.description, _package.description);
      expect(parsed.durationDays, 3);
      expect(parsed.price, 12000);
      expect(parsed.touristPrice?.domestic, 10000);
      expect(parsed.touristPrice?.international, 14000);
      expect(parsed.difficulty, 'Easy');
      expect(parsed.rating, 4.5);
      expect(parsed.imageUrl, _package.imageUrl);
      expect(parsed.highlights, _package.highlights);
      expect(parsed.includedPlaces, _package.includedPlaces);
      expect(parsed.priceFor('International Tourist'), 14000);
      expect(parsed.priceFor('Domestic Tourist'), 10000);
    });

    test('a malformed package document degrades instead of throwing', () {
      final parsed = CatalogFirestoreMapper.packageDocumentFromMap(
        documentId: 'broken',
        data: const {
          'title': 7,
          'durationDays': 'five',
          'price': 'free',
          'rating': null,
          'highlights': 3,
          'includedPlaces': <String, dynamic>{'a': 1},
          'touristPrice': 'cheaper',
        },
      );

      expect(parsed.title, isEmpty);
      expect(parsed.durationDays, 0);
      expect(parsed.price, 0);
      expect(parsed.rating, 0);
      expect(parsed.highlights, isEmpty);
      expect(parsed.includedPlaces, isEmpty);
      expect(parsed.touristPrice, isNull);
    });
  });

  group('booking serialization is untouched', () {
    test('a coordinator snapshot is still exactly id/name/phone/email', () {
      final map = BookingFirestoreMapper.coordinatorToMap(
        _coordinator.copyWith(active: false),
      );

      expect(map.keys.toSet(), {'id', 'name', 'phone', 'email'});
    });

    test('an old snapshot without the flag still parses', () {
      final parsed = BookingFirestoreMapper.coordinatorFromMap(const {
        'id': 'coord-001',
        'name': 'Legacy Staff',
        'phone': '+977 9800000001',
        'email': 'legacy@yatra.app',
      });

      expect(parsed.name, 'Legacy Staff');
      expect(parsed.active, isTrue);
    });

    test('a place snapshot is still exactly the ten business fields', () {
      final map = BookingFirestoreMapper.placeToMap(_place);

      expect(map.keys.toSet(), {
        'name',
        'location',
        'description',
        'imageUrl',
        'entryFee',
        'touristEntryFee',
        'openingHours',
        'transportation',
        'travelTrip',
        'recommendedHours',
      });

      // Registry metadata is never written into a booking.
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('active'), isFalse);
    });

    test('a snapshot place parses back with an empty registry id', () {
      final parsed = BookingFirestoreMapper.placeFromMap(
        BookingFirestoreMapper.placeToMap(_place),
      );

      expect(parsed.id, isEmpty);
      expect(parsed.active, isTrue);
      expect(parsed.name, 'Muktinath');
      expect(parsed.touristEntryFee?.domestic, 800);
    });
  });

  group('model helpers', () {
    test('copyWith never mutates the original record', () {
      const original = _coordinator;

      final copy = original.copyWith(name: 'Renamed', active: false);

      expect(original.name, 'Sushmita Gurung');
      expect(original.active, isTrue);
      expect(copy.name, 'Renamed');
      expect(copy.active, isFalse);
      expect(copy.phone, original.phone);
    });

    test('a place copyWith keeps the untouched fields', () {
      final copy = _place.copyWith(id: 'other', active: false);

      expect(copy.id, 'other');
      expect(copy.active, isFalse);
      expect(copy.entryFee, 1000);
      expect(copy.recommendedHours, 4);
      expect(copy.touristEntryFee, isNotNull);
    });

    test('a package copyWith copies the list fields defensively', () {
      final copy = _package.copyWith(highlights: const ['Only one']);

      expect(copy.highlights, ['Only one']);
      expect(_package.highlights.length, 2);
    });
  });

  group('the tourist static catalogs are untouched by Part 1', () {
    test('every bundled place is still available to the planner', () {
      expect(nepalPlaces.length, 20);
      expect(nepalPlaces, isNotEmpty);
    });

    test('every bundled package is still available to the planner', () {
      expect(tourPackages, isNotEmpty);
      expect(tourPackages.every((package) => package.id.isNotEmpty), isTrue);
    });

    test('the bundled coordinator list is still the migration source', () {
      expect(kMockCoordinators, isNotEmpty);
      expect(
        kMockCoordinators.every((coordinator) => coordinator.id.isNotEmpty),
        isTrue,
      );
    });

    test('destination cost profiles remain static and are not in Part 1', () {
      // Still resolved for the tourist cost estimator, so the static data is
      // intact...
      expect(
        destinationCostProfileFor('Everest Base Camp Trek').location,
        'Everest',
      );
      expect(destinationCostProfileFor('Pokhara').stayPerDay, greaterThan(0));

      // ...and no Part 1 service reads it, because it is estimator input
      // rather than admin-editable catalog content.
      for (final path in [
        'lib/services/firestore_place_service.dart',
        'lib/services/firestore_package_service.dart',
        'lib/services/catalog_seed_service.dart',
      ]) {
        expect(
          _libSource(path).contains('destination_cost_profiles.dart'),
          isFalse,
          reason: path,
        );
      }
    });
  });

  group('architecture', () {
    test('only the migration seed reads the bundled coordinator list', () {
      final sources = {
        ..._libSources('lib/screens/admin'),
        ..._libSources('lib/services'),
      };

      final readers = sources.entries
          .where(
            (entry) =>
                entry.value.contains('mock_coordinators.dart') ||
                entry.value.contains('kMockCoordinators'),
          )
          .map((entry) => entry.key)
          .toList();

      expect(readers, ['lib/services/catalog_seed_service.dart']);
    });

    test('the repositories keep the Firestore services as the default', () {
      final coordinator = _libSource(
        'lib/services/firestore_coordinator_service.dart',
      );
      final place = _libSource('lib/services/firestore_place_service.dart');
      final package = _libSource('lib/services/firestore_package_service.dart');

      expect(coordinator, contains("collection('coordinators')"));
      expect(place, contains("collection('places')"));
      expect(package, contains("collection('packages')"));
    });

    test('no service or screen hard-codes an admin identity', () {
      final sources = {
        ..._libSources('lib/screens/admin'),
        ..._libSources('lib/services'),
      };

      for (final entry in sources.entries) {
        // A hard-coded identity would bypass the role check entirely: an
        // admin-only email/uid constant, or a comparison against one.
        expect(
          RegExp(r'kAdmin(Email|Uid|UID)').hasMatch(entry.value),
          isFalse,
          reason: entry.key,
        );

        expect(
          RegExp(r"(email|uid)\s*==\s*'[^']").hasMatch(entry.value),
          isFalse,
          reason: entry.key,
        );
      }
    });

    test(
      'the catalog mapper is the only place that adds registry metadata',
      () {
        final place = _libSource('lib/services/firestore_place_service.dart');

        // The service delegates every field mapping instead of hand-rolling a
        // second serializer.
        expect(place, contains('CatalogFirestoreMapper.placeDocumentToMap'));
        expect(place, contains('CatalogFirestoreMapper.placeUpdateToMap'));
        expect(place, contains('CatalogFirestoreMapper.placeDocumentFromMap'));
      },
    );
  });

  group('Firestore security rules', () {
    final rules = _libSource('firestore.rules');

    test('the three new collections are covered', () {
      expect(rules, contains('match /coordinators/{coordinatorId}'));
      expect(rules, contains('match /places/{placeId}'));
      expect(rules, contains('match /packages/{packageId}'));
    });

    test('nothing is opened up globally', () {
      expect(rules, isNot(contains('allow read, write: if true')));
      expect(rules, isNot(contains('allow write: if true')));
    });

    test('tourist access is limited to active records', () {
      expect(rules, contains('resource.data.active == true'));
    });

    test('writes stay admin-only and required fields are enforced', () {
      expect(rules, contains('allow create, update: if isAdmin()'));
      expect(rules, contains("hasAll([ 'name', 'phone', 'email', 'active' ])"));
      expect(
        rules,
        contains(
          "hasAll([ 'title', 'region', 'price', 'durationDays', 'active' ])",
        ),
      );
    });

    test('catalog documents are never hard-deleted', () {
      // users, bookings and the three catalogs all keep history.
      expect('allow delete: if false;'.allMatches(rules).length, 5);
    });

    test('tourist profile and booking ownership rules are unchanged', () {
      expect(rules, contains("request.resource.data.role == 'tourist'"));
      expect(rules, contains('resource.data.userId == request.auth.uid'));
      expect(
        rules,
        contains(".hasOnly([ 'status', 'assignedCoordinator', 'updatedAt' ])"),
      );
    });
  });
}
