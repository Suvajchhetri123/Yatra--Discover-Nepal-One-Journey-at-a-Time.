import 'package:flutter/material.dart';

import '../models/transportation_option_model.dart';

/// A destination and its available transportation options.
class DestinationTransport {
  final String destination;
  final List<TransportationOption> options;

  const DestinationTransport({
    required this.destination,
    required this.options,
  });
}

/// A transportation mode available for a specific A -> B route leg.
class RouteTransport {
  final TransportationOption option;

  /// True when the mode only covers part of A -> B and requires a transfer.
  final bool requiresTransfer;

  /// Explanation shown under the option name.
  final String? transferNote;

  const RouteTransport({
    required this.option,
    this.requiresTransfer = false,
    this.transferNote,
  });
}

// ============================================================
// LOCAL EXPLORATION OPTIONS
// ============================================================

const TransportationOption kathmanduLocalOption = TransportationOption(
  name: 'Visit Kathmandu Locally',
  icon: Icons.location_city,
  description:
      'Explore Kathmandu and nearby attractions without travelling outside the city',
  details:
      'Visit Kathmandu Durbar Square, Swayambhunath, Pashupatinath, Boudhanath and other local attractions',
);

const TransportationOption pokharaLocalOption = TransportationOption(
  name: 'Visit Pokhara Locally',
  icon: Icons.explore_outlined,
  description:
      'Explore Pokhara and nearby attractions without travelling to another city',
  details:
      'Visit Phewa Lake, Davis Falls, World Peace Pagoda, Sarangkot and other local attractions',
);

const TransportationOption chitwanLocalOption = TransportationOption(
  name: 'Visit Chitwan Locally',
  icon: Icons.explore_outlined,
  description:
      'Explore Chitwan and nearby attractions without travelling to another city',
  details:
      'Explore Chitwan National Park, Sauraha, Rapti River, Tharu culture and other local attractions',
);

// ============================================================
// DESTINATION-BASED TRANSPORTATION
// ============================================================

