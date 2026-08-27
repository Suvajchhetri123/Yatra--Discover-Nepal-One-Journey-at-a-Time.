import '../data/places_data.dart';
import '../models/place_model.dart';
import '../models/travel_route_model.dart';

class DayPlan {
  final int day;
  final List<DayPlanItem> items;

  const DayPlan({required this.day, required this.items});
}

enum DayPlanItemType { travel, attraction }

class DayPlanItem {
  final DayPlanItemType type;
  final String title;
  final String? subtitle;

  const DayPlanItem.travel({required this.title, required this.subtitle})
    : type = DayPlanItemType.travel;

  const DayPlanItem.attraction({required this.title, this.subtitle})
    : type = DayPlanItemType.attraction;
}

class TripRecommendation {
  final String recommendedDurationTitle;
  final String recommendedDurationMessage;

  final String title;
  final String summary;

  final List<String> suggestedPlaces;
  final List<String> routeDestinations;
  final List<String> reasons;
  final List<DayPlan> dayPlans;

  final double estimatedMinimumCost;
  final bool budgetIsLow;
  final String budgetMessage;

  final int recommendedMinimumDays;
  final int recommendedMaximumDays;

  final bool durationIsTooShort;
  final bool durationIsTooLong;

  final String durationMessage;

  final List<String> additionalDestinations;
  final String remainingDaysMessage;

  const TripRecommendation({
    required this.recommendedDurationTitle,
    required this.recommendedDurationMessage,
    required this.title,
    required this.summary,
    required this.suggestedPlaces,
    required this.routeDestinations,
    required this.reasons,
    required this.dayPlans,
    required this.estimatedMinimumCost,
    required this.budgetIsLow,
    required this.budgetMessage,
    required this.recommendedMinimumDays,
    required this.recommendedMaximumDays,
    required this.durationIsTooShort,
    required this.durationIsTooLong,
    required this.durationMessage,
    required this.additionalDestinations,
    required this.remainingDaysMessage,
  });
}

