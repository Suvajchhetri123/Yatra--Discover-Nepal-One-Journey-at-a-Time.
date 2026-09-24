import '../data/places_data.dart';
import '../models/journey_stop_plan.dart';
import '../models/place_model.dart';
import '../models/travel_route_model.dart';
import 'trip_cost_estimator.dart';

/// Represents one day in the recommended itinerary.
class DayPlan {
  final int day;
  final List<DayPlanItem> items;

  const DayPlan({required this.day, required this.items});

  /// Returns a copy of this plan with the given items, keeping the day number.
  DayPlan replaceItems(List<DayPlanItem> newItems) {
    return DayPlan(day: day, items: List.of(newItems));
  }
}

/// Represents the type of item in a day plan.
enum DayPlanItemType { travel, attraction, activity }

/// Represents one item inside a day.
class DayPlanItem {
  final DayPlanItemType type;

  // Travel information
  final String? from;
  final String? to;
  final String? transportation;

  // Attraction information
  final Place? place;

  // Activity information
  final String? activity;

  /// Optional user-edited title override shown instead of the generated one.
  ///
  /// Set during itinerary editing; an empty/null value falls back to the
  /// generated title so "Reset to Recommended" restores the original text.
  final String? customTitle;

  /// Optional free-text note the tourist can add while editing the itinerary.
  final String? note;

  const DayPlanItem.travel({
    required this.from,
    required this.to,
    required this.transportation,
  }) : type = DayPlanItemType.travel,
       place = null,
       activity = null,
       customTitle = null,
       note = null;

  const DayPlanItem.attraction({
    required this.place,
    this.customTitle,
    this.note,
  }) : type = DayPlanItemType.attraction,
       from = null,
       to = null,
       transportation = null,
       activity = null;

  const DayPlanItem.activity({required this.activity, this.note})
    : type = DayPlanItemType.activity,
      from = null,
      to = null,
      transportation = null,
      place = null,
      customTitle = null;

  /// Returns a copy with editable text fields replaced.
  ///
  /// Travel items are read-only and returned unchanged. An empty title is
  /// stored as null so the generated title is used again.
  DayPlanItem copyWith({String? customTitle, String? note, String? activity}) {
    if (type == DayPlanItemType.travel) {
      return this;
    }

    final trimmedTitle = customTitle?.trim() ?? '';

    if (type == DayPlanItemType.attraction) {
      return DayPlanItem.attraction(
        place: place,
        customTitle: trimmedTitle.isEmpty ? null : trimmedTitle,
        note: note,
      );
    }

    return DayPlanItem.activity(activity: activity?.trim() ?? '', note: note);
  }

  /// Text displayed as the main title in RecommendationScreen.
  String get title {
    final override = customTitle?.trim() ?? '';

    if (override.isNotEmpty) {
      return override;
    }

    if (type == DayPlanItemType.travel) {
      return '$from → $to';
    }

    if (type == DayPlanItemType.activity) {
      return activity ?? 'Activity';
    }

    return place?.name ?? 'Unknown attraction';
  }

  /// Text displayed below the title in RecommendationScreen.
  String? get subtitle {
    if (type == DayPlanItemType.travel) {
      return transportation;
    }

    if (type == DayPlanItemType.activity) {
      return 'Recommended activity';
    }

    if (place == null) {
      return null;
    }

    return place!.location;
  }
}

/// Complete recommendation result.
class RecommendationResult {
  // ============================================================
  // DURATION
  // ============================================================

  final int minimumDays;
  final int maximumDays;
  final String recommendedTime;

  final int travelDays;
  final int visitDays;
  final int returnDays;

  // ============================================================
  // GENERAL RECOMMENDATION
  // ============================================================

  final String title;
  final String summary;

  // ============================================================
  // SUITABILITY
  // ============================================================

  final String overallSuitability;
  final int overallScore;
  final List<String> suitabilityFactors;

  // ============================================================
  // BUDGET
  // ============================================================

  final bool budgetIsLow;
  final String budgetMessage;

  /// Three-tier budget verdict computed by [TripCostEstimator].
  final BudgetVerdict budgetVerdict;

  /// Detailed per-component trip cost estimate.
  final TripCostEstimate tripCostEstimate;

  // ============================================================
  // ROUTE
  // ============================================================

  final List<String> routeDestinations;

  // ============================================================
  // DURATION MESSAGE
  // ============================================================

  final String recommendedDurationTitle;
  final String recommendedDurationMessage;
  final String durationMessage;
  final bool durationIsTooShort;
  final bool durationIsTooLong;

  // ============================================================
  // REMAINING DAYS
  // ============================================================

  final String remainingDaysMessage;
  final List<String> additionalDestinations;

  // ============================================================
  // DAY PLAN
  // ============================================================

  final List<DayPlan> dayPlans;

  // ============================================================
  // OTHER
  // ============================================================

  final List<String> reasons;
  final List<String> suggestedPlaces;

  const RecommendationResult({
    required this.minimumDays,
    required this.maximumDays,
    required this.recommendedTime,
    required this.travelDays,
    required this.visitDays,
    required this.returnDays,
    required this.title,
    required this.summary,
    required this.overallSuitability,
    required this.overallScore,
    required this.suitabilityFactors,
    required this.budgetIsLow,
    required this.budgetMessage,
    required this.budgetVerdict,
    required this.tripCostEstimate,
    required this.routeDestinations,
    required this.recommendedDurationTitle,
    required this.recommendedDurationMessage,
    required this.durationMessage,
    required this.durationIsTooShort,
    required this.durationIsTooLong,
    required this.remainingDaysMessage,
    required this.additionalDestinations,
    required this.dayPlans,
    required this.reasons,
    required this.suggestedPlaces,
  });
}

class RecommendationService {
  // ============================================================
  // CHILD AGE ANALYSIS
  // ============================================================

  /// Gets the ages belonging to children.
  ///
  /// AgeScreen stores adult ages first and child ages after them.
  /// Therefore, when childCount is available, the last childCount
  /// ages are treated as the children's ages.
  static List<int> _getChildAges(
    List<int> ages, {
    int adultCount = 0,
    int childCount = 0,
  }) {
    if (childCount <= 0 || ages.isEmpty) {
      return const [];
    }

    final int startIndex = adultCount.clamp(0, ages.length);

    final List<int> possibleChildAges = ages.skip(startIndex).toList();

    if (possibleChildAges.isEmpty) {
      return const [];
    }

    final int numberOfChildren = childCount.clamp(0, possibleChildAges.length);

    return possibleChildAges
        .take(numberOfChildren)
        .where((age) => age >= 1 && age < 18)
        .toList();
  }

  /// Children aged 1-4.
  static bool _hasVeryYoungChild(
    List<int> ages, {
    int adultCount = 0,
    int childCount = 0,
  }) {
    return _getChildAges(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    ).any((age) => age <= 4);
  }

