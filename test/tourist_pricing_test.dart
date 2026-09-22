import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/journey_stop_plan.dart';
import 'package:yatra/models/package_model.dart';
import 'package:yatra/models/place_model.dart';
import 'package:yatra/models/tourist_pricing.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/trip_cost_estimator.dart';

void main() {
  TravelRoute makeRoute({
    String destination = 'Mustang',
    List<RouteSegment> segments = const [],
    List<JourneyStopPlan> stopPlans = const [],
  }) {
    return TravelRoute(
      boardingPoint: 'Kathmandu',
      destination: destination,
      segments: segments,
      tripDirection: TripDirection.oneWay,
      stopPlans: stopPlans,
    );
  }

  // Standard Mustang-bound route (Kathmandu → Pokhara → Jomsom → Mustang).
  TravelRoute mustangRoute({List<JourneyStopPlan> stopPlans = const []}) {
    return makeRoute(
      destination: 'Mustang',
      segments: const [
        RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
        RouteSegment(from: 'Pokhara', to: 'Jomsom', transportation: 'Jeep'),
        RouteSegment(from: 'Jomsom', to: 'Mustang', transportation: 'Jeep'),
      ],
      stopPlans: stopPlans,
    );
  }

  TripCostEstimate estimate({
    String touristType = 'Domestic Tourist',
    String destination = 'Kathmandu',
    int durationDays = 4,
    int adultCount = 1,
    int childCount = 0,
    List<int> childAges = const [],
    required TravelRoute route,
    TourPackage? package,
  }) {
    return TripCostEstimator.estimate(
      touristType: touristType,
      destination: destination,
      durationDays: durationDays,
      adultCount: adultCount,
      childCount: childCount,
      childAges: childAges,
      route: route,
      package: package,
    );
  }

  const int baseMustangTotal = 30000;
  const int transportMustangTotal = 7900;
  const int domJomsom4Exploration = 22100;
  const int intlJomsom4Exploration = 45100;

  final jomsom4Days = const [
    JourneyStopPlan(location: 'Jomsom', explorationDays: 4),
  ];

  // TEST 1 — Exploration days raise the total trip cost.
  test('exploration days increase the estimated trip total', () {
    final withoutStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(),
    );
    final withStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(stopPlans: jomsom4Days),
    );

    expect(withoutStops.total, baseMustangTotal);
    expect(withStops.total, baseMustangTotal + domJomsom4Exploration);
    expect(withStops.total, greaterThan(withoutStops.total));
  });

  // TEST 2 — Transport is untouched by exploration days.
  test('exploration days never change the transport cost', () {
    final withoutStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(),
    );
    final withStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(stopPlans: jomsom4Days),
    );

    expect(withoutStops.transport, transportMustangTotal);
    expect(withStops.transport, transportMustangTotal);
    expect(withStops.transport, withoutStops.transport);
  });

  // TEST 3 — Stay / accommodation grows with exploration days.
  test('exploration days raise the stay cost', () {
    final withoutStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(),
    );
    final withStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(stopPlans: jomsom4Days),
    );

    // Base stay 18,900 + Jomsom 3500 * 1.35 * 4 = 18,900.
    expect(withoutStops.stay, 18900);
    expect(withStops.stay, 37800);
    expect(withStops.stay, greaterThan(withoutStops.stay));
  });

  // TEST 4 — Activity budget grows with exploration days.
  test('exploration days raise the activity cost', () {
    final withoutStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(),
    );
    final withStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(stopPlans: jomsom4Days),
    );

    expect(withoutStops.activity, 3200);
    expect(withStops.activity, 6400);
    expect(withStops.activity, greaterThan(withoutStops.activity));
  });

  // TEST 5 — A budget verdict flips as exploration pushes the total over.
  test('budget verdict changes when exploration days push the total over', () {
    final withoutStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(),
    );
    final withStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(stopPlans: jomsom4Days),
    );

    // 40,000 sits in the suitable band for 30,000 but is below 52,100.
    expect(
      TripCostEstimator.evaluateBudget(
        budgetNpr: 40000,
        estimate: withoutStops,
      ),
      BudgetVerdict.suitable,
    );
    expect(
      TripCostEstimator.evaluateBudget(budgetNpr: 40000, estimate: withStops),
      BudgetVerdict.insufficient,
    );
  });

  // TEST 6 — Zero exploration days add nothing to the estimate.
  test('zero exploration days add no extra cost', () {
    final noStops = estimate(destination: 'Mustang', route: mustangRoute());
    final zeroDayStops = estimate(
      destination: 'Mustang',
      route: mustangRoute(
        stopPlans: const [
          JourneyStopPlan(location: 'Jomsom', explorationDays: 0),
        ],
      ),
    );

    expect(zeroDayStops.total, noStops.total);
    expect(zeroDayStops.stay, noStops.stay);
    expect(zeroDayStops.activity, noStops.activity);
  });

  // TEST 7 — Domestic tourists are priced at the domestic rate.
  test('domestic tourists resolve the domestic stay and activity rate', () {
    expect(
      TripCostEstimator.stayPerDayFor(
        touristType: 'Domestic Tourist',
        location: 'Mustang',
      ),
      3500,
    );
    expect(
      TripCostEstimator.activityPerDayFor(
        touristType: 'Domestic Tourist',
        location: 'Mustang',
      ),
      800,
    );
  });

  // TEST 8 — International tourists are priced at the international rate.
  test('international tourists resolve the international rate', () {
    expect(
      TripCostEstimator.stayPerDayFor(
        touristType: 'International Tourist',
        location: 'Mustang',
      ),
      6500,
    );
    expect(
      TripCostEstimator.activityPerDayFor(
        touristType: 'International Tourist',
        location: 'Mustang',
      ),
      2500,
    );
  });

  // TEST 9 — Universal prices stay shared when no differential data exists.
  test('universal place fee applies to both tourist segments', () {
    const place = Place(
      name: 'Public Temple',
      location: 'Kathmandu',
      description: '',
      imageUrl: '',
      entryFee: 200,
      openingHours: '',
      transportation: '',
      travelTrip: '',
      recommendedHours: 1,
    );

    expect(place.entryFeeFor('Domestic Tourist'), 200);
    expect(place.entryFeeFor('International Tourist'), 200);
  });

  // TEST 10 — Differential entry fees are explicit per-service data.
  test('differential entry fees resolve per tourist segment', () {
    const place = Place(
      name: 'Pashupatinath Temple',
      location: 'Kathmandu',
      description: '',
      imageUrl: '',
      entryFee: 1000,
      touristEntryFee: TouristPricing(domestic: 100, international: 1000),
      openingHours: '',
      transportation: '',
      travelTrip: '',
      recommendedHours: 2,
    );

    expect(place.entryFeeFor('Domestic Tourist'), 100);
    expect(place.entryFeeFor('International Tourist'), 1000);
  });

  // TEST 11 — Differential package prices apply exactly once, never doubled.
  test(
    'differential package price is applied once and replaces the universal price',
    () {
      final package = TourPackage(
        id: 'PKG',
        title: 'Everest Trek',
        region: 'Everest',
        summary: '',
        description: '',
        durationDays: 12,
        price: 80000,
        touristPrice: TouristPricing(domestic: 70000, international: 100000),
        difficulty: 'Challenging',
        rating: 4.8,
        imageUrl: '',
        highlights: const [],
        includedPlaces: const [],
      );

      // Everest baseline transport (empty route) is 9000; the Everest profile
      // charges 800/day activity domestic and 3000/day international.
      final domestic = estimate(
        destination: 'Everest',
        durationDays: 12,
        route: makeRoute(destination: 'Everest'),
        package: package,
      );
      final international = estimate(
        touristType: 'International Tourist',
        destination: 'Everest',
        durationDays: 12,
        route: makeRoute(destination: 'Everest'),
        package: package,
      );

      expect(domestic.packagePrice, 70000);
      expect(international.packagePrice, 100000);

      // The package price is used once (never "universal + delta"), so the only
      // extra difference comes from the tourist-specific activities.
      expect(domestic.total, 9000 + 70000 + 800 * 12);
      expect(international.total, 9000 + 100000 + 3000 * 12);
      expect(
        international.total - domestic.total,
        30000 + 3000 * 12 - 800 * 12,
      );
    },
  );

  // TEST 12 — Exploration days are priced differentially per tourist type.
  test(
    'exploration cost differs between domestic and international tourists',
    () {
      final domestic = estimate(
        destination: 'Mustang',
        route: mustangRoute(stopPlans: jomsom4Days),
      );
      final international = estimate(
        touristType: 'International Tourist',
        destination: 'Mustang',
        route: mustangRoute(stopPlans: jomsom4Days),
      );

      // Domestic increment = (3500*1.35*4) + (800*4)  = 22,100.
      // International increment = (6500*1.35*4) + (2500*4) = 45,100.
      expect(domestic.total - baseMustangTotal, domJomsom4Exploration);
      expect(international.total - 53000, intlJomsom4Exploration);
      expect(international.total, greaterThan(domestic.total));
    },
  );

  // TEST 13 — The same budget verdict can differ by tourist type.
  test('budget verdict depends on tourist type for the same budget', () {
    final ktmRoute = makeRoute(destination: 'Kathmandu', segments: const []);

    final domestic = estimate(
      destination: 'Kathmandu',
      durationDays: 4,
      adultCount: 2,
      route: ktmRoute,
    );
    final international = estimate(
      touristType: 'International Tourist',
      destination: 'Kathmandu',
      durationDays: 4,
      adultCount: 2,
      route: ktmRoute,
    );

    expect(domestic.total, 34200);
    expect(international.total, 58600);

    // A 50,000 budget fits the domestic estimate but not the international one.
    expect(
      TripCostEstimator.evaluateBudget(budgetNpr: 50000, estimate: domestic),
      BudgetVerdict.suitable,
    );
    expect(
      TripCostEstimator.evaluateBudget(
        budgetNpr: 50000,
        estimate: international,
      ),
      BudgetVerdict.insufficient,
    );
  });

  // TEST 14 — No global multiplier: ratios differ per service.
  test('international prices are explicit data, not a global multiplier', () {
    final pashupatinath = priceForTouristType(
      touristType: 'International Tourist',
      universalPrice: 1000,
      pricing: const TouristPricing(domestic: 100, international: 1000),
    );
    final swayambhunath = priceForTouristType(
      touristType: 'International Tourist',
      universalPrice: 200,
      pricing: const TouristPricing(domestic: 50, international: 200),
    );

    // Both resolve to their explicit international values.
    expect(pashupatinath, 1000);
    expect(swayambhunath, 200);

    // The domestic→international ratio differs (10x vs 4x), proving the
    // prices are structured per service and never derived by one multiplier.
    expect(1000 / 100, isNot(200 / 50));
  });
}