class RecommendationService {
  static TripRecommendation generate({
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
    final reasons = <String>[];
    final transportation = _routeTransportation(route);

    final travellerAges = ages.isEmpty ? [18] : ages;

    final oldestAge = travellerAges.reduce((a, b) => a > b ? a : b);

    final youngestAge = travellerAges.reduce((a, b) => a < b ? a : b);

    // ==================================================
    // PLACES
    // ==================================================

    final routeDestinations = _routeDestinations(route, destination);

    final destinationPlaces = _placesForDestinations(routeDestinations);

    if (routeDestinations.length > 1) {
      reasons.add(
        'Attractions are selected from your travel route: '
        '${routeDestinations.join(' → ')}.',
      );
    }

    // ==================================================
    // DURATION
    // ==================================================

    final recommendedDuration = _recommendedDuration(
      destination: destination,
      ages: travellerAges,
      travelType: travelType,
      groupSize: groupSize,
      transportation: transportation,
    );

    final recommendedMinimumDays = recommendedDuration['minimum']!;

    final recommendedMaximumDays = recommendedDuration['maximum']!;

    final durationIsTooShort = duration < recommendedMinimumDays;

    final durationIsTooLong = duration > recommendedMaximumDays;

    String durationMessage;

    if (durationIsTooShort) {
      durationMessage =
          'Your selected trip is $duration days, but $destination '
          'is better suited to approximately '
          '$recommendedMinimumDays–$recommendedMaximumDays days '
          'for your travel group using $transportation. '
          'A longer trip would provide a more comfortable pace.';
    } else if (durationIsTooLong) {
      durationMessage =
          'Your selected trip is $duration days, while $destination '
          'is generally suited to approximately '
          '$recommendedMinimumDays–$recommendedMaximumDays days. '
          'The additional time can be used to explore nearby destinations.';
    } else {
      durationMessage =
          'Your selected trip of $duration days fits well within '
          'the recommended $recommendedMinimumDays–'
          '$recommendedMaximumDays days for your travel group.';
    }

    const recommendedDurationTitle = 'Recommended Travel Duration';

    final recommendedDurationMessage =
        '$recommendedMinimumDays–$recommendedMaximumDays days';

    // ==================================================
    // SEASON
    // ==================================================

    if (suitability == 'Highly Suitable') {
      reasons.add('$season is a favorable season for $destination.');
    } else if (suitability == 'Less Suitable') {
      reasons.add(
        'The selected travel period may have challenging '
        'conditions for $destination.',
      );
    } else {
      reasons.add(
        'The selected season is generally suitable '
        'with proper planning.',
      );
    }

    // ==================================================
    // TRAVEL TYPE
    // ==================================================

    if (travelType == 'Solo') {
      reasons.add(
        'Solo travel allows greater flexibility and lets '
        'you maintain your own travel pace.',
      );
    } else {
      reasons.add(
        'Group travel may require additional time for '
        'coordination, transportation and shared activities.',
      );
    }

    // ==================================================
    // AGE
    // ==================================================

    if (travelType == 'Solo') {
      reasons.add(
        'Your age of $oldestAge years is considered when '
        'estimating a suitable travel pace.',
      );
    } else {
      reasons.add(
        'The ages of all travellers are considered when '
        'determining the recommended travel pace.',
      );

      reasons.add('The oldest traveller is $oldestAge years old.');
    }

    if (oldestAge <= 30) {
      reasons.add(
        'The age profile allows a relatively active travel '
        'pace when destination conditions permit.',
      );
    } else if (oldestAge <= 45) {
      reasons.add(
        'A balanced itinerary with reasonable activity levels '
        'is recommended for the age profile.',
      );
    } else if (oldestAge <= 60) {
      reasons.add(
        'Additional travel time and rest periods can make '
        'the journey more comfortable.',
      );
    } else {
      reasons.add(
        'A comfortable itinerary with manageable activity '
        'levels and additional rest time is recommended.',
      );
    }

    if (travelType == 'Group' && youngestAge != oldestAge) {
      reasons.add('The group age range is $youngestAge–$oldestAge years.');
    }

    // ==================================================
    // GROUP SIZE
    // ==================================================

    if (travelType == 'Solo') {
      reasons.add(
        'Travelling alone allows quicker decisions and '
        'greater flexibility.',
      );
    } else if (groupSize <= 4) {
      reasons.add(
        'A small group of $groupSize travellers can usually '
        'move efficiently.',
      );
    } else {
      reasons.add(
        'A group of $groupSize travellers may require '
        'additional coordination time.',
      );
    }

    // ==================================================
    // TRANSPORTATION
    // ==================================================

    reasons.add(
      '$transportation was selected as the preferred '
      'transportation method.',
    );

    if (transportation == 'Bus') {
      reasons.add(
        'Bus travel may require additional time on long '
        'or winding road routes.',
      );
    } else if (transportation == 'Flight') {
      reasons.add('Flight travel can reduce long-distance transfer time.');
    } else if (transportation == 'Jeep') {
      reasons.add('Jeep travel is useful for mountainous and remote areas.');
    } else if (transportation == 'Private Vehicle') {
      reasons.add('A private vehicle provides greater flexibility for stops.');
    } else if (transportation == 'Motorbike') {
      reasons.add('Motorbike travel provides flexibility on suitable roads.');
    } else if (transportation == 'Hybrid') {
      reasons.add(
        'Hybrid transportation allows different transport methods '
        'to be combined for different parts of the journey.',
      );
    }

    // ==================================================
    // DATA
    // ==================================================

    if (destinationPlaces.isEmpty) {
      reasons.add('More attraction data is needed for this destination.');
    }

    // ==================================================
    // BUDGET
    // ==================================================

    final dailyBase = _dailyBaseCost(destination);

    final transportationMultiplier = _transportationMultiplier(transportation);

    final groupFactor = travelType == 'Group' ? 0.90 : 1.0;

    final estimatedMinimumCost =
        dailyBase *
        duration *
        groupSize *
        transportationMultiplier *
        groupFactor;

    final budgetInNpr = _convertToNpr(budget, currency);

    final budgetIsLow = budgetInNpr < estimatedMinimumCost;

    String budgetMessage;

    if (budgetIsLow) {
      final difference = estimatedMinimumCost - budgetInNpr;

      budgetMessage =
          'Your budget may not be enough for this trip. '
          'The estimated minimum is around '
          'NPR ${estimatedMinimumCost.toStringAsFixed(0)}, '
          'while your budget is approximately '
          'NPR ${budgetInNpr.toStringAsFixed(0)}. '
          'You may need approximately '
          'NPR ${difference.toStringAsFixed(0)} more.';
    } else {
      budgetMessage =
          'Your budget appears reasonable for this trip. '
          'Actual costs may vary depending on accommodation, '
          'food, transportation and activities.';
    }

    // ==================================================
    // REMAINING DAYS
    // ==================================================

    final dayPlans = _createDayPlans(
      route: route,
      places: destinationPlaces,
      duration: duration,
    );

    final plannedPlaceNames = dayPlans
        .expand((dayPlan) => dayPlan.items)
        .where((item) => item.type == DayPlanItemType.attraction)
        .map((item) => item.title.toLowerCase())
        .toSet();

    final suggestedPlaces = destinationPlaces
        .where((place) => !plannedPlaceNames.contains(place.name.toLowerCase()))
        .map((place) => place.name)
        .toList();

    final additionalDestinations = _getAdditionalDestinations(
      destination: destination,
      duration: duration,
      routeDestinations: routeDestinations,
    );

    final usedDestinationDays = _destinationRecommendedDays(destination);

    final remainingDays = duration - usedDestinationDays;

    String remainingDaysMessage;

    if (remainingDays > 0 && additionalDestinations.isNotEmpty) {
      remainingDaysMessage =
          'You have approximately $remainingDays additional '
          'day(s). Consider adding ${additionalDestinations.join(', ')} '
          'to make better use of your trip.';
    } else if (remainingDays > 0 && suggestedPlaces.isNotEmpty) {
      remainingDaysMessage =
          'You have approximately $remainingDays additional '
          'day(s). Use them to explore the additional places suggested '
          'along your selected route.';
    } else if (remainingDays > 0) {
      remainingDaysMessage =
          'You have approximately $remainingDays additional day(s). '
          'Consider relaxing or adding local activities at your final stop.';
    } else {
      remainingDaysMessage =
          'Your selected duration can be used effectively for '
          'the main destination.';
    }

    for (final extraDestination in additionalDestinations) {
      reasons.add(
        '$extraDestination can be considered for the remaining '
        'time in your trip.',
      );
    }

    // ==================================================
    // SUMMARY
    // ==================================================

    String summary;

    if (destinationPlaces.isEmpty) {
      summary =
          'A $duration-day $travelType trip to $destination '
          'can be planned around your selected budget, '
          'transportation and travel dates.';
    } else if (durationIsTooShort) {
      summary =
          'Your $duration-day $travelType trip to $destination '
          'may be shorter than recommended for your travel group. '
          'A $recommendedMinimumDays–$recommendedMaximumDays day '
          'trip would provide a more comfortable pace.';
    } else if (additionalDestinations.isNotEmpty) {
      summary =
          'A $duration-day $travelType trip to $destination '
          'has been planned around your age profile, budget, '
          'transportation, season and available attractions. '
          'Additional destinations have been suggested for the '
          'remaining time.';
    } else if (routeDestinations.length > 1) {
      summary =
          'A $duration-day $travelType trip to $destination '
          'has been planned using your route through '
          '${routeDestinations.join(' → ')}, along with your group ages, '
          'budget, transportation preference and season.';
    } else {
      summary =
          'A $duration-day $travelType trip to $destination '
          'has been planned around your group ages, budget, '
          'transportation preference, season and attractions.';
    }

    return TripRecommendation(
      recommendedDurationTitle: recommendedDurationTitle,
      recommendedDurationMessage: recommendedDurationMessage,
      title: '$destination Trip Recommendation',
      summary: summary,
      suggestedPlaces: suggestedPlaces,
      routeDestinations: routeDestinations,
      reasons: reasons,
      dayPlans: dayPlans,
      estimatedMinimumCost: estimatedMinimumCost,
      budgetIsLow: budgetIsLow,
      budgetMessage: budgetMessage,
      recommendedMinimumDays: recommendedMinimumDays,
      recommendedMaximumDays: recommendedMaximumDays,
      durationIsTooShort: durationIsTooShort,
      durationIsTooLong: durationIsTooLong,
      durationMessage: durationMessage,
      additionalDestinations: additionalDestinations,
      remainingDaysMessage: remainingDaysMessage,
    );
  }

  // ==================================================
  // ROUTE-BASED PLACES
  // ==================================================

  static List<String> _routeDestinations(
    TravelRoute route,
    String selectedDestination,
  ) {
    final destinations = <String>[
      route.boardingPoint,
      ...route.segments.map((segment) => segment.to),
      route.destination,
      selectedDestination,
    ];

    final seen = <String>{};

    return destinations.where((destination) {
      final normalizedDestination = destination.trim().toLowerCase();

      return normalizedDestination.isNotEmpty &&
          seen.add(normalizedDestination);
    }).toList();
  }

  static String _routeTransportation(TravelRoute route) {
    final methods = route.segments
        .map((segment) => segment.transportation)
        .toSet();

    if (methods.length != 1) return 'Hybrid';
    return methods.single;
  }

  static List<Place> _placesForDestinations(List<String> destinations) {
    final places = <Place>[];
    final addedPlaceNames = <String>{};

    for (final destination in destinations) {
      for (final place in nepalPlaces.where(
        (place) => place.location.toLowerCase() == destination.toLowerCase(),
      )) {
        if (addedPlaceNames.add(place.name.toLowerCase())) {
          places.add(place);
        }
      }
    }

    return places;
  }

  // ==================================================
  // RECOMMENDED DURATION
  // ==================================================

  static Map<String, int> _recommendedDuration({
    required String destination,
    required List<int> ages,
    required String travelType,
    required int groupSize,
    required String transportation,
  }) {
    final travellerAges = ages.isEmpty ? [18] : ages;

    final oldestAge = travellerAges.reduce((a, b) => a > b ? a : b);

    int minimum;
    int maximum;

    if (destination == 'Mustang') {
      if (oldestAge <= 30) {
        minimum = 4;
        maximum = 5;
      } else if (oldestAge <= 45) {
        minimum = 5;
        maximum = 6;
      } else if (oldestAge <= 60) {
        minimum = 6;
        maximum = 7;
      } else {
        minimum = 7;
        maximum = 9;
      }
    } else if (destination == 'Everest') {
      if (oldestAge <= 30) {
        minimum = 7;
        maximum = 10;
      } else if (oldestAge <= 45) {
        minimum = 8;
        maximum = 11;
      } else if (oldestAge <= 60) {
        minimum = 10;
        maximum = 13;
      } else {
        minimum = 12;
        maximum = 15;
      }
    } else if (destination == 'Annapurna') {
      if (oldestAge <= 30) {
        minimum = 5;
        maximum = 7;
      } else if (oldestAge <= 45) {
        minimum = 6;
        maximum = 8;
      } else if (oldestAge <= 60) {
        minimum = 7;
        maximum = 9;
      } else {
        minimum = 8;
        maximum = 10;
      }
    } else if (destination == 'Pokhara') {
      if (oldestAge <= 30) {
        minimum = 2;
        maximum = 3;
      } else if (oldestAge <= 45) {
        minimum = 3;
        maximum = 4;
      } else if (oldestAge <= 60) {
        minimum = 3;
        maximum = 5;
      } else {
        minimum = 4;
        maximum = 5;
      }
    } else if (destination == 'Chitwan') {
      if (oldestAge <= 30) {
        minimum = 2;
        maximum = 3;
      } else if (oldestAge <= 45) {
        minimum = 2;
        maximum = 4;
      } else if (oldestAge <= 60) {
        minimum = 3;
        maximum = 4;
      } else {
        minimum = 3;
        maximum = 5;
      }
    } else {
      if (oldestAge <= 30) {
        minimum = 2;
        maximum = 3;
      } else if (oldestAge <= 45) {
        minimum = 2;
        maximum = 4;
      } else if (oldestAge <= 60) {
        minimum = 3;
        maximum = 4;
      } else {
        minimum = 3;
        maximum = 5;
      }
    }

    if (travelType == 'Group') {
      minimum += 1;
      maximum += 1;
    }

    if (groupSize >= 8) {
      minimum += 1;
      maximum += 1;
    }

    final transportAdjustment = _transportationDurationAdjustment(
      destination: destination,
      transportation: transportation,
    );

    minimum += transportAdjustment;
    maximum += transportAdjustment;

    if (minimum < 1) {
      minimum = 1;
    }

    if (maximum < minimum) {
      maximum = minimum;
    }

    return {'minimum': minimum, 'maximum': maximum};
  }

  // ==================================================
  // TRANSPORT DURATION
  // ==================================================

  static int _transportationDurationAdjustment({
    required String destination,
    required String transportation,
  }) {
    final mountainDestination =
        destination == 'Mustang' ||
        destination == 'Everest' ||
        destination == 'Annapurna';

    switch (transportation) {
      case 'Flight':
        return mountainDestination ? -1 : 0;

      case 'Bus':
        if (mountainDestination ||
            destination == 'Pokhara' ||
            destination == 'Chitwan') {
          return 1;
        }
        return 0;

      case 'Jeep':
        return mountainDestination ? 1 : 0;

      case 'Motorbike':
        if (destination == 'Mustang' || destination == 'Annapurna') {
          return 1;
        }
        return 0;

      case 'Hybrid':
        return 0;

      case 'Private Vehicle':
      default:
        return 0;
    }
  }

  // ==================================================
  // DESTINATION DAYS
  // ==================================================

  static int _destinationRecommendedDays(String destination) {
    switch (destination) {
      case 'Mustang':
        return 5;

      case 'Everest':
        return 10;

      case 'Annapurna':
        return 7;

      case 'Pokhara':
        return 3;

      case 'Chitwan':
        return 3;

      case 'Kathmandu':
      default:
        return 3;
    }
  }

  // ==================================================
  // ADDITIONAL DESTINATIONS
  // ==================================================

  static List<String> _getAdditionalDestinations({
    required String destination,
    required int duration,
    required List<String> routeDestinations,
  }) {
    final requiredDays = _destinationRecommendedDays(destination);

    if (duration <= requiredDays) {
      return [];
    }

    final remainingDays = duration - requiredDays;

    final suggestions = <String>[];

    switch (destination) {
      case 'Mustang':
        if (remainingDays >= 2) {
          suggestions.add('Pokhara');
        }

        if (remainingDays >= 4) {
          suggestions.add('Kathmandu');
        }
        break;

      case 'Pokhara':
        if (remainingDays >= 2) {
          suggestions.add('Chitwan');
        }

        if (remainingDays >= 4) {
          suggestions.add('Kathmandu');
        }
        break;

      case 'Chitwan':
        if (remainingDays >= 2) {
          suggestions.add('Pokhara');
        }

        if (remainingDays >= 4) {
          suggestions.add('Kathmandu');
        }
        break;

      case 'Kathmandu':
        if (remainingDays >= 2) {
          suggestions.add('Pokhara');
        }

        if (remainingDays >= 4) {
          suggestions.add('Chitwan');
        }
        break;

      case 'Annapurna':
        if (remainingDays >= 2) {
          suggestions.add('Pokhara');
        }
        break;

      case 'Everest':
        if (remainingDays >= 2) {
          suggestions.add('Kathmandu');
        }
        break;
    }

    final routeDestinationNames = routeDestinations
        .map((routeDestination) => routeDestination.toLowerCase())
        .toSet();

    return suggestions
        .where(
          (suggestion) =>
              !routeDestinationNames.contains(suggestion.toLowerCase()),
        )
        .toList();
  }

  // ==================================================
  // DAILY COST
  // ==================================================

  static double _dailyBaseCost(String destination) {
    switch (destination) {
      case 'Mustang':
        return 3500;

      case 'Everest':
        return 5000;

      case 'Annapurna':
        return 4000;

      case 'Chitwan':
        return 3000;

      case 'Pokhara':
        return 2800;

      case 'Kathmandu':
      default:
        return 2200;
    }
  }

  // ==================================================
  // TRANSPORT COST
  // ==================================================

  static double _transportationMultiplier(String transportation) {
    switch (transportation) {
      case 'Flight':
        return 1.8;

      case 'Private Vehicle':
        return 1.35;

      case 'Jeep':
        return 1.30;

      case 'Motorbike':
        return 1.10;

      case 'Hybrid':
        return 1.45;

      case 'Bus':
      default:
        return 1.0;
    }
  }

  // ==================================================
  // CURRENCY
  // ==================================================

  static double _convertToNpr(double amount, String currency) {
    switch (currency) {
      case 'USD':
        return amount * 140;

      case 'INR':
        return amount * 1.60;

      case 'EUR':
        return amount * 160;

      case 'GBP':
        return amount * 185;

      case 'NPR':
      default:
        return amount;
    }
  }

  // ==================================================
  // DAY PLANS
  // ==================================================

  static List<DayPlan> _createDayPlans({
    required TravelRoute route,
    required List<Place> places,
    required int duration,
  }) {
    if (duration <= 0) {
      return [];
    }

    final plans = <DayPlan>[];

    final plannedPlaceNames = <String>{};
    var segmentIndex = 0;

    for (var day = 1; day <= duration; day++) {
      final items = <DayPlanItem>[];

      if (segmentIndex < route.segments.length) {
        final segment = route.segments[segmentIndex];
        items.add(
          DayPlanItem.travel(
            title: '${segment.from} → ${segment.to}',
            subtitle: segment.transportation,
          ),
        );
        segmentIndex++;

        // If the trip has more segments than days, keep the remaining travel
        // visible on the final day instead of silently dropping it.
        if (day == duration) {
          while (segmentIndex < route.segments.length) {
            final remainingSegment = route.segments[segmentIndex];
            items.add(
              DayPlanItem.travel(
                title: '${remainingSegment.from} → ${remainingSegment.to}',
                subtitle: remainingSegment.transportation,
              ),
            );
            segmentIndex++;
          }
        }

        final stopPlaces = _placesForStop(
          places: places,
          stop: segment.to,
          plannedPlaceNames: plannedPlaceNames,
          maximumPlaces: 2,
        );

        for (final place in stopPlaces) {
          items.add(
            DayPlanItem.attraction(title: place.name, subtitle: place.location),
          );
        }
      } else {
        final finalStop = route.segments.isEmpty
            ? route.destination
            : route.segments.last.to;
        final remainingPlaces = _placesForStop(
          places: places,
          stop: finalStop,
          plannedPlaceNames: plannedPlaceNames,
          maximumPlaces: 3,
        );

        if (remainingPlaces.isEmpty) {
          continue;
        }

        final remainingDays = duration - day + 1;
        final placesForToday = (remainingPlaces.length / remainingDays)
            .ceil()
            .clamp(1, 3);

        for (final place in remainingPlaces.take(placesForToday)) {
          items.add(
            DayPlanItem.attraction(title: place.name, subtitle: place.location),
          );
        }
      }

      if (items.isNotEmpty) {
        plans.add(DayPlan(day: day, items: items));
      }
    }

    return plans;
  }

  static List<Place> _placesForStop({
    required List<Place> places,
    required String stop,
    required Set<String> plannedPlaceNames,
    required int maximumPlaces,
  }) {
    final matchingPlaces = places
        .where(
          (place) =>
              place.location.toLowerCase() == stop.toLowerCase() &&
              !plannedPlaceNames.contains(place.name.toLowerCase()),
        )
        .take(maximumPlaces)
        .toList();

    for (final place in matchingPlaces) {
      plannedPlaceNames.add(place.name.toLowerCase());
    }

    return matchingPlaces;
  }
}