  /// Children aged 5-8.
  static bool _hasYoungChild(
    List<int> ages, {
    int adultCount = 0,
    int childCount = 0,
  }) {
    return _getChildAges(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    ).any((age) => age >= 5 && age <= 8);
  }

  /// Children aged 9-12.
  static bool _hasOlderChild(
    List<int> ages, {
    int adultCount = 0,
    int childCount = 0,
  }) {
    return _getChildAges(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    ).any((age) => age >= 9 && age <= 12);
  }

  /// Teenagers aged 13-17.
  static bool _hasTeenager(
    List<int> ages, {
    int adultCount = 0,
    int childCount = 0,
  }) {
    return _getChildAges(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    ).any((age) => age >= 13 && age < 18);
  }

  // ============================================================
  // MAIN METHOD
  // ============================================================

  static RecommendationResult generate({
    required String touristType,
    required String destination,
    required String season,
    required String suitability,
    required double budget,
    required String currency,
    required List<int> ages,
    required String travelType,
    required int groupSize,

    /// Number of adults in the travelling group.
    ///
    /// Defaults are kept for compatibility with older calls.
    int adultCount = 1,

    /// Number of children in the travelling group.
    ///
    /// Defaults are kept for compatibility with older calls.
    int childCount = 0,

    /// User's selected calendar duration.
    required int duration,

    required TravelRoute route,
  }) {
    // ==========================================================
    // NORMALIZE GROUP COUNTS
    // ==========================================================

    final int normalizedAdultCount = adultCount < 0 ? 0 : adultCount;

    final int normalizedChildCount = childCount < 0 ? 0 : childCount;

    final List<int> childAges = _getChildAges(
      ages,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
    );

    // ==========================================================
    // 1. OUTBOUND TRAVEL DAYS
    // ==========================================================

    final int travelDays = _calculateOutboundTravelDays(route);

    // ==========================================================
    // 2. DESTINATION VISIT DAYS
    // ==========================================================

    final int visitDays = _calculateVisitDays(
      destination: route.destination,
      isRoundTrip: route.isRoundTrip,
    );

    // ==========================================================
    // 3. RETURN TRAVEL DAYS
    // ==========================================================

    final int returnDays = route.isRoundTrip
        ? _calculateReturnTravelDays(route)
        : 0;

    // ==========================================================
    // 4. ACTUAL ROUTE DURATION
    // ==========================================================

    final int minimumDays =
        travelDays + visitDays + returnDays + route.explorationDays;

    final int maximumDays = minimumDays + 1;

    final String recommendedTime = '$minimumDays-$maximumDays days';

    // ==========================================================
    // 5. DAY-BY-DAY PLAN
    // ==========================================================

    // The detailed itinerary should cover the recommended core journey only.
    // The user's full selected date range is handled separately by the
    // duration/remaining-days logic below. For example, if the user has
    // 38 available days but this route needs only 3 days, dayPlans should
    // contain 3 days and the other 35 days should appear as extra days.
    final List<DayPlan> dayPlans = _generateDayPlans(
      route: route,
      travelDays: travelDays,
      visitDays: visitDays,
      returnDays: returnDays,
      ages: ages,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
      actualJourneyDays: minimumDays,
    );

    // ==========================================================
    // 6. DESTINATION PLACES
    // ==========================================================

    final List<Place> destinationPlaces = _getDestinationPlaces(
      route.destination,
    );

    final List<String> suggestedPlaces = destinationPlaces
        .map((place) => place.name)
        .toList();

    // ==========================================================
    // 7. ROUTE DESTINATIONS
    // ==========================================================

    final List<String> routeDestinations = _getRouteDestinations(route);

    // ==========================================================
    // 8. GENERAL RECOMMENDATION
    // ==========================================================

    final String title = 'Recommended $recommendedTime Trip';

    final String summary = _buildSummary(
      destination: route.destination,
      route: route,
      minimumDays: minimumDays,
      maximumDays: maximumDays,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
      childAges: childAges,
    );

    // ==========================================================
    // 9. SUITABILITY
    // ==========================================================

    final int overallScore = _calculateOverallScore(
      touristType: touristType,
      season: season,
      suitability: suitability,
      ages: ages,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
      travelType: travelType,
      groupSize: groupSize,
      destination: route.destination,
    );

    final String overallSuitability = _getOverallSuitability(overallScore);

    final List<String> suitabilityFactors = _buildSuitabilityFactors(
      touristType: touristType,
      season: season,
      suitability: suitability,
      ages: ages,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
      travelType: travelType,
      groupSize: groupSize,
      destination: route.destination,
    );

    // ==========================================================
    // 10. BUDGET
    // ==========================================================

    // Base journey days exclude the extra per-stop exploration days; those are
    // priced separately from route.stopPlans so they are not double counted.
    final int baseJourneyDays = travelDays + visitDays + returnDays;

    final TripCostEstimate tripCostEstimate = TripCostEstimator.estimate(
      touristType: touristType,
      destination: route.destination,
      durationDays: baseJourneyDays,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
      childAges: childAges,
      route: route,
    );

    final double budgetNpr = TripCostEstimator.toNpr(budget, currency);

    final BudgetVerdict budgetVerdict = TripCostEstimator.evaluateBudget(
      budgetNpr: budgetNpr,
      estimate: tripCostEstimate,
    );

    final bool budgetIsLow = budgetVerdict == BudgetVerdict.insufficient;

    final String budgetMessage = TripCostEstimator.verdictMessage(
      verdict: budgetVerdict,
      budgetNpr: budgetNpr,
      estimate: tripCostEstimate,
      currency: currency,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
    );

    // ==========================================================
    // 11. DURATION STATUS
    // ==========================================================

    final bool durationIsTooShort = duration < minimumDays;

    final bool durationIsTooLong = duration > maximumDays;

    final String recommendedDurationMessage =
        'For ${route.destination}, we recommend '
        '$recommendedTime.';

    final String durationMessage = _buildDurationMessage(
      selectedDuration: duration,
      minimumDays: minimumDays,
      maximumDays: maximumDays,
    );

    final String recommendedDurationTitle = durationIsTooShort
        ? 'Trip Duration Is Too Short'
        : durationIsTooLong
        ? 'You Have Extra Days'
        : 'Recommended Duration';

    // ==========================================================
    // 12. REMAINING DAYS
    // ==========================================================

    final int remainingDays = duration > minimumDays
        ? duration - minimumDays
        : 0;

    final List<String> additionalDestinations = remainingDays > 0
        ? _getAdditionalDestinations(destination: route.destination)
        : [];

    final String remainingDaysMessage = _buildRemainingDaysMessage(
      selectedDuration: duration,
      minimumDays: minimumDays,
      remainingDays: remainingDays,
      destination: route.destination,
    );

    // ==========================================================
    // 13. REASONS
    // ==========================================================

    final List<String> reasons = _buildReasons(
      touristType: touristType,
      destination: route.destination,
      route: route,
      minimumDays: minimumDays,
      maximumDays: maximumDays,
      season: season,
      travelType: travelType,
      ages: ages,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
      childAges: childAges,
    );

    // ==========================================================
    // RETURN RESULT
    // ==========================================================

    return RecommendationResult(
      minimumDays: minimumDays,
      maximumDays: maximumDays,
      recommendedTime: recommendedTime,
      travelDays: travelDays,
      visitDays: visitDays,
      returnDays: returnDays,
      title: title,
      summary: summary,
      overallSuitability: overallSuitability,
      overallScore: overallScore,
      suitabilityFactors: suitabilityFactors,
      budgetIsLow: budgetIsLow,
      budgetMessage: budgetMessage,
      budgetVerdict: budgetVerdict,
      tripCostEstimate: tripCostEstimate,
      routeDestinations: routeDestinations,
      recommendedDurationTitle: recommendedDurationTitle,
      recommendedDurationMessage: recommendedDurationMessage,
      durationMessage: durationMessage,
      durationIsTooShort: durationIsTooShort,
      durationIsTooLong: durationIsTooLong,
      remainingDaysMessage: remainingDaysMessage,
      additionalDestinations: additionalDestinations,
      dayPlans: dayPlans,
      reasons: reasons,
      suggestedPlaces: suggestedPlaces,
    );
  }

