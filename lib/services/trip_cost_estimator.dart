import '../data/destination_cost_profiles.dart';
import '../models/package_model.dart';
import '../models/tourist_pricing.dart';
import '../models/travel_route_model.dart';

// ============================================================
// BUDGET VERDICT
// ============================================================

enum BudgetVerdict { insufficient, suitable, excessive }

// ============================================================
// TRIP COST ESTIMATE
// ============================================================

class TripCostEstimate {
  /// Minimum realistic NPR cost for this trip (no frills).
  final double minimum;

  /// Comfortable / recommended NPR cost for this trip.
  final double recommended;

  /// Total transport cost across all outbound + return legs.
  final double transport;

  /// Total accommodation / stay cost across all days.
  final double stay;

  /// Total activity budget.
  final double activity;

  /// Package price if a TourPackage is attached (NPR).
  final double packagePrice;

  /// Final total used for the budget verdict comparison.
  /// When a package price is present this equals
  /// [transport] + [packagePrice] + [activity].
  /// Otherwise it equals [recommended].
  final double total;

  const TripCostEstimate({
    required this.minimum,
    required this.recommended,
    required this.transport,
    required this.stay,
    required this.activity,
    required this.packagePrice,
    required this.total,
  });
}

// ============================================================
// ESTIMATOR
// ============================================================

class TripCostEstimator {
  TripCostEstimator._();

  // ==========================================================
  // CURRENCY
  // ==========================================================

  static const Map<String, double> _exchangeRates = {
    'NPR': 1,
    'USD': 133,
    'INR': 1.6,
    'EUR': 145,
    'GBP': 168,
  };

  /// Convert an amount in [currency] to NPR.
  static double toNpr(double amount, String currency) {
    final rate = _exchangeRates[currency] ?? 1;
    return amount * rate;
  }

  /// Format an NPR amount with thousands separators.
  /// e.g. `12345` → `'NPR 12,345'`.
  ///
  /// Named distinctly from `formatNpr` (package_model.dart) so both helpers
  /// can be imported together without a symbol collision.
  static String formatNprAmount(double amount) {
    final digits = amount.toStringAsFixed(0);
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    return 'NPR ${buffer.toString()}';
  }

  /// Format an NPR amount in the user's [currency] with thousands separators.
  ///
  /// The result is approximate and for display only — it never feeds back
  /// into business logic.
  static String formatInCurrency(double nprAmount, String currency) {
    final rate = _exchangeRates[currency];
    final converted = rate != null && rate > 0 ? nprAmount / rate : nprAmount;
    final digits = converted.toStringAsFixed(0);
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    return '$currency ${buffer.toString()}';
  }

  // ==========================================================
  // DAILY BASE RATES (NPR / adult / day)
  // ==========================================================

  /// Daily accommodation rate that applies to [touristType] at [location].
  ///
  /// Structured per-destination, per-segment data; never a global
  /// domestic→international multiplier.
  static double stayPerDayFor({
    required String touristType,
    required String location,
  }) {
    final profile = destinationCostProfileFor(location);
    return priceForTouristType(
      touristType: touristType,
      universalPrice: profile.stayPerDay,
      pricing: profile.stayPricing,
    );
  }

  /// Daily activity budget that applies to [touristType] at [location].
  static double activityPerDayFor({
    required String touristType,
    required String location,
  }) {
    final profile = destinationCostProfileFor(location);
    return priceForTouristType(
      touristType: touristType,
      universalPrice: profile.activityPerDay,
      pricing: profile.activityPricing,
    );
  }

  static const double _recommendedMultiplier = 1.35;

  // ==========================================================
  // TRANSPORT COST PER LEG
  // ==========================================================

  static double transportCostForMode(String mode) {
    final m = mode.toLowerCase();

    if (m.contains('flight') || m.contains('air')) return 9000;
    if (m.contains('jeep')) return 3200;
    if (m.contains('private vehicle') ||
        m.contains('car') ||
        m.contains('taxi') ||
        m.contains('local bus')) {
      return 2000;
    }
    if (m.contains('motorbike') || m.contains('motor')) return 1300;
    if (m.contains('bus')) return 1500;
    if (m.contains('trek') || m.contains('walk')) return 0;

    return 2000;
  }

  /// Baseline transport cost when the route has no explicit legs (e.g. a
  /// local exploration or destination-only flow where the transport leg is
  /// implicit).
  static double _baselineTransport(String destination) {
    final d = destination.toLowerCase();

    if (d.contains('everest')) return 9000;
    if (d.contains('mustang') || d.contains('annapurna')) return 8000;
    if (d.contains('chitwan')) return 5000;

    return 4000;
  }

