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

  /// Optional return-trip segments as chosen by the user.
  ///
  /// When null, return legs are derived by reversing the outgoing
  /// segments (and reusing their transportation). When provided,
  /// these exact segments (points, legs and transportation) are used.
  final List<RouteSegment>? _explicitReturnSegments;

  final TripDirection tripDirection;

  const TravelRoute({
    required this.boardingPoint,
    required this.destination,
    required this.segments,
    this.tripDirection = TripDirection.oneWay,
    List<RouteSegment>? returnSegments,
  }) : _explicitReturnSegments = returnSegments;

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