  // ============================================================
  // OUTBOUND TRAVEL
  // ============================================================

  static int _calculateOutboundTravelDays(TravelRoute route) {
    if (route.segments.isEmpty) {
      return 0;
    }

    int totalDays = 0;

    for (final segment in route.segments) {
      totalDays += _daysForTransport(
        from: segment.from,
        to: segment.to,
        transportation: segment.transportation,
      );
    }

    return totalDays;
  }

  // ============================================================
  // RETURN TRAVEL
  // ============================================================

  static int _calculateReturnTravelDays(TravelRoute route) {
    if (!route.isRoundTrip || route.returnSegments.isEmpty) {
      return 0;
    }

    int totalDays = 0;

    for (final segment in route.returnSegments) {
      totalDays += _daysForTransport(
        from: segment.from,
        to: segment.to,
        transportation: segment.transportation,
      );
    }

    return totalDays;
  }

  // ============================================================
  // TRANSPORTATION DAYS
  // ============================================================

  static int _daysForTransport({
    required String from,
    required String to,
    required String transportation,
  }) {
    final String transport = transportation.toLowerCase().trim();

    if (transport.contains('flight') || transport.contains('air')) {
      return 1;
    }

    if (transport.contains('motorbike') ||
        transport.contains('motor bike') ||
        transport.contains('motorcycle')) {
      return 1;
    }

    if (transport.contains('bike') && !transport.contains('motorbike')) {
      return 1;
    }

    if (transport.contains('bus') ||
        transport.contains('jeep') ||
        transport.contains('car') ||
        transport.contains('taxi') ||
        transport.contains('vehicle')) {
      return 1;
    }

    if (transport.contains('trek') ||
        transport.contains('hike') ||
        transport.contains('walking') ||
        transport.contains('walk')) {
      return _trekkingDays(from: from.toLowerCase(), to: to.toLowerCase());
    }

    if (transport.contains('road')) {
      return 1;
    }

    // A normal intercity route leg is treated as one travel day unless
    // the selected mode is a trekking route with an explicit multi-day rule.
    return 1;
  }

  // ============================================================
  // TREKKING DAYS
  // ============================================================

  static int _trekkingDays({required String from, required String to}) {
    if (from.contains('lukla') && to.contains('namche')) {
      return 2;
    }

    if (to.contains('everest')) {
      return 3;
    }

    if (to.contains('annapurna base camp')) {
      return 3;
    }

    if (to.contains('poon hill')) {
      return 2;
    }

    if (to.contains('ghandruk')) {
      return 1;
    }

    return 2;
  }

  // ============================================================
  // DESTINATION VISIT DAYS
  // ============================================================

  static int _calculateVisitDays({
    required String destination,
    required bool isRoundTrip,
  }) {
    final String destinationLower = destination.toLowerCase();

    if (destinationLower.contains('mustang')) {
      return isRoundTrip ? 3 : 2;
    }

    if (destinationLower.contains('pokhara')) {
      return isRoundTrip ? 3 : 2;
    }

    if (destinationLower.contains('kathmandu')) {
      return isRoundTrip ? 3 : 2;
    }

    if (destinationLower.contains('chitwan')) {
      return isRoundTrip ? 3 : 2;
    }

    if (destinationLower.contains('everest')) {
      return isRoundTrip ? 6 : 4;
    }

    if (destinationLower.contains('annapurna')) {
      return isRoundTrip ? 5 : 3;
    }

    return isRoundTrip ? 3 : 2;
  }

  // ============================================================
  // DAY-BY-DAY PLAN
  // ============================================================

