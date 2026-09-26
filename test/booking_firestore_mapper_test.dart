import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/journey_stop_plan.dart';
import 'package:yatra/models/place_model.dart';
import 'package:yatra/models/tourist_pricing.dart';
import 'package:yatra/models/travel_coordinator.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/booking_firestore_mapper.dart';
import 'package:yatra/services/recommendation_service.dart';

/// A full round-trip route: explicit outbound legs, an explicitly stored
/// return route that is NOT simply the reversed outbound route, plus stay
/// plans on both directions.
const _place = Place(
  name: 'Phewa Lake',
  location: 'Pokhara',
  description: 'Lakeside landmark in Pokhara.',
  imageUrl: 'https://example.com/phewa.jpg',
  entryFee: 200,
  touristEntryFee: TouristPricing(domestic: 100, international: 500),
  openingHours: '6:00 - 18:00',
  transportation: 'Walking',
  travelTrip: 'Best in the evening',
  recommendedHours: 2,
);

const _roundTripRoute = TravelRoute(
  boardingPoint: 'Kathmandu',
  destination: 'Pokhara',
  segments: [
    RouteSegment(from: 'Kathmandu', to: 'Bandipur', transportation: 'Bus'),
    RouteSegment(from: 'Bandipur', to: 'Pokhara', transportation: 'Jeep'),
  ],
  // Stored explicitly so the return leg survives even if route generation
  // rules change later.
  returnSegments: [
    RouteSegment(from: 'Pokhara', to: 'Bandipur', transportation: 'Jeep'),
    RouteSegment(from: 'Bandipur', to: 'Kathmandu', transportation: 'Bus'),
  ],
  tripDirection: TripDirection.roundTrip,
  stopPlans: [JourneyStopPlan(location: 'Bandipur', explorationDays: 1)],
  returnStopPlans: [JourneyStopPlan(location: 'Bandipur', explorationDays: 0)],
);

const _dayPlans = [
  DayPlan(
    day: 1,
    items: [
      DayPlanItem.travel(
        from: 'Kathmandu',
        to: 'Bandipur',
        transportation: 'Tourist Bus',
      ),
      DayPlanItem.attraction(
        place: _place,
        customTitle: 'Sunrise over the ridge',
        note: 'Carry a light jacket.',
      ),
    ],
  ),
  DayPlan(
    day: 2,
    items: [
      DayPlanItem.travel(
        from: 'Bandipur',
        to: 'Pokhara',
        transportation: 'Jeep',
      ),
      DayPlanItem.activity(
        activity: 'Boat ride on Phewa Lake',
        note: 'Go early.',
      ),
      DayPlanItem.activity(activity: 'Paragliding'),
    ],
  ),
];

ItineraryBooking _booking({BookingStatus status = BookingStatus.pending}) {
  return ItineraryBooking(
    id: 'CkQ7dXbZmN3pVrT1',
    bookingCode: 'YT-2026-CKQ7DX',
    userId: 'user-uid-1',
    createdAt: DateTime(2026, 9, 20, 10, 30),
    updatedAt: DateTime(2026, 9, 20, 11),
    status: status,
    destination: 'Pokhara',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 4),
    touristType: 'International Tourist',
    adultCount: 2,
    childCount: 1,
    travelType: 'Family',
    groupSize: 3,
    currency: 'NPR',
    estimatedCost: 42150.5,
    duration: 4,
    packageTitle: 'Annapurna Explorer',
    tripDirection: TripDirection.roundTrip,
    route: _roundTripRoute,
    dayPlans: _dayPlans,
  );
}

const _coordinator = TravelCoordinator(
  id: 'coord-1',
  name: 'Sita Gurung',
  phone: '+9779800000000',
  email: 'sita@yatra.app',
);

