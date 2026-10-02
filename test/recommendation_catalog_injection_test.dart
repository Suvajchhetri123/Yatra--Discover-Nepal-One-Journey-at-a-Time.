import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/places_data.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/recommendation_service.dart';

const TravelRoute _route = TravelRoute(
  boardingPoint: 'Kathmandu',
  destination: 'Kathmandu',
  segments: [],
  tripDirection: TripDirection.oneWay,
);

/// Regression guard for the recommendation algorithm's catalog contract.
///
/// `RecommendationService` no longer imports `places_data.dart`. It receives
/// the catalog from its caller, so the same input must always produce the same
/// output, and an empty catalog must degrade gracefully instead of throwing.
void main() {
  group('RecommendationService catalog injection', () {
    test('produces identical results for identical catalog input', () {
      final first = RecommendationService.generate(
        places: nepalPlaces,
        touristType: 'Domestic Tourist',
        destination: 'Kathmandu',
        season: 'Winter',
        suitability: 'Cultural',
        budget: 50000,
        currency: 'NPR',
        ages: const [28],
        travelType: 'Solo',
        groupSize: 1,
        adultCount: 1,
        childCount: 0,
        duration: 7,
        route: _route,
      );

      final second = RecommendationService.generate(
        places: nepalPlaces,
        touristType: 'Domestic Tourist',
        destination: 'Kathmandu',
        season: 'Winter',
        suitability: 'Cultural',
        budget: 50000,
        currency: 'NPR',
        ages: const [28],
        travelType: 'Solo',
        groupSize: 1,
        adultCount: 1,
        childCount: 0,
        duration: 7,
        route: _route,
      );

      expect(second.minimumDays, first.minimumDays);
      expect(second.maximumDays, first.maximumDays);
      expect(second.tripCostEstimate.minimum, first.tripCostEstimate.minimum);
      expect(
        second.tripCostEstimate.recommended,
        first.tripCostEstimate.recommended,
      );
      expect(
        second.tripCostEstimate.transport,
        first.tripCostEstimate.transport,
      );
      expect(second.tripCostEstimate.stay, first.tripCostEstimate.stay);
      expect(second.tripCostEstimate.activity, first.tripCostEstimate.activity);
      expect(
        second.tripCostEstimate.packagePrice,
        first.tripCostEstimate.packagePrice,
      );
      expect(second.tripCostEstimate.total, first.tripCostEstimate.total);
      expect(second.dayPlans.length, first.dayPlans.length);
      expect(second.suggestedPlaces, first.suggestedPlaces);
      expect(second.routeDestinations, first.routeDestinations);
    });

    test('suggests attractions only from the supplied catalog', () {
      final onlyPokhara = nepalPlaces
          .where((place) => place.location == 'Pokhara')
          .toList();

      final result = RecommendationService.generate(
        places: onlyPokhara,
        touristType: 'Domestic Tourist',
        destination: 'Kathmandu',
        season: 'Winter',
        suitability: 'Cultural',
        budget: 50000,
        currency: 'NPR',
        ages: const [28],
        travelType: 'Solo',
        groupSize: 1,
        adultCount: 1,
        childCount: 0,
        duration: 7,
        route: _route,
      );

      final allowed = onlyPokhara.map((place) => place.name).toSet();

      for (final suggested in result.suggestedPlaces) {
        expect(allowed, contains(suggested));
      }
    });

    test(
      'omitting the catalog yields no attractions but a valid itinerary',
      () {
        final result = RecommendationService.generate(
          touristType: 'Domestic Tourist',
          destination: 'Kathmandu',
          season: 'Winter',
          suitability: 'Cultural',
          budget: 50000,
          currency: 'NPR',
          ages: const [28],
          travelType: 'Solo',
          groupSize: 1,
          adultCount: 1,
          childCount: 0,
          duration: 7,
          route: _route,
        );

        expect(result.suggestedPlaces, isEmpty);
        expect(result.dayPlans, isNotEmpty);
        expect(result.minimumDays, greaterThan(0));
      },
    );

    test('wrappers accept and forward the catalog', () {
      expect(
        RecommendationService.minimumDaysFor(route: _route),
        greaterThan(0),
      );

      final plans = RecommendationService.getDayPlans(
        route: _route,
        places: nepalPlaces,
      );

      expect(plans, isNotEmpty);
      expect(
        RecommendationService.getRecommendedTime(route: _route),
        isNotEmpty,
      );
    });
  });
}
