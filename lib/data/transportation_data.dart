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
        details: 'Available for the Everest trekking route',
      ),
      TransportationOption(
        name: 'Jeep',
        icon: Icons.directions_car_filled,
        description: 'Useful for road sections of the journey',
        details: 'Available on selected routes toward the Everest region',
      ),
      TransportationOption(
        name: 'Bus',
        icon: Icons.directions_bus,
        description: 'Available for road sections',
        details: 'Usually combined with other transportation',
      ),
      TransportationOption(
        name: 'Motorbike',
        icon: Icons.two_wheeler,
        description: 'Possible on accessible road sections',
        details: 'Not suitable for the trekking sections',
      ),
      TransportationOption(
        name: 'Private Vehicle',
        icon: Icons.directions_car,
        description: 'Available for accessible road sections',
        details: 'Does not replace the trekking portion',
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
        details: 'Suitable for families and groups',
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

/// Access to Jomsom.
///
/// Motorbike is allowed because the road journey can be travelled by
/// experienced riders.
List<TransportationOption> _jomsomOptions() => const [
      _flightOption,
      _busOption,
      _jeepOption,
      _privateVehicleOption,
      _motorbikeOption,
    ];

/// Mustang road network.
///
/// Motorbike is intentionally INCLUDED here.
/// This allows:
/// Jomsom -> Mustang
/// Marpha -> Mustang
/// Kagbeni -> Mustang
/// Jomsom -> Kagbeni
/// etc.
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
    'No road reaches Lukla directly: drive to Jiri/Salleri, then trek the rest.';

const String _viaJomsomNote =
    'Via Jomsom: combine air travel with road transportation.';

const String _trailheadNote =
    'Road to the trailhead, then trek the remaining section.';

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
  //
  // Road modes reach these destinations directly.
  //
  // Flight reaches Jomsom first and therefore requires a transfer.
  //
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
  //
  // Flight is direct.
  //
  // Road modes can be used to reach a trailhead such as
  // Jiri/Salleri, after which trekking is required.
  //
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
  // Annapurna trail routes
  // ----------------------------------------------------------

  final trailheadTrek = <RouteTransport>[
    _direct(
      trekOption,
    ),
    _transfer(
      _jeepOption,
      _trailheadNote,
    ),
    _transfer(
      _privateVehicleOption,
      _trailheadNote,
    ),
    _transfer(
      _busOption,
      _trailheadNote,
    ),
  ];

  // ==========================================================
  // RETURN ROUTE MAP
  // ==========================================================

  return {
    // ========================================================
    // MUSTANG
    // ========================================================

    _routeKey(
      'Kathmandu',
      'Pokhara',
    ): roadAndAir,

    _routeKey(
      'Pokhara',
      'Kathmandu',
    ): roadAndAir,

    _routeKey(
      'Kathmandu',
      'Jomsom',
    ): jomsom,

    _routeKey(
      'Pokhara',
      'Jomsom',
    ): jomsom,

    _routeKey(
      'Kathmandu',
      'Kagbeni',
    ): viaJomsom,

    _routeKey(
      'Pokhara',
      'Kagbeni',
    ): viaJomsom,

    _routeKey(
      'Kathmandu',
      'Mustang',
    ): viaJomsom,

    _routeKey(
      'Pokhara',
      'Mustang',
    ): viaJomsom,

    // Mustang interior.
    //
    // IMPORTANT:
    // Motorbike is INCLUDED here.
    _routeKey(
      'Jomsom',
      'Kagbeni',
    ): mustangRoadOnly,

    _routeKey(
      'Kagbeni',
      'Jomsom',
    ): mustangRoadOnly,

    _routeKey(
      'Jomsom',
      'Marpha',
    ): mustangRoadOnly,

    _routeKey(
      'Marpha',
      'Jomsom',
    ): mustangRoadOnly,

    _routeKey(
      'Jomsom',
      'Mustang',
    ): mustangRoadOnly,

    _routeKey(
      'Mustang',
      'Jomsom',
    ): mustangRoadOnly,

    _routeKey(
      'Marpha',
      'Kagbeni',
    ): mustangRoadOnly,

    _routeKey(
      'Kagbeni',
      'Marpha',
    ): mustangRoadOnly,

    _routeKey(
      'Marpha',
      'Mustang',
    ): mustangRoadOnly,

    _routeKey(
      'Mustang',
      'Marpha',
    ): mustangRoadOnly,

    _routeKey(
      'Kagbeni',
      'Muktinath',
    ): mustangRoadOnly,

    _routeKey(
      'Muktinath',
      'Kagbeni',
    ): mustangRoadOnly,

    _routeKey(
      'Kagbeni',
      'Mustang',
    ): mustangRoadOnly,

    _routeKey(
      'Mustang',
      'Kagbeni',
    ): mustangRoadOnly,

    // ========================================================
    // ANNAPURNA
    // ========================================================

    _routeKey(
      'Pokhara',
      'Ghandruk',
    ): roadOnly,

    _routeKey(
      'Ghandruk',
      'Pokhara',
    ): roadOnly,

    _routeKey(
      'Pokhara',
      'Poon Hill',
    ): trailheadTrek,

    _routeKey(
      'Poon Hill',
      'Pokhara',
    ): trailheadTrek,

    _routeKey(
      'Ghandruk',
      'Poon Hill',
    ): trekOnly,

    _routeKey(
      'Poon Hill',
      'Ghandruk',
    ): trekOnly,

    _routeKey(
      'Ghandruk',
      'Annapurna',
    ): trekOnly,

    _routeKey(
      'Annapurna',
      'Ghandruk',
    ): trekOnly,

    _routeKey(
      'Poon Hill',
      'Annapurna',
    ): trekOnly,

    _routeKey(
      'Annapurna',
      'Poon Hill',
    ): trekOnly,

    _routeKey(
      'Pokhara',
      'Annapurna',
    ): trailheadTrek,

    _routeKey(
      'Annapurna',
      'Pokhara',
    ): trailheadTrek,

    // ========================================================
    // EVEREST
    // ========================================================

    _routeKey(
      'Kathmandu',
      'Lukla',
    ): kathmanduLukla,

    _routeKey(
      'Lukla',
      'Kathmandu',
    ): kathmanduLukla,

    _routeKey(
      'Lukla',
      'Namche Bazaar',
    ): trekOnly,

    _routeKey(
      'Namche Bazaar',
      'Lukla',
    ): trekOnly,

    _routeKey(
      'Namche Bazaar',
      'Everest',
    ): trekOnly,

    _routeKey(
      'Everest',
      'Namche Bazaar',
    ): trekOnly,

    // ========================================================
    // LOWLAND / CONNECTING ROUTES
    // ========================================================

    _routeKey(
      'Kathmandu',
      'Chitwan',
    ): roadAndAir,

    _routeKey(
      'Chitwan',
      'Kathmandu',
    ): roadAndAir,

    _routeKey(
      'Kathmandu',
      'Tansen',
    ): roadOnly,

    _routeKey(
      'Tansen',
      'Kathmandu',
    ): roadOnly,

    _routeKey(
      'Kathmandu',
      'Rasuwa',
    ): roadOnly,

    _routeKey(
      'Rasuwa',
      'Kathmandu',
    ): roadOnly,

    _routeKey(
      'Chitwan',
      'Pokhara',
    ): roadOnly,

    _routeKey(
      'Pokhara',
      'Chitwan',
    ): roadOnly,

    _routeKey(
      'Chitwan',
      'Tansen',
    ): roadOnly,

    _routeKey(
      'Tansen',
      'Chitwan',
    ): roadOnly,

    _routeKey(
      'Tansen',
      'Pokhara',
    ): roadOnly,

    _routeKey(
      'Pokhara',
      'Tansen',
    ): roadOnly,
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

  // Then try B -> A because most routes have the same transportation
  // suitability in both directions.
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
  return [
    for (final option in transportOptionsFor(to))
      _direct(option),
  ];
}

// ============================================================
// NORMALIZATION
// ============================================================

String _normalize(String value) {
  return value.trim().toLowerCase();
}