void main() {
  // ============================================================
  // TEST 11: ROUTE ROUND-TRIP
  // ============================================================

  test('TEST 11: a round-trip route survives a mapper round-trip', () {
    final original = _booking();
    final restored = BookingFirestoreMapper.bookingFromMap(
      documentId: original.id,
      data: BookingFirestoreMapper.bookingToMap(original),
    );

    expect(restored.route.tripDirection, TripDirection.roundTrip);
    expect(restored.route.isRoundTrip, isTrue);
    expect(restored.route.boardingPoint, 'Kathmandu');
    expect(restored.route.destination, 'Pokhara');

    // Going route.
    expect(restored.route.routeDescription, 'Kathmandu → Bandipur → Pokhara');
    expect(restored.route.segments, hasLength(2));
    expect(restored.route.segments.first.from, 'Kathmandu');
    expect(restored.route.segments.first.to, 'Bandipur');
    expect(restored.route.segments.first.transportation, 'Bus');
    expect(restored.route.segments.last.to, 'Pokhara');
    expect(restored.route.segments.last.transportation, 'Jeep');

    // Coming back route is read from the stored returnSegments and is never
    // regenerated in the UI.
    expect(restored.route.returnSegments, hasLength(2));
    expect(
      restored.route.returnSegments.map(
        (segment) => '${segment.from}→${segment.to}',
      ),
      <String>['Pokhara→Bandipur', 'Bandipur→Kathmandu'],
    );
    expect(restored.route.returnSegments.first.transportation, 'Jeep');
    expect(restored.route.returnSegments.last.transportation, 'Bus');

    // Both direction summaries stay independent.
    // The coming-back summary is built exactly like the details screen does.
    final returnSegments = restored.route.returnSegments;
    final goingDescription = restored.route.routeDescription;
    final comingBackDescription = <String>[
      returnSegments.first.from,
      ...returnSegments.map((segment) => segment.to),
    ].join(' → ');

    expect(goingDescription, 'Kathmandu → Bandipur → Pokhara');
    expect(comingBackDescription, 'Pokhara → Bandipur → Kathmandu');
    expect(goingDescription, isNot(comingBackDescription));
    expect(
      restored.route.completeRouteDescription,
      'Kathmandu → Bandipur → Pokhara → Bandipur → Kathmandu',
    );

    // Stay plans on both directions.
    expect(restored.route.stopPlans, hasLength(1));
    expect(restored.route.stopPlans.first.location, 'Bandipur');
    expect(restored.route.stopPlans.first.explorationDays, 1);
    expect(restored.route.returnStopPlans, hasLength(1));
    expect(restored.route.returnStopPlans.first.location, 'Bandipur');
    expect(restored.route.explorationDays, 1);
  });

  test('TEST 11b: a one-way route keeps an empty return route', () {
    final original = ItineraryBooking(
      id: 'doc-one-way',
      bookingCode: 'YT-2026-ONEWAY',
      userId: 'user-uid-1',
      createdAt: DateTime(2026, 9, 20),
      status: BookingStatus.pending,
      destination: 'Pokhara',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 4),
      touristType: 'Domestic Tourist',
      adultCount: 1,
      childCount: 0,
      travelType: 'Solo',
      groupSize: 1,
      currency: 'NPR',
      estimatedCost: 10000,
      duration: 3,
      tripDirection: TripDirection.oneWay,
      route: const TravelRoute(
        boardingPoint: 'Kathmandu',
        destination: 'Pokhara',
        segments: [
          RouteSegment(
            from: 'Kathmandu',
            to: 'Pokhara',
            transportation: 'Tourist Bus',
          ),
        ],
      ),
      dayPlans: const [],
    );

    final restored = BookingFirestoreMapper.bookingFromMap(
      documentId: original.id,
      data: BookingFirestoreMapper.bookingToMap(original),
    );

    expect(restored.route.isRoundTrip, isFalse);
    expect(restored.route.returnSegments, isEmpty);
    expect(restored.route.completeSegments, hasLength(1));
    expect(restored.tripDirection, TripDirection.oneWay);
    expect(restored.goingRouteDescription, 'Kathmandu → Pokhara');
  });

  // ============================================================
  // TEST 12: DAY PLAN / DAY PLAN ITEM ROUND-TRIP
  // ============================================================

  test('TEST 12: day plans and day plan items survive a mapper round-trip', () {
    final original = _booking();
    final restored = BookingFirestoreMapper.bookingFromMap(
      documentId: original.id,
      data: BookingFirestoreMapper.bookingToMap(original),
    );

    expect(restored.dayPlans, hasLength(2));

    // Day numbers and ordering.
    expect(restored.dayPlans.first.day, 1);
    expect(restored.dayPlans.last.day, 2);
    expect(restored.dayPlans.first.items, hasLength(2));
    expect(restored.dayPlans.last.items, hasLength(3));

    // Travel item.
    final travel = restored.dayPlans.first.items.first;
    expect(travel.type, DayPlanItemType.travel);
    expect(travel.from, 'Kathmandu');
    expect(travel.to, 'Bandipur');
    expect(travel.transportation, 'Tourist Bus');
    expect(travel.place, isNull);
    expect(travel.activity, isNull);
    expect(travel.title, 'Kathmandu → Bandipur');

    // Attraction item with an edited title, a note and a full place snapshot.
    final attraction = restored.dayPlans.first.items.last;
    expect(attraction.type, DayPlanItemType.attraction);
    expect(attraction.customTitle, 'Sunrise over the ridge');
    expect(attraction.note, 'Carry a light jacket.');
    expect(attraction.title, 'Sunrise over the ridge');
    expect(attraction.from, isNull);

    final place = attraction.place;
    expect(place, isNotNull);
    expect(place!.name, 'Phewa Lake');
    expect(place.location, 'Pokhara');
    expect(place.description, 'Lakeside landmark in Pokhara.');
    expect(place.imageUrl, 'https://example.com/phewa.jpg');
    expect(place.entryFee, 200);
    expect(place.openingHours, '6:00 - 18:00');
    expect(place.transportation, 'Walking');
    expect(place.travelTrip, 'Best in the evening');
    expect(place.recommendedHours, 2);
    expect(place.touristEntryFee, isNotNull);
    expect(place.touristEntryFee!.domestic, 100);
    expect(place.touristEntryFee!.international, 500);

    // The pricing resolver still works on the reconstructed snapshot.
    expect(place.entryFeeFor('Domestic Tourist'), 100);
    expect(place.entryFeeFor('International Tourist'), 500);
    expect(place.entryFeeFor('Other Visitor'), 200);

    // Activity items keep their text and note.
    final activity = restored.dayPlans.last.items[1];
    expect(activity.type, DayPlanItemType.activity);
    expect(activity.activity, 'Boat ride on Phewa Lake');
    expect(activity.note, 'Go early.');
    expect(activity.place, isNull);
    expect(activity.title, 'Boat ride on Phewa Lake');

    final plainActivity = restored.dayPlans.last.items.last;
    expect(plainActivity.activity, 'Paragliding');
    expect(plainActivity.note, isNull);
    expect(plainActivity.customTitle, isNull);
  });

  // ============================================================
  // BOOKING-LEVEL ROUND-TRIP
  // ============================================================

  test(
    'a booking survives a mapper round-trip with its identity and snapshot',
    () {
      final original = _booking();
      final map = BookingFirestoreMapper.bookingToMap(original);
      final restored = BookingFirestoreMapper.bookingFromMap(
        documentId: original.id,
        data: map,
      );

      // Identity: document id vs user-facing code.
      expect(restored.id, original.id);
      expect(restored.bookingCode, original.bookingCode);
      expect(restored.bookingCode, isNot(restored.id));
      expect(restored.userId, 'user-uid-1');

      // Document fields written to Firestore.
      expect(map['bookingCode'], 'YT-2026-CKQ7DX');
      expect(map['status'], 'pending');
      expect(map['destination'], 'Pokhara');
      expect(map['touristType'], 'International Tourist');
      expect(map['adultCount'], 2);
      expect(map['childCount'], 1);
      expect(map['travelType'], 'Family');
      expect(map['groupSize'], 3);
      expect(map['currency'], 'NPR');
      expect(map['estimatedCost'], 42150.5);
      expect(map['duration'], 4);
      expect(map['packageTitle'], 'Annapurna Explorer');
      expect(map['tripDirection'], 'roundTrip');
      expect(map['assignedCoordinator'], isNull);
      expect(map['createdAt'], isNotNull);
      expect(map['updatedAt'], isNotNull);
      expect(map['route'], isA<Map<String, dynamic>>());
      expect(map['dayPlans'], isA<List<dynamic>>());

      // Restored values.
      expect(restored.status, BookingStatus.pending);
      expect(restored.destination, 'Pokhara');
      expect(restored.startDate, DateTime(2026, 9, 1));
      expect(restored.endDate, DateTime(2026, 9, 4));
      expect(restored.touristType, 'International Tourist');
      expect(restored.adultCount, 2);
      expect(restored.childCount, 1);
      expect(restored.travelType, 'Family');
      expect(restored.groupSize, 3);
      expect(restored.currency, 'NPR');
      expect(restored.estimatedCost, 42150.5);
      expect(restored.duration, 4);
      expect(restored.packageTitle, 'Annapurna Explorer');
      expect(restored.tripDirection, TripDirection.roundTrip);
      expect(restored.tripTypeLabel, 'Round Trip');
      expect(restored.createdAt, DateTime(2026, 9, 20, 10, 30));
      expect(restored.updatedAt, DateTime(2026, 9, 20, 11));
      expect(restored.assignedCoordinator, isNull);
    },
  );

  test('an assigned coordinator snapshot survives a mapper round-trip', () {
    final original = _booking()..assignedCoordinator = _coordinator;

    final restored = BookingFirestoreMapper.bookingFromMap(
      documentId: original.id,
      data: BookingFirestoreMapper.bookingToMap(original),
    );

    expect(restored.assignedCoordinator, isNotNull);
    expect(restored.assignedCoordinator!.id, _coordinator.id);
    expect(restored.assignedCoordinator!.name, _coordinator.name);
    expect(restored.assignedCoordinator!.phone, _coordinator.phone);
    expect(restored.assignedCoordinator!.email, _coordinator.email);
  });

  test('a cancelled status is preserved instead of being reset to pending', () {
    final original = _booking(status: BookingStatus.cancelled);

    final restored = BookingFirestoreMapper.bookingFromMap(
      documentId: original.id,
      data: BookingFirestoreMapper.bookingToMap(original),
    );

    expect(restored.status, BookingStatus.cancelled);
  });

  test('malformed day plan items fall back safely instead of throwing', () {
    final restored = BookingFirestoreMapper.bookingFromMap(
      documentId: 'doc-legacy',
      data: {
        'bookingCode': 'YT-2026-LEGACY',
        'status': 'pending',
        'dayPlans': [
          {
            'day': 1,
            'items': [
              {'type': 'unknown-legacy-type', 'note': 'kept'},
            ],
          },
        ],
      },
    );

    expect(restored.dayPlans, hasLength(1));
    expect(restored.dayPlans.first.items, hasLength(1));
    expect(restored.dayPlans.first.items.first.type, DayPlanItemType.activity);
    expect(restored.dayPlans.first.items.first.note, 'kept');
  });
}
