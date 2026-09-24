import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/google_maps_queries.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/screens/recommendation/recommendation_screen.dart';
import 'package:yatra/services/google_maps_launcher.dart';

/// Pumps [RecommendationScreen] directly for a given [route], so the map
/// navigation feature is tested in isolation from the boarding flow.
Future<void> _pumpRecommendation(
  WidgetTester tester, {
  required TravelRoute route,
  String destination = 'Pokhara',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RecommendationScreen(
        touristType: 'Domestic Tourist',
        destination: destination,
        departureDate: DateTime(2026, 9, 1),
        returnDate: DateTime(2026, 9, 10),
        season: 'Autumn',
        suitability: 'Good',
        currency: 'USD',
        budget: 5000,
        ages: [30],
        adultCount: 1,
        childCount: 0,
        travelType: 'Couples',
        groupSize: 2,
        seasonMessage: 'msg',
        route: route,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The [View in Google Maps] button that belongs to the travel leg / route
/// leg whose body text is [markerText]. The button lives in the same narrow
/// Column as the marker text, so the nearest ancestor Column scopes it
/// correctly (a travel-item column in the day plan, or a route-leg column in
/// the "Your Travel Route" card).
Finder _directionsButtonFor(String markerText) {
  final column = find
      .ancestor(of: find.text(markerText), matching: find.byType(Column))
      .first;

  return find.descendant(
    of: column,
    matching: find.widgetWithText(OutlinedButton, 'View in Google Maps'),
  );
}

Future<void> _tapButton(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _openFromDayPlan(
  WidgetTester tester,
  String from,
  String to,
) async {
  final button = _directionsButtonFor('Travel · $from → $to');
  expect(button, findsOneWidget, reason: 'itinerary leg $from → $to button');
  await _tapButton(tester, button);

  expect(find.text('Map & Offline Access'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.text('Open Google Maps'), findsOneWidget);

  await tester.tap(find.text('Open Google Maps'));
  await tester.pumpAndSettle();
}

TravelRoute _oneWay({String transport = 'Bus'}) {
  return TravelRoute(
    boardingPoint: 'Kathmandu',
    destination: 'Pokhara',
    segments: [
      RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: transport),
    ],
  );
}

TravelRoute _trekRoute() {
  return TravelRoute(
    boardingPoint: 'Ghandruk',
    destination: 'Poon Hill',
    segments: const [
      RouteSegment(from: 'Ghandruk', to: 'Poon Hill', transportation: 'Trek'),
    ],
  );
}

TravelRoute _customReturnRoute() {
  return TravelRoute(
    boardingPoint: 'Kathmandu',
    destination: 'Mustang',
    tripDirection: TripDirection.roundTrip,
    segments: const [
      RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
      RouteSegment(from: 'Pokhara', to: 'Jomsom', transportation: 'Flight'),
      RouteSegment(from: 'Jomsom', to: 'Mustang', transportation: 'Jeep'),
    ],
    returnSegments: const [
      RouteSegment(from: 'Mustang', to: 'Jomsom', transportation: 'Jeep'),
      RouteSegment(from: 'Jomsom', to: 'Marpha', transportation: 'Bus'),
      RouteSegment(from: 'Marpha', to: 'Kagbeni', transportation: 'Jeep'),
      RouteSegment(from: 'Kagbeni', to: 'Muktinath', transportation: 'Bus'),
      RouteSegment(from: 'Muktinath', to: 'Kagbeni', transportation: 'Bus'),
      RouteSegment(from: 'Kagbeni', to: 'Jomsom', transportation: 'Jeep'),
      RouteSegment(from: 'Jomsom', to: 'Kathmandu', transportation: 'Flight'),
    ],
  );
}

void main() {
  Uri? launchedUri;

  setUp(() {
    launchedUri = null;

    // Every test records the exact directions URI that would be opened
    // instead of really handing off to the device. Individual tests may
    // override the return value to simulate launch failures.
    GoogleMapsLauncher.openUri = (uri) async {
      launchedUri = uri;
      return true;
    };
  });

  group('GoogleMapsLauncher travel modes', () {
    test('car/taxi/jeep/private vehicle -> driving', () {
      expect(GoogleMapsLauncher.travelModeFor('Car'), 'driving');
      expect(GoogleMapsLauncher.travelModeFor('Taxi'), 'driving');
      expect(GoogleMapsLauncher.travelModeFor('Jeep'), 'driving');
      expect(GoogleMapsLauncher.travelModeFor('Private Vehicle'), 'driving');
      expect(GoogleMapsLauncher.travelModeFor('Motorbike'), 'driving');
    });

    test('walk/trek/hiking -> walking', () {
      expect(GoogleMapsLauncher.travelModeFor('Walk'), 'walking');
      expect(GoogleMapsLauncher.travelModeFor('Trek'), 'walking');
      expect(GoogleMapsLauncher.travelModeFor('Trekking'), 'walking');
      expect(GoogleMapsLauncher.travelModeFor('Hiking'), 'walking');
    });

    test('flight and bus do not force a mode', () {
      expect(GoogleMapsLauncher.travelModeFor('Flight'), isNull);
      expect(GoogleMapsLauncher.travelModeFor('Bus'), isNull);
      expect(GoogleMapsLauncher.travelModeFor('Air'), isNull);
    });

    test('null and unknown modes do not force a mode', () {
      expect(GoogleMapsLauncher.travelModeFor(null), isNull);
      expect(GoogleMapsLauncher.travelModeFor('Something Else'), isNull);
    });
  });

  group('GoogleMapsLauncher directions URI', () {
    test('TEST 1: Kathmandu -> Pokhara uses canonical textual queries', () {
      final uri = GoogleMapsLauncher.buildDirectionsUri(
        from: 'Kathmandu',
        to: 'Pokhara',
        transportation: 'Bus',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['origin'], 'Kathmandu, Nepal');
      expect(uri.queryParameters['destination'], 'Pokhara, Nepal');
      expect(uri.queryParameters.containsKey('travelmode'), isFalse);
    });

    test('TEST 2: toString is a well-formed directions deep-link', () {
      final uri = GoogleMapsLauncher.buildDirectionsUri(
        from: 'Kathmandu',
        to: 'Pokhara',
        transportation: 'Bus',
      );

      final url = uri.toString();
      expect(url, startsWith('https://www.google.com/maps/dir/?'));
      expect(url, contains('api=1'));
      expect(url, contains('origin='));
      expect(url, contains('destination='));
    });

    test(
      r'TEST 3: unknown/simple destinations fall back to "$location, Nepal"',
      () {
        final uri = GoogleMapsLauncher.buildDirectionsUri(
          from: 'Kathmandu',
          to: 'Bandipur',
          transportation: 'Bus',
        );

        expect(uri.queryParameters['origin'], 'Kathmandu, Nepal');
        expect(uri.queryParameters['destination'], 'Bandipur, Nepal');
        expect(googleMapsQueryFor('Bandipur'), 'Bandipur, Nepal');
      },
    );

    test(
      'TEST 4: ambiguous Mustang resolves to Lo Manthang, never a coordinate',
      () {
        expect(googleMapsQueryFor('Mustang'), 'Lo Manthang, Mustang, Nepal');

        final uri = GoogleMapsLauncher.buildDirectionsUri(
          from: 'Jomsom',
          to: 'Mustang',
          transportation: 'Jeep',
        );

        expect(uri.queryParameters['origin'], 'Jomsom, Mustang, Nepal');
        expect(
          uri.queryParameters['destination'],
          'Lo Manthang, Mustang, Nepal',
        );
      },
    );

    test(
      'TEST 5: no placeCoordinates lookup is needed by GoogleMapsLauncher',
      () {
        // Kathmandu, Pokhara and Chitwan were in the old coordinate table;
        // external navigation must now use plain textual queries instead.
        final kathmandu = googleMapsQueryFor('Kathmandu');
        final pokhara = googleMapsQueryFor('Pokhara');
        final chitwan = googleMapsQueryFor('Chitwan');

        expect(kathmandu, 'Kathmandu, Nepal');
        expect(pokhara, 'Pokhara, Nepal');
        expect(chitwan, 'Chitwan, Nepal');

        expect(kathmandu, isNot(contains('27.7172')));
        expect(pokhara, isNot(contains('28.2096')));
        expect(
          GoogleMapsLauncher.buildDirectionsUri(
            from: 'Ghandruk',
            to: 'Poon Hill',
            transportation: 'Trek',
          ).queryParameters['origin'],
          'Ghandruk, Nepal',
        );
      },
    );

    test(
      'TEST 6: custom-return leg (Jomsom -> Pokhara) uses the same resolver',
      () {
        final uri = GoogleMapsLauncher.buildDirectionsUri(
          from: 'Jomsom',
          to: 'Pokhara',
          transportation: 'Flight',
        );

        expect(uri.queryParameters['origin'], 'Jomsom, Mustang, Nepal');
        expect(uri.queryParameters['destination'], 'Pokhara, Nepal');
      },
    );

    test('TEST: driving legs include travelmode=driving', () {
      final uri = GoogleMapsLauncher.buildDirectionsUri(
        from: 'Kathmandu',
        to: 'Pokhara',
        transportation: 'Jeep',
      );

      expect(uri.queryParameters['travelmode'], 'driving');

      final trekUri = GoogleMapsLauncher.buildDirectionsUri(
        from: 'Ghandruk',
        to: 'Poon Hill',
        transportation: 'Trek',
      );
      expect(trekUri.queryParameters['travelmode'], 'walking');
    });

    test('TEST: flight legs never include travelmode=driving', () {
      final uri = GoogleMapsLauncher.buildDirectionsUri(
        from: 'Kathmandu',
        to: 'Pokhara',
        transportation: 'Flight',
      );

      expect(uri.queryParameters.containsKey('travelmode'), isFalse);
      expect(uri.queryParameters['travelmode'], isNot('driving'));
    });
  });

  group('googleMapsQueryFor', () {
    test('known destinations use their canonical query', () {
      expect(googleMapsQueryFor('Kathmandu'), 'Kathmandu, Nepal');
      expect(googleMapsQueryFor('Pokhara'), 'Pokhara, Nepal');
      expect(googleMapsQueryFor('Chitwan'), 'Chitwan, Nepal');
    });

    test('Mustang-region settlements carry the district', () {
      expect(googleMapsQueryFor('Jomsom'), 'Jomsom, Mustang, Nepal');
      expect(googleMapsQueryFor('Kagbeni'), 'Kagbeni, Mustang, Nepal');
      expect(googleMapsQueryFor('Marpha'), 'Marpha, Mustang, Nepal');
      expect(googleMapsQueryFor('Muktinath'), 'Muktinath, Mustang, Nepal');
      expect(googleMapsQueryFor('Lo Manthang'), 'Lo Manthang, Mustang, Nepal');
    });

    test('region-level destinations resolve to their trek endpoint', () {
      expect(googleMapsQueryFor('Mustang'), 'Lo Manthang, Mustang, Nepal');
      expect(googleMapsQueryFor('Annapurna'), 'Annapurna Base Camp, Nepal');
      expect(googleMapsQueryFor('Everest'), 'Everest Base Camp, Nepal');
    });

    test('matching is case-insensitive and ignores surrounding whitespace', () {
      expect(googleMapsQueryFor('  kathmandu  '), 'Kathmandu, Nepal');
      expect(googleMapsQueryFor('MUSTANG'), 'Lo Manthang, Mustang, Nepal');
    });

    test(r'unknown locations fall back to "$location, Nepal"', () {
      expect(googleMapsQueryFor('Bandipur'), 'Bandipur, Nepal');
      expect(googleMapsQueryFor('Tansen'), 'Tansen, Nepal');
      expect(googleMapsQueryFor('Rasuwa'), 'Rasuwa, Nepal');
      expect(
        googleMapsQueryFor('Some Unknown Town'),
        'Some Unknown Town, Nepal',
      );
    });

    test('empty input stays empty', () {
      expect(googleMapsQueryFor('  '), '');
      expect(googleMapsQueryFor(''), '');
    });
  });

  group('RecommendationScreen map navigation', () {
    testWidgets(
      'TEST 1: the itinerary travel leg shows [View in Google Maps]',
      (tester) async {
        await _pumpRecommendation(tester, route: _oneWay());

        expect(find.text('Travel · Kathmandu → Pokhara'), findsOneWidget);
        expect(
          _directionsButtonFor('Travel · Kathmandu → Pokhara'),
          findsOneWidget,
        );

        // One button on the itinerary leg plus one on the Route Card leg.
        expect(find.text('View in Google Maps'), findsNWidgets(2));
      },
    );

    testWidgets(
      'TEST 2: the Route Card going leg shows [View in Google Maps]',
      (tester) async {
        await _pumpRecommendation(tester, route: _oneWay());

        expect(find.text('Kathmandu → Pokhara\nBus'), findsOneWidget);
        expect(
          _directionsButtonFor('Kathmandu → Pokhara\nBus'),
          findsOneWidget,
        );
      },
    );

    testWidgets('TEST 3: itinerary leg and Route Card leg both have buttons', (
      tester,
    ) async {
      await _pumpRecommendation(tester, route: _oneWay());

      expect(
        _directionsButtonFor('Travel · Kathmandu → Pokhara'),
        findsOneWidget,
      );
      expect(_directionsButtonFor('Kathmandu → Pokhara\nBus'), findsOneWidget);
    });

    testWidgets(
      'TEST 4: tapping opens the Map & Offline Access dialog; Cancel does not launch',
      (tester) async {
        await _pumpRecommendation(tester, route: _oneWay());

        await _tapButton(
          tester,
          _directionsButtonFor('Travel · Kathmandu → Pokhara'),
        );

        expect(find.text('Map & Offline Access'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Open Google Maps'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Map & Offline Access'), findsNothing);
        expect(launchedUri, isNull);
      },
    );

    testWidgets('TEST 5: every custom-return leg gets its own button', (
      tester,
    ) async {
      await _pumpRecommendation(tester, route: _customReturnRoute());

      for (final (from, to, transport) in const [
        ('Mustang', 'Jomsom', 'Jeep'),
        ('Jomsom', 'Marpha', 'Bus'),
        ('Marpha', 'Kagbeni', 'Jeep'),
        ('Kagbeni', 'Muktinath', 'Bus'),
        ('Muktinath', 'Kagbeni', 'Bus'),
        ('Kagbeni', 'Jomsom', 'Jeep'),
        ('Jomsom', 'Kathmandu', 'Flight'),
      ]) {
        final marker = '$from → $to\n$transport';
        expect(find.text(marker), findsOneWidget, reason: 'return leg shown');
        expect(
          _directionsButtonFor(marker),
          findsOneWidget,
          reason: '$from → $to return leg button',
        );
      }
    });

    testWidgets('TEST 6: exploration-only days show no route button', (
      tester,
    ) async {
      await _pumpRecommendation(tester, route: _oneWay());

      final dayPlanMarker = _directionsButtonFor(
        'Travel · Kathmandu → Pokhara',
      );
      expect(dayPlanMarker, findsOneWidget);

      // Day 2 onwards only explore the destination (no travel legs).
      final dayTwoCard = find
          .ancestor(of: find.text('Day 2'), matching: find.byType(Card))
          .first;
      expect(dayTwoCard, findsOneWidget);
      expect(
        find.descendant(
          of: dayTwoCard,
          matching: find.text('View in Google Maps'),
        ),
        findsNothing,
      );
    });

    testWidgets('TEST 6: the launcher receives the full Uri', (tester) async {
      await _pumpRecommendation(tester, route: _oneWay(transport: 'Jeep'));

      final button = _directionsButtonFor('Travel · Kathmandu → Pokhara');
      await _tapButton(tester, button);

      expect(find.text('Map & Offline Access'), findsOneWidget);
      await tester.tap(find.text('Open Google Maps'));
      await tester.pumpAndSettle();

      // The full Uri must reach the launcher: the directions path AND the
      // query parameters together. Losing the query is what caused the 404.
      expect(launchedUri, isNotNull);
      expect(launchedUri!.path, '/maps/dir/');
      expect(launchedUri!.queryParameters['api'], '1');
      expect(launchedUri!.queryParameters['origin'], isNotEmpty);
      expect(launchedUri!.queryParameters['destination'], isNotEmpty);
      expect(
        launchedUri!.toString(),
        startsWith('https://www.google.com/maps/dir/?'),
      );
    });

    testWidgets('TEST 7: Jeep leg opens Google Maps with travelmode=driving', (
      tester,
    ) async {
      await _pumpRecommendation(tester, route: _oneWay(transport: 'Jeep'));

      await _openFromDayPlan(tester, 'Kathmandu', 'Pokhara');

      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters['travelmode'], 'driving');
      expect(launchedUri!.queryParameters['origin'], 'Kathmandu, Nepal');
      expect(launchedUri!.queryParameters['destination'], 'Pokhara, Nepal');
    });

    testWidgets('TEST 8: Trek leg opens Google Maps with travelmode=walking', (
      tester,
    ) async {
      await _pumpRecommendation(
        tester,
        route: _trekRoute(),
        destination: 'Poon Hill',
      );

      await _openFromDayPlan(tester, 'Ghandruk', 'Poon Hill');

      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters['travelmode'], 'walking');
      expect(launchedUri!.queryParameters['origin'], 'Ghandruk, Nepal');
      expect(launchedUri!.queryParameters['destination'], 'Poon Hill, Nepal');
    });

    testWidgets('TEST 9: Flight leg does not force a driving route', (
      tester,
    ) async {
      await _pumpRecommendation(tester, route: _oneWay(transport: 'Flight'));

      await _openFromDayPlan(tester, 'Kathmandu', 'Pokhara');

      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters.containsKey('travelmode'), isFalse);
      expect(launchedUri!.queryParameters['travelmode'], isNot('driving'));
    });

    testWidgets('TEST 10: launch failure shows "Unable to open Google Maps"', (
      tester,
    ) async {
      GoogleMapsLauncher.openUri = (uri) async {
        launchedUri = uri;
        return false;
      };

      await _pumpRecommendation(tester, route: _oneWay());

      await _openFromDayPlan(tester, 'Kathmandu', 'Pokhara');

      expect(launchedUri, isNotNull);
      expect(
        find.text('Unable to open Google Maps on this device.'),
        findsOneWidget,
      );
    });
  });
}
