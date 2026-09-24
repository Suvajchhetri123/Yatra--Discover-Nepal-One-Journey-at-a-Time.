import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/transportation_data.dart';
import 'package:yatra/models/journey_stop_plan.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/recommendation_service.dart';
import 'package:yatra/services/trip_cost_estimator.dart';

TravelRoute _route({
  String destination = 'Mustang',
  required List<RouteSegment> segments,
  List<RouteSegment>? returnSegments,
  TripDirection tripDirection = TripDirection.roundTrip,
  List<JourneyStopPlan> stopPlans = const [],
  List<JourneyStopPlan> returnStopPlans = const [],
  String boardingPoint = 'Kathmandu',
}) {
  return TravelRoute(
    boardingPoint: boardingPoint,
    destination: destination,
    segments: segments,
    tripDirection: tripDirection,
    returnSegments: returnSegments,
    stopPlans: stopPlans,
    returnStopPlans: returnStopPlans,
  );
}

const _outbound = [
  RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
  RouteSegment(from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
];

const _customReturn = [
  RouteSegment(from: 'Mustang', to: 'Kagbeni', transportation: 'Jeep'),
  RouteSegment(
    from: 'Kagbeni',
    to: 'Jomsom',
    transportation: 'Private Vehicle',
  ),
  RouteSegment(from: 'Jomsom', to: 'Pokhara', transportation: 'Bus'),
  RouteSegment(from: 'Pokhara', to: 'Kathmandu', transportation: 'Flight'),
];

const _chitwanOutbound = [
  RouteSegment(from: 'Kathmandu', to: 'Chitwan', transportation: 'Bus'),
];

const _chitwanReturn = [
  RouteSegment(from: 'Chitwan', to: 'Pokhara', transportation: 'Bus'),
  RouteSegment(from: 'Pokhara', to: 'Kathmandu', transportation: 'Flight'),
];

void main() {
  group('connectedDestinationsFrom', () {
    test('mustang offers stops that are NOT on the outbound route', () {
      final options = connectedDestinationsFrom('Mustang');

      // Kagbeni and Jomsom are connected to Mustang in the route database,
      // even though the outbound route Kathmandu->Pokhara->Mustang never
      // visits them.
      expect(options, contains('Kagbeni'));
      expect(options, contains('Jomsom'));
      expect(options, contains('Pokhara'));
      expect(options, contains('Kathmandu'));
    });

    test('kagbeni connects onward to jomsom and pokhara', () {
      final options = connectedDestinationsFrom('Kagbeni');

      expect(options, contains('Jomsom'));
      expect(options, contains('Marpha'));
      expect(options, contains('Muktinath'));
      expect(options, contains('Mustang'));
      expect(options, contains('Pokhara'));
      expect(options, contains('Kathmandu'));
    });

    test('jomsom connects onward to pokhara and kathmandu', () {
      final options = connectedDestinationsFrom('Jomsom');

      expect(options, contains('Pokhara'));
      expect(options, contains('Kathmandu'));
      expect(options, contains('Marpha'));
      expect(options, contains('Mustang'));
      expect(options, contains('Kagbeni'));
    });

    test('results are canonical, deduplicated and sorted', () {
      final options = connectedDestinationsFrom('mustang');

      expect(options, isA<List<String>>());
      expect(options.toSet().length, options.length);
      expect(options, List.of(options)..sort());
    });

    test('never fabricates connections across route families', () {
      final everest = connectedDestinationsFrom('Everest');

      // Everest only shares routes with Kathmandu/Lukla/Namche Bazaar.
      // Mustang and its valley are in a completely different network.
      expect(everest, contains('Lukla'));
      expect(everest, contains('Namche Bazaar'));
      expect(everest, isNot(contains('Mustang')));
      expect(everest, isNot(contains('Kagbeni')));

      // The via-Jomsom route means Kathmandu<->Mustang IS a real connection,
      // so a direct Kathmandu->Mustang leg is legitimately offered.
      expect(connectedDestinationsFrom('Kathmandu'), contains('Mustang'));
      expect(transportOptionsForRoute('Kathmandu', 'Mustang'), isNotEmpty);
    });
  });

  group('TravelRoute with explicit custom return', () {
    test('keeps every explicit return leg, not the reversed outbound', () {
      final route = _route(segments: _outbound, returnSegments: _customReturn);

      expect(route.returnSegments.length, 4);
      expect(route.completeSegments.length, 6);

      // The custom return is preserved verbatim.
      expect(route.returnSegments.map((s) => '${s.from}->${s.to}').toList(), [
        'Mustang->Kagbeni',
        'Kagbeni->Jomsom',
        'Jomsom->Pokhara',
        'Pokhara->Kathmandu',
      ]);

      // completeSegments = outbound + explicit return, in order.
      expect(route.completeSegments[2].from, 'Mustang');
      expect(route.completeSegments[2].to, 'Kagbeni');
      expect(route.completeSegments.last.to, 'Kathmandu');
    });

    test('keeps return-stop plans distinct and sums all exploration days', () {
      final route = _route(
        segments: _outbound,
        returnSegments: _customReturn,
        stopPlans: const [
          JourneyStopPlan(location: 'Pokhara', explorationDays: 2),
        ],
        returnStopPlans: const [
          JourneyStopPlan(location: 'Jomsom', explorationDays: 2),
          JourneyStopPlan(location: 'Pokhara', explorationDays: 1),
        ],
      );

      expect(route.stopPlans.map((p) => p.location).toList(), ['Pokhara']);
      expect(route.returnStopPlans.map((p) => p.location).toList(), [
        'Jomsom',
        'Pokhara',
      ]);

      // stopPlans + returnStopPlans both feed the shared exploration-days sum.
      expect(route.explorationDays, 5);

      // Stop plans never change the route geometry.
      expect(route.completeSegments.length, 6);
    });
  });

  group('TripCostEstimator', () {
    test('uses the actual custom return legs when calculating transport', () {
      TripCostEstimate estimateFor(TravelRoute route) {
        return TripCostEstimator.estimate(
          touristType: 'Domestic Tourist',
          destination: route.destination,
          durationDays: 5,
          adultCount: 1,
          childCount: 0,
          childAges: TripCostEstimator.childAgesFrom(
            ages: const [30],
            adultCount: 1,
            childCount: 0,
          ),
          route: route,
        );
      }

      final automatic = _route(segments: _outbound);
      final custom = _route(segments: _outbound, returnSegments: _customReturn);

      // Automatic: 2 return legs (Jeep 3200 + Bus 1500).
      // Custom: 4 return legs (Jeep 3200 + Private Vehicle 2000
      // + Bus 1500 + Flight 9000).
      expect(estimateFor(automatic).transport, 1500 + 3200 + 3200 + 1500);
      expect(
        estimateFor(custom).transport,
        1500 + 3200 + 3200 + 2000 + 1500 + 9000,
      );

      expect(
        estimateFor(custom).transport,
        greaterThan(estimateFor(automatic).transport),
      );
    });

    test('prices return-stop stays without touching transport cost', () {
      TripCostEstimate estimateFor(TravelRoute route) {
        return TripCostEstimator.estimate(
          touristType: 'Domestic Tourist',
          destination: route.destination,
          durationDays: 5,
          adultCount: 1,
          childCount: 0,
          childAges: TripCostEstimator.childAgesFrom(
            ages: const [30],
            adultCount: 1,
            childCount: 0,
          ),
          route: route,
        );
      }

      final base = estimateFor(
        _route(segments: _outbound, returnSegments: _customReturn),
      );
      final withReturnStops = estimateFor(
        _route(
          segments: _outbound,
          returnSegments: _customReturn,
          returnStopPlans: const [
            JourneyStopPlan(location: 'Jomsom', explorationDays: 2),
            JourneyStopPlan(location: 'Pokhara', explorationDays: 1),
          ],
        ),
      );

      // Jomsom and Pokhara are return-only stops, so their stay days only
      // appear when returnStopPlans is populated.
      expect(withReturnStops.stay, greaterThan(base.stay));
      expect(withReturnStops.activity, greaterThan(base.activity));
      expect(withReturnStops.total, greaterThan(base.total));

      // Return stays are exploration, not transport: the legs are unchanged.
      expect(withReturnStops.transport, base.transport);
      expect(
        withReturnStops.total - base.total,
        (withReturnStops.stay + withReturnStops.activity) -
            (base.stay + base.activity),
      );

      // A return stop with zero days behaves exactly like no plan at all.
      final zeroDays = estimateFor(
        _route(
          segments: _outbound,
          returnSegments: _customReturn,
          returnStopPlans: const [
            JourneyStopPlan(location: 'Jomsom', explorationDays: 0),
          ],
        ),
      );
      expect(zeroDays.stay, base.stay);
      expect(zeroDays.total, base.total);
    });

    test('prices outbound stop stays during a round trip too', () {
      TripCostEstimate estimateFor(TravelRoute route) {
        return TripCostEstimator.estimate(
          touristType: 'Domestic Tourist',
          destination: route.destination,
          durationDays: 5,
          adultCount: 1,
          childCount: 0,
          childAges: TripCostEstimator.childAgesFrom(
            ages: const [30],
            adultCount: 1,
            childCount: 0,
          ),
          route: route,
        );
      }

      final base = estimateFor(
        _route(segments: _outbound, returnSegments: _customReturn),
      );
      final withOutboundStop = estimateFor(
        _route(
          segments: _outbound,
          returnSegments: _customReturn,
          stopPlans: const [
            JourneyStopPlan(location: 'Pokhara', explorationDays: 2),
          ],
        ),
      );

      // Pokhara is an outbound-only intermediate stop here, so its extra stay
      // days only show once the outbound stop plan is populated.
      expect(withOutboundStop.stay, greaterThan(base.stay));
      expect(withOutboundStop.activity, greaterThan(base.activity));
      expect(withOutboundStop.total, greaterThan(base.total));

      // Outbound exploration days are stays, not transport.
      expect(withOutboundStop.transport, base.transport);
    });
  });

  group('RecommendationService', () {
    List<(String, String)> travelPairs(List<DayPlan> plans) {
      return [
        for (final plan in plans)
          for (final item in plan.items)
            if (item.type == DayPlanItemType.travel &&
                item.from != null &&
                item.to != null)
              (item.from!, item.to!),
      ];
    }

    test('itinerary uses the explicit custom return legs, in order', () {
      final custom = _route(segments: _outbound, returnSegments: _customReturn);
      final automatic = _route(segments: _outbound);

      final customPairs = travelPairs(
        RecommendationService.getDayPlans(route: custom),
      );
      final automaticPairs = travelPairs(
        RecommendationService.getDayPlans(route: automatic),
      );

      // Custom return legs appear after the outbound journey.
      expect(customPairs.take(2).toList(), [
        ('Kathmandu', 'Pokhara'),
        ('Pokhara', 'Mustang'),
      ]);

      expect(customPairs, contains(('Mustang', 'Kagbeni')));
      expect(customPairs, contains(('Kagbeni', 'Jomsom')));
      expect(customPairs, contains(('Jomsom', 'Pokhara')));
      expect(customPairs, contains(('Pokhara', 'Kathmandu')));

      // The automatic return has fewer legs and never visits Kagbeni.
      expect(automaticPairs, contains(('Mustang', 'Pokhara')));
      expect(automaticPairs, contains(('Pokhara', 'Kathmandu')));
      expect(automaticPairs, isNot(contains(('Mustang', 'Kagbeni'))));
    });

    List<String> signatures(List<DayPlan> plans) {
      return [
        for (final plan in plans)
          for (final item in plan.items)
            switch (item.type) {
              DayPlanItemType.travel => 'travel ${item.from}->${item.to}',
              DayPlanItemType.attraction =>
                'attraction ${item.place?.name ?? '?'}',
              DayPlanItemType.activity => 'activity',
            },
      ];
    }

    test('minimumDays includes return-stop exploration days', () {
      final noStops = _route(
        segments: _outbound,
        returnSegments: _customReturn,
      );
      final withStops = _route(
        segments: _outbound,
        returnSegments: _customReturn,
        returnStopPlans: const [
          JourneyStopPlan(location: 'Jomsom', explorationDays: 2),
          JourneyStopPlan(location: 'Pokhara', explorationDays: 1),
        ],
      );

      // 2 travel + 3 Mustang visit + 4 return travel + 0 stays.
      expect(RecommendationService.minimumDaysFor(route: noStops), 9);

      // + 3 days of return-stop stays (Jomsom 2, Pokhara 1).
      expect(RecommendationService.minimumDaysFor(route: withStops), 12);
    });

    test('interleaves each return stop exploration AFTER its arrival leg', () {
      final route = _route(
        segments: _outbound,
        returnSegments: _customReturn,
        returnStopPlans: const [
          JourneyStopPlan(location: 'Jomsom', explorationDays: 2),
          JourneyStopPlan(location: 'Pokhara', explorationDays: 1),
        ],
      );

      final sig = signatures(RecommendationService.getDayPlans(route: route));

      // Outbound travel comes first, then the destination visit days.
      expect(sig[0], 'travel Kathmandu->Pokhara');
      expect(sig[1], 'travel Pokhara->Mustang');

      // Chronological ordering of every return travel item.
      final iM2K = sig.indexOf('travel Mustang->Kagbeni');
      final iK2J = sig.indexOf('travel Kagbeni->Jomsom');
      final iJ2P = sig.indexOf('travel Jomsom->Pokhara');
      final iP2K = sig.indexOf('travel Pokhara->Kathmandu');

      expect(iM2K, lessThan(iK2J));
      expect(iK2J, lessThan(iJ2P));
      expect(iJ2P, lessThan(iP2K));

      // Jomsom gets its 2 stay days between arriving (Kagbeni->Jomsom) and
      // leaving (Jomsom->Pokhara).
      final jomsomGap = sig.sublist(iK2J + 1, iJ2P);
      expect(jomsomGap, hasLength(2));
      expect(jomsomGap.every((s) => !s.startsWith('travel')), isTrue);

      // Pokhara gets its single stay day between arriving and the last leg.
      final pokharaGap = sig.sublist(iJ2P + 1, iP2K);
      expect(pokharaGap, hasLength(1));
      expect(pokharaGap.single, startsWith('attraction'));
    });

    test('applies the same chronology to a second route family (Chitwan)', () {
      final route = _route(
        destination: 'Chitwan',
        segments: _chitwanOutbound,
        returnSegments: _chitwanReturn,
        returnStopPlans: const [
          JourneyStopPlan(location: 'Pokhara', explorationDays: 2),
        ],
      );

      // 1 travel + 3 Chitwan visit + 2 return travel + 2 Pokhara stay = 8.
      expect(RecommendationService.minimumDaysFor(route: route), 8);

      final sig = signatures(RecommendationService.getDayPlans(route: route));

      final iK2C = sig.indexOf('travel Kathmandu->Chitwan');
      final iC2P = sig.indexOf('travel Chitwan->Pokhara');
      final iP2K = sig.indexOf('travel Pokhara->Kathmandu');

      expect(iC2P, greaterThan(iK2C));
      expect(iC2P, lessThan(iP2K));

      // Pokhara is a return-only stop here: its stay days sit between the
      // Chitwan->Pokhara leg and the final Pokhara->Kathmandu leg.
      final pokharaGap = sig.sublist(iC2P + 1, iP2K);
      expect(pokharaGap, hasLength(2));
      expect(pokharaGap.every((s) => !s.startsWith('travel')), isTrue);
    });

    test('a round trip plans outbound-stop exploration interleaved with the '
        'outbound legs', () {
      final route = _route(
        segments: _outbound,
        returnSegments: _customReturn,
        stopPlans: const [
          JourneyStopPlan(location: 'Pokhara', explorationDays: 2),
        ],
        returnStopPlans: const [
          JourneyStopPlan(location: 'Jomsom', explorationDays: 1),
        ],
      );

      // 2 travel + 3 Mustang visit + 4 return travel + 2 outbound Pokhara
      // stay + 1 return Jomsom stay.
      expect(RecommendationService.minimumDaysFor(route: route), 12);

      final sig = signatures(RecommendationService.getDayPlans(route: route));

      // Pokhara sits between the outbound legs: its stay days follow the
      // Kathmandu->Pokhara leg and precede the Pokhara->Mustang leg.
      final iK2P = sig.indexOf('travel Kathmandu->Pokhara');
      final iP2M = sig.indexOf('travel Pokhara->Mustang');
      final pokharaGap = sig.sublist(iK2P + 1, iP2M);
      expect(pokharaGap, hasLength(2));
      expect(pokharaGap.every((s) => !s.startsWith('travel')), isTrue);

      // The return Jomsom stay still lands after its own arrival leg.
      final iK2J = sig.indexOf('travel Kagbeni->Jomsom');
      final iJ2P = sig.indexOf('travel Jomsom->Pokhara');
      expect(sig.sublist(iK2J + 1, iJ2P), hasLength(1));
    });

    test('keeps same-named outbound and return stays as separate blocks', () {
      final route = _route(
        segments: _outbound,
        returnSegments: _customReturn,
        stopPlans: const [
          JourneyStopPlan(location: 'Pokhara', explorationDays: 1),
        ],
        returnStopPlans: const [
          JourneyStopPlan(location: 'Pokhara', explorationDays: 2),
        ],
      );

      // Both Pokharas count towards exploration but never merge.
      expect(route.explorationDays, 3);
      expect(route.stopPlans.single.location, 'Pokhara');
      expect(route.returnStopPlans.single.location, 'Pokhara');

      final sig = signatures(RecommendationService.getDayPlans(route: route));

      // Outbound Pokhara: 1 day between Kathmandu->Pokhara and
      // Pokhara->Mustang.
      final iK2P = sig.indexOf('travel Kathmandu->Pokhara');
      final iP2M = sig.indexOf('travel Pokhara->Mustang');
      expect(sig.sublist(iK2P + 1, iP2M), hasLength(1));

      // Return Pokhara: 2 days between Jomsom->Pokhara and
      // Pokhara->Kathmandu — separate from the outbound block.
      final iJ2P = sig.indexOf('travel Jomsom->Pokhara');
      final iP2K = sig.indexOf('travel Pokhara->Kathmandu');
      expect(sig.sublist(iJ2P + 1, iP2K), hasLength(2));

      // The two blocks are chronologically ordered (outbound first).
      expect(iK2P, lessThan(iP2M));
      expect(iP2M, lessThan(iJ2P));
    });

    test('derives the automatic reversed return for duration calculations', () {
      // A round trip without explicit return legs falls back to the automatic
      // reversed route; minimumDaysFor must still resolve it.
      final automatic = _route(segments: _outbound);

      expect(automatic.isRoundTrip, isTrue);
      expect(automatic.returnSegments, isNotEmpty);
      expect(automatic.completeSegments.length, 4);

      // 2 outbound travel + 3 Mustang visit + 2 automatic return travel.
      expect(RecommendationService.minimumDaysFor(route: automatic), 7);
    });
  });
}
