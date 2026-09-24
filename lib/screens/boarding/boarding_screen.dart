import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../theme/app_theme.dart';
import '../../models/journey_stop_plan.dart';
import '../../models/travel_route_model.dart';
import '../../data/transportation_data.dart';
import '../../services/recommendation_service.dart';
import '../../services/trip_cost_estimator.dart';
import '../../widgets/yatra_components.dart';
import '../recommendation/recommendation_screen.dart';

class BoardingScreen extends StatefulWidget {
  final String touristType;
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final String season;
  final String suitability;
  final String currency;
  final double budget;
  final List<int> ages;
  final int adultCount;
  final int childCount;
  final String travelType;
  final int groupSize;
  final String seasonMessage;

  /// Transportation selected on the previous Transportation screen.
  final String? selectedTransport;

  const BoardingScreen({
    super.key,
    required this.touristType,
    required this.destination,
    this.selectedTransport,
    required this.departureDate,
    required this.returnDate,
    required this.season,
    required this.suitability,
    required this.currency,
    required this.budget,
    required this.ages,
    required this.adultCount,
    required this.childCount,
    required this.travelType,
    required this.groupSize,
    required this.seasonMessage,
  });

  @override
  State<BoardingScreen> createState() => _BoardingScreenState();
}

class _BoardingScreenState extends State<BoardingScreen> {
  Position? currentPosition;
  bool isLoadingCurrentLOcation = false;
  String? selectedBoardingPoint;
  String? selectedNextPoint;

  /// True when the selected destination is being explored locally.
  bool exploreLocally = false;

  /// Transportation used to move around the destination locally.
  String? selectedLocalTransportation;

  // Transportation for the currently pending outgoing leg.
  String? selectedTransportation;

  // Destination for the currently pending customized return leg.
  String? selectedReturnNextPoint;

  // Transportation for the currently pending return leg.
  String? selectedReturnTransportation;

  /// By default, a round trip automatically mirrors the completed
  /// outgoing route in reverse order. The user can optionally customize
  /// the transportation used on each return leg.
  bool customizeReturnRoute = false;

  TripDirection selectedTripDirection = TripDirection.oneWay;

  /// Extra exploration days requested per intermediate stop, keyed by the
  /// stop's display name. Fed into TravelRoute.stopPlans so the day planner
  /// reserves time slots and the minimum-days check accounts for them.
  final Map<String, int> stopExplorationDays = {};

  /// Extra exploration days chosen for stops on the return journey, keyed by
  /// the stop's display name. Fed into TravelRoute.returnStopPlans so the
  /// estimator and day planner treat them like any other stay, but placed
  /// chronologically between the return legs. Works for BOTH an automatic
  /// (reversed) return and a customized one: the value is taken from the
  /// resolved return route, never from a hard-coded destination list.
  final Map<String, int> returnStopExplorationDays = {};

  // ============================================================
  // LOCAL TRANSPORTATION
  // ============================================================

  static const List<_LocalTransportationOption> localTransportationOptions = [
    _LocalTransportationOption(
      name: 'Walking',
      icon: Icons.directions_walk,
      description: 'Explore nearby attractions on foot',
      details: 'Best for short distances and walking-friendly areas',
    ),
    _LocalTransportationOption(
      name: 'Local Bus',
      icon: Icons.directions_bus,
      description: 'Use local public bus services',
      details: 'Budget-friendly option for longer local journeys',
    ),
    _LocalTransportationOption(
      name: 'Taxi',
      icon: Icons.local_taxi,
      description: 'Travel between attractions by taxi',
      details: 'Convenient and flexible for local sightseeing',
    ),
    _LocalTransportationOption(
      name: 'Motorbike',
      icon: Icons.two_wheeler,
      description: 'Explore locally by motorbike',
      details: 'Suitable for experienced riders',
    ),
    _LocalTransportationOption(
      name: 'Private Vehicle',
      icon: Icons.directions_car,
      description: 'Travel in a private car or vehicle',
      details: 'Comfortable option for families and groups',
    ),
  ];

  // ============================================================
  // OUTGOING ROUTE
  // ============================================================

  final List<RouteSegment> segments = [];

  // ============================================================
  // RETURN ROUTE
  // ============================================================

  final List<RouteSegment> returnSegments = [];

  // ============================================================
  // ALL LOCATIONS
  // ============================================================

  final List<String> locations = [
    'Kathmandu',
    'Pokhara',
    'Chitwan',
    'Jomsom',
    'Marpha',
    'Kagbeni',
    'Muktinath',
    'Mustang',
    'Lukla',
    'Namche Bazaar',
    'Ghandruk',
    'Poon Hill',
    'Annapurna',
    'Everest',
    'Tansen',
    'Rasuwa',
  ];

  // ============================================================
  // DESTINATION-SPECIFIC ROUTES
  // ============================================================