  static List<DayPlan> _generateDayPlans({
    required TravelRoute route,
    required int travelDays,
    required int visitDays,
    required int returnDays,
    required List<int> ages,
    required int adultCount,
    required int childCount,
    required int actualJourneyDays,
  }) {
    final List<DayPlan> plans = [];

    // Use the user's selected calendar duration whenever it is available.
    // Older helper calls may pass 0, so fall back to the calculated
    // minimum journey duration in that case.
    final int fallbackDays =
        travelDays + visitDays + returnDays + route.explorationDays;
    final int totalPlanDays = actualJourneyDays > 0
        ? actualJourneyDays
        : fallbackDays;

    if (totalPlanDays <= 0) {
      return plans;
    }

    // Local exploration has no intercity route segments.
    if (route.segments.isEmpty) {
      return _createVisitPlans(
        places: _getDestinationPlaces(route.destination),
        numberOfDays: totalPlanDays,
        startingDay: 1,
        ages: ages,
        adultCount: adultCount,
        childCount: childCount,
        localTransportation: route.localTransportation,
      );
    }

    List<DayPlanItem> expandTravelDays(List<RouteSegment> routeSegments) {
      final List<DayPlanItem> items = [];

      for (final segment in routeSegments) {
        final int days = _daysForTransport(
          from: segment.from,
          to: segment.to,
          transportation: segment.transportation,
        );

        final int safeDays = days > 0 ? days : 1;

        for (int i = 0; i < safeDays; i++) {
          items.add(
            DayPlanItem.travel(
              from: segment.from,
              to: segment.to,
              transportation: segment.transportation,
            ),
          );
        }
      }

      return items;
    }

    final List<DayPlanItem> outboundTravelItems = expandTravelDays(
      route.segments,
    );

    final List<DayPlanItem> returnTravelItems = route.isRoundTrip
        ? expandTravelDays(route.returnSegments)
        : <DayPlanItem>[];

    final int outboundDaysToUse = outboundTravelItems.length < totalPlanDays
        ? outboundTravelItems.length
        : totalPlanDays;

    final int remainingDays = totalPlanDays - outboundDaysToUse;

    // Reserve the end of a round trip for the user's actual return route.
    int returnDaysToUse = 0;

    if (route.isRoundTrip &&
        returnTravelItems.isNotEmpty &&
        remainingDays > 0) {
      returnDaysToUse = returnTravelItems.length < remainingDays
          ? returnTravelItems.length
          : remainingDays;
    }

    // Days available for non-travel time between the outbound journey and the
    // start of the return journey: exploration at outbound stops, the core
    // destination stay, and exploration at stops that only exist on a custom
    // return route.
    final int explorationDays = remainingDays - returnDaysToUse;

    // EXTRA STOP EXPLORATION DAYS (outbound stops)
    int stopPlanDaysToUse = 0;

    if (route.stopPlans.isNotEmpty && explorationDays > 0) {
      final int requestedStopDays = route.stopPlans.fold(
        0,
        (total, plan) =>
            total + (plan.explorationDays > 0 ? plan.explorationDays : 0),
      );

      stopPlanDaysToUse = requestedStopDays < explorationDays
          ? requestedStopDays
          : explorationDays;
    }

    // How many stay days each outbound stop contributes, keyed canonically.
    // Each stop's days attach to the leg that actually arrives there so the
    // plan reads in true chronological order (travel -> stay -> next travel).
    final Map<String, int> outboundStopDaysByStop = <String, int>{};

    if (stopPlanDaysToUse > 0) {
      int allocated = 0;

      for (final plan in route.stopPlans) {
        if (plan.explorationDays <= 0) {
          continue;
        }

        if (allocated >= stopPlanDaysToUse) {
          break;
        }

        final int daysToUse =
            plan.explorationDays < (stopPlanDaysToUse - allocated)
            ? plan.explorationDays
            : (stopPlanDaysToUse - allocated);

        outboundStopDaysByStop[plan.location.toLowerCase()] = daysToUse;

        allocated += daysToUse;
      }
    }

    // RETURN-ONLY STOP EXPLORATION DAYS
    // Kept out of the destination stay so they can be interleaved between the
    // return legs in chronological order (each stop's days follow the leg that
    // arrives there and precede the next return leg).
    final int returnStopBudget = explorationDays - stopPlanDaysToUse;

    final List<JourneyStopPlan> returnStopsToUse = <JourneyStopPlan>[];

    if (route.isRoundTrip) {
      int allocated = 0;

      for (final plan in route.returnStopPlans) {
        if (plan.explorationDays <= 0) {
          continue;
        }

        if (allocated >= returnStopBudget) {
          break;
        }

        final int daysToUse =
            plan.explorationDays < (returnStopBudget - allocated)
            ? plan.explorationDays
            : (returnStopBudget - allocated);

        returnStopsToUse.add(
          JourneyStopPlan(location: plan.location, explorationDays: daysToUse),
        );

        allocated += daysToUse;
      }
    }

    // DESTINATION VISIT DAYS (the core stay at the destination)
    final int requestedReturnStopDays = returnStopsToUse.fold(
      0,
      (total, plan) => total + plan.explorationDays,
    );
    final int destinationDays = returnStopBudget - requestedReturnStopDays;

    // OUTBOUND JOURNEY
    // Each leg is followed by the traveller's stay at the stop it reaches:
    // intermediate stops draw from [route.stopPlans] while the final leg leads
    // into the core destination stay. Keeping outbound stops in true travel
    // order also guarantees that a stop visited on the way out (for example
    // Pokhara with 1 day) is never merged with the same stop visited again on
    // the return journey (Pokhara with 2 days).
    int currentDay = 1;
    int outboundItemIndex = 0;

    for (
      int legIndex = 0;
      legIndex < route.segments.length && currentDay <= totalPlanDays;
      legIndex++
    ) {
      final RouteSegment segment = route.segments[legIndex];

      final int travelDaysForLeg = _daysForTransport(
        from: segment.from,
        to: segment.to,
        transportation: segment.transportation,
      );

      for (
        int i = 0;
        i < travelDaysForLeg &&
            outboundItemIndex < outboundTravelItems.length &&
            currentDay <= totalPlanDays;
        i++
      ) {
        plans.add(
          DayPlan(
            day: currentDay,
            items: [outboundTravelItems[outboundItemIndex]],
          ),
        );

        currentDay++;
        outboundItemIndex++;
      }

      if (currentDay > totalPlanDays) {
        break;
      }

      final bool isFinalOutboundLeg = legIndex == route.segments.length - 1;

      if (isFinalOutboundLeg) {
        // EXTRA EXPLORATION DAYS at the destination itself (the final
        // destination is a normal stop plan): planned before the core visit.
        final int? destStopDays =
            outboundStopDaysByStop[segment.to.toLowerCase()];

        if (destStopDays != null && destStopDays > 0) {
          final List<DayPlan> stopPlans = _createStopPlans(
            stops: [
              JourneyStopPlan(
                location: segment.to,
                explorationDays: destStopDays,
              ),
            ],
            numberOfDays: destStopDays,
            startingDay: currentDay,
            ages: ages,
            adultCount: adultCount,
            childCount: childCount,
          );

          plans.addAll(stopPlans);
          currentDay += stopPlans.length;

          outboundStopDaysByStop[segment.to.toLowerCase()] = 0;
        }

        // DESTINATION VISIT DAYS (the core stay at the destination)
        if (destinationDays > 0) {
          final List<DayPlan> visitPlans = _createVisitPlans(
            places: _getDestinationPlaces(route.destination),
            numberOfDays: destinationDays,
            startingDay: currentDay,
            ages: ages,
            adultCount: adultCount,
            childCount: childCount,
          );

          plans.addAll(visitPlans);
          currentDay += visitPlans.length;
        }
      } else {
        // EXPLORATION DAYS at this intermediate stop before the next leg.
        final int? stopDays = outboundStopDaysByStop[segment.to.toLowerCase()];

        if (stopDays != null && stopDays > 0) {
          final List<DayPlan> stopPlans = _createStopPlans(
            stops: [
              JourneyStopPlan(location: segment.to, explorationDays: stopDays),
            ],
            numberOfDays: stopDays,
            startingDay: currentDay,
            ages: ages,
            adultCount: adultCount,
            childCount: childCount,
          );

          plans.addAll(stopPlans);
          currentDay += stopPlans.length;

          // Produced exactly once; clear so a later outbound leg to the same
          // place cannot add the stop a second time.
          outboundStopDaysByStop[segment.to.toLowerCase()] = 0;
        }
      }
    }

    // RETURN JOURNEY
    // Travel legs come first, each followed by the traveller's exploration
    // days at the stop just reached, before moving on to the next return leg.
    if (route.isRoundTrip && returnDaysToUse > 0) {
      // Remaining stop days per return stop, keyed canonically. Each return
      // stop plans to stay only at the leg that actually arrives there.
      final remainingStopDaysByStop = <String, int>{
        for (final plan in returnStopsToUse)
          plan.location.toLowerCase(): plan.explorationDays,
      };

      int returnItemIndex = 0;

      for (
        int legIndex = 0;
        legIndex < route.returnSegments.length &&
            returnItemIndex < returnDaysToUse;
        legIndex++
      ) {
        final RouteSegment segment = route.returnSegments[legIndex];

        final int travelDaysForLeg = _daysForTransport(
          from: segment.from,
          to: segment.to,
          transportation: segment.transportation,
        );

        for (
          int i = 0;
          i < travelDaysForLeg && returnItemIndex < returnDaysToUse;
          i++
        ) {
          if (currentDay > totalPlanDays) {
            break;
          }

          plans.add(
            DayPlan(
              day: currentDay,
              items: [returnTravelItems[returnItemIndex]],
            ),
          );

          currentDay++;
          returnItemIndex++;
        }

        // Exploration days at the stop reached by this leg, before continuing
        // with the next return leg.
        if (currentDay <= totalPlanDays) {
          final int? stopDays =
              remainingStopDaysByStop[segment.to.toLowerCase()];

          if (stopDays != null && stopDays > 0) {
            final List<DayPlan> stopPlans = _createStopPlans(
              stops: [
                JourneyStopPlan(
                  location: segment.to,
                  explorationDays: stopDays,
                ),
              ],
              numberOfDays: stopDays,
              startingDay: currentDay,
              ages: ages,
              adultCount: adultCount,
              childCount: childCount,
            );

            plans.addAll(stopPlans);
            currentDay += stopPlans.length;

            // Produced exactly once; clear so a later leg to the same place
            // cannot add the stop a second time.
            remainingStopDaysByStop[segment.to.toLowerCase()] = 0;
          }
        }
      }
    }

    if (plans.length > totalPlanDays) {
      return plans.sublist(0, totalPlanDays);
    }

    return plans;
  }

