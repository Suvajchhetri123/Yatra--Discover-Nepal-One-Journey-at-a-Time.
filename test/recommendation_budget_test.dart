import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/journey_stop_plan.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/recommendation_service.dart';
import 'package:yatra/services/trip_cost_estimator.dart';

TravelRoute _mustangRoute({List<JourneyStopPlan> stopPlans = const []}) {
  return TravelRoute(
    boardingPoint: 'Kathmandu',
    destination: 'Mustang',
    segments: const [
      RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
      RouteSegment(from: 'Pokhara', to: 'Jomsom', transportation: 'Jeep'),
      RouteSegment(from: 'Jomsom', to: 'Mustang', transportation: 'Jeep'),
    ],
    tripDirection: TripDirection.oneWay,
    stopPlans: stopPlans,
  );
}

RecommendationResult _generate({
  required TravelRoute route,
  required int duration,
  double budget = 500000,
}) {
  return RecommendationService.generate(
    touristType: 'Domestic Tourist',
    destination: route.destination,
    season: 'Autumn',
    suitability: 'Suitable',
    budget: budget,
    currency: 'NPR',
    ages: const [30],
    travelType: 'Solo',
    groupSize: 1,
    duration: duration,
    route: route,
  );
}

void main() {
  test('minimumDaysFor grows with bootstrapped exploration days', () {
    final withoutStops = _mustangRoute();

    final withStops = _mustangRoute(
      stopPlans: const [
        JourneyStopPlan(location: 'Jomsom', explorationDays: 2),
      ],
    );

    expect(
      RecommendationService.minimumDaysFor(route: withoutStops),
      5, // 3 travel days + 2 Mustang visit days.
    );

    expect(
      RecommendationService.minimumDaysFor(route: withStops),
      7, // +2 Jomsom exploration days.
    );
  });

  test('stop-plan days appear in the generated itinerary', () {
    final route = _mustangRoute(
      stopPlans: const [
        JourneyStopPlan(location: 'Jomsom', explorationDays: 2),
      ],
    );

    // Duration above the minimum (7) still yields the core 7-day itinerary;
    // the 2 Jomsom exploration days are allocated inside it.
    final result = _generate(route: route, duration: 9);

    expect(result.minimumDays, 7);
    expect(result.dayPlans.length, 7);

    final stopDayItems = result.dayPlans.expand((plan) => plan.items);
    final jomsomDays = stopDayItems.where((item) {
      return item.type == DayPlanItemType.activity &&
          (item.activity ?? '').contains('Jomsom');
    });

    expect(jomsomDays.length, 2);
  });

  test('recommendation exposes budget verdict and cost estimate', () {
    final route = _mustangRoute();
    final result = _generate(route: route, duration: 7, budget: 5000);

    expect(result.budgetIsLow, isTrue);
    expect(result.budgetVerdict, BudgetVerdict.insufficient);
    expect(result.tripCostEstimate.total, greaterThan(5000));
    expect(result.budgetMessage, contains('not enough'));

    final comfortable = _generate(route: route, duration: 7, budget: 1000000);
    expect(comfortable.budgetVerdict, isNot(BudgetVerdict.insufficient));
  });

  test(
    'stop plans survive longer durations without losing the core routine',
    () {
      final route = _mustangRoute(
        stopPlans: const [
          JourneyStopPlan(location: 'Jomsom', explorationDays: 3),
        ],
      );

      for (int duration = 8; duration <= 12; duration++) {
        final result = _generate(route: route, duration: duration);

        // The detailed itinerary always reflects the recommended core
        // journey (min days), never collapsing or over-expanding.
        expect(result.dayPlans.length, 8);

        final stopDayItems = result.dayPlans.expand((plan) => plan.items);
        final jomsomDays = stopDayItems.where((item) {
          return item.type == DayPlanItemType.activity &&
              (item.activity ?? '').contains('Jomsom');
        });

        expect(jomsomDays.length, 3);
      }
    },
  );
}
