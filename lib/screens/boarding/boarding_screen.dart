import 'package:flutter/material.dart';

import '../../models/travel_route_model.dart';
import '../../data/transportation_data.dart';
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
          children: [
            Icon(option.icon,
                size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(option.name),
                  if (rt.requiresTransfer && rt.transferNote != null)
                    Text(
                      rt.transferNote!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Route'),
        centerTitle: true,
      ),

      // ========================================================
      // IMPORTANT:
      // SingleChildScrollView fixes the bottom overflow.
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              const Text(
                'Plan Your Route',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Build your route to '
                '${widget.destination} using relevant locations.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // BOARDING POINT
              // ==================================================

              const Text(
                'Boarding Point',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: selectedBoardingPoint,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Choose where you want to start',
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
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

              const SizedBox(height: 20),

              // ==================================================
              // OUTGOING ROUTE
              // ==================================================

              if (selectedBoardingPoint != null) ...[
                const Text(
                  'Your Route',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    _outgoingRoutePreview(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],

              // ==================================================
              // OUTGOING LOCATION
              // ==================================================

              if (selectedBoardingPoint != null &&
                  !routeComplete) ...[
                Text(
                  'From ${currentLocation!}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: selectedNextPoint,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'Choose next location',
                    prefixIcon: const Icon(
                      Icons.place_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
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

                const SizedBox(height: 16),

                if (selectedNextPoint != null) ...[
                  // ==========================================
                  // TRANSPORTATION FOR THE CURRENT OUTGOING LEG
                  // Only shown once the leg's destination (the
                  // next point) has been chosen.
                  // ==========================================

                  const Text(
                    'Transportation',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Transportation: '
                    '${currentLocation!} → $selectedNextPoint',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: selectedTransportation,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Choose transportation',
                      prefixIcon: const Icon(
                        Icons.directions_bus_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
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

                  const SizedBox(height: 16),

                  if (selectedTransportation != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _addRouteLeg,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add Route Leg',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
                ],
              ],

              // ==================================================
              // REMOVE OUTGOING LEG
              // ==================================================

              if (segments.isNotEmpty && !routeComplete)
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: TextButton.icon(
                    onPressed: _removeLastLeg,
                    icon: const Icon(Icons.undo),
                    label: const Text(
                      'Remove Last Leg',
                    ),
                  ),
                ),

              // ==================================================
              // TRIP DIRECTION
              // ==================================================

              if (routeComplete) ...[
                const SizedBox(height: 20),

                const Text(
                  'Trip Direction',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

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

                    const SizedBox(width: 10),

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

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade100,
                  ),
                  child: Text(
                    selectedTripDirection ==
                            TripDirection.roundTrip
                        ? 'The return journey is planned '
                            'separately, so you can choose '
                            'different transportation for the '
                            'return trip.'
                        : 'The itinerary will end at '
                            '${widget.destination}.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              // ==================================================
              // RETURN JOURNEY
              // ==================================================

              if (routeComplete &&
                  selectedTripDirection ==
                      TripDirection.roundTrip) ...[
                const SizedBox(height: 20),

                const Text(
                  'Return Journey',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.grey.shade100,
                  ),
                  child: Text(
                    _returnRoutePreview(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (!returnRouteComplete) ...[
                  Text(
                    'From ${currentReturnLocation!}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Returning to '
                    '${nextReturnLocation ?? selectedBoardingPoint}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (nextReturnLocation != null) ...[
                    const Text(
                      'Transportation',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Transportation: '
                      '${currentReturnLocation!} → '
                      '$nextReturnLocation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      initialValue: selectedReturnTransportation,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Choose transportation',
                        prefixIcon: const Icon(
                          Icons.directions_bus_outlined,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
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

                    const SizedBox(height: 16),
                  ],

                  if (selectedReturnTransportation != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _addReturnLeg,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add Return Leg',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  if (returnSegments.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: TextButton.icon(
                        onPressed:
                            _removeLastReturnLeg,
                        icon: const Icon(Icons.undo),
                        label: const Text(
                          'Remove Last Return Leg',
                        ),
                      ),
                    ),
                ],
              ],

              // ==================================================
              // COMPLETION MESSAGE
              // ==================================================

              if (routeComplete &&
                  selectedTripDirection ==
                      TripDirection.oneWay) ...[
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have reached '
                          '${widget.destination}.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
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
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Round trip route completed.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ==================================================
              // CONTINUE BUTTON
              // ==================================================

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      routeComplete &&
                              returnRouteComplete
                          ? _continue
                          : null,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Extra bottom space for comfortable scrolling.
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}