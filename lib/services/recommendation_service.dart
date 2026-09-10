import '../data/places_data.dart';
import '../models/place_model.dart';
import '../models/travel_route_model.dart';

/// Represents one day in the recommended itinerary.
class DayPlan {
  final int day;
  final List<DayPlanItem> items;

  const DayPlan({required this.day, required this.items});
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

  const DayPlanItem.travel({
    required this.from,
    required this.to,
    required this.transportation,
  }) : type = DayPlanItemType.travel,
       place = null,
       activity = null;

  const DayPlanItem.attraction({required this.place})
    : type = DayPlanItemType.attraction,
      from = null,
      to = null,
      transportation = null,
      activity = null;

  const DayPlanItem.activity({required this.activity})
    : type = DayPlanItemType.activity,
      from = null,
      to = null,
      transportation = null,
      place = null;

  /// Text displayed as the main title in RecommendationScreen.
  String get title {
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

    final int minimumDays = travelDays + visitDays + returnDays;

    final int maximumDays = minimumDays + 1;

    final String recommendedTime = '$minimumDays-$maximumDays days';

    // ==========================================================
    // 5. DAY-BY-DAY PLAN
    // ==========================================================

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

    final bool budgetIsLow = _isBudgetLow(
      destination: route.destination,
      budget: budget,
      duration: minimumDays,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
      childAges: childAges,
    );

    final String budgetMessage = _buildBudgetMessage(
      destination: route.destination,
      budget: budget,
      currency: currency,
      duration: minimumDays,
      adultCount: normalizedAdultCount,
      childCount: normalizedChildCount,
      childAges: childAges,
      isLow: budgetIsLow,
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
      return 2;
    }

    if (transport.contains('bike') && !transport.contains('motorbike')) {
      return 2;
    }

    if (transport.contains('bus') ||
        transport.contains('jeep') ||
        transport.contains('car') ||
        transport.contains('taxi') ||
        transport.contains('vehicle')) {
      return 2;
    }

    if (transport.contains('trek') ||
        transport.contains('hike') ||
        transport.contains('walking') ||
        transport.contains('walk')) {
      return _trekkingDays(from: from.toLowerCase(), to: to.toLowerCase());
    }

    if (transport.contains('road')) {
      return 2;
    }

    return 2;
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

    final List<RouteSegment> outbound = List<RouteSegment>.from(route.segments);

    if (actualJourneyDays <= 0) {
      return plans;
    }

    if (outbound.isEmpty) {
      return _createVisitPlans(
        places: _getDestinationPlaces(route.destination),
        numberOfDays: actualJourneyDays,
        startingDay: 1,
        ages: ages,
        adultCount: adultCount,
        childCount: childCount,
        localTransportation: route.localTransportation,
      );
    }

    final List<RouteSegment> effectiveOutbound =
        outbound.length > actualJourneyDays
        ? outbound.sublist(0, actualJourneyDays)
        : outbound;

    final List<RouteSegment> returnLegs = route.isRoundTrip
        ? List<RouteSegment>.from(route.returnSegments)
        : <RouteSegment>[];

    int remainingJourneyDays = actualJourneyDays - effectiveOutbound.length;

    if (remainingJourneyDays < 0) {
      remainingJourneyDays = 0;
    }

    int currentDay = 1;

    for (final RouteSegment segment in effectiveOutbound) {
      if (currentDay > actualJourneyDays) {
        break;
      }

      plans.add(
        DayPlan(
          day: currentDay,
          items: [
            DayPlanItem.travel(
              from: segment.from,
              to: segment.to,
              transportation: segment.transportation,
            ),
          ],
        ),
      );

      currentDay++;
    }

    int returnDaysToUse = 0;

    if (route.isRoundTrip && returnLegs.isNotEmpty) {
      returnDaysToUse = returnLegs.length < remainingJourneyDays
          ? returnLegs.length
          : remainingJourneyDays;
    }

    final int explorationDays = remainingJourneyDays - returnDaysToUse;

    final List<Place> destinationPlaces = _getDestinationPlaces(
      route.destination,
    );

    if (explorationDays > 0) {
      final List<DayPlan> visitPlans = _createVisitPlans(
        places: destinationPlaces,
        numberOfDays: explorationDays,
        startingDay: currentDay,
        ages: ages,
        adultCount: adultCount,
        childCount: childCount,
      );

      plans.addAll(visitPlans);

      currentDay += explorationDays;
    }

    if (route.isRoundTrip) {
      for (
        int i = 0;
        i < returnDaysToUse && currentDay <= actualJourneyDays;
        i++
      ) {
        final RouteSegment segment = returnLegs[i];

        plans.add(
          DayPlan(
            day: currentDay,
            items: [
              DayPlanItem.travel(
                from: segment.from,
                to: segment.to,
                transportation: segment.transportation,
              ),
            ],
          ),
        );

        currentDay++;
      }
    }

    if (plans.length > actualJourneyDays) {
      return plans.sublist(0, actualJourneyDays);
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

  static double _calculateEstimatedTotal({
    required String destination,
    required int duration,
    required int adultCount,
    required int childCount,
    required List<int> childAges,
  }) {
    double estimatedPerAdultPerDay = 2500;

    final String destinationLower = destination.toLowerCase();

    if (destinationLower.contains('mustang')) {
      estimatedPerAdultPerDay = 3500;
    } else if (destinationLower.contains('everest')) {
      estimatedPerAdultPerDay = 4500;
    } else if (destinationLower.contains('annapurna')) {
      estimatedPerAdultPerDay = 4000;
    } else if (destinationLower.contains('chitwan')) {
      estimatedPerAdultPerDay = 3000;
    }

    double childCostFactor = 0;

    for (final int age in childAges) {
      if (age <= 5) {
        childCostFactor += 0.50;
      } else if (age <= 12) {
        childCostFactor += 0.70;
      } else {
        childCostFactor += 0.85;
      }
    }

    // If the stored child ages are incomplete, use a conservative
    // 70% estimate for each missing child.
    if (childAges.length < childCount) {
      childCostFactor += (childCount - childAges.length) * 0.70;
    }

    final double adultCost = adultCount * estimatedPerAdultPerDay;

    final double childCost = childCostFactor * estimatedPerAdultPerDay;

    return (adultCost + childCost) * duration;
  }

  // ============================================================
  // BUDGET CHECK
  // ============================================================

  static bool _isBudgetLow({
    required String destination,
    required double budget,
    required int duration,
    required int adultCount,
    required int childCount,
    required List<int> childAges,
  }) {
    final double estimatedTotal = _calculateEstimatedTotal(
      destination: destination,
      duration: duration,
      adultCount: adultCount,
      childCount: childCount,
      childAges: childAges,
    );

    return budget < estimatedTotal;
  }

  // ============================================================
  // BUDGET MESSAGE
  // ============================================================

  static String _buildBudgetMessage({
    required String destination,
    required double budget,
    required String currency,
    required int duration,
    required int adultCount,
    required int childCount,
    required List<int> childAges,
    required bool isLow,
  }) {
    if (isLow) {
      return 'Your selected budget of $currency '
          '${budget.toStringAsFixed(0)} may be low for '
          'the recommended $duration-day trip to '
          '$destination for $adultCount adult(s) and '
          '$childCount child(ren). '
          'Child ages are considered using reduced estimated '
          'costs based on age. Consider increasing the budget '
          'or reducing optional expenses.';
    }

    return 'Your selected budget of $currency '
        '${budget.toStringAsFixed(0)} appears reasonable '
        'for the recommended trip duration to '
        '$destination for $adultCount adult(s) and '
        '$childCount child(ren). '
        'The estimate considers the children ages.';
  }

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
