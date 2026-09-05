import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/recommendation_service.dart';

TravelRoute _mustangRoute() {
  return const TravelRoute(
    boardingPoint: 'Kathmandu',
    destination: 'Mustang',
    segments: [
      RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
      RouteSegment(from: 'Pokhara', to: 'Jomsom', transportation: 'Jeep'),
      RouteSegment(from: 'Jomsom', to: 'Kagbeni', transportation: 'Jeep'),
      RouteSegment(from: 'Kagbeni', to: 'Mustang', transportation: 'Jeep'),
    ],
    tripDirection: TripDirection.oneWay,
  );
}

RecommendationResult _generate(int duration) {
  return RecommendationService.generate(
    destination: 'Mustang',
    season: 'Autumn',
    suitability: 'Suitable',
    budget: 5000,
    currency: 'NPR',
    ages: const [30],
    travelType: 'Solo',
    groupSize: 1,
    duration: duration,
    route: _mustangRoute(),
  );
}

void main() {
  test('itinerary contains exactly the selected number of days (6)', () {
    final result = _generate(6);

    expect(result.dayPlans.length, 6);
    expect(result.dayPlans.map((d) => d.day), [1, 2, 3, 4, 5, 6]);
  });

  test('itinerary contains exactly the selected number of days (7)', () {
    final result = _generate(7);

    expect(result.dayPlans.length, 7);
    expect(result.dayPlans.map((d) => d.day), [1, 2, 3, 4, 5, 6, 7]);
  });

  test('itinerary never exceeds the selected duration for any trip length',
      () {
    for (int duration = 1; duration <= 14; duration++) {
      final result = _generate(duration);

      expect(result.dayPlans.length, duration,
          reason: 'generated ${result.dayPlans.length} days '
              'for a $duration-day trip');
      expect(result.dayPlans.first.day, 1);
      expect(result.dayPlans.last.day, duration);
    }
  });

  test('continuous current-location logic is preserved (KTM -> Pokhara, 4d)',
      () {
    const route = TravelRoute(
      boardingPoint: 'Kathmandu',
      destination: 'Pokhara',
      segments: [
        RouteSegment(
          from: 'Kathmandu',
          to: 'Pokhara',
          transportation: 'Tourist Bus',
        ),
      ],
      tripDirection: TripDirection.oneWay,
    );

    final result = RecommendationService.generate(
      destination: 'Pokhara',
      season: 'Autumn',
      suitability: 'Suitable',
      budget: 5000,
      currency: 'NPR',
      ages: const [30],
      travelType: 'Solo',
      groupSize: 1,
      duration: 4,
      route: route,
    );

    expect(result.dayPlans.length, 4);
    expect(result.dayPlans[0].items.first.title, 'Kathmandu → Pokhara');
    expect(result.dayPlans[0].items.first.subtitle, 'Tourist Bus');
    expect(result.dayPlans[3].items.first.title, 'Pokhara → Kathmandu');
  });
}