  // ==========================================================
  // TRANSPORT TOTAL
  // ==========================================================

  static double _totalTransport(TravelRoute route) {
    final allSegments = route.completeSegments;

    if (allSegments.isEmpty) {
      return _baselineTransport(route.destination);
    }

    double total = 0;

    for (final segment in allSegments) {
      total += transportCostForMode(segment.transportation);
    }

    return total;
  }

  // ==========================================================
  // CHILD AGES
  // ==========================================================

  /// Extract child ages from the full ages list.
  ///
  /// Screen flows store adult ages first and child ages after them. When
  /// [childCount] is available, the last [childCount] ages are the children's.
  static List<int> childAgesFrom({
    required List<int> ages,
    required int adultCount,
    required int childCount,
  }) {
    if (childCount <= 0 || ages.isEmpty) {
      return const [];
    }

    final int startIndex = adultCount < 0
        ? 0
        : (adultCount > ages.length ? ages.length : adultCount);

    return ages.skip(startIndex).where((age) => age >= 1 && age < 18).toList();
  }

  // ==========================================================
  // ESTIMATE
  // ==========================================================

  /// Compute a full trip cost estimate.
  ///
  /// [touristType] selects which structured prices apply (domestic vs
  /// international for stay, activities and the package price).
  ///
  /// When a [package] is supplied the base transport + stay cost is replaced
  /// by the package price, because the package bundles accommodation and
  /// destination transport together.
  ///
  /// [durationDays] is the base journey length. Extra per-stop stay/exploration
  /// days carried on [route.stopPlans] are added on top using each stop's own
  /// rates, so exploring more always raises the stay/activity cost while
  /// transport stays untouched.
  static TripCostEstimate estimate({
    required String touristType,
    required String destination,
    required int durationDays,
    required int adultCount,
    required int childCount,
    required List<int> childAges,
    required TravelRoute route,
    TourPackage? package,
  }) {
    final baseRate = stayPerDayFor(
      touristType: touristType,
      location: destination,
    );
    final activityRate = activityPerDayFor(
      touristType: touristType,
      location: destination,
    );
    final recommendedRate = baseRate * _recommendedMultiplier;

    // --- Transport (unchanged by exploration / stay days) ---
    final transport = _totalTransport(route);

    // --- Child cost factors ---
    // Children ≤ 12 at half rate, 13-17 at 85%, adults at full rate.
    final childCostFactor = _childCostFactor(
      childAges: childAges,
      childCount: childCount,
    );

    // --- Base stay (from the trip duration) ---
    final adultStayCost = recommendedRate * durationDays * adultCount;
    final childStayCost = recommendedRate * durationDays * childCostFactor;

    // --- Base activity (flat daily budget, matching traveller count) ---
    final baseActivity = activityRate * durationDays;

    // --- Extra exploration / stay days at route stops ---
    // Each stop uses its own daily rates so a Jomsom visit costs less than an
    // Everest stop, and stays/activities are priced per tourist type. Both
    // outbound stops and stops introduced during a custom return contribute.
    final allStopPlans = [...route.stopPlans, ...route.returnStopPlans];

    double explorationStay = 0;
    double explorationMinimumStay = 0;
    double explorationActivity = 0;

    for (final plan in allStopPlans) {
      final stopRate = stayPerDayFor(
        touristType: touristType,
        location: plan.location,
      );
      final stopActivity = activityPerDayFor(
        touristType: touristType,
        location: plan.location,
      );
      final travellerUnits =
          plan.explorationDays * (adultCount + childCostFactor);

      explorationStay += stopRate * _recommendedMultiplier * travellerUnits;
      explorationMinimumStay += stopRate * travellerUnits;
      explorationActivity += stopActivity * plan.explorationDays;
    }

    final stay = adultStayCost + childStayCost + explorationStay;
    final activity = baseActivity + explorationActivity;

    // --- Package price ---
    final packagePrice = package?.priceFor(touristType) ?? 0;

    // --- Total ---
    final double total;

    if (package != null) {
      // Package bundles accommodation + destination transport.
      // We still include the outbound transport the user travels from
      // home to the package region.
      total = transport + packagePrice + activity;
    } else {
      total = transport + stay + activity;
    }

    // --- Minimum (no-frills) estimate ---
    final minStayCost =
        baseRate * durationDays * adultCount +
        baseRate * durationDays * childCostFactor +
        explorationMinimumStay;
    final minimum = transport + minStayCost;

    return TripCostEstimate(
      minimum: minimum,
      recommended: transport + stay + activity,
      transport: transport,
      stay: stay,
      activity: activity,
      packagePrice: packagePrice,
      total: total,
    );
  }

