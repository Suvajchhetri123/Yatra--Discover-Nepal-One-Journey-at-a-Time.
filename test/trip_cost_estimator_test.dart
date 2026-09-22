import 'package:flutter_test/flutter_test.dart';
import 'package:yatra/models/package_model.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/trip_cost_estimator.dart';

void main() {
  TravelRoute makeRoute({
    String boardingPoint = 'Kathmandu',
    String destination = 'Kathmandu',
    TripDirection direction = TripDirection.oneWay,
    List<RouteSegment> segments = const [],
  }) {
    return TravelRoute(
      boardingPoint: boardingPoint,
      destination: destination,
      segments: segments,
      tripDirection: direction,
    );
  }

  TripCostEstimate estimate({
    String touristType = 'Domestic Tourist',
    String destination = 'Kathmandu',
    int durationDays = 4,
    int adultCount = 2,
    int childCount = 0,
    List<int> childAges = const [],
    TravelRoute? route,
    TourPackage? package,
  }) {
    return TripCostEstimator.estimate(
      touristType: touristType,
      destination: destination,
      durationDays: durationDays,
      adultCount: adultCount,
      childCount: childCount,
      childAges: childAges,
      route: route ?? makeRoute(),
      package: package,
    );
  }

  // Expected numbers for Kathmandu, 4 days, 2 adults, no route transit:
  //   stay      = 2500 * 1.35 * 4 * 2 = 27,000
  //   activity  = 800 * 4             =  3,200
  //   transport = baseline 4000
  //   total     = 34,200
  test('estimate computes stay, activity, and baseline transport', () {
    final result = estimate();

    expect(result.stay, 27000);
    expect(result.activity, 3200);
    expect(result.transport, 4000);
    expect(result.total, 34200);
    expect(result.recommended, result.total);
  });

  test('per-leg transport modes are summed from the route', () {
    final result = estimate(
      route: makeRoute(
        destination: 'Mustang',
        segments: const [
          RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
          RouteSegment(from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
        ],
      ),
      destination: 'Mustang',
    );

    // Bus 1500 + Jeep 3200.
    expect(result.transport, 4700);
  });

  test('round trip route counts both outgoing and return legs', () {
    final result = estimate(
      route: makeRoute(
        destination: 'Mustang',
        direction: TripDirection.roundTrip,
        segments: const [
          RouteSegment(
            from: 'Kathmandu',
            to: 'Mustang',
            transportation: 'Flight',
          ),
        ],
      ),
      destination: 'Mustang',
    );

    // Explicit return segment plus derived automatic reverse of the outgoing
    // leg are included in completeSegments.
    expect(result.transport >= 9000, isTrue);
  });

  test(
    'children cost less than adults so a family of 3 equals 1.5 stay budget',
    () {
      final soloAdult = estimate(
        adultCount: 1,
        childCount: 0,
      ).stay; // 2500 * 1.35 * 4 = 13,500.

      final adultPlusChild = estimate(
        adultCount: 1,
        childCount: 1,
        childAges: const [6],
      );

      // 1 adult (factor 1.0) + 1 child aged 6 (factor 0.5) = 1.5 units.
      expect(adultPlusChild.stay, closeTo(soloAdult * 1.5, 1));

      // Toddlers are cheaper still: age 3 uses the 0.30 factor.
      final adultPlusToddler = estimate(
        adultCount: 1,
        childCount: 1,
        childAges: const [3],
      );

      expect(adultPlusToddler.stay, closeTo(soloAdult * 1.3, 1));
    },
  );

  test('package price replaces stay cost in the total', () {
    final package = TourPackage(
      id: 'PKG-1',
      title: 'Everest Base Camp Trek',
      region: 'Everest',
      summary: 'Reach base camp',
      description: 'Full trek',
      durationDays: 12,
      price: 80000,
      difficulty: 'Challenging',
      rating: 4.8,
      imageUrl: '',
      highlights: const ['Base camp'],
      includedPlaces: const ['Lukla', 'Namche Bazaar'],
    );

    final result = estimate(
      destination: 'Everest',
      durationDays: 12,
      adultCount: 1,
      route: makeRoute(destination: 'Everest'),
      package: package,
    );

    // Everest baseline transport (no legs) is 9000.
    expect(result.transport, 9000);
    expect(result.packagePrice, 80000);
    // total = transport + package + activity.
    expect(result.total, 9000 + 80000 + 800 * 12);
  });

  test('evaluateBudget returns insufficient, suitable, and excessive', () {
    final result = estimate();

    expect(
      TripCostEstimator.evaluateBudget(
        budgetNpr: result.total - 1,
        estimate: result,
      ),
      BudgetVerdict.insufficient,
    );

    expect(
      TripCostEstimator.evaluateBudget(
        budgetNpr: result.total,
        estimate: result,
      ),
      BudgetVerdict.suitable,
    );

    expect(
      TripCostEstimator.evaluateBudget(
        budgetNpr: result.total * 2,
        estimate: result,
      ),
      BudgetVerdict.excessive,
    );
  });

  test('currency conversion is applied and never mutates the estimate', () {
    final result = estimate();

    // 100 USD = 13,300 NPR.
    expect(TripCostEstimator.toNpr(100, 'USD'), 13300);
    expect(TripCostEstimator.toNpr(5000, 'NPR'), 5000);

    // 350 USD = 46,550 NPR. The 34,200 estimate fits inside it but stays
    // under the 1.5x "excessive" threshold (51,300).
    final budgetNpr = TripCostEstimator.toNpr(350, 'USD');
    expect(budgetNpr, 46550);

    expect(
      TripCostEstimator.evaluateBudget(budgetNpr: budgetNpr, estimate: result),
      BudgetVerdict.suitable,
    );
  });

  test('verdict messages surface the shortfall or spare amount', () {
    final result = estimate();

    final insufficient = TripCostEstimator.verdictMessage(
      verdict: BudgetVerdict.insufficient,
      budgetNpr: result.total - 1000,
      estimate: result,
      currency: 'NPR',
      adultCount: 2,
      childCount: 0,
    );

    expect(insufficient, contains('not enough'));
    expect(insufficient, contains('short'));

    final excessive = TripCostEstimator.verdictMessage(
      verdict: BudgetVerdict.excessive,
      budgetNpr: result.total * 2,
      estimate: result,
      currency: 'NPR',
      adultCount: 2,
      childCount: 0,
    );

    expect(excessive, contains('exceeds'));
  });

  test('formatting helpers group digits and label the currency', () {
    expect(TripCostEstimator.formatNprAmount(1234567), 'NPR 1,234,567');
    expect(TripCostEstimator.formatInCurrency(13300, 'USD'), 'USD 100');
  });
}