const List<DestinationTransport> destinationTransports = [
  // ==========================================================
  // EVEREST
  // ==========================================================
  DestinationTransport(
    destination: 'Everest',
    options: [
      TransportationOption(
        name: 'Flight',
        icon: Icons.flight,
        description: 'Flight to Lukla is the usual starting option',
        details:
            'Fly to Lukla, then continue the Everest journey by trekking',
      ),
      TransportationOption(
        name: 'Jeep',
        icon: Icons.directions_car_filled,
        description: 'Useful for reaching road-accessible trailheads',
        details:
            'Travel toward Salleri/Jiri, then continue the journey by trekking',
      ),
      TransportationOption(
        name: 'Bus',
        icon: Icons.directions_bus,
        description: 'Available for road sections',
        details:
            'Travel toward Salleri/Jiri, then continue the journey by trekking',
      ),
      TransportationOption(
        name: 'Motorbike',
        icon: Icons.two_wheeler,
        description: 'Possible on accessible road sections',
        details:
            'Ride toward Salleri/Jiri, then continue the journey by trekking',
      ),
      TransportationOption(
        name: 'Private Vehicle',
        icon: Icons.directions_car,
        description: 'Available for accessible road sections',
        details:
            'Travel toward Salleri/Jiri, then continue the journey by trekking',
      ),
    ],
  ),

  // ==========================================================
  // MUSTANG
  // ==========================================================
  DestinationTransport(
    destination: 'Mustang',
    options: [
      TransportationOption(
        name: 'Jeep',
        icon: Icons.directions_car_filled,
        description: 'Common option for Mustang mountain roads',
        details: 'Recommended for remote and rough road sections',
      ),
      TransportationOption(
        name: 'Bus',
        icon: Icons.directions_bus,
        description: 'Available on major road sections',
        details: 'Budget-friendly option where routes are available',
      ),
      TransportationOption(
        name: 'Flight',
        icon: Icons.flight,
        description: 'Flights are available to Jomsom',
        details: 'Useful for reducing road travel time',
      ),
      TransportationOption(
        name: 'Motorbike',
        icon: Icons.two_wheeler,
        description: 'Possible for experienced riders',
        details: 'Suitable for the drivable Mustang road network',
      ),
      TransportationOption(
        name: 'Private Vehicle',
        icon: Icons.directions_car,
        description: 'Comfortable option for road travel',
        details: 'Suitable for families and groups',
      ),
    ],
  ),

  // ==========================================================
  // ANNAPURNA
  // ==========================================================
  DestinationTransport(
    destination: 'Annapurna',
    options: [
      TransportationOption(
        name: 'Bus',
        icon: Icons.directions_bus,
        description: 'Available for major road sections',
        details: 'Often combined with trekking',
      ),
      TransportationOption(
        name: 'Jeep',
        icon: Icons.directions_car_filled,
        description: 'Useful for mountain road sections',
        details: 'Common for reaching trekking starting points',
      ),
      TransportationOption(
        name: 'Private Vehicle',
        icon: Icons.directions_car,
        description: 'Comfortable for road sections',
        details: 'Suitable for reaching trekking starting points',
      ),
      TransportationOption(
        name: 'Motorbike',
        icon: Icons.two_wheeler,
        description: 'Possible on accessible roads',
        details: 'Recommended for experienced riders',
      ),
    ],
  ),

  // ==========================================================
  // POKHARA
  // ==========================================================
  DestinationTransport(
    destination: 'Pokhara',
    options: [
      pokharaLocalOption,
      TransportationOption(
        name: 'Bus',
        icon: Icons.directions_bus,
        description: 'Widely available from Kathmandu',
        details: 'Budget-friendly option',
      ),
      TransportationOption(
        name: 'Flight',
        icon: Icons.flight,
        description: 'Fastest option from Kathmandu',
        details: 'Useful when time is limited',
      ),
      TransportationOption(
        name: 'Private Vehicle',
        icon: Icons.directions_car,
        description: 'Comfortable and flexible',
        details: 'Good for families and groups',
      ),
      TransportationOption(
        name: 'Motorbike',
        icon: Icons.two_wheeler,
        description: 'Suitable for experienced riders',
        details: 'Scenic road journey',
      ),
    ],
  ),

  // ==========================================================
  // CHITWAN
  // ==========================================================
  DestinationTransport(
    destination: 'Chitwan',
    options: [
      chitwanLocalOption,
      TransportationOption(
        name: 'Bus',
        icon: Icons.directions_bus,
        description: 'Widely available road connection',
        details: 'Budget-friendly option',
      ),
      TransportationOption(
        name: 'Flight',
        icon: Icons.flight,
        description: 'Flights are available to Bharatpur',
        details: 'Useful for faster travel',
      ),
      TransportationOption(
        name: 'Private Vehicle',
        icon: Icons.directions_car,
        description: 'Comfortable road travel',
        details: 'Suitable for families and groups',
      ),
      TransportationOption(
        name: 'Motorbike',
        icon: Icons.two_wheeler,
        description: 'Possible by road',
        details: 'Suitable for experienced riders',
      ),
    ],
  ),

  // ==========================================================
  // KATHMANDU
  // ==========================================================
  DestinationTransport(
    destination: 'Kathmandu',
    options: [
      kathmanduLocalOption,
      TransportationOption(
        name: 'Bus',
        icon: Icons.directions_bus,
        description: 'Widely available road transportation',
        details: 'Budget-friendly option',
      ),
      TransportationOption(
        name: 'Flight',
        icon: Icons.flight,
        description: 'Available for major domestic routes',
        details: 'Fastest option for suitable destinations',
      ),
      TransportationOption(
        name: 'Private Vehicle',
        icon: Icons.directions_car,
        description: 'Comfortable and flexible',
        details: 'Suitable for families and groups',
      ),
      TransportationOption(
        name: 'Motorbike',
        icon: Icons.two_wheeler,
        description: 'Available for road travel',
        details: 'Best suited for experienced riders',
      ),
    ],
  ),
];

// ============================================================
// DESTINATION LOOKUP
// ============================================================

List<TransportationOption> transportOptionsFor(String destination) {
  final normalized = _normalize(destination);

  for (final item in destinationTransports) {
    if (_normalize(item.destination) == normalized) {
      return item.options;
    }
  }

  return const [];
}

TransportationOption? transportOptionForDestination(
  String destination,
  String mode,
) {
  final options = transportOptionsFor(destination);

  for (final option in options) {
    if (_normalize(option.name) == _normalize(mode)) {
      return option;
    }
  }

  return null;
}

// ============================================================
// LOCAL EXPLORATION DETECTION
// ============================================================

bool isLocalExplorationOption(
  String destination,
  String? selectedTransport,
) {
  if (selectedTransport == null) {
    return false;
  }

  final destinationName = _normalize(destination);
  final transportName = _normalize(selectedTransport);

  if (destinationName == 'kathmandu') {
    return transportName == 'visit kathmandu locally' ||
        transportName == 'visit local places' ||
        transportName == 'kathmandu';
  }

  if (destinationName == 'pokhara') {
    return transportName == 'visit pokhara locally' ||
        transportName == 'visit local places';
  }

  if (destinationName == 'chitwan') {
    return transportName == 'visit chitwan locally' ||
        transportName == 'visit local places';
  }

  return false;
}

