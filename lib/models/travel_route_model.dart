enum TripDirection { oneWay, roundTrip }

class RouteSegment {
  final String from;
  final String to;
  final String transportation;

  const RouteSegment({
    required this.from,
    required this.to,
    required this.transportation,
  });
}

class TravelRoute {
  final String boardingPoint;
  final String destination;
  final List<RouteSegment> segments;

  /// Transportation used while exploring a destination locally.
  ///
  /// Example:
  /// Walking, Local Bus, Taxi, Motorbike, Private Vehicle.
  ///
  /// This is only used when [segments] is empty and the user
  /// selected local exploration.
  final String? localTransportation;

  /// Optional return-trip segments as chosen by the user.
  ///
  /// When null, return legs are derived by reversing the outgoing
  /// segments and reusing their transportation.
  final List<RouteSegment>? _explicitReturnSegments;

  final TripDirection tripDirection;

  const TravelRoute({
    required this.boardingPoint,
    required this.destination,
    required this.segments,
    this.localTransportation,
    this.tripDirection = TripDirection.oneWay,
    List<RouteSegment>? returnSegments,
  }) : _explicitReturnSegments = returnSegments;

  /// True when this is a local exploration route.
  bool get isLocalExploration {
    return segments.isEmpty && localTransportation != null;
  }

  bool get isOneWay {
    return tripDirection == TripDirection.oneWay;
  }

  bool get isRoundTrip {
    return tripDirection == TripDirection.roundTrip;
  }

  String get tripDirectionDescription {
    if (isRoundTrip) {
      return 'Round Trip';
    }

    return 'One Way';
  }

  String get transportationDescription {
    // Local exploration transportation.
    if (isLocalExploration) {
      return 'Local Transportation: $localTransportation';
    }

    if (segments.isEmpty) {
      return 'No transportation selected';
    }

    return segments
        .map(
          (segment) =>
              '${segment.from} → ${segment.to} (${segment.transportation})',
        )
        .join(' • ');
  }

  String get routeDescription {
    // Local exploration.
    if (isLocalExploration) {
      return 'Explore $destination Locally';
    }

    if (segments.isEmpty) {
      return '$boardingPoint → $destination';
    }

    final points = <String>[
      segments.first.from,
      ...segments.map((segment) => segment.to),
    ];

    return points.join(' → ');
  }

  List<RouteSegment> get returnSegments {
    if (!isRoundTrip || segments.isEmpty) {
      return [];
    }

    // Use the user's explicitly selected return legs when available.
    final explicit = _explicitReturnSegments;

    if (explicit != null && explicit.isNotEmpty) {
      return List<RouteSegment>.from(explicit);
    }

    final reversed = segments.reversed.toList();

    return reversed
        .map(
          (segment) => RouteSegment(
            from: segment.to,
            to: segment.from,
            transportation: segment.transportation,
          ),
        )
        .toList();
  }

  List<RouteSegment> get completeSegments {
    if (!isRoundTrip) {
      return List<RouteSegment>.from(segments);
    }

    return [...segments, ...returnSegments];
  }

  String get completeRouteDescription {
    // Local exploration.
    if (isLocalExploration) {
      return 'Explore $destination Locally';
    }

    final allSegments = completeSegments;

    if (allSegments.isEmpty) {
      return '$boardingPoint → $destination';
    }

    final points = <String>[
      allSegments.first.from,
      ...allSegments.map((segment) => segment.to),
    ];

    return points.join(' → ');
  }
}