  // ============================================================
  // STOP-PLAN DAYS
  // ============================================================

  /// Builds the day plans for the traveller's extra stay days at specific
  /// route stops. Each selected stop contributes its exploration days in
  /// order, using matching places when available and a friendly free-text
  /// activity otherwise. Works for both outbound stops ([TravelRoute.stopPlans])
  /// and stops introduced on a custom return route ([TravelRoute.returnStopPlans]).
  static List<DayPlan> _createStopPlans({
    required List<JourneyStopPlan> stops,
    required int numberOfDays,
    required int startingDay,
    required List<int> ages,
    required int adultCount,
    required int childCount,
  }) {
    final List<DayPlan> plans = [];

    int allocated = 0;
    int day = startingDay;

    for (final plan in stops) {
      if (allocated >= numberOfDays) {
        break;
      }

      if (plan.explorationDays <= 0) {
        continue;
      }

      final int daysToUse = plan.explorationDays < numberOfDays - allocated
          ? plan.explorationDays
          : numberOfDays - allocated;

      final places = _getDestinationPlaces(plan.location);

      for (int i = 0; i < daysToUse; i++) {
        final List<DayPlanItem> items = [];

        if (i < places.length) {
          items.add(DayPlanItem.attraction(place: places[i]));
        } else {
          items.add(
            DayPlanItem.activity(
              activity:
                  'Spend extra time exploring ${plan.location} and its '
                  'surroundings at your own pace',
            ),
          );
        }

        plans.add(DayPlan(day: day, items: items));
        day++;
      }

      allocated += daysToUse;
    }

    return plans;
  }

  // ============================================================
  // GET DESTINATION PLACES
  // ============================================================

  static List<Place> _getDestinationPlaces(String destination) {
    final String destinationLower = destination.toLowerCase().trim();

    final List<Place> exactMatches = nepalPlaces.where((place) {
      return place.location.toLowerCase().trim() == destinationLower;
    }).toList();

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    return nepalPlaces.where((place) {
      final String location = place.location.toLowerCase();

      return destinationLower.contains(location) ||
          location.contains(destinationLower);
    }).toList();
  }

  // ============================================================
  // CREATE VISIT PLANS
  // ============================================================