// ============================================================
// CANONICAL TRANSPORT OPTIONS
// ============================================================

const TransportationOption trekOption = TransportationOption(
  name: 'Trek',
  icon: Icons.hiking,
  description: 'Trekking or walking on foot',
  details: 'Suitable for trekking-only sections of the route',
);

const TransportationOption _busOption = TransportationOption(
  name: 'Bus',
  icon: Icons.directions_bus,
  description: 'Widely available road transportation',
  details: 'Budget-friendly option',
);

const TransportationOption _flightOption = TransportationOption(
  name: 'Flight',
  icon: Icons.flight,
  description: 'Available for major domestic routes',
  details: 'Fastest option for suitable destinations',
);

const TransportationOption _privateVehicleOption = TransportationOption(
  name: 'Private Vehicle',
  icon: Icons.directions_car,
  description: 'Comfortable and flexible',
  details: 'Suitable for families and groups',
);

const TransportationOption _jeepOption = TransportationOption(
  name: 'Jeep',
  icon: Icons.directions_car_filled,
  description: 'Good for road sections and mountain roads',
  details: 'Common for rugged road sections',
);

const TransportationOption _motorbikeOption = TransportationOption(
  name: 'Motorbike',
  icon: Icons.two_wheeler,
  description: 'Available for road travel',
  details: 'Best suited for experienced riders',
);

// ============================================================
// OPTION GROUPS
// ============================================================

List<TransportationOption> _roadAndAir() => const [
      _busOption,
      _flightOption,
      _privateVehicleOption,
      _jeepOption,
      _motorbikeOption,
    ];

List<TransportationOption> _roadOnly() => const [
      _busOption,
      _privateVehicleOption,
      _jeepOption,
      _motorbikeOption,
    ];

List<TransportationOption> _jomsomOptions() => const [
      _flightOption,
      _busOption,
      _jeepOption,
      _privateVehicleOption,
      _motorbikeOption,
    ];

List<TransportationOption> _mustangRoadOnly() => const [
      _busOption,
      _jeepOption,
      _privateVehicleOption,
      _motorbikeOption,
    ];

List<TransportationOption> _trekOnly() => const [
      trekOption,
    ];

// ============================================================
// TRANSFER NOTES
// ============================================================

const String _luklaNote =
    'Travel to Jiri/Salleri by road, then continue the remaining journey by trekking.';

const String _kathmanduEverestFlightNote =
    'Fly from Kathmandu to Lukla, then continue toward Everest by trekking.';

const String _kathmanduEverestRoadNote =
    'Travel from Kathmandu toward Salleri/Jiri by road, then continue toward Everest by trekking.';

const String _kathmanduAnnapurnaRoadNote =
    'Travel from Kathmandu toward Pokhara/Ghandruk or the accessible trailhead, then continue toward Annapurna by trekking.';

const String _pokharaAnnapurnaRoadNote =
    'Travel from Pokhara to the accessible trekking trailhead, then continue toward Annapurna by trekking.';

const String _viaJomsomNote =
    'Via Jomsom: combine air travel with road transportation.';

// ============================================================
// ROUTE WRAPPERS
// ============================================================

RouteTransport _direct(TransportationOption option) {
  return RouteTransport(
    option: option,
  );
}

RouteTransport _transfer(
  TransportationOption option,
  String note,
) {
  return RouteTransport(
    option: option,
    requiresTransfer: true,
    transferNote: note,
  );
}

List<RouteTransport> _directList(
  List<TransportationOption> options,
) {
  return [
    for (final option in options) _direct(option),
  ];
}

List<RouteTransport> _transferList(
  List<TransportationOption> options,
  String note,
) {
  return [
    for (final option in options) _transfer(option, note),
  ];
}

// ============================================================
// ROUTE KEY
// ============================================================

String _routeKey(
  String from,
  String to,
) {
  return '${_normalize(from)}->${_normalize(to)}';
}

// ============================================================
// ROUTE TRANSPORTATION DATABASE
// ============================================================