  // ==========================================================
  // CHILD COST FACTOR
  // ==========================================================

  static double _childCostFactor({
    required List<int> childAges,
    required int childCount,
  }) {
    double factor = 0;

    for (final age in childAges) {
      if (age <= 4) {
        factor += 0.30;
      } else if (age <= 12) {
        factor += 0.50;
      } else {
        factor += 0.85;
      }
    }

    // If stored child ages are incomplete, use a conservative 50% per
    // missing child.
    if (childAges.length < childCount) {
      factor += (childCount - childAges.length) * 0.50;
    }

    return factor;
  }

  // ==========================================================
  // VERDICT
  // ==========================================================

  static const double _excessiveMultiple = 1.5;

  /// Evaluate a budget against a trip cost estimate.
  static BudgetVerdict evaluateBudget({
    required double budgetNpr,
    required TripCostEstimate estimate,
  }) {
    if (budgetNpr < estimate.total) {
      return BudgetVerdict.insufficient;
    }

    if (budgetNpr > estimate.total * _excessiveMultiple) {
      return BudgetVerdict.excessive;
    }

    return BudgetVerdict.suitable;
  }

  /// Short human-readable summary of the verdict.
  static String verdictTitle(BudgetVerdict verdict) {
    switch (verdict) {
      case BudgetVerdict.insufficient:
        return 'Budget Too Low';
      case BudgetVerdict.suitable:
        return 'Budget Sufficient';
      case BudgetVerdict.excessive:
        return 'Budget More Than Enough';
    }
  }

  /// Build a budget verdict message for the recommendation screen.
  static String verdictMessage({
    required BudgetVerdict verdict,
    required double budgetNpr,
    required TripCostEstimate estimate,
    required String currency,
    required int adultCount,
    required int childCount,
  }) {
    final budgetDisplay = formatInCurrency(budgetNpr, currency);
    final totalDisplay = formatNprAmount(estimate.total);

    switch (verdict) {
      case BudgetVerdict.insufficient:
        final shortfall = estimate.total - budgetNpr;
        final shortfallDisplay = formatInCurrency(shortfall, currency);
        return 'Your budget of $budgetDisplay is not enough for this trip. '
            'The estimated total is $totalDisplay. '
            'You are about $shortfallDisplay short. '
            'Consider increasing your budget or reducing optional expenses.';

      case BudgetVerdict.suitable:
        return 'Your budget of $budgetDisplay is suitable for this trip '
            '(estimated $totalDisplay). You have enough for the journey '
            'and the recommended comfort level.';

      case BudgetVerdict.excessive:
        final spare = budgetNpr - estimate.total;
        final spareDisplay = formatInCurrency(spare, currency);
        return 'Your budget of $budgetDisplay exceeds the estimated '
            '$totalDisplay by about $spareDisplay. '
            'You have significant room for upgrades or extra activities.';
    }
  }

  // ==========================================================
  // FINAL BUDGET GATE
  // ==========================================================

  /// True when [budgetNpr] cannot even cover the no-frills minimum cost of
  /// this trip. This is the hard floor the boarding screen enforces before
  /// the itinerary is finalised: below it the trip is not affordable.
  static bool budgetBlocksForTrip({
    required double budgetNpr,
    required TripCostEstimate estimate,
  }) {
    return budgetNpr < estimate.minimum;
  }

  /// How much more budget is needed to cover the no-frills minimum trip cost.
  /// Zero when the budget already covers the minimum.
  static double minimumShortfall({
    required double budgetNpr,
    required TripCostEstimate estimate,
  }) {
    final shortfall = estimate.minimum - budgetNpr;
    return shortfall > 0 ? shortfall : 0;
  }

  /// Message shown on the boarding screen when the budget is below the
  /// no-frills minimum trip cost. The trip cannot continue until the user
  /// raises their budget or adjusts the trip.
  static String minimumShortfallMessage({
    required double budgetNpr,
    required TripCostEstimate estimate,
    required String currency,
  }) {
    final budgetDisplay = formatInCurrency(budgetNpr, currency);
    final minimumDisplay = formatNprAmount(estimate.minimum);
    final shortfallDisplay = formatInCurrency(
      minimumShortfall(budgetNpr: budgetNpr, estimate: estimate),
      currency,
    );

    return 'Your budget is not enough for this trip.\n'
        'Your budget: $budgetDisplay\n'
        'Estimated minimum: $minimumDisplay\n'
        'Additional amount needed: $shortfallDisplay.\n'
        'Increase your budget or adjust your trip.';
  }
}
