/// An admin-managed connection used by Yatra's trip planner.
///
/// A route belongs to a final [destination], while [from] -> [to] describes
/// one travel leg that can be used to reach that destination.
///
/// Example:
///
/// destination: Ilam
/// from: Kathmandu
/// to: Birtamod
///
/// A second route may then describe:
///
/// destination: Ilam
/// from: Birtamod
/// to: Ilam
///
/// This allows the Admin CMS to build multi-leg journeys without changing
/// application source code.
class RouteConfig {
  final String id;

  /// Final trip destination whose route graph this leg belongs to.
  final String destination;

  /// Start of this route leg.
  final String from;

  /// End of this route leg.
  final String to;

  /// Canonical transportation names supported on this leg.
  ///
  /// Examples: Bus, Jeep, Flight, Private Vehicle, Motorbike, Trek.
  final List<String> transportModes;

  /// Whether the same connection can also be travelled from [to] to [from].
  final bool bidirectional;

  /// Optional explanation shown with the route.
  final String note;

  /// Soft-removal flag.
  final bool active;

  const RouteConfig({
    this.id = '',
    required this.destination,
    required this.from,
    required this.to,
    required this.transportModes,
    this.bidirectional = true,
    this.note = '',
    this.active = true,
  });

  RouteConfig copyWith({
    String? id,
    String? destination,
    String? from,
    String? to,
    List<String>? transportModes,
    bool? bidirectional,
    String? note,
    bool? active,
  }) {
    return RouteConfig(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      from: from ?? this.from,
      to: to ?? this.to,
      transportModes: transportModes ?? this.transportModes,
      bidirectional: bidirectional ?? this.bidirectional,
      note: note ?? this.note,
      active: active ?? this.active,
    );
  }
}

/// Transportation modes the Admin route editor may publish.
///
/// These names intentionally match the existing transportation engine.
const List<String> kRouteTransportModes = <String>[
  'Bus',
  'Jeep',
  'Flight',
  'Private Vehicle',
  'Motorbike',
  'Trek',
];