Map<String, List<RouteTransport>> get routeTransportOptions {
  final roadAndAir = _directList(
    _roadAndAir(),
  );

  final roadOnly = _directList(
    _roadOnly(),
  );

  final mustangRoadOnly = _directList(
    _mustangRoadOnly(),
  );

  final jomsom = _directList(
    _jomsomOptions(),
  );

  final trekOnly = _directList(
    _trekOnly(),
  );

  // ----------------------------------------------------------
  // Kathmandu/Pokhara -> Kagbeni/Mustang
  // ----------------------------------------------------------

  final viaJomsom = <RouteTransport>[
    ..._directList(
      _mustangRoadOnly(),
    ),
    _transfer(
      _flightOption,
      _viaJomsomNote,
    ),
  ];

  // ----------------------------------------------------------
  // Kathmandu <-> Lukla
  // ----------------------------------------------------------

  final kathmanduLukla = <RouteTransport>[
    _direct(
      _flightOption,
    ),
    ..._transferList(
      const [
        _busOption,
        _privateVehicleOption,
        _jeepOption,
        _motorbikeOption,
      ],
      _luklaNote,
    ),
  ];

  // ----------------------------------------------------------
  // Kathmandu <-> Everest
  // ----------------------------------------------------------

  final kathmanduEverest = <RouteTransport>[
    _transfer(
      _flightOption,
      _kathmanduEverestFlightNote,
    ),
    _transfer(
      _jeepOption,
      _kathmanduEverestRoadNote,
    ),
    _transfer(
      _busOption,
      _kathmanduEverestRoadNote,
    ),
    _transfer(
      _privateVehicleOption,
      _kathmanduEverestRoadNote,
    ),
    _transfer(
      _motorbikeOption,
      _kathmanduEverestRoadNote,
    ),
  ];

  // ----------------------------------------------------------
  // Kathmandu <-> Annapurna
  // ----------------------------------------------------------

  final kathmanduAnnapurna = <RouteTransport>[
    _transfer(
      _busOption,
      _kathmanduAnnapurnaRoadNote,
    ),
    _transfer(
      _jeepOption,
      _kathmanduAnnapurnaRoadNote,
    ),
    _transfer(
      _privateVehicleOption,
      _kathmanduAnnapurnaRoadNote,
    ),
    _transfer(
      _motorbikeOption,
      _kathmanduAnnapurnaRoadNote,
    ),
  ];

  // ----------------------------------------------------------
  // Pokhara <-> Annapurna
  // ----------------------------------------------------------

  final pokharaAnnapurna = <RouteTransport>[
    _transfer(
      _jeepOption,
      _pokharaAnnapurnaRoadNote,
    ),
    _transfer(
      _busOption,
      _pokharaAnnapurnaRoadNote,
    ),
    _transfer(
      _privateVehicleOption,
      _pokharaAnnapurnaRoadNote,
    ),
    _transfer(
      _motorbikeOption,
      _pokharaAnnapurnaRoadNote,
    ),
  ];

  // ----------------------------------------------------------
  // Annapurna trekking routes
  // ----------------------------------------------------------

  final trekOnlyRoutes = <RouteTransport>[
    _direct(
      trekOption,
    ),
  ];

  // ==========================================================
  // RETURN ROUTE MAP
  // ==========================================================

  return {
    // ========================================================
    // MUSTANG
    // ========================================================

    _routeKey('Kathmandu', 'Pokhara'): roadAndAir,
    _routeKey('Pokhara', 'Kathmandu'): roadAndAir,

    _routeKey('Kathmandu', 'Jomsom'): jomsom,
    _routeKey('Pokhara', 'Jomsom'): jomsom,

    _routeKey('Kathmandu', 'Kagbeni'): viaJomsom,
    _routeKey('Pokhara', 'Kagbeni'): viaJomsom,

    _routeKey('Kathmandu', 'Mustang'): viaJomsom,
    _routeKey('Pokhara', 'Mustang'): viaJomsom,

    _routeKey('Jomsom', 'Kagbeni'): mustangRoadOnly,
    _routeKey('Kagbeni', 'Jomsom'): mustangRoadOnly,

    _routeKey('Jomsom', 'Marpha'): mustangRoadOnly,
    _routeKey('Marpha', 'Jomsom'): mustangRoadOnly,

    _routeKey('Jomsom', 'Mustang'): mustangRoadOnly,
    _routeKey('Mustang', 'Jomsom'): mustangRoadOnly,

    _routeKey('Marpha', 'Kagbeni'): mustangRoadOnly,
    _routeKey('Kagbeni', 'Marpha'): mustangRoadOnly,

    _routeKey('Marpha', 'Mustang'): mustangRoadOnly,
    _routeKey('Mustang', 'Marpha'): mustangRoadOnly,

    _routeKey('Kagbeni', 'Muktinath'): mustangRoadOnly,
    _routeKey('Muktinath', 'Kagbeni'): mustangRoadOnly,

    _routeKey('Kagbeni', 'Mustang'): mustangRoadOnly,
    _routeKey('Mustang', 'Kagbeni'): mustangRoadOnly,

    // ========================================================
    // ANNAPURNA
    // ========================================================

    _routeKey('Kathmandu', 'Annapurna'): kathmanduAnnapurna,
    _routeKey('Annapurna', 'Kathmandu'): kathmanduAnnapurna,

    _routeKey('Pokhara', 'Ghandruk'): roadOnly,
    _routeKey('Ghandruk', 'Pokhara'): roadOnly,

    _routeKey('Pokhara', 'Annapurna'): pokharaAnnapurna,
    _routeKey('Annapurna', 'Pokhara'): pokharaAnnapurna,

    _routeKey('Ghandruk', 'Poon Hill'): trekOnlyRoutes,
    _routeKey('Poon Hill', 'Ghandruk'): trekOnlyRoutes,

    _routeKey('Ghandruk', 'Annapurna'): trekOnlyRoutes,
    _routeKey('Annapurna', 'Ghandruk'): trekOnlyRoutes,

    _routeKey('Poon Hill', 'Annapurna'): trekOnlyRoutes,
    _routeKey('Annapurna', 'Poon Hill'): trekOnlyRoutes,

    // ========================================================
    // EVEREST
    // ========================================================

    _routeKey('Kathmandu', 'Lukla'): kathmanduLukla,
    _routeKey('Lukla', 'Kathmandu'): kathmanduLukla,

    _routeKey('Kathmandu', 'Everest'): kathmanduEverest,
    _routeKey('Everest', 'Kathmandu'): kathmanduEverest,

    _routeKey('Lukla', 'Everest'): trekOnly,
    _routeKey('Everest', 'Lukla'): trekOnly,

    _routeKey('Lukla', 'Namche Bazaar'): trekOnly,
    _routeKey('Namche Bazaar', 'Lukla'): trekOnly,

    _routeKey('Namche Bazaar', 'Everest'): trekOnly,
    _routeKey('Everest', 'Namche Bazaar'): trekOnly,

    // ========================================================
    // LOWLAND / CONNECTING ROUTES
    // ========================================================

    _routeKey('Kathmandu', 'Chitwan'): roadAndAir,
    _routeKey('Chitwan', 'Kathmandu'): roadAndAir,

    _routeKey('Kathmandu', 'Tansen'): roadOnly,
    _routeKey('Tansen', 'Kathmandu'): roadOnly,

    _routeKey('Kathmandu', 'Rasuwa'): roadOnly,
    _routeKey('Rasuwa', 'Kathmandu'): roadOnly,

    _routeKey('Chitwan', 'Pokhara'): roadOnly,
    _routeKey('Pokhara', 'Chitwan'): roadOnly,

    _routeKey('Chitwan', 'Tansen'): roadOnly,
    _routeKey('Tansen', 'Chitwan'): roadOnly,

    _routeKey('Tansen', 'Pokhara'): roadOnly,
    _routeKey('Pokhara', 'Tansen'): roadOnly,
  };
}

// ============================================================
// ROUTE LOOKUP
// ============================================================

List<RouteTransport> transportOptionsForRoute(
  String from,
  String to,
) {
  // First try the exact A -> B route.
  final direct = routeTransportOptions[
    _routeKey(
      from,
      to,
    )
  ];

  if (direct != null) {
    return direct;
  }

  // Then try B -> A.
  final reversed = routeTransportOptions[
    _routeKey(
      to,
      from,
    )
  ];

  if (reversed != null) {
    return reversed;
  }

  // Final fallback to destination-based transportation.
  //
  // Local exploration options are intentionally NOT included
  // here because they are not transportation between two
  // different locations.
  return [
    for (final option in transportOptionsFor(to))
      if (!_isLocalExplorationOption(option))
        _direct(option),
  ];
}

// ============================================================
// HELPERS
// ============================================================

bool _isLocalExplorationOption(
  TransportationOption option,
) {
  final name = _normalize(option.name);

  return name == 'visit kathmandu locally' ||
      name == 'visit pokhara locally' ||
      name == 'visit chitwan locally' ||
      name == 'visit local places';
}

// ============================================================
// NORMALIZATION
// ============================================================

String _normalize(String value) {
  return value.trim().toLowerCase();
}