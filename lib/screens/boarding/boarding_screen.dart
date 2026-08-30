import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/travel_route_model.dart';
import '../../data/transportation_data.dart';
import '../../widgets/yatra_components.dart';
import '../recommendation/recommendation_screen.dart';

class BoardingScreen extends StatefulWidget {
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

  const BoardingScreen({
    super.key,
    required this.destination,
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

  // Transportation for the currently pending outgoing leg, i.e.
  // the leg `currentLocation -> selectedNextPoint`. Choosing a new
  // next point resets this so a fresh selection is required per leg.
  String? selectedTransportation;

  // Transportation for the currently pending return leg, i.e. the
  // leg `currentReturnLocation -> nextReturnLocation`.
  String? selectedReturnTransportation;

  TripDirection selectedTripDirection = TripDirection.oneWay;

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
    'Tansen',
    'Rasuwa',
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
  ];

  // ============================================================
  // DESTINATION-SPECIFIC ROUTES
  // ============================================================

  final Map<String, Map<String, List<String>>> destinationRoutes = {
    'Mustang': {
      'Kathmandu': [
        'Pokhara',
        'Jomsom',
        'Kagbeni',
        'Mustang',
      ],
      'Pokhara': [
        'Jomsom',
        'Kagbeni',
        'Mustang',
      ],
      'Jomsom': [
        'Marpha',
        'Kagbeni',
        'Mustang',
      ],
      'Marpha': [
        'Kagbeni',
        'Mustang',
      ],
      'Kagbeni': [
        'Muktinath',
        'Mustang',
      ],
    },

    'Annapurna': {
      'Kathmandu': [
        'Pokhara',
      ],
      'Pokhara': [
        'Ghandruk',
        'Poon Hill',
        'Annapurna',
      ],
      'Ghandruk': [
        'Poon Hill',
        'Annapurna',
      ],
      'Poon Hill': [
        'Annapurna',
      ],
    },

    'Everest': {
      'Kathmandu': [
        'Lukla',
      ],
      'Lukla': [
        'Namche Bazaar',
      ],
      'Namche Bazaar': [
        'Everest',
      ],
    },

    'Pokhara': {
      'Kathmandu': [
        'Pokhara',
      ],
      'Chitwan': [
        'Pokhara',
      ],
      'Tansen': [
        'Pokhara',
      ],
    },

    'Chitwan': {
      'Kathmandu': [
        'Chitwan',
      ],
      'Pokhara': [
        'Chitwan',
      ],
      'Tansen': [
        'Chitwan',
      ],
    },

    'Kathmandu': {
      'Pokhara': [
        'Kathmandu',
      ],
      'Chitwan': [
        'Kathmandu',
      ],
      'Tansen': [
        'Kathmandu',
      ],
      'Rasuwa': [
        'Kathmandu',
      ],
      'Lukla': [
        'Kathmandu',
      ],
    },

    'Tansen': {
      'Kathmandu': [
        'Tansen',
      ],
      'Pokhara': [
        'Tansen',
      ],
      'Chitwan': [
        'Tansen',
      ],
    },

    'Rasuwa': {
      'Kathmandu': [
        'Rasuwa',
      ],
      'Rasuwa': [],
    },
  };

  // ============================================================
  // NORMALIZE
  // ============================================================

  String _normalize(String value) {
    return value.trim().toLowerCase();
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

  bool _canReachDestination(
    String start,
    String destination,
  ) {
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

      if (_canReachDestination(
        location,
        widget.destination,
      )) {
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

    final possible = <String>[
      ...(routeMap[current] ?? []),
    ];

    // Destination fallback
    if (_normalize(current) != _normalize(widget.destination) &&
        _canReachDestination(
          current,
          widget.destination,
        ) &&
        !possible.any(
          (location) =>
              _normalize(location) ==
              _normalize(widget.destination),
        )) {
      final directDestination = locations.firstWhere(
        (location) =>
            _normalize(location) ==
            _normalize(widget.destination),
        orElse: () => widget.destination,
      );

      if (possible.isEmpty) {
        possible.add(directDestination);
      }
    }

    // Remove current location.
    possible.removeWhere(
      (location) =>
          _normalize(location) ==
          _normalize(current),
    );

    // Remove locations already used.
    possible.removeWhere(
      (location) => segments.any(
        (segment) =>
            _normalize(segment.from) ==
                _normalize(location) ||
            _normalize(segment.to) ==
                _normalize(location),
      ),
    );

    // Safety filter.
    possible.removeWhere(
      (location) => !_canReachDestination(
        location,
        widget.destination,
      ),
    );

    return possible;
  }

  // ============================================================
  // OUTGOING ROUTE COMPLETE
  // ============================================================

  bool get routeComplete {
    return currentLocation != null &&
        _normalize(currentLocation!) ==
            _normalize(widget.destination) &&
        segments.isNotEmpty;
  }

  // ============================================================
  // RETURN ROUTE COMPLETE
  // ============================================================

  bool get returnRouteComplete {
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
      ...segments.map(
        (segment) => segment.to,
      ),
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
      (point) =>
          _normalize(point) ==
          _normalize(current ?? ''),
    );

    if (currentIndex == -1 ||
        currentIndex >= points.length - 1) {
      return null;
    }

    return points[currentIndex + 1];
  }

  // ============================================================
  // SELECT BOARDING POINT
  // ============================================================

  void _selectBoardingPoint(String? value) {
    setState(() {
      selectedBoardingPoint = value;
      selectedNextPoint = null;
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

      // A new destination for this leg starts with an unset
      // transportation for that leg.
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

      // Outgoing route changed, so return route
      // must be rebuilt.
      returnSegments.clear();
    });
  }

  // ============================================================
  // ADD RETURN LEG
  // ============================================================

  void _addReturnLeg() {
    final from = currentReturnLocation;
    final to = nextReturnLocation;

    if (from == null || to == null ||
        selectedReturnTransportation == null) {
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

  void _selectTripDirection(
    TripDirection direction,
  ) {
    setState(() {
      selectedTripDirection = direction;

      if (direction == TripDirection.oneWay) {
        returnSegments.clear();
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

    /*
     * The TravelRoute model now supports explicit return segments.
     *
     * When this is a round trip the user's exact return legs and
     * their chosen transportation are preserved. For a one-way trip
     * we pass no return segments, so TravelRoute leaves them empty.
     */

    final route = TravelRoute(
      boardingPoint: segments.first.from,
      destination: widget.destination,
      segments: List<RouteSegment>.from(segments),
      tripDirection: selectedTripDirection,
      returnSegments: selectedTripDirection == TripDirection.roundTrip
          ? List<RouteSegment>.from(returnSegments)
          : null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecommendationScreen(
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
      ...segments.map(
        (segment) => segment.to,
      ),
    ];

    return points.join(' → ');
  }

  // ============================================================
  // RETURN ROUTE PREVIEW
  // ============================================================

  String _returnRoutePreview() {
    if (!routeComplete) {
      return '';
    }

    if (returnSegments.isEmpty) {
      return '${widget.destination} → ... → '
          '${selectedBoardingPoint!}';
    }

    final points = <String>[
      returnSegments.first.from,
      ...returnSegments.map(
        (segment) => segment.to,
      ),
    ];

    return points.join(' → ');
  }

  // ============================================================
  // TRANSPORTATION OPTIONS
  // ============================================================

  /// Builds the dropdown items for the transportation selector. Options
  /// that only partially cover the A -> B leg (requiresTransfer) show a
  /// short note under their name so a transfer journey is never presented
  /// as a direct one.
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
            Icon(option.icon,
                size: 20, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.name,
                    style: AppType.bodyEmphasis,
                  ),
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
  // ROUTE VISUALIZATION (FROM → TO)
  // ============================================================

  Widget _routeConnector({
    required String from,
    required String to,
  }) {
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
          child: Icon(
            Icons.arrow_forward,
            color: scheme.outline,
            size: 22,
          ),
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
  // JOURNEY SECTION HEADER (GOING / RETURN)
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
          child: YatraSectionTitle(
            title: title,
            subtitle: subtitle,
          ),
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
      return Text(
        'Transportation: $from → $to',
        style: AppType.caption,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Selected: $selected',
              style: textTheme.bodyMedium,
            ),
          ),
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
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.6),
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
    final outgoing = boardingChosen && !routeComplete;
    final transportChosen = selectedNextPoint != null;
    final canAddLeg = outgoing && transportChosen &&
        selectedTransportation != null;

    final showReturn =
        routeComplete &&
            selectedTripDirection == TripDirection.roundTrip;

    // Continue is available once the outgoing (and return, if round trip)
    // routes are complete.
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
                    // ============================================
                    // HEADER
                    // ============================================

                    Text(
                      'Choose Your Transportation',
                      style: textTheme.headlineMedium,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      'Build your route to ${widget.destination} and pick '
                      'how you get there — every leg, your way.',
                      style: textTheme.bodyLarge,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ============================================
                    // ROUTE VISUALIZATION (FROM → TO)
                    // ============================================

                    YatraCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _routeConnector(
                        from: selectedBoardingPoint ?? 'Select start',
                        to: widget.destination,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ============================================
                    // OUTGOING ROUTE PREVIEW
                    // ============================================

                    if (boardingChosen) ...[
                      YatraCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Icon(
                              Icons.route_outlined,
                              color: scheme.primary,
                            ),
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

                    // ============================================
                    // BOARDING POINT
                    // ============================================

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
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                        ),
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

                    // ============================================
                    // GOING — OUTGOING JOURNEY
                    // ============================================

                    if (outgoing) ...[
                      const SizedBox(height: AppSpacing.xxl + AppSpacing.md),

                      _journeyHeader(
                        title: 'Going',
                        subtitle:
                            'From ${currentLocation!} to '
                            '${widget.destination}.',
                        icon: Icons.navigation_outlined,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Next location picker.
                      Text(
                        'Next stop',
                        style: textTheme.titleLarge,
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      DropdownButtonFormField<String>(
                        initialValue: selectedNextPoint,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Choose next location',
                          prefixIcon: Icon(
                            Icons.place_outlined,
                          ),
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

                      // Transportation for current outgoing leg,
                      // only shown once the leg's destination is chosen.
                      if (transportChosen) ...[
                        Text(
                          'Transportation',
                          style: textTheme.titleLarge,
                        ),

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
                            prefixIcon: Icon(
                              Icons.directions_bus_outlined,
                            ),
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

                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],

                    // Remove last outgoing leg.
                    if (segments.isNotEmpty && !routeComplete)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _removeLastLeg,
                          icon: const Icon(Icons.undo),
                          label: const Text('Remove Last Leg'),
                        ),
                      ),

                    // ============================================
                    // TRIP DIRECTION
                    // ============================================

                    if (routeComplete) ...[
                      const SizedBox(height: AppSpacing.xl),

                      Text('Trip Direction', style: textTheme.titleLarge),

                      const SizedBox(height: AppSpacing.md),

                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 19,
                                  ),
                                  SizedBox(width: 7),
                                  Text('One Way'),
                                ],
                              ),
                              selected:
                                  selectedTripDirection ==
                                      TripDirection.oneWay,
                              onSelected: (_) {
                                _selectTripDirection(
                                  TripDirection.oneWay,
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: AppSpacing.md),

                          Expanded(
                            child: ChoiceChip(
                              label: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sync_alt,
                                    size: 19,
                                  ),
                                  SizedBox(width: 7),
                                  Text('Round Trip'),
                                ],
                              ),
                              selected:
                                  selectedTripDirection ==
                                      TripDirection.roundTrip,
                              onSelected: (_) {
                                _selectTripDirection(
                                  TripDirection.roundTrip,
                                );
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
                              selectedTripDirection ==
                                      TripDirection.roundTrip
                                  ? Icons.sync_alt
                                  : Icons.info_outline,
                              size: 20,
                              color: AppColors.onSurfaceMuted,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                selectedTripDirection ==
                                        TripDirection.roundTrip
                                    ? 'The return journey is planned '
                                        'separately, so you can choose '
                                        'different transportation for the '
                                        'return trip.'
                                    : 'The itinerary will end at '
                                        '${widget.destination}.',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ============================================
                    // RETURN JOURNEY
                    // ============================================

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
                            Icon(
                              Icons.route_outlined,
                              color: AppColors.accent,
                            ),
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
                          Text(
                            'Transportation',
                            style: textTheme.titleLarge,
                          ),

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
                              prefixIcon: Icon(
                                Icons.directions_bus_outlined,
                              ),
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
                              label:
                                  const Text('Remove Last Return Leg'),
                            ),
                          ),
                      ],
                    ],

                    // ============================================
                    // COMPLETION MESSAGES
                    // ============================================

                    if (routeComplete &&
                        selectedTripDirection ==
                            TripDirection.oneWay) ...[
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
                            Icon(
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

                    if (selectedTripDirection ==
                            TripDirection.roundTrip &&
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
                            Icon(
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

                    // Extra bottom space so the pinned CTA never overlaps
                    // the last scrollable item.
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),

            // ============================================
            // PINNED BOTTOM CTA
            // ============================================

            _bottomBar(canContinue),
          ],
        ),
      ),
    );
  }
}