  static List<DayPlan> _createVisitPlans({
    required List<Place> places,
    required int numberOfDays,
    required int startingDay,
    required List<int> ages,
    required int adultCount,
    required int childCount,
    String? localTransportation,
  }) {
    final List<DayPlan> plans = [];

    if (numberOfDays <= 0) {
      return plans;
    }

    // ==========================================================
    // AGE INFORMATION
    // ==========================================================

    final bool hasVeryYoungChild = _hasVeryYoungChild(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasYoungChild = _hasYoungChild(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasOlderChild = _hasOlderChild(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasTeenager = _hasTeenager(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasSenior = ages.any((age) => age >= 60);

    // ==========================================================
    // NO PLACES
    // ==========================================================

    if (places.isEmpty) {
      for (int i = 0; i < numberOfDays; i++) {
        plans.add(DayPlan(day: startingDay + i, items: const []));
      }

      return plans;
    }

    // ==========================================================
    // EVEREST SPECIAL ITINERARY
    // ==========================================================

    final bool isEverest = places.any(
      (place) => place.location.toLowerCase().trim() == 'everest',
    );

    if (isEverest) {
      for (int i = 0; i < numberOfDays; i++) {
        final int day = startingDay + i;

        final List<DayPlanItem> items = [];

        // ------------------------------------------------------
        // VERY YOUNG CHILD
        // ------------------------------------------------------

        if (hasVeryYoungChild) {
          if (i.isEven) {
            items.add(
              const DayPlanItem.activity(
                activity:
                    'Easy family-friendly exploration with frequent rest breaks',
              ),
            );
          } else {
            items.add(
              const DayPlanItem.activity(
                activity:
                    'Rest day and light acclimatization suitable for a very young child',
              ),
            );
          }

          plans.add(DayPlan(day: day, items: items));

          continue;
        }

        // ------------------------------------------------------
        // YOUNG CHILD
        // ------------------------------------------------------

        if (hasYoungChild) {
          if (i == 0 || i.isEven) {
            if (i < places.length) {
              items.add(DayPlanItem.attraction(place: places[i]));
            } else {
              items.add(
                const DayPlanItem.activity(
                  activity: 'Easy sightseeing and family-friendly exploration',
                ),
              );
            }
          } else {
            items.add(
              const DayPlanItem.activity(
                activity:
                    'Rest, easy exploration and acclimatization suitable for children',
              ),
            );
          }

          plans.add(DayPlan(day: day, items: items));

          continue;
        }

        // ------------------------------------------------------
        // OLDER CHILD / TEENAGER / SENIOR
        // ------------------------------------------------------

        if (hasOlderChild || hasTeenager || hasSenior) {
          if (i < places.length) {
            items.add(DayPlanItem.attraction(place: places[i]));
          } else {
            items.add(
              const DayPlanItem.activity(
                activity:
                    'Acclimatization, rest and exploration of the Everest region',
              ),
            );
          }

          plans.add(DayPlan(day: day, items: items));

          continue;
        }

        // ------------------------------------------------------
        // ADULT-ONLY EVEREST
        // ------------------------------------------------------

        if (i < places.length) {
          items.add(DayPlanItem.attraction(place: places[i]));
        } else {
          switch (i) {
            case 2:
              items.add(
                const DayPlanItem.activity(
                  activity:
                      'Acclimatization and exploration around Namche Bazaar',
                ),
              );
              break;

            case 3:
              items.add(
                const DayPlanItem.activity(
                  activity:
                      'Trekking preparation and exploration of the Everest region',
                ),
              );
              break;

            case 4:
              items.add(
                const DayPlanItem.activity(
                  activity:
                      'Rest, acclimatization and preparation for the return journey',
                ),
              );
              break;

            case 5:
              items.add(
                const DayPlanItem.activity(
                  activity:
                      'Final Everest region exploration and trek preparation',
                ),
              );
              break;

            default:
              items.add(
                const DayPlanItem.activity(
                  activity:
                      'Explore the Everest region and prepare for the next stage',
                ),
              );
          }
        }

        plans.add(DayPlan(day: day, items: items));
      }

      return plans;
    }

    // ==========================================================
    // OTHER DESTINATIONS
    // ==========================================================

    final List<List<Place>> placesPerDay = List.generate(
      numberOfDays,
      (_) => <Place>[],
    );

    final int maximumPlacesPerDay = hasVeryYoungChild
        ? 1
        : hasYoungChild
        ? 2
        : hasOlderChild || hasTeenager || hasSenior
        ? 2
        : 3;

    for (int i = 0; i < places.length; i++) {
      final int dayIndex = i % numberOfDays;

      if (placesPerDay[dayIndex].length < maximumPlacesPerDay) {
        placesPerDay[dayIndex].add(places[i]);
      }
    }

    // ==========================================================
    // CREATE DAY PLANS
    // ==========================================================

    for (int i = 0; i < numberOfDays; i++) {
      final List<DayPlanItem> items = placesPerDay[i]
          .map((place) => DayPlanItem.attraction(place: place))
          .toList();

      // --------------------------------------------------------
      // VERY YOUNG CHILD
      // --------------------------------------------------------

      if (hasVeryYoungChild) {
        if (i.isOdd) {
          plans.add(
            DayPlan(
              day: startingDay + i,
              items: const [
                DayPlanItem.activity(
                  activity:
                      'Rest, family-friendly activities and frequent breaks',
                ),
              ],
            ),
          );
        } else if (items.isEmpty) {
          plans.add(
            DayPlan(
              day: startingDay + i,
              items: const [
                DayPlanItem.activity(
                  activity:
                      'Easy local exploration suitable for a very young child',
                ),
              ],
            ),
          );
        } else {
          plans.add(DayPlan(day: startingDay + i, items: items));
        }

        continue;
      }

      // --------------------------------------------------------
      // YOUNG CHILD
      // --------------------------------------------------------

      if (hasYoungChild) {
        if (items.isEmpty) {
          plans.add(
            DayPlan(
              day: startingDay + i,
              items: const [
                DayPlanItem.activity(
                  activity:
                      'Easy sightseeing, family-friendly activities and regular rest breaks',
                ),
              ],
            ),
          );
        } else {
          plans.add(DayPlan(day: startingDay + i, items: items));
        }

        continue;
      }

      // --------------------------------------------------------
      // OLDER CHILD / TEENAGER / SENIOR
      // --------------------------------------------------------

      if (items.isEmpty && (hasOlderChild || hasTeenager || hasSenior)) {
        plans.add(
          DayPlan(
            day: startingDay + i,
            items: const [
              DayPlanItem.activity(
                activity:
                    'Rest and easy local exploration suitable for the group',
              ),
            ],
          ),
        );
      } else {
        plans.add(DayPlan(day: startingDay + i, items: items));
      }
    }

    return plans;
  }

  // ============================================================
  // ROUTE DESTINATIONS
  // ============================================================

  static List<String> _getRouteDestinations(TravelRoute route) {
    final List<String> destinations = [];

    for (final segment in route.segments) {
      if (!destinations.contains(segment.from)) {
        destinations.add(segment.from);
      }

      if (!destinations.contains(segment.to)) {
        destinations.add(segment.to);
      }
    }

    if (!destinations.contains(route.destination)) {
      destinations.add(route.destination);
    }

    return destinations;
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  static String _buildSummary({
    required String destination,
    required TravelRoute route,
    required int minimumDays,
    required int maximumDays,
    required int adultCount,
    required int childCount,
    required List<int> childAges,
  }) {
    final String direction = route.isRoundTrip ? 'round trip' : 'one-way trip';

    String travellerDescription = '$adultCount adult(s)';

    if (childCount > 0) {
      travellerDescription += ' and $childCount child(ren)';

      if (childAges.isNotEmpty) {
        travellerDescription += ' aged ${childAges.join(', ')}';
      }
    }

    return 'For a $direction to $destination, '
        'the recommended duration is '
        '$minimumDays-$maximumDays days for '
        '$travellerDescription. '
        'This includes the time needed to travel to the '
        'destination, explore important places, and '
        '${route.isRoundTrip ? 'return to your starting point.' : 'complete the destination visit.'}';
  }

  // ============================================================
  // SUITABILITY SCORE
  // ============================================================

  static int _calculateOverallScore({
    required String touristType,
    required String season,
    required String suitability,
    required List<int> ages,
    required int adultCount,
    required int childCount,
    required String travelType,
    required int groupSize,
    required String destination,
  }) {
    int score = 75;

    final String seasonLower = season.toLowerCase();

    final String suitabilityLower = suitability.toLowerCase();

    // ----------------------------------------------------------
    // SEASON SUITABILITY
    // ----------------------------------------------------------

    if (suitabilityLower.contains('good') ||
        suitabilityLower.contains('excellent') ||
        suitabilityLower.contains('suitable')) {
      score += 10;
    }

    if (suitabilityLower.contains('poor') ||
        suitabilityLower.contains('unsuitable')) {
      score -= 20;
    }

    if (seasonLower.contains('autumn') || seasonLower.contains('spring')) {
      score += 5;
    }

    // ----------------------------------------------------------
    // MUSTANG MONSOON
    // ----------------------------------------------------------

    if (destination.toLowerCase().contains('mustang') &&
        seasonLower.contains('monsoon')) {
      score -= 15;
    }

    // ----------------------------------------------------------
    // CHILD AGE IMPACT
    // ----------------------------------------------------------

    final List<int> childAges = _getChildAges(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasVeryYoungChild = _hasVeryYoungChild(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasYoungChild = _hasYoungChild(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasOlderChild = _hasOlderChild(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasTeenager = _hasTeenager(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    final bool hasSenior = ages.any((age) => age >= 60);

    if (adultCount > 0) {
      score += 2;
    }

    if (childCount > 0) {
      // Having children does not automatically make a trip bad.
      // The score is adjusted according to their age.
      score += 1;
    }

    if (hasVeryYoungChild) {
      score -= 8;
    } else if (hasYoungChild) {
      score -= 5;
    } else if (hasOlderChild) {
      score -= 3;
    } else if (hasTeenager) {
      score -= 1;
    }

    if (hasSenior) {
      score -= 4;
    }

    if (childAges.length > 1) {
      score += 1;
    }

    // ----------------------------------------------------------
    // GROUP SIZE
    // ----------------------------------------------------------

    if (groupSize >= 6) {
      score -= 2;
    } else if (groupSize >= 3) {
      score += 1;
    } else if (groupSize == 2) {
      score += 2;
    }

    // ----------------------------------------------------------
    // TRAVEL TYPE
    // ----------------------------------------------------------

    final String travelTypeLower = travelType.toLowerCase();

    if (travelTypeLower.contains('solo')) {
      score -= 2;
    } else if (travelTypeLower.contains('couple')) {
      score += 2;
    } else if (travelTypeLower.contains('family')) {
      score += 3;
    } else if (travelTypeLower.contains('group')) {
      score += 1;
    }

    // ----------------------------------------------------------
    // TOURIST TYPE
    // ----------------------------------------------------------

    final String touristTypeLower = touristType.toLowerCase();

    if (touristTypeLower.contains('international')) {
      score += 1;
    } else if (touristTypeLower.contains('domestic')) {
      score += 2;
    }

    return score.clamp(0, 100);
  }

  // ============================================================
  // SUITABILITY TEXT
  // ============================================================

  static String _getOverallSuitability(int score) {
    if (score >= 90) {
      return 'Excellent';
    }

    if (score >= 80) {
      return 'Very Good';
    }

    if (score >= 70) {
      return 'Good';
    }

    if (score >= 60) {
      return 'Moderate';
    }

    return 'Needs Caution';
  }

  // ============================================================
  // SUITABILITY FACTORS
  // ============================================================

  static List<String> _buildSuitabilityFactors({
    required String touristType,
    required String season,
    required String suitability,
    required List<int> ages,
    required int adultCount,
    required int childCount,
    required String travelType,
    required int groupSize,
    required String destination,
  }) {
    final List<String> factors = [];

    // ----------------------------------------------------------
    // TOURIST TYPE
    // ----------------------------------------------------------

    final String touristTypeLower = touristType.toLowerCase();

    if (touristTypeLower.contains('international')) {
      factors.add(
        'The recommendation considers that international travellers may need additional attention to local transportation, acclimatization and travel conditions in Nepal.',
      );
    } else if (touristTypeLower.contains('domestic')) {
      factors.add(
        'The recommendation considers that domestic travellers are travelling within Nepal and may already be familiar with local travel conditions.',
      );
    }

    factors.add(
      'Travel suitability is based on the selected season and destination.',
    );

    factors.add(
      'The selected route and transportation are included in the trip calculation.',
    );

    // ----------------------------------------------------------
    // GROUP COMPOSITION
    // ----------------------------------------------------------

    factors.add(
      'The travelling group contains $adultCount adult(s) and $childCount child(ren).',
    );

    // ----------------------------------------------------------
    // AGE FACTORS
    // ----------------------------------------------------------

    final List<int> childAges = _getChildAges(
      ages,
      adultCount: adultCount,
      childCount: childCount,
    );

    if (childAges.isNotEmpty) {
      final int youngestChild = childAges.reduce((a, b) => a < b ? a : b);

      if (youngestChild <= 4) {
        factors.add(
          'The itinerary is adjusted for a very young child by prioritizing easier activities, shorter sightseeing periods and additional rest.',
        );
      } else if (youngestChild <= 8) {
        factors.add(
          'The itinerary considers the child age by prioritizing family-friendly activities, moderate sightseeing and regular rest.',
        );
      } else if (youngestChild <= 12) {
        factors.add(
          'The itinerary considers the child age and allows a wider range of moderate sightseeing activities.',
        );
      } else {
        factors.add(
          'The itinerary considers the teenager age and allows greater flexibility for activities and sightseeing.',
        );
      }

      factors.add(
        'The individual child ages considered by the recommendation are: ${childAges.join(', ')}.',
      );
    } else if (adultCount > 0 && childCount == 0) {
      factors.add(
        'All travellers are adults, so the itinerary can use a more flexible sightseeing schedule.',
      );
    }

    if (ages.any((age) => age >= 60)) {
      factors.add(
        'The itinerary considers senior travellers by allowing easier activities and rest periods.',
      );
    }

    // ----------------------------------------------------------
    // GROUP
    // ----------------------------------------------------------

    if (groupSize > 1) {
      factors.add(
        'Travelling as a group can provide additional support during the journey.',
      );
    } else {
      factors.add(
        'Solo travel requires additional attention to transportation and safety.',
      );
    }

    // ----------------------------------------------------------
    // MUSTANG
    // ----------------------------------------------------------

    if (destination.toLowerCase().contains('mustang')) {
      factors.add(
        'Mustang travel should account for changing mountain weather and road conditions.',
      );
    }

    // ----------------------------------------------------------
    // FAMILY
    // ----------------------------------------------------------

    if (travelType.toLowerCase().contains('family')) {
      factors.add(
        'Family travel benefits from allowing additional rest and flexible activities.',
      );
    }

    // ----------------------------------------------------------
    // MONSOON
    // ----------------------------------------------------------

    if (season.toLowerCase().contains('monsoon') &&
        destination.toLowerCase().contains('mustang')) {
      factors.add(
        'Monsoon conditions may affect Mustang road travel and accessibility.',
      );
    }

    return factors;
  }

  // ============================================================
  // BUDGET ESTIMATION
  // ============================================================

  // Budget estimation (per-component estimate + three-tier verdict) is now
  // delegated to TripCostEstimator. See generate() above.

  // ============================================================
  // DURATION MESSAGE
  // ============================================================

  static String _buildDurationMessage({
    required int selectedDuration,
    required int minimumDays,
    required int maximumDays,
  }) {
    if (selectedDuration < minimumDays) {
      final int shortage = minimumDays - selectedDuration;

      return 'You have $selectedDuration day(s), '
          'but the recommended trip needs at least '
          '$minimumDays days. '
          'You need approximately $shortage more day(s).';
    }

    if (selectedDuration > maximumDays) {
      final int extra = selectedDuration - minimumDays;

      return 'You have $selectedDuration day(s). '
          'The actual journey uses about '
          '$minimumDays day(s), leaving '
          '$extra extra day(s) available for '
          'other destinations.';
    }

    return 'Your selected $selectedDuration-day duration '
        'fits the recommended travel duration.';
  }

  // ============================================================
  // REMAINING DAYS MESSAGE
  // ============================================================

  static String _buildRemainingDaysMessage({
    required int selectedDuration,
    required int minimumDays,
    required int remainingDays,
    required String destination,
  }) {
    if (remainingDays <= 0) {
      return 'Your selected duration is already close to '
          'the recommended time for $destination.';
    }

    return 'The $destination journey uses about '
        '$minimumDays day(s). You have $remainingDays '
        'remaining day(s) from your $selectedDuration-day '
        'trip. These days are not added to the $destination '
        'itinerary. You can use them to explore other '
        'destinations in Nepal.';
  }

  // ============================================================
  // ADDITIONAL DESTINATIONS
  // ============================================================

  static List<String> _getAdditionalDestinations({
    required String destination,
  }) {
    final String destinationLower = destination.toLowerCase();

    if (destinationLower.contains('mustang')) {
      return ['Pokhara', 'Chitwan', 'Kathmandu'];
    }

    if (destinationLower.contains('pokhara')) {
      return ['Chitwan', 'Kathmandu', 'Mustang'];
    }

    if (destinationLower.contains('chitwan')) {
      return ['Pokhara', 'Kathmandu', 'Mustang'];
    }

    if (destinationLower.contains('kathmandu')) {
      return ['Pokhara', 'Chitwan', 'Mustang'];
    }

    if (destinationLower.contains('everest')) {
      return ['Kathmandu', 'Pokhara', 'Chitwan'];
    }

    if (destinationLower.contains('annapurna')) {
      return ['Pokhara', 'Mustang', 'Chitwan'];
    }

    return ['Kathmandu', 'Pokhara', 'Chitwan'];
  }

  // ============================================================
  // REASONS
  // ============================================================

  static List<String> _buildReasons({
    required String touristType,
    required String destination,
    required TravelRoute route,
    required int minimumDays,
    required int maximumDays,
    required String season,
    required String travelType,
    required List<int> ages,
    required int adultCount,
    required int childCount,
    required List<int> childAges,
  }) {
    final List<String> reasons = [];

    // ----------------------------------------------------------
    // TOURIST TYPE
    // ----------------------------------------------------------

    final String touristTypeLower = touristType.toLowerCase();

    if (touristTypeLower.contains('international')) {
      reasons.add(
        'The recommendation considers the needs of international travellers visiting Nepal, including local travel conditions and acclimatization.',
      );
    } else if (touristTypeLower.contains('domestic')) {
      reasons.add(
        'The recommendation considers that domestic travellers are travelling within Nepal and may have greater familiarity with local travel conditions.',
      );
    }

    // ----------------------------------------------------------
    // GROUP COMPOSITION
    // ----------------------------------------------------------

    reasons.add(
      'The trip is planned for $adultCount adult(s) and $childCount child(ren).',
    );

    // ----------------------------------------------------------
    // AGE REASON
    // ----------------------------------------------------------

    if (childAges.isNotEmpty) {
      final int youngestChild = childAges.reduce((a, b) => a < b ? a : b);

      if (youngestChild <= 4) {
        reasons.add(
          'The youngest child is $youngestChild years old, so the itinerary prioritizes easy activities, shorter sightseeing periods and additional rest.',
        );
      } else if (youngestChild <= 8) {
        reasons.add(
          'The youngest child is $youngestChild years old, so the itinerary prioritizes family-friendly activities and regular rest.',
        );
      } else if (youngestChild <= 12) {
        reasons.add(
          'The youngest child is $youngestChild years old, allowing a wider range of moderate sightseeing activities.',
        );
      } else {
        reasons.add(
          'The youngest traveller under 18 is $youngestChild years old, so the itinerary allows greater flexibility for activities.',
        );
      }

      reasons.add('Individual child ages considered: ${childAges.join(', ')}.');
    }

    reasons.add(
      'The recommended duration is calculated from your actual travel route.',
    );

    reasons.add(
      'Transportation time and destination exploration time are calculated separately.',
    );

    // ----------------------------------------------------------
    // TRIP DIRECTION
    // ----------------------------------------------------------

    if (route.isRoundTrip) {
      reasons.add(
        'Your round-trip selection includes both the outbound and return journeys.',
      );
    } else {
      reasons.add(
        'Your one-way selection calculates the journey to the destination without adding a return journey.',
      );
    }

    // ----------------------------------------------------------
    // MUSTANG
    // ----------------------------------------------------------

    if (destination.toLowerCase().contains('mustang')) {
      reasons.add(
        'Mustang requires additional time to explore attractions such as Jomsom, Kagbeni and Marpha.',
      );
    }

    // ----------------------------------------------------------
    // EVEREST
    // ----------------------------------------------------------

    if (destination.toLowerCase().contains('everest')) {
      reasons.add(
        'Everest trips require additional time for trekking and acclimatization.',
      );
    }

    // ----------------------------------------------------------
    // FAMILY
    // ----------------------------------------------------------

    if (travelType.toLowerCase().contains('family')) {
      reasons.add(
        'Family travel is considered with a more comfortable and flexible itinerary.',
      );
    }

    reasons.add(
      'The recommendation is not expanded just because the traveller has more available days.',
    );

    return reasons;
  }

  // ============================================================
  // CONVENIENCE METHODS
  // ============================================================

  static String getRecommendedTime({required TravelRoute route}) {
    return generate(
      touristType: 'Domestic Tourist',
      destination: route.destination,
      season: '',
      suitability: '',
      budget: 0,
      currency: '',
      ages: const [],
      travelType: 'Solo',
      groupSize: 1,
      adultCount: 1,
      childCount: 0,
      duration: 0,
      route: route,
    ).recommendedTime;
  }

  /// Minimum number of days this route needs, including any extra
  /// exploration/stay days chosen by the traveller on top of the core
  /// journey. Used for date validation before the itinerary is generated.
  static int minimumDaysFor({required TravelRoute route}) {
    return generate(
      touristType: 'Domestic Tourist',
      destination: route.destination,
      season: '',
      suitability: '',
      budget: 0,
      currency: '',
      ages: const [],
      travelType: 'Solo',
      groupSize: 1,
      adultCount: 1,
      childCount: 0,
      duration: 0,
      route: route,
    ).minimumDays;
  }

  static List<DayPlan> getDayPlans({required TravelRoute route}) {
    return generate(
      touristType: 'Domestic Tourist',
      destination: route.destination,
      season: '',
      suitability: '',
      budget: 0,
      currency: '',
      ages: const [],
      travelType: 'Solo',
      groupSize: 1,
      adultCount: 1,
      childCount: 0,
      duration: 0,
      route: route,
    ).dayPlans;
  }
}
