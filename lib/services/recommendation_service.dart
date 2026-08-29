import '../data/places_data.dart';
import '../models/place_model.dart';
import '../models/travel_route_model.dart';

/// Represents one day in the recommended itinerary.
class DayPlan {
  final int day;
  final List<DayPlanItem> items;

  const DayPlan({
    required this.day,
    required this.items,
  });
}

/// Represents the type of item in a day plan.
enum DayPlanItemType {
  travel,
  attraction,
  activity,
}

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
  })  : type = DayPlanItemType.travel,
        place = null,
        activity = null;

  const DayPlanItem.attraction({
    required this.place,
  })  : type = DayPlanItemType.attraction,
        from = null,
        to = null,
        transportation = null,
        activity = null;

  const DayPlanItem.activity({
    required this.activity,
  })  : type = DayPlanItemType.activity,
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
  // MAIN METHOD
  // ============================================================

  static RecommendationResult generate({
    required String destination,
    required String season,
    required String suitability,
    required double budget,
    required String currency,
    required List<int> ages,
    required String travelType,
    required int groupSize,
    required int duration,
    required TravelRoute route,
  }) {
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
    // 4. TOTAL RECOMMENDED DURATION
    // ==========================================================

    final int minimumDays =
        travelDays + visitDays + returnDays;

    final int maximumDays = minimumDays + 1;

    final String recommendedTime =
        '$minimumDays-$maximumDays days';

    // ==========================================================
    // 5. DAY-BY-DAY PLAN
    // ==========================================================

    final List<DayPlan> dayPlans = _generateDayPlans(
      route: route,
      travelDays: travelDays,
      visitDays: visitDays,
      returnDays: returnDays,
      ages: ages,
    );

    // ==========================================================
    // 6. DESTINATION PLACES
    // ==========================================================

    final List<Place> destinationPlaces =
        _getDestinationPlaces(route.destination);

    final List<String> suggestedPlaces = destinationPlaces
        .map((place) => place.name)
        .toList();

    // ==========================================================
    // 7. ROUTE DESTINATIONS
    // ==========================================================

    final List<String> routeDestinations =
        _getRouteDestinations(route);

    // ==========================================================
    // 8. GENERAL RECOMMENDATION
    // ==========================================================

    final String title =
        'Recommended $recommendedTime Trip';

    final String summary = _buildSummary(
      destination: route.destination,
      route: route,
      minimumDays: minimumDays,
      maximumDays: maximumDays,
    );

    // ==========================================================
    // 9. SUITABILITY
    // ==========================================================

    final int overallScore = _calculateOverallScore(
      season: season,
      suitability: suitability,
      ages: ages,
      travelType: travelType,
      groupSize: groupSize,
      destination: route.destination,
    );

    final String overallSuitability =
        _getOverallSuitability(overallScore);

    final List<String> suitabilityFactors =
        _buildSuitabilityFactors(
      season: season,
      suitability: suitability,
      ages: ages,
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
      groupSize: groupSize,
    );

    final String budgetMessage = _buildBudgetMessage(
      destination: route.destination,
      budget: budget,
      currency: currency,
      duration: minimumDays,
      groupSize: groupSize,
      isLow: budgetIsLow,
    );

    // ==========================================================
    // 11. DURATION STATUS
    // ==========================================================

    final bool durationIsTooShort =
        duration < minimumDays;

    final bool durationIsTooLong =
        duration > maximumDays;

    final String recommendedDurationMessage =
        'For ${route.destination}, we recommend '
        '$recommendedTime.';

    final String durationMessage =
        _buildDurationMessage(
      selectedDuration: duration,
      minimumDays: minimumDays,
      maximumDays: maximumDays,
    );

    final String recommendedDurationTitle =
        durationIsTooShort
            ? 'Trip Duration Is Too Short'
            : durationIsTooLong
                ? 'You Have Extra Days'
                : 'Recommended Duration';

    // ==========================================================
    // 12. REMAINING DAYS
    // ==========================================================

    final int remainingDays =
        duration > maximumDays
            ? duration - maximumDays
            : 0;

    final List<String> additionalDestinations =
        remainingDays > 0
            ? _getAdditionalDestinations(
                destination: route.destination,
              )
            : [];

    final String remainingDaysMessage =
        _buildRemainingDaysMessage(
      selectedDuration: duration,
      maximumDays: maximumDays,
      remainingDays: remainingDays,
      destination: route.destination,
    );

    // ==========================================================
    // 13. REASONS
    // ==========================================================

    final List<String> reasons = _buildReasons(
      destination: route.destination,
      route: route,
      minimumDays: minimumDays,
      maximumDays: maximumDays,
      season: season,
      travelType: travelType,
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
      recommendedDurationTitle:
          recommendedDurationTitle,
      recommendedDurationMessage:
          recommendedDurationMessage,
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

  static int _calculateOutboundTravelDays(
    TravelRoute route,
  ) {
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

  static int _calculateReturnTravelDays(
    TravelRoute route,
  ) {
    if (!route.isRoundTrip ||
        route.returnSegments.isEmpty) {
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
    final String transport =
        transportation.toLowerCase().trim();

    // ----------------------------------------------------------
    // FLIGHT
    // ----------------------------------------------------------

    if (transport.contains('flight') ||
        transport.contains('air')) {
      return 1;
    }

    // ----------------------------------------------------------
    // MOTORBIKE
    // ----------------------------------------------------------

    if (transport.contains('motorbike') ||
        transport.contains('motor bike') ||
        transport.contains('motorcycle')) {
      return 2;
    }

    // ----------------------------------------------------------
    // BICYCLE
    // ----------------------------------------------------------

    if (transport.contains('bike') &&
        !transport.contains('motorbike')) {
      return 2;
    }

    // ----------------------------------------------------------
    // BUS / JEEP / CAR / TAXI
    // ----------------------------------------------------------

    if (transport.contains('bus') ||
        transport.contains('jeep') ||
        transport.contains('car') ||
        transport.contains('taxi') ||
        transport.contains('vehicle')) {
      return 2;
    }

    // ----------------------------------------------------------
    // TREKKING / HIKING
    // ----------------------------------------------------------

    if (transport.contains('trek') ||
        transport.contains('hike') ||
        transport.contains('walking') ||
        transport.contains('walk')) {
      return _trekkingDays(
        from: from.toLowerCase(),
        to: to.toLowerCase(),
      );
    }

    // ----------------------------------------------------------
    // ROAD
    // ----------------------------------------------------------

    if (transport.contains('road')) {
      return 2;
    }

    // ----------------------------------------------------------
    // DEFAULT
    // ----------------------------------------------------------

    return 2;
  }

  // ============================================================
  // TREKKING DAYS
  // ============================================================

  static int _trekkingDays({
    required String from,
    required String to,
  }) {
    // Everest

    if (from.contains('lukla') &&
        to.contains('namche')) {
      return 2;
    }

    if (to.contains('everest')) {
      return 3;
    }

    // Annapurna

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
    final String destinationLower =
        destination.toLowerCase();

    // ----------------------------------------------------------
    // MUSTANG
    // ----------------------------------------------------------

    if (destinationLower.contains('mustang')) {
      return isRoundTrip ? 3 : 2;
    }

    // ----------------------------------------------------------
    // POKHARA
    // ----------------------------------------------------------

    if (destinationLower.contains('pokhara')) {
      return isRoundTrip ? 3 : 2;
    }

    // ----------------------------------------------------------
    // KATHMANDU
    // ----------------------------------------------------------

    if (destinationLower.contains('kathmandu')) {
      return isRoundTrip ? 3 : 2;
    }

    // ----------------------------------------------------------
    // CHITWAN
    // ----------------------------------------------------------

    if (destinationLower.contains('chitwan')) {
      return isRoundTrip ? 3 : 2;
    }

    // ----------------------------------------------------------
    // EVEREST
    // ----------------------------------------------------------

    if (destinationLower.contains('everest')) {
      return isRoundTrip ? 6 : 4;
    }

    // ----------------------------------------------------------
    // ANNAPURNA
    // ----------------------------------------------------------

    if (destinationLower.contains('annapurna')) {
      return isRoundTrip ? 5 : 3;
    }

    // ----------------------------------------------------------
    // DEFAULT
    // ----------------------------------------------------------

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
  }) {
    final List<DayPlan> plans = [];

    int currentDay = 1;

    // Age information is intentionally passed to the
    // itinerary generator so that future itinerary rules
    // can use it without changing the public API.

    // ==========================================================
    // 1. OUTBOUND JOURNEY
    // ==========================================================

    for (final segment in route.segments) {
      final int segmentDays = _daysForTransport(
        from: segment.from,
        to: segment.to,
        transportation: segment.transportation,
      );

      for (int i = 0; i < segmentDays; i++) {
        plans.add(
          DayPlan(
            day: currentDay,
            items: [
              DayPlanItem.travel(
                from: segment.from,
                to: segment.to,
                transportation:
                    segment.transportation,
              ),
            ],
          ),
        );

        currentDay++;
      }
    }

    // ==========================================================
    // 2. DESTINATION VISITS
    // ==========================================================

    final List<Place> destinationPlaces =
        _getDestinationPlaces(route.destination);

    final List<DayPlan> visitPlans =
        _createVisitPlans(
      places: destinationPlaces,
      numberOfDays: visitDays,
      startingDay: currentDay,
      ages: ages,
    );

    plans.addAll(visitPlans);

    currentDay += visitDays;

    // ==========================================================
    // 3. RETURN JOURNEY
    // ==========================================================

    if (route.isRoundTrip) {
      for (final segment in route.returnSegments) {
        final int segmentDays =
            _daysForTransport(
          from: segment.from,
          to: segment.to,
          transportation: segment.transportation,
        );

        for (int i = 0; i < segmentDays; i++) {
          plans.add(
            DayPlan(
              day: currentDay,
              items: [
                DayPlanItem.travel(
                  from: segment.from,
                  to: segment.to,
                  transportation:
                      segment.transportation,
                ),
              ],
            ),
          );

          currentDay++;
        }
      }
    }

    return plans;
  }

  // ============================================================
  // GET DESTINATION PLACES
  // ============================================================

  static List<Place> _getDestinationPlaces(
    String destination,
  ) {
    final String destinationLower =
        destination.toLowerCase().trim();

    // First try exact location.

    final List<Place> exactMatches =
        nepalPlaces.where((place) {
      return place.location
              .toLowerCase()
              .trim() ==
          destinationLower;
    }).toList();

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    // Then try partial matching.

    return nepalPlaces.where((place) {
      final String location =
          place.location.toLowerCase();

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
  }) {
    final List<DayPlan> plans = [];

    if (numberOfDays <= 0) {
      return plans;
    }

    // ==========================================================
    // AGE INFORMATION
    // ==========================================================

    final bool hasChild =
        ages.any((age) => age < 13);

    final bool hasSenior =
        ages.any((age) => age >= 60);

    // ==========================================================
    // NO PLACES
    // ==========================================================

    if (places.isEmpty) {
      for (int i = 0; i < numberOfDays; i++) {
        plans.add(
          DayPlan(
            day: startingDay + i,
            items: const [],
          ),
        );
      }

      return plans;
    }

    // ==========================================================
    // EVEREST SPECIAL ITINERARY
    // ==========================================================

    final bool isEverest = places.any(
      (place) =>
          place.location.toLowerCase().trim() ==
          'everest',
    );

    if (isEverest) {
      for (int i = 0; i < numberOfDays; i++) {
        final int day = startingDay + i;

        final List<DayPlanItem> items = [];

        // ------------------------------------------------------
        // FIRST DAYS
        // ------------------------------------------------------

        if (i < places.length) {
          final Place place = places[i];

          if (hasChild || hasSenior) {
            // For children or seniors, alternate attractions
            // with easier activities.

            if (i == 0 || i % 2 == 0) {
              items.add(
                DayPlanItem.attraction(
                  place: place,
                ),
              );
            } else {
              items.add(
                const DayPlanItem.activity(
                  activity:
                      'Easy exploration, rest and acclimatization suitable for the group',
                ),
              );
            }
          } else {
            items.add(
              DayPlanItem.attraction(
                place: place,
              ),
            );
          }
        } else {
          // ----------------------------------------------------
          // REMAINING EVEREST DAYS
          // ----------------------------------------------------

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

        plans.add(
          DayPlan(
            day: day,
            items: items,
          ),
        );
      }

      return plans;
    }

    // ==========================================================
    // OTHER DESTINATIONS
    // ==========================================================

    final List<List<Place>> placesPerDay =
        List.generate(
      numberOfDays,
      (_) => <Place>[],
    );

    for (int i = 0; i < places.length; i++) {
      final int dayIndex =
          i % numberOfDays;

      // Maximum 3 attractions per day.

      if (placesPerDay[dayIndex].length < 3) {
        placesPerDay[dayIndex].add(
          places[i],
        );
      }
    }

    // ==========================================================
    // CREATE DAY PLANS
    // ==========================================================

    for (int i = 0; i < numberOfDays; i++) {
      final List<DayPlanItem> items =
          placesPerDay[i]
              .map(
                (place) =>
                    DayPlanItem.attraction(
                  place: place,
                ),
              )
              .toList();

      // If the group contains a child or senior and
      // a day has no attraction, provide an easy activity.

      if (items.isEmpty &&
          (hasChild || hasSenior)) {
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
        plans.add(
          DayPlan(
            day: startingDay + i,
            items: items,
          ),
        );
      }
    }

    return plans;
  }

  // ============================================================
  // ROUTE DESTINATIONS
  // ============================================================

  static List<String> _getRouteDestinations(
    TravelRoute route,
  ) {
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
  }) {
    final String direction =
        route.isRoundTrip
            ? 'round trip'
            : 'one-way trip';

    return 'For a $direction to $destination, '
        'the recommended duration is '
        '$minimumDays-$maximumDays days. '
        'This includes the time needed to travel to the '
        'destination, explore important places, and '
        '${route.isRoundTrip ? 'return to your starting point.' : 'complete the destination visit.'}';
  }

  // ============================================================
  // SUITABILITY SCORE
  // ============================================================

  static int _calculateOverallScore({
    required String season,
    required String suitability,
    required List<int> ages,
    required String travelType,
    required int groupSize,
    required String destination,
  }) {
    int score = 75;

    final String seasonLower =
        season.toLowerCase();

    final String suitabilityLower =
        suitability.toLowerCase();

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

    if (seasonLower.contains('autumn') ||
        seasonLower.contains('spring')) {
      score += 5;
    }

    // ----------------------------------------------------------
    // MUSTANG MONSOON
    // ----------------------------------------------------------

    if (destination
            .toLowerCase()
            .contains('mustang') &&
        seasonLower.contains('monsoon')) {
      score -= 15;
    }

    // ----------------------------------------------------------
    // AGE
    // ----------------------------------------------------------

    if (ages.isNotEmpty) {
      final int averageAge =
          ages.reduce((a, b) => a + b) ~/
              ages.length;

      final bool hasChild =
          ages.any((age) => age < 13);

      final bool hasSenior =
          ages.any((age) => age >= 60);

      if (averageAge >= 18 &&
          averageAge <= 55) {
        score += 5;
      }

      if (hasChild) {
        score -= 3;
      }

      if (hasSenior) {
        score -= 4;
      }

      if (ages.length > 1) {
        score += 1;
      }
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

    final String travelTypeLower =
        travelType.toLowerCase();

    if (travelTypeLower.contains('solo')) {
      score -= 2;
    } else if (travelTypeLower.contains('couple')) {
      score += 2;
    } else if (travelTypeLower.contains('family')) {
      score += 3;
    } else if (travelTypeLower.contains('group')) {
      score += 1;
    }

    return score.clamp(0, 100);
  }

  // ============================================================
  // SUITABILITY TEXT
  // ============================================================

  static String _getOverallSuitability(
    int score,
  ) {
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
    required String season,
    required String suitability,
    required List<int> ages,
    required String travelType,
    required int groupSize,
    required String destination,
  }) {
    final List<String> factors = [];

    factors.add(
      'Travel suitability is based on the selected season and destination.',
    );

    factors.add(
      'The selected route and transportation are included in the trip calculation.',
    );

    if (ages.isNotEmpty) {
      factors.add(
        'Age information is considered when evaluating general trip suitability.',
      );
    }

    if (groupSize > 1) {
      factors.add(
        'Travelling as a group can provide additional support during the journey.',
      );
    } else {
      factors.add(
        'Solo travel requires additional attention to transportation and safety.',
      );
    }

    if (destination
        .toLowerCase()
        .contains('mustang')) {
      factors.add(
        'Mustang travel should account for changing mountain weather and road conditions.',
      );
    }

    if (travelType
        .toLowerCase()
        .contains('family')) {
      factors.add(
        'Family travel benefits from allowing additional rest and flexible activities.',
      );
    }

    if (season
            .toLowerCase()
            .contains('monsoon') &&
        destination
            .toLowerCase()
            .contains('mustang')) {
      factors.add(
        'Monsoon conditions may affect Mustang road travel and accessibility.',
      );
    }

    return factors;
  }

  // ============================================================
  // BUDGET CHECK
  // ============================================================

  static bool _isBudgetLow({
    required String destination,
    required double budget,
    required int duration,
    required int groupSize,
  }) {
    double estimatedPerPersonPerDay = 2500;

    final String destinationLower =
        destination.toLowerCase();

    if (destinationLower.contains('mustang')) {
      estimatedPerPersonPerDay = 3500;
    } else if (destinationLower.contains('everest')) {
      estimatedPerPersonPerDay = 4500;
    } else if (destinationLower.contains('annapurna')) {
      estimatedPerPersonPerDay = 4000;
    } else if (destinationLower.contains('chitwan')) {
      estimatedPerPersonPerDay = 3000;
    }

    final double estimatedTotal =
        estimatedPerPersonPerDay *
            duration *
            groupSize;

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
    required int groupSize,
    required bool isLow,
  }) {
    if (isLow) {
      return 'Your selected budget of $currency '
          '${budget.toStringAsFixed(0)} may be low for '
          'the recommended $duration-day trip to '
          '$destination for $groupSize traveller(s). '
          'Consider increasing the budget or reducing '
          'optional expenses.';
    }

    return 'Your selected budget of $currency '
        '${budget.toStringAsFixed(0)} appears reasonable '
        'for the recommended trip duration to '
        '$destination.';
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
      final int shortage =
          minimumDays - selectedDuration;

      return 'You have $selectedDuration day(s), '
          'but the recommended trip needs at least '
          '$minimumDays days. '
          'You need approximately $shortage more day(s).';
    }

    if (selectedDuration > maximumDays) {
      final int extra =
          selectedDuration - maximumDays;

      return 'You have $selectedDuration day(s). '
          'The recommended trip uses about '
          '$minimumDays-$maximumDays days, leaving '
          '$extra extra day(s) available for other destinations.';
    }

    return 'Your selected $selectedDuration-day duration '
        'fits the recommended travel duration.';
  }

  // ============================================================
  // REMAINING DAYS MESSAGE
  // ============================================================

  static String _buildRemainingDaysMessage({
    required int selectedDuration,
    required int maximumDays,
    required int remainingDays,
    required String destination,
  }) {
    if (remainingDays <= 0) {
      return 'Your selected duration is already close to '
          'the recommended time for $destination.';
    }

    return 'The $destination plan uses about '
        '$maximumDays days. You have $remainingDays '
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
    final String destinationLower =
        destination.toLowerCase();

    if (destinationLower.contains('mustang')) {
      return [
        'Pokhara',
        'Chitwan',
        'Kathmandu',
      ];
    }

    if (destinationLower.contains('pokhara')) {
      return [
        'Chitwan',
        'Kathmandu',
        'Mustang',
      ];
    }

    if (destinationLower.contains('chitwan')) {
      return [
        'Pokhara',
        'Kathmandu',
        'Mustang',
      ];
    }

    if (destinationLower.contains('kathmandu')) {
      return [
        'Pokhara',
        'Chitwan',
        'Mustang',
      ];
    }

    if (destinationLower.contains('everest')) {
      return [
        'Kathmandu',
        'Pokhara',
        'Chitwan',
      ];
    }

    if (destinationLower.contains('annapurna')) {
      return [
        'Pokhara',
        'Mustang',
        'Chitwan',
      ];
    }

    return [
      'Kathmandu',
      'Pokhara',
      'Chitwan',
    ];
  }

  // ============================================================
  // REASONS
  // ============================================================

  static List<String> _buildReasons({
    required String destination,
    required TravelRoute route,
    required int minimumDays,
    required int maximumDays,
    required String season,
    required String travelType,
  }) {
    final List<String> reasons = [];

    reasons.add(
      'The recommended duration is calculated from your actual travel route.',
    );

    reasons.add(
      'Transportation time and destination exploration time are calculated separately.',
    );

    if (route.isRoundTrip) {
      reasons.add(
        'Your round-trip selection includes both the outbound and return journeys.',
      );
    } else {
      reasons.add(
        'Your one-way selection calculates the journey to the destination without adding a return journey.',
      );
    }

    if (destination
        .toLowerCase()
        .contains('mustang')) {
      reasons.add(
        'Mustang requires additional time to explore attractions such as Jomsom, Kagbeni and Marpha.',
      );
    }

    if (destination
        .toLowerCase()
        .contains('everest')) {
      reasons.add(
        'Everest trips require additional time for trekking and acclimatization.',
      );
    }

    if (travelType
        .toLowerCase()
        .contains('family')) {
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

  static String getRecommendedTime({
    required TravelRoute route,
  }) {
    return generate(
      destination: route.destination,
      season: '',
      suitability: '',
      budget: 0,
      currency: '',
      ages: const [],
      travelType: 'Solo',
      groupSize: 1,
      duration: 0,
      route: route,
    ).recommendedTime;
  }

  static List<DayPlan> getDayPlans({
    required TravelRoute route,
  }) {
    return generate(
      destination: route.destination,
      season: '',
      suitability: '',
      budget: 0,
      currency: '',
      ages: const [],
      travelType: 'Solo',
      groupSize: 1,
      duration: 0,
      route: route,
    ).dayPlans;
  }
}