  final Map<String, Map<String, List<String>>> destinationRoutes = {
    'Mustang': {
      'Kathmandu': ['Pokhara', 'Jomsom', 'Kagbeni', 'Mustang'],
      'Pokhara': ['Jomsom', 'Kagbeni', 'Mustang'],
      'Jomsom': ['Marpha', 'Kagbeni', 'Mustang'],
      'Marpha': ['Kagbeni', 'Mustang'],
      'Kagbeni': ['Muktinath', 'Mustang'],
    },

    'Annapurna': {
      'Kathmandu': ['Pokhara', 'Ghandruk', 'Poon Hill', 'Annapurna'],
      'Pokhara': ['Ghandruk', 'Poon Hill', 'Annapurna'],
      'Ghandruk': ['Poon Hill', 'Annapurna'],
      'Poon Hill': ['Annapurna'],
    },

    'Everest': {
      'Kathmandu': ['Lukla', 'Namche Bazaar', 'Everest'],
      'Lukla': ['Namche Bazaar', 'Everest'],
      'Namche Bazaar': ['Everest'],
    },

    'Pokhara': {
      'Kathmandu': ['Pokhara'],
      'Chitwan': ['Pokhara'],
      'Tansen': ['Pokhara'],
    },

    'Chitwan': {
      'Kathmandu': ['Chitwan'],
      'Pokhara': ['Chitwan'],
      'Tansen': ['Chitwan'],
    },

    'Kathmandu': {
      'Pokhara': ['Kathmandu'],
      'Chitwan': ['Kathmandu'],
      'Tansen': ['Kathmandu'],
      'Rasuwa': ['Kathmandu'],
      'Lukla': ['Kathmandu'],
    },

    'Tansen': {
      'Kathmandu': ['Tansen'],
      'Pokhara': ['Tansen'],
      'Chitwan': ['Tansen'],
    },
  };

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    /*
 * Carry the transportation selection from the previous
 * Transportation screen into the Route Builder.
 *
 * Kathmandu, Pokhara and Chitwan support local exploration.
 */
    exploreLocally = isLocalExplorationOption(
      widget.destination,
      widget.selectedTransport,
    );
  }

  // ============================================================
  // NORMALIZE
  // ============================================================

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  String? _preferredTransportationForRoute(String from, String to) {
    final preferred = widget.selectedTransport?.trim();

    if (preferred == null || preferred.isEmpty) {
      return null;
    }

    final options = transportOptionsForRoute(from, to);

    for (final routeTransport in options) {
      if (_normalize(routeTransport.option.name) == _normalize(preferred)) {
        return routeTransport.option.name;
      }
    }
    return null;
  }

  // ============================================================
  // LOCAL EXPLORATION
  // ============================================================

  bool get supportsLocalExploration {
    final destination = _normalize(widget.destination);

    return destination == 'kathmandu' ||
        destination == 'pokhara' ||
        destination == 'chitwan';
  }

  bool get isLocalExploration {
    return supportsLocalExploration && exploreLocally;
  }

  String get localDestinationName {
    final destination = widget.destination.trim();

    if (_normalize(destination) == 'kathmandu') {
      return 'Kathmandu';
    }

    if (_normalize(destination) == 'pokhara') {
      return 'Pokhara';
    }

    if (_normalize(destination) == 'chitwan') {
      return 'Chitwan';
    }

    return destination;
  }

  IconData get localDestinationIcon {
    switch (_normalize(widget.destination)) {
      case 'kathmandu':
        return Icons.location_city;

      case 'pokhara':
        return Icons.landscape_outlined;

      case 'chitwan':
        return Icons.forest_outlined;

      default:
        return Icons.explore_outlined;
    }
  }

  String get localDescription {
    switch (_normalize(widget.destination)) {
      case 'kathmandu':
        return 'Explore Kathmandu and nearby Kathmandu Valley '
            'attractions without travelling to another city.';

      case 'pokhara':
        return 'Explore Pokhara and nearby attractions without '
            'travelling to another city.';

      case 'chitwan':
        return 'Explore Chitwan and nearby attractions without '
            'travelling to another city.';

      default:
        return 'Explore local attractions without travelling '
            'to another destination.';
    }
  }

  String get localPlacesHint {
    switch (_normalize(widget.destination)) {
      case 'kathmandu':
        return 'Kathmandu Durbar Square, Swayambhunath, '
            'Pashupatinath, Boudhanath and more.';

      case 'pokhara':
        return 'Phewa Lake, Davis Falls, World Peace Pagoda, '
            'Sarangkot and more.';

      case 'chitwan':
        return 'Chitwan National Park, Sauraha, Rapti River, '
            'Tharu culture and more.';

      default:
        return 'Explore recommended local attractions.';
    }
  }

  // ============================================================
  // CURRENT OUTGOING LOCATION
  // ============================================================

  String? get currentLocation {
    if (segments.isEmpty) {
      return selectedBoardingPoint;
    }

    return segments.last.to;
  }

  // ============================================================
  // CURRENT RETURN LOCATION
  // ============================================================

  String? get currentReturnLocation {
    if (returnSegments.isEmpty) {
      return widget.destination;
    }

    return returnSegments.last.to;
  }

  /// Stops reached on the return journey (every `segment.to` of the actual
  /// return route, excluding the original boarding point / final endpoint).
  ///
  /// The return route is derived from the user's real route data: the custom
  /// legs while a custom return is being built, otherwise the automatic
  /// reversed outgoing route. No destination names are hard-coded here.
  List<String> get _returnArrivalStops {
    if (isLocalExploration ||
        selectedTripDirection != TripDirection.roundTrip ||
        segments.isEmpty) {
      return const [];
    }

    final boarding = selectedBoardingPoint;

    final List<String> arrivals;
    if (customizeReturnRoute) {
      arrivals = [for (final segment in returnSegments) segment.to];
    } else {
      // Automatic return reverses the outgoing route, so the arrivals are the
      // outbound points (excluding the boarding point) in reverse order.
      final points = <String>[
        segments.first.from,
        ...segments.map((segment) => segment.to),
      ];
      arrivals = points.reversed.skip(1).toList();
    }

    return [
      for (final stop in arrivals)
        if (boarding != null && _normalize(stop) != _normalize(boarding)) stop,
    ];
  }

  /// Exploration plans for stops reached on the return journey, in the order
  /// the route visits them. The return route is the actual one being planned:
  /// the explicit custom legs when the traveller is building a custom return,
  /// otherwise the automatic reversed outbound route. Return stops default to
  /// zero days and only count once the traveller raises the stepper; the
  /// boarding point is never a stop plan.
  List<JourneyStopPlan> get _returnStopPlans {
    final result = <JourneyStopPlan>[];

    for (final stop in _returnArrivalStops) {
      final days = returnStopExplorationDays[stop] ?? 0;
      if (days <= 0) {
        continue;
      }

      result.add(JourneyStopPlan(location: stop, explorationDays: days));
    }

    return result;
  }

  /// Minimum days the selected round trip requires, or null when the duration
  /// check does not apply (one-way trips and local exploration).
  ///
  /// The minimum counts outbound travel, outbound exploration, the destination
  /// stay, return travel and return-stop exploration. It applies to BOTH the
  /// automatic (reversed) return route and a customized one, so a round trip
  /// never starts with a calendar too short to cover the return journey.
  int? get _minimumNeedDays {
    if (selectedTripDirection != TripDirection.roundTrip ||
        !routeComplete ||
        !returnRouteComplete) {
      return null;
    }

    return RecommendationService.minimumDaysFor(route: buildRoute());
  }

  /// True when the user's selected calendar dates are shorter than what the
  /// round trip (including return-stop stays) needs.
  bool get _durationTooShort {
    final minimum = _minimumNeedDays;
    if (minimum == null) {
      return false;
    }
    return _tripDuration < minimum;
  }

  // ============================================================
  // ACTIVE ROUTE MAP
  // ============================================================

  Map<String, List<String>> get activeRouteMap {
    final destinationKey = widget.destination.trim();

    if (destinationRoutes.containsKey(destinationKey)) {
      return destinationRoutes[destinationKey]!;
    }

    for (final entry in destinationRoutes.entries) {
      if (_normalize(entry.key) == _normalize(widget.destination)) {
        return entry.value;
      }
    }

    return {};
  }

  // ============================================================
  // CAN REACH DESTINATION
  // ============================================================

  bool _canReachDestination(String start, String destination) {
    final routeMap = activeRouteMap;
    final visited = <String>{};
    final queue = <String>[start];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (_normalize(current) == _normalize(destination)) {
        return true;
      }

      final normalizedCurrent = _normalize(current);

      if (visited.contains(normalizedCurrent)) {
        continue;
      }

      visited.add(normalizedCurrent);

      final next = routeMap[current] ?? [];

      for (final location in next) {
        if (!visited.contains(_normalize(location))) {
          queue.add(location);
        }
      }
    }

    return false;
  }

  // ============================================================
  // BOARDING POINTS
  // ============================================================

  List<String> get boardingPoints {
    final result = <String>[];

    for (final location in locations) {
      if (_normalize(location) == _normalize(widget.destination)) {
        continue;
      }

      if (_canReachDestination(location, widget.destination)) {
        result.add(location);
      }
    }

    result.sort();

    return result;
  }

  // ============================================================
  // NEXT OUTGOING LOCATIONS
  // ============================================================

  List<String> get nextLocations {
    final current = currentLocation;

    if (current == null) {
      return [];
    }

    final routeMap = activeRouteMap;

    final possible = <String>[...(routeMap[current] ?? [])];

    // Destination fallback.
    if (_normalize(current) != _normalize(widget.destination) &&
        _canReachDestination(current, widget.destination) &&
        !possible.any(
          (location) => _normalize(location) == _normalize(widget.destination),
        )) {
      final directDestination = locations.firstWhere(
        (location) => _normalize(location) == _normalize(widget.destination),
        orElse: () => widget.destination,
      );

      if (possible.isEmpty) {
        possible.add(directDestination);
      }
    }

    // Remove current location.
    possible.removeWhere(
      (location) => _normalize(location) == _normalize(current),
    );

    // Remove locations already used.
    possible.removeWhere(
      (location) => segments.any(
        (segment) =>
            _normalize(segment.from) == _normalize(location) ||
            _normalize(segment.to) == _normalize(location),
      ),
    );

    // Safety filter.
    possible.removeWhere(
      (location) => !_canReachDestination(location, widget.destination),
    );

    return possible;
  }

  // ============================================================
  // OUTGOING ROUTE COMPLETE
  // ============================================================

  bool get routeComplete {
    // Local exploration requires only a local transportation choice.
    if (isLocalExploration) {
      return selectedLocalTransportation != null;
    }

    return currentLocation != null &&
        _normalize(currentLocation!) == _normalize(widget.destination) &&
        segments.isNotEmpty;
  }

  // ============================================================
  // RETURN ROUTE COMPLETE
  // ============================================================

  bool get returnRouteComplete {
    // Local exploration does not have a return route.
    if (isLocalExploration) {
      return true;
    }

    if (selectedTripDirection == TripDirection.oneWay) {
      return true;
    }

    if (!routeComplete || selectedBoardingPoint == null) {
      return false;
    }

    // Normal round-trip behavior:
    // TravelRoute can automatically derive a complete return journey by
    // reversing the outgoing segments and reusing their transportation.
    if (!customizeReturnRoute) {
      return true;
    }

    // When the user chooses to customize the return journey, the explicit
    // return route must be completed all the way back to the boarding point.
    if (returnSegments.isEmpty) {
      return false;
    }

    return _normalize(returnSegments.last.to) ==
        _normalize(selectedBoardingPoint!);
  }

  // ============================================================
  // RETURN DESTINATION OPTIONS
  // ============================================================

  /// Next return destinations available from the current return location.
  ///
  /// Choices come from the actual route transportation database (places
  /// directly connected to the current stop) rather than from the reversed
  /// outgoing route. This lets the user add stops — like Kagbeni or Jomsom
  /// on the Mustang route — that were never part of the outbound journey,
  /// and it matches how every return leg is validated when the leg is built.
  List<String> get returnDestinationOptions {
    final current = currentReturnLocation;
    final boarding = selectedBoardingPoint;

    if (!customizeReturnRoute || current == null || boarding == null) {
      return [];
    }

    // Locations already visited on the return journey, plus the current
    // stop itself, are not offered again to avoid looping.
    final used = <String>{};
    for (final segment in returnSegments) {
      used.add(segment.from);
      used.add(segment.to);
    }

    final result = <String>[];

    for (final place in connectedDestinationsFrom(current)) {
      if (_normalize(place) == _normalize(current)) {
        continue;
      }

      if (used.any((entry) => _normalize(entry) == _normalize(place))) {
        continue;
      }

      result.add(place);
    }

    result.sort();

    return result;
  }

  // ============================================================
  // SELECT LOCAL EXPLORATION
  // ============================================================

  void _selectLocalExploration() {
    setState(() {
      exploreLocally = true;

      selectedBoardingPoint = null;
      selectedNextPoint = null;
      selectedLocalTransportation = null;
      selectedTransportation = null;
      selectedReturnNextPoint = null;
      selectedReturnTransportation = null;

      segments.clear();
      returnSegments.clear();
      returnStopExplorationDays.clear();
      customizeReturnRoute = false;

      selectedTripDirection = TripDirection.oneWay;
    });
  }

  // ============================================================
  // SELECT NORMAL ROUTE
  // ============================================================

  void _selectNormalRoute() {
    setState(() {
      exploreLocally = false;

      selectedBoardingPoint = null;
      selectedNextPoint = null;
      selectedLocalTransportation = null;
      selectedTransportation = null;
      selectedReturnNextPoint = null;
      selectedReturnTransportation = null;

      segments.clear();
      returnSegments.clear();
      returnStopExplorationDays.clear();
      customizeReturnRoute = false;

      selectedTripDirection = TripDirection.oneWay;
    });
  }

  // ============================================================
  // SELECT BOARDING POINT
  // ============================================================

  void _selectBoardingPoint(String? value) {
    setState(() {
      exploreLocally = false;

      selectedBoardingPoint = value;
      selectedNextPoint = null;
      selectedLocalTransportation = null;
      selectedTransportation = null;
      selectedReturnNextPoint = null;
      selectedReturnTransportation = null;

      // The trip type is intentionally NOT reset here: choosing a boarding
      // point rebuilds the route but must preserve the traveller's One Way /
      // Round Trip decision made earlier on the screen.

      segments.clear();
      returnSegments.clear();
      returnStopExplorationDays.clear();
      customizeReturnRoute = false;
    });
  }

  // ============================================================
  // SELECT NEXT LOCATION
  // ============================================================

  void _selectNextPoint(String? value) {
    setState(() {
      selectedNextPoint = value;

      // Transportation is selected only after the next
      // destination has been chosen.
      selectedTransportation = value == null
          ? null
          : _preferredTransportationForRoute(currentLocation!, value);
    });
  }

  // ============================================================
  // ADD OUTGOING LEG
  // ============================================================

  void _addRouteLeg() {
    if (currentLocation == null ||
        selectedNextPoint == null ||
        selectedTransportation == null) {
      return;
    }

    setState(() {
      segments.add(
        RouteSegment(
          from: currentLocation!,
          to: selectedNextPoint!,
          transportation: selectedTransportation!,
        ),
      );

      selectedNextPoint = null;
      selectedTransportation = null;

      // Rebuild the automatic return route when the outgoing route changes.
      returnSegments.clear();
      returnStopExplorationDays.clear();
      customizeReturnRoute = false;
    });
  }

  // ============================================================
  // SELECT RETURN DESTINATION
  // ============================================================

  void _selectReturnNextPoint(String? value) {
    setState(() {
      selectedReturnNextPoint = value;
      selectedReturnTransportation = null;
    });
  }

  // ============================================================
  // ADD RETURN LEG
  // ============================================================

  void _addReturnLeg() {
    final from = currentReturnLocation;
    final to = selectedReturnNextPoint;

    if (from == null || to == null || selectedReturnTransportation == null) {
      return;
    }

    setState(() {
      returnSegments.add(
        RouteSegment(
          from: from,
          to: to,
          transportation: selectedReturnTransportation!,
        ),
      );

      selectedReturnNextPoint = null;
      selectedReturnTransportation = null;
    });
  }

  // ============================================================
  // REMOVE OUTGOING LEG
  // ============================================================

  void _removeLastLeg() {
    if (segments.isEmpty) {
      return;
    }

    setState(() {
      segments.removeLast();

      selectedNextPoint = null;
      selectedTransportation = null;

      returnSegments.clear();
      returnStopExplorationDays.clear();
      customizeReturnRoute = false;
    });
  }

  // ============================================================
  // REMOVE RETURN LEG
  // ============================================================

  /// Removes the return leg at [index] together with every downstream leg.
  ///
  /// Removing an earlier stop makes all later return segments invalid (they
  /// branch from the removed stop), so the whole tail of the return route is
  /// reset cleanly instead of leaving a dangling route behind.
  void _removeReturnStop(int index) {
    if (index < 0 || index >= returnSegments.length) {
      return;
    }

    setState(() {
      final removed = returnSegments.sublist(index);

      for (final leg in removed) {
        returnStopExplorationDays.remove(leg.to);
      }

      returnSegments.removeRange(index, returnSegments.length);
      selectedReturnNextPoint = null;
      selectedReturnTransportation = null;
    });
  }

  // ============================================================
  // SELECT TRIP DIRECTION
  // ============================================================

  void _selectTripDirection(TripDirection direction) {
    setState(() {
      selectedTripDirection = direction;
      returnSegments.clear();
      returnStopExplorationDays.clear();
      selectedReturnNextPoint = null;
      selectedReturnTransportation = null;
      customizeReturnRoute = false;
    });
  }

  // ============================================================
  // CUSTOMIZE RETURN ROUTE
  // ============================================================

  void _startReturnCustomization() {
    setState(() {
      customizeReturnRoute = true;
      returnSegments.clear();
      returnStopExplorationDays.clear();
      selectedReturnNextPoint = null;
      selectedReturnTransportation = null;
    });
  }

  void _useAutomaticReturnRoute() {
    setState(() {
      customizeReturnRoute = false;
      returnSegments.clear();
      returnStopExplorationDays.clear();
      selectedReturnNextPoint = null;
      selectedReturnTransportation = null;
    });
  }

  // ============================================================
  // CONTINUE
  // ============================================================

  // ============================================================
  // RELATED: Build Route
  // ============================================================

  /// All destinations arrived at along the completed outgoing route — every
  /// `segment.to`, excluding the original boarding point. The final
  /// destination is included because it is a stay/arrival like any other.
  ///
  /// The list is derived purely from the actual route segments, so it works
  /// generically for every destination Yatra supports. Outbound exploration
  /// is independent of the trip direction: the same stops are offered for
  /// both one-way and round trips.
  List<String> get _goingStops {
    if (isLocalExploration || segments.isEmpty) {
      return const [];
    }

    final boarding = selectedBoardingPoint;

    return [
      for (final segment in segments)
        if (boarding != null && _normalize(segment.to) != _normalize(boarding))
          segment.to,
    ];
  }

  /// Exploration plans for outbound arrivals, in the order the route reaches
  /// them. EVERY arrival — including the final destination — becomes a stop
  /// plan, so a stay at any point of the journey is possible and existing
  /// cost / duration logic applies unchanged. Stops default to zero days
  /// (pass-through) and are ignored until the traveller raises the stepper.
  List<JourneyStopPlan> get _stopPlans {
    return _goingStops
        .map(
          (stop) => JourneyStopPlan(
            location: stop,
            explorationDays: stopExplorationDays[stop] ?? 0,
          ),
        )
        .toList();
  }

  TravelRoute buildRoute() {
    if (isLocalExploration) {
      return TravelRoute(
        boardingPoint: localDestinationName,
        destination: localDestinationName,
        segments: const [],
        localTransportation: selectedLocalTransportation,
        tripDirection: TripDirection.oneWay,
      );
    }

    return TravelRoute(
      boardingPoint: segments.first.from,
      destination: widget.destination,
      segments: List<RouteSegment>.from(segments),
      tripDirection: selectedTripDirection,
      returnSegments:
          selectedTripDirection == TripDirection.roundTrip &&
              customizeReturnRoute &&
              returnSegments.isNotEmpty
          ? List<RouteSegment>.from(returnSegments)
          : null,
      stopPlans: _stopPlans,
      returnStopPlans: _returnStopPlans,
    );
  }

  // ============================================================
  // LIVE ROUTE COST SUMMARY
  // ============================================================

  int get _tripDuration {
    final days = widget.returnDate.difference(widget.departureDate).inDays + 1;
    return days > 0 ? days : 1;
  }

  TripCostEstimate? get _routeEstimate {
    if (!routeComplete) {
      return null;
    }

    return TripCostEstimator.estimate(
      touristType: widget.touristType,
      destination: widget.destination,
      durationDays: _tripDuration,
      adultCount: widget.adultCount,
      childCount: widget.childCount,
      childAges: TripCostEstimator.childAgesFrom(
        ages: widget.ages,
        adultCount: widget.adultCount,
        childCount: widget.childCount,
      ),
      route: buildRoute(),
    );
  }

  BudgetVerdict _routeVerdict(TripCostEstimate estimate) {
    final budgetNpr = TripCostEstimator.toNpr(widget.budget, widget.currency);

    return TripCostEstimator.evaluateBudget(
      budgetNpr: budgetNpr,
      estimate: estimate,
    );
  }

  void _continue() {
    if (!routeComplete) {
      return;
    }

    if (selectedTripDirection == TripDirection.roundTrip &&
        !returnRouteComplete) {
      return;
    }

    if (_durationTooShort) {
      return;
    }

    final TravelRoute route = buildRoute();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecommendationScreen(
          touristType: widget.touristType,
          destination: widget.destination,
          departureDate: widget.departureDate,
          returnDate: widget.returnDate,
          season: widget.season,
          suitability: widget.suitability,
          currency: widget.currency,
          budget: widget.budget,
          ages: widget.ages,
          adultCount: widget.adultCount,
          childCount: widget.childCount,
          travelType: widget.travelType,
          groupSize: widget.groupSize,
          seasonMessage: widget.seasonMessage,
          route: route,
        ),
      ),
    );
  }

  // ============================================================
  // OUTGOING ROUTE PREVIEW
  // ============================================================

  String _outgoingRoutePreview() {
    if (selectedBoardingPoint == null) {
      return '';
    }

    if (segments.isEmpty) {
      return '${selectedBoardingPoint!} → ... → '
          '${widget.destination}';
    }

    final points = <String>[
      segments.first.from,
      ...segments.map((segment) => segment.to),
    ];

    return points.join(' → ');
  }

  // ============================================================
  // TRIP TYPE SELECTOR
  // ============================================================

  /// The first planning choice on the screen: One Way or Round Trip.
  ///
  /// Choosing a direction never touches the outbound journey. Moving from a
  /// round trip to a one way trip only discards return-specific state, while
  /// switching to a round trip keeps the outbound route intact.
  Widget _tripTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _journeyHeader(
          title: 'Trip Type',
          subtitle: 'Choose how you want to go and come back.',
          icon: Icons.sync_alt,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _tripTypeCard(
                direction: TripDirection.oneWay,
                title: 'One Way',
                subtitle: 'Travel to your destination only',
                icon: Icons.arrow_forward,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _tripTypeCard(
                direction: TripDirection.roundTrip,
                title: 'Round Trip',
                subtitle: 'Plan your return journey too',
                icon: Icons.sync_alt,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tripTypeCard({
    required TripDirection direction,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final selected = selectedTripDirection == direction;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _selectTripDirection(direction),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? scheme.primary.withValues(alpha: 0.06)
                : AppColors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: selected ? scheme.primary : AppColors.onSurfaceMuted,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.primary : null,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : scheme.outline,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: AppType.caption.copyWith(height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RETURN JOURNEY
  // ============================================================

  /// Automatic / Custom picker for the return journey.
  Widget _returnTypeCard({required bool automatic, required bool selected}) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final title = automatic ? 'Automatic Return' : 'Custom Return';
    final subtitle = automatic
        ? 'Return using the reverse of your outgoing route.'
        : 'Choose different places to visit on your way back.';
    final icon = automatic ? Icons.sync_alt : Icons.tune;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          if (automatic) {
            _useAutomaticReturnRoute();
          } else {
            _startReturnCustomization();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? scheme.primary.withValues(alpha: 0.06)
                : AppColors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: selected ? scheme.primary : AppColors.onSurfaceMuted,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.primary : null,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : scheme.outline,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: AppType.caption.copyWith(height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }

  /// Read-only summary of the automatic return: the outgoing route reversed,
  /// without any dropdowns or editing controls.
  Widget _automaticReturnSummary() {
    final textTheme = Theme.of(context).textTheme;

    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    final points = <String>[
      segments.first.from,
      ...segments.map((segment) => segment.to),
    ].reversed.toList();

    return YatraCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < points.length; i++) ...[
            Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(points[i], style: textTheme.titleSmall)),
              ],
            ),
            if (i < points.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Automatic return uses your outgoing route in reverse.',
            style: AppType.caption.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  /// Step-by-step builder for a custom return journey.
  Widget _customReturnSection() {
    final textTheme = Theme.of(context).textTheme;

    final boarding = selectedBoardingPoint ?? widget.destination;
    final from = currentReturnLocation ?? widget.destination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Custom Return Journey', style: textTheme.titleLarge),
            ),
            TextButton(
              onPressed: _useAutomaticReturnRoute,
              child: const Text('Use Automatic'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Returning from: ${widget.destination}',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Returning to: $boarding', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('Current location: $from', style: textTheme.bodyMedium),

        const SizedBox(height: AppSpacing.lg),

        Text('Where do you want to go next?', style: textTheme.titleLarge),

        const SizedBox(height: AppSpacing.sm),

        DropdownButtonFormField<String>(
          initialValue: selectedReturnNextPoint,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Choose next return destination',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          items: returnDestinationOptions
              .map(
                (place) =>
                    DropdownMenuItem<String>(value: place, child: Text(place)),
              )
              .toList(),
          onChanged: _selectReturnNextPoint,
        ),

        if (selectedReturnNextPoint != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text('How will you travel?', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _transportSelectionHint(
            selected: selectedReturnTransportation,
            from: from,
            to: selectedReturnNextPoint!,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: selectedReturnTransportation,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Choose transportation',
              prefixIcon: Icon(Icons.directions_bus_outlined),
            ),
            items: _transportItems(
              transportOptionsForRoute(from, selectedReturnNextPoint!),
            ),
            onChanged: (value) {
              setState(() {
                selectedReturnTransportation = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (selectedReturnNextPoint != null &&
            selectedReturnTransportation != null) ...[
          const SizedBox(height: AppSpacing.sm),
          YatraSecondaryButton(
            label: 'Add to Return Journey',
            icon: Icons.add,
            expanded: false,
            onPressed: _addReturnLeg,
          ),
        ],

        if (returnSegments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _returnJourneyPreview(),
        ],

        if (!returnRouteComplete) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Continue planning your return until you reach $boarding.',
              style: textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ],
    );
  }

  /// Vertical preview of the return journey that has been built so far. Each
  /// stop shows its transportation and stay days, with a remove control whose
  /// removal resets every downstream return leg.
  Widget _returnJourneyPreview() {
    final textTheme = Theme.of(context).textTheme;

    return YatraCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Return Journey', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < returnSegments.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${returnSegments[i].from} → '
                        '${returnSegments[i].to}',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${returnSegments[i].transportation} '
                        '• Stay: '
                        '${returnStopExplorationDays[returnSegments[i].to] ?? 0} '
                        'day(s)',
                        style: AppType.caption.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removeReturnStop(i),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Remove',
                ),
              ],
            ),
            if (i < returnSegments.length - 1)
              const Divider(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }

  /// Friendly notice shown when the selected calendar dates are shorter than
  /// the round trip (outbound + return) actually needs.
  Widget _durationWarning() {
    final textTheme = Theme.of(context).textTheme;

    final minimum = _minimumNeedDays ?? _tripDuration;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        'This plan needs at least $minimum days, but your selected '
        'dates provide $_tripDuration days.',
        style: textTheme.bodySmall?.copyWith(height: 1.4),
      ),
    );
  }

  // ============================================================
  // TRANSPORTATION OPTIONS
  // ============================================================

  List<DropdownMenuItem<String>> _transportItems(
    List<RouteTransport> transports,
  ) {
    return transports.map((rt) {
      final option = rt.option;

      return DropdownMenuItem<String>(
        value: option.name,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(option.icon, size: 20, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(option.name, style: AppType.bodyEmphasis),
                  if (rt.requiresTransfer && rt.transferNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        rt.transferNote!,
                        style: AppType.caption.copyWith(height: 1.4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ============================================================
  // LOCAL TRANSPORTATION CARD
  // ============================================================

  Widget _localTransportationCard() {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return YatraCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _journeyHeader(
            title: 'How will you explore locally?',
            subtitle:
                'Choose how you want to travel between '
                'the recommended local attractions.',
            icon: Icons.directions_walk_outlined,
          ),

          const SizedBox(height: AppSpacing.lg),

          ...localTransportationOptions.map((option) {
            final selected = selectedLocalTransportation == option.name;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedLocalTransportation = option.name;
                    });
                  },
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: selected
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.06)
                          : AppColors.surface,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            color: selected
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            option.icon,
                            color: selected ? Colors.white : scheme.primary,
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: AppSpacing.md),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.name,
                                style: selected
                                    ? textTheme.titleMedium?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      )
                                    : textTheme.titleMedium,
                              ),

                              const SizedBox(height: AppSpacing.xs),

                              Text(
                                option.description,
                                style: textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: AppSpacing.xs),

                              Text(
                                option.details,
                                style: AppType.caption.copyWith(height: 1.4),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: AppSpacing.sm),

                        Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: selected ? scheme.primary : scheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          if (selectedLocalTransportation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Local transportation: '
                      '$selectedLocalTransportation',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // ROUTE VISUALIZATION
  // ============================================================

  Widget _routeConnector({required String from, required String to}) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _routeStop(
            label: 'From',
            value: from,
            icon: Icons.trip_origin,
            color: AppColors.primary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.lg,
          ),
          child: Icon(Icons.arrow_forward, color: scheme.outline, size: 22),
        ),
        Expanded(
          child: _routeStop(
            label: 'To',
            value: to,
            icon: Icons.location_on_outlined,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _routeStop({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppType.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // JOURNEY SECTION HEADER
  // ============================================================

  Widget _journeyHeader({
    required String title,
    required String subtitle,
    IconData icon = Icons.navigation_outlined,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: YatraSectionTitle(title: title, subtitle: subtitle),
        ),
      ],
    );
  }

  // ============================================================
  // SELECTED TRANSPORT INDICATOR
  // ============================================================

  Widget _transportSelectionHint({
    required String? selected,
    required String from,
    required String to,
  }) {
    final textTheme = Theme.of(context).textTheme;

    if (selected == null) {
      return Text('Transportation: $from → $to', style: AppType.caption);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Selected: $selected', style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCAL EXPLORATION CARD
  // ============================================================

  Widget _localExplorationCard() {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return YatraCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  localDestinationIcon,
                  color: scheme.primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore $localDestinationName Locally',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      localDescription,
                      style: textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    localPlacesHint,
                    style: textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          YatraPrimaryButton(
            label: exploreLocally
                ? 'Local Exploration Selected'
                : 'Explore $localDestinationName Locally',
            icon: exploreLocally ? Icons.check_circle : Icons.explore_outlined,
            onPressed: exploreLocally ? null : _selectLocalExploration,
          ),

          if (exploreLocally) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Local exploration selected. '
                      'Choose how you want to travel around '
                      '$localDestinationName.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            TextButton.icon(
              onPressed: _selectNormalRoute,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Travel from another location instead'),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // NORMAL ROUTE CARD
  // ============================================================

  Widget _normalRouteCard() {
    return YatraCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _routeConnector(
            from: selectedBoardingPoint ?? 'Select start',
            to: widget.destination,
          ),

          const SizedBox(height: AppSpacing.xl),

          _journeyHeader(
            title: 'Boarding Point',
            subtitle: 'Where does your journey begin?',
            icon: Icons.trip_origin_outlined,
          ),

          const SizedBox(height: AppSpacing.md),

          DropdownButtonFormField<String>(
            initialValue: selectedBoardingPoint,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Choose where you want to start',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: boardingPoints
                .map(
                  (place) => DropdownMenuItem<String>(
                    value: place,
                    child: Text(place),
                  ),
                )
                .toList(),
            onChanged: _selectBoardingPoint,
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'Choose a starting location and then '
            'build your journey one leg at a time.',
            style: AppType.caption,
          ),

          if (selectedBoardingPoint != null) ...[
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: _selectNormalRoute,
              icon: const Icon(Icons.refresh),
              label: const Text('Change Route'),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM CTA
  // ============================================================

  Widget _bottomBar(bool enabled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: YatraPrimaryButton(
          label: 'Continue',
          icon: Icons.arrow_forward,
          onPressed: enabled ? _continue : null,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final boardingChosen = selectedBoardingPoint != null;

    final outgoing = boardingChosen && !routeComplete && !isLocalExploration;

    final transportChosen = selectedNextPoint != null;

    final canAddLeg =
        outgoing && transportChosen && selectedTransportation != null;

    final showReturn =
        routeComplete &&
        !isLocalExploration &&
        selectedTripDirection == TripDirection.roundTrip;

    final canContinue =
        routeComplete && returnRouteComplete && !_durationTooShort;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Transportation')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // HEADER
                    // ==========================================
                    Text(
                      'Choose Your Transportation',
                      style: textTheme.headlineMedium,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      isLocalExploration
                          ? 'You are exploring '
                                '$localDestinationName locally.'
                          : 'Build your route to '
                                '${widget.destination} and pick '
                                'how you get there — every leg, '
                                'your way.',
                      style: textTheme.bodyLarge,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ==========================================
                    // TRIP TYPE — the first planning choice
                    // ==========================================
                    if (!isLocalExploration) ...[
                      _tripTypeSection(),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // ==========================================
                    // LOCAL DESTINATION FLOW
                    // ==========================================
                    if (supportsLocalExploration) ...[
                      _journeyHeader(
                        title: localDestinationName,
                        subtitle:
                            'Choose local exploration or '
                            'travel here from another location.',
                        icon: localDestinationIcon,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _localExplorationCard(),

                      // Local transportation appears only after
                      // local exploration has been selected.
                      if (isLocalExploration) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _localTransportationCard(),
                      ],

                      if (!isLocalExploration) ...[
                        const SizedBox(height: AppSpacing.xl),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: scheme.outlineVariant),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Text(
                                'OR',
                                style: AppType.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: scheme.outlineVariant),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        _normalRouteCard(),
                      ],
                    ]
                    // ==========================================
                    // OTHER DESTINATIONS
                    // ==========================================
                    else ...[
                      YatraCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _routeConnector(
                          from: selectedBoardingPoint ?? 'Select start',
                          to: widget.destination,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      if (boardingChosen) ...[
                        YatraCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              Icon(Icons.route_outlined, color: scheme.primary),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  _outgoingRoutePreview(),
                                  style: textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      _journeyHeader(
                        title: 'Boarding Point',
                        subtitle: 'Where does your journey begin?',
                        icon: Icons.trip_origin_outlined,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      DropdownButtonFormField<String>(
                        initialValue: selectedBoardingPoint,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Choose where you want to start',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: boardingPoints
                            .map(
                              (place) => DropdownMenuItem<String>(
                                value: place,
                                child: Text(place),
                              ),
                            )
                            .toList(),
                        onChanged: _selectBoardingPoint,
                      ),
                    ],

                    // ==========================================
                    // GOING
                    // ==========================================
                    if (outgoing) ...[
                      const SizedBox(height: AppSpacing.xxl + AppSpacing.md),

                      _journeyHeader(
                        title: 'Going',
                        subtitle:
                            'From ${currentLocation!} '
                            'to ${widget.destination}.',
                        icon: Icons.navigation_outlined,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Text('Next stop', style: textTheme.titleLarge),

                      const SizedBox(height: AppSpacing.sm),

                      DropdownButtonFormField<String>(
                        initialValue: selectedNextPoint,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Choose next location',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        items: nextLocations
                            .map(
                              (place) => DropdownMenuItem<String>(
                                value: place,
                                child: Text(place),
                              ),
                            )
                            .toList(),
                        onChanged: _selectNextPoint,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Transportation appears ONLY after
                      // the intermediate destination is chosen.
                      if (transportChosen) ...[
                        Text('Transportation', style: textTheme.titleLarge),

                        const SizedBox(height: AppSpacing.sm),

                        _transportSelectionHint(
                          selected: selectedTransportation,
                          from: currentLocation!,
                          to: selectedNextPoint!,
                        ),

                        const SizedBox(height: AppSpacing.md),

                        DropdownButtonFormField<String>(
                          initialValue: selectedTransportation,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Choose transportation',
                            prefixIcon: Icon(Icons.directions_bus_outlined),
                          ),
                          items: _transportItems(
                            transportOptionsForRoute(
                              currentLocation!,
                              selectedNextPoint!,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              selectedTransportation = value;
                            });
                          },
                        ),

                        const SizedBox(height: AppSpacing.md),

                        if (canAddLeg)
                          YatraSecondaryButton(
                            label: 'Add Route Leg',
                            icon: Icons.add,
                            expanded: false,
                            onPressed: _addRouteLeg,
                          ),
                      ],
                    ],

                    // ==========================================
                    // REMOVE OUTGOING LEG
                    // ==========================================
                    if (segments.isNotEmpty && !routeComplete)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _removeLastLeg,
                          icon: const Icon(Icons.undo),
                          label: const Text('Remove Last Leg'),
                        ),
                      ),

                    // ==========================================
                    // GOING — STAY / EXPLORATION DAYS
                    // ==========================================
                    // Every destination arrived at on the outgoing route
                    // (each segment.to, excluding the boarding point) gets a
                    // stay control the moment its leg exists, even before the
                    // route is complete. The final destination is included
                    // and stays adjustable like any other arrival. The list
                    // is derived purely from route data.
                    if (!isLocalExploration && segments.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),

                      _journeyHeader(
                        title: 'Stay / Exploration Days',
                        subtitle:
                            'How many days will you spend staying at '
                            'each arrival on your route?',
                        icon: Icons.hotel_outlined,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      YatraCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Going',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            for (final stop in _goingStops)
                              _ExplorationDayStepper(
                                stop: stop,
                                days: stopExplorationDays[stop] ?? 0,
                                onChanged: (value) {
                                  setState(() {
                                    stopExplorationDays[stop] = value.clamp(
                                      0,
                                      14,
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],

                    // ==========================================
                    // RETURN JOURNEY
                    // ==========================================
                    if (showReturn) ...[
                      const SizedBox(height: AppSpacing.xl),

                      _journeyHeader(
                        title: 'Return Journey',
                        subtitle:
                            '${widget.destination} → '
                            '$selectedBoardingPoint.',
                        icon: Icons.sync_alt,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Choose how to come back: automatic (reversed route)
                      // or a fully custom return journey.
                      Row(
                        children: [
                          Expanded(
                            child: _returnTypeCard(
                              automatic: true,
                              selected: !customizeReturnRoute,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _returnTypeCard(
                              automatic: false,
                              selected: customizeReturnRoute,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      if (!customizeReturnRoute)
                        _automaticReturnSummary()
                      else
                        _customReturnSection(),

                      // The duration check applies to the automatic AND the
                      // custom return once the return journey is ready.
                      if (_durationTooShort) ...[
                        const SizedBox(height: AppSpacing.md),
                        _durationWarning(),
                      ],

                      // ==========================================
                      // COMING BACK — STAY / EXPLORATION DAYS
                      // ==========================================
                      // Every arrival on the actual return route (automatic
                      // reversed or custom) gets its own stay control. The
                      // list appears as soon as a return leg exists — a
                      // partial custom return still shows the stops already
                      // added — and never includes the original boarding
                      // point. Derived purely from route data.
                      if (_returnArrivalStops.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),

                        YatraCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Coming Back',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              for (final stop in _returnArrivalStops)
                                _ExplorationDayStepper(
                                  stop: stop,
                                  days: returnStopExplorationDays[stop] ?? 0,
                                  onChanged: (value) {
                                    setState(() {
                                      returnStopExplorationDays[stop] = value
                                          .clamp(0, 14);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    // ==========================================
                    // LOCAL COMPLETION MESSAGE
                    // ==========================================
                    if (isLocalExploration &&
                        selectedLocalTransportation != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: AppColors.success.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'Local exploration of '
                                '$localDestinationName is ready. '
                                'You will explore by '
                                '$selectedLocalTransportation.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ==========================================
                    // NORMAL ONE-WAY COMPLETION
                    // ==========================================
                    if (routeComplete &&
                        !isLocalExploration &&
                        selectedTripDirection == TripDirection.oneWay) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: AppColors.success.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'You have reached '
                                '${widget.destination}.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ==========================================
                    // ROUND TRIP COMPLETION
                    // ==========================================
                    if (selectedTripDirection == TripDirection.roundTrip &&
                        returnRouteComplete) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: AppColors.success.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'Return journey complete.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ==========================================
                    // ROUTE COST SUMMARY
                    // ==========================================
                    if (routeComplete && _routeEstimate != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _RouteCostSummaryCard(
                        estimate: _routeEstimate!,
                        verdict: _routeVerdict(_routeEstimate!),
                        route: buildRoute(),
                        budget: widget.budget,
                        currency: widget.currency,
                        adultCount: widget.adultCount,
                        childCount: widget.childCount,
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),

            // ================================================
            // PINNED CONTINUE BUTTON
            // ================================================
            _bottomBar(canContinue),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOCAL TRANSPORTATION MODEL
// ============================================================

class _LocalTransportationOption {
  final String name;
  final IconData icon;
  final String description;
  final String details;

  const _LocalTransportationOption({
    required this.name,
    required this.icon,
    required this.description,
    required this.details,
  });
}

// ============================================================
// EXPLORATION DAYS STEPPER
// ============================================================

class _ExplorationDayStepper extends StatelessWidget {
  final String stop;
  final int days;
  final ValueChanged<int> onChanged;

  const _ExplorationDayStepper({
    required this.stop,
    required this.days,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final canDecrease = days > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop, style: textTheme.titleSmall),
                Text(
                  days == 1
                      ? '1 day of exploration'
                      : '$days days of exploration',
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: canDecrease ? () => onChanged(days - 1) : null,
            icon: Icon(
              Icons.remove_circle_outline,
              color: canDecrease ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$days',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: days >= 14 ? null : () => onChanged(days + 1),
            icon: Icon(
              Icons.add_circle_outline,
              color: days >= 14 ? scheme.outlineVariant : scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ROUTE COST SUMMARY
// ============================================================

class _RouteCostSummaryCard extends StatelessWidget {
  final TripCostEstimate estimate;
  final BudgetVerdict verdict;
  final TravelRoute route;
  final double budget;
  final String currency;
  final int adultCount;
  final int childCount;

  const _RouteCostSummaryCard({
    required this.estimate,
    required this.verdict,
    required this.route,
    required this.budget,
    required this.currency,
    required this.adultCount,
    required this.childCount,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isInsufficient = verdict == BudgetVerdict.insufficient;
    final accent = isInsufficient ? AppColors.danger : AppColors.success;

    final segments = route.completeSegments;

    final budgetNpr = TripCostEstimator.toNpr(budget, currency);

    final message = TripCostEstimator.verdictMessage(
      verdict: verdict,
      budgetNpr: budgetNpr,
      estimate: estimate,
      currency: currency,
      adultCount: adultCount,
      childCount: childCount,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route Cost Summary', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (segments.isNotEmpty) ...[
            ...segments.map(
              (segment) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${segment.from} → ${segment.to} '
                        '(${segment.transportation})',
                        style: textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      TripCostEstimator.formatNprAmount(
                        TripCostEstimator.transportCostForMode(
                          segment.transportation,
                        ),
                      ),
                      style: AppType.bodyEmphasis.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transport total',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                TripCostEstimator.formatNprAmount(estimate.transport),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estimated trip total',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                TripCostEstimator.formatNprAmount(estimate.total),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl * 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isInsufficient
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TripCostEstimator.verdictTitle(verdict),
                      style: textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
