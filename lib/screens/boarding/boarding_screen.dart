import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/travel_route_model.dart';
import '../../data/transportation_data.dart';
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
    required this.travelType,
    required this.groupSize,
    required this.seasonMessage,
  });

  @override
  State<BoardingScreen> createState() => _BoardingScreenState();
}

class _BoardingScreenState extends State<BoardingScreen> {
  String? selectedBoardingPoint;
  String? selectedNextPoint;

  /// True when the selected destination is being explored locally.
  bool exploreLocally = false;

  /// Transportation used to move around the destination locally.
  String? selectedLocalTransportation;

  // Transportation for the currently pending outgoing leg.
  String? selectedTransportation;

  // Transportation for the currently pending return leg.
  String? selectedReturnTransportation;

  TripDirection selectedTripDirection = TripDirection.oneWay;

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

    if (!routeComplete) {
      return false;
    }

    if (selectedBoardingPoint == null) {
      return false;
    }

    if (returnSegments.isEmpty) {
      return false;
    }

    return _normalize(returnSegments.last.to) ==
        _normalize(selectedBoardingPoint!);
  }

  // ============================================================
  // RETURN ROUTE LOCATIONS
  // ============================================================

  List<String> get returnLocations {
    if (!routeComplete || selectedBoardingPoint == null) {
      return [];
    }

    final outgoingPoints = <String>[
      segments.first.from,
      ...segments.map((segment) => segment.to),
    ];

    return outgoingPoints.reversed.toList();
  }

  // ============================================================
  // NEXT RETURN LOCATION
  // ============================================================

  String? get nextReturnLocation {
    final points = returnLocations;

    if (points.isEmpty) {
      return null;
    }

    final current = currentReturnLocation;

    final currentIndex = points.indexWhere(
      (point) => _normalize(point) == _normalize(current ?? ''),
    );

    if (currentIndex == -1 || currentIndex >= points.length - 1) {
      return null;
    }

    return points[currentIndex + 1];
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
      selectedReturnTransportation = null;

      segments.clear();
      returnSegments.clear();

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
      selectedReturnTransportation = null;

      segments.clear();
      returnSegments.clear();

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
      selectedReturnTransportation = null;

      selectedTripDirection = TripDirection.oneWay;

      segments.clear();
      returnSegments.clear();
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
      selectedTransportation = null;
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

      // Rebuild return route when outgoing route changes.
      returnSegments.clear();
    });
  }

  // ============================================================
  // ADD RETURN LEG
  // ============================================================

  void _addReturnLeg() {
    final from = currentReturnLocation;
    final to = nextReturnLocation;

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
    });
  }

  // ============================================================
  // REMOVE RETURN LEG
  // ============================================================

  void _removeLastReturnLeg() {
    if (returnSegments.isEmpty) {
      return;
    }

    setState(() {
      returnSegments.removeLast();
      selectedReturnTransportation = null;
    });
  }

  // ============================================================
  // SELECT TRIP DIRECTION
  // ============================================================

  void _selectTripDirection(TripDirection direction) {
    setState(() {
      selectedTripDirection = direction;

      if (direction == TripDirection.oneWay) {
        returnSegments.clear();
        selectedReturnTransportation = null;
      }
    });
  }

  // ============================================================
  // CONTINUE
  // ============================================================

  void _continue() {
    if (!routeComplete) {
      return;
    }

    if (selectedTripDirection == TripDirection.roundTrip &&
        !returnRouteComplete) {
      return;
    }

    final TravelRoute route;

    if (isLocalExploration) {
      /*
   * Local exploration has no fake destination -> destination
   * route segment.
   *
   * The selected local transportation is stored directly
   * in TravelRoute.
   */
      route = TravelRoute(
        boardingPoint: localDestinationName,
        destination: localDestinationName,
        segments: const [],
        localTransportation: selectedLocalTransportation,
        tripDirection: TripDirection.oneWay,
      );
    } else {
      route = TravelRoute(
        boardingPoint: segments.first.from,
        destination: widget.destination,
        segments: List<RouteSegment>.from(segments),
        tripDirection: selectedTripDirection,
        returnSegments: selectedTripDirection == TripDirection.roundTrip
            ? List<RouteSegment>.from(returnSegments)
            : null,
      );
    }

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
  // RETURN ROUTE PREVIEW
  // ============================================================

  String _returnRoutePreview() {
    if (!routeComplete || selectedBoardingPoint == null) {
      return '';
    }

    if (returnSegments.isEmpty) {
      return '${widget.destination} → ... → '
          '$selectedBoardingPoint';
    }

    final points = <String>[
      returnSegments.first.from,
      ...returnSegments.map((segment) => segment.to),
    ];

    return points.join(' → ');
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

    final canContinue = routeComplete && returnRouteComplete;

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
                    // TRIP DIRECTION
                    // ==========================================
                    if (routeComplete && !isLocalExploration) ...[
                      const SizedBox(height: AppSpacing.xl),

                      Text('Trip Direction', style: textTheme.titleLarge),

                      const SizedBox(height: AppSpacing.md),

                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_forward, size: 19),
                                  SizedBox(width: 7),
                                  Text('One Way'),
                                ],
                              ),
                              selected:
                                  selectedTripDirection == TripDirection.oneWay,
                              onSelected: (_) {
                                _selectTripDirection(TripDirection.oneWay);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ChoiceChip(
                              label: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sync_alt, size: 19),
                                  SizedBox(width: 7),
                                  Text('Round Trip'),
                                ],
                              ),
                              selected:
                                  selectedTripDirection ==
                                  TripDirection.roundTrip,
                              onSelected: (_) {
                                _selectTripDirection(TripDirection.roundTrip);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      YatraCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              selectedTripDirection == TripDirection.roundTrip
                                  ? Icons.sync_alt
                                  : Icons.info_outline,
                              size: 20,
                              color: AppColors.onSurfaceMuted,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                selectedTripDirection == TripDirection.roundTrip
                                    ? 'The return journey is '
                                          'planned separately, '
                                          'so you can choose '
                                          'different '
                                          'transportation for '
                                          'the return trip.'
                                    : 'The itinerary will end '
                                          'at ${widget.destination}.',
                                style: textTheme.bodyMedium,
                              ),
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
                        title: 'Return',
                        subtitle:
                            '${widget.destination} → '
                            '$selectedBoardingPoint.',
                        icon: Icons.sync_alt,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      YatraCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Icon(Icons.route_outlined, color: AppColors.accent),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                _returnRoutePreview(),
                                style: textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (!returnRouteComplete) ...[
                        const SizedBox(height: AppSpacing.lg),

                        Text(
                          'From ${currentReturnLocation!}',
                          style: textTheme.titleLarge,
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        Text(
                          'Returning to '
                          '${nextReturnLocation ?? selectedBoardingPoint}',
                          style: AppType.caption,
                        ),

                        const SizedBox(height: AppSpacing.md),

                        if (nextReturnLocation != null) ...[
                          Text('Transportation', style: textTheme.titleLarge),

                          const SizedBox(height: AppSpacing.sm),

                          _transportSelectionHint(
                            selected: selectedReturnTransportation,
                            from: currentReturnLocation!,
                            to: nextReturnLocation!,
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
                              transportOptionsForRoute(
                                currentReturnLocation!,
                                nextReturnLocation!,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                selectedReturnTransportation = value;
                              });
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),
                        ],

                        if (selectedReturnTransportation != null)
                          YatraSecondaryButton(
                            label: 'Add Return Leg',
                            icon: Icons.add,
                            expanded: false,
                            onPressed: _addReturnLeg,
                          ),

                        if (returnSegments.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _removeLastReturnLeg,
                              icon: const Icon(Icons.undo),
                              label: const Text('Remove Last Leg'),
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
                                'Round trip route completed.',
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
