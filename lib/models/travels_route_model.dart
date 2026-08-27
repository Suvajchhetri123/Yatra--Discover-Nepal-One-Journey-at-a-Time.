class TravelRoute {
  final String boardingPoint;
  final String destination;
  final List<RouteSegment> segments;

  const TravelRoute({
    required this.boardingPoint,
    required this.destination,
    required this.segments,
  });

  String get routeDescription {
    if (segments.isEmpty) {
      return '$boardingPoint → $destination';
    }

    final points = <String>[boardingPoint];

    for (final segment in segments) {
      points.add(segment.to);
    }

    return points.join(' → ');
  }

  String get transportationDescription {
    if (segments.isEmpty) {
      return 'Not selected';
    }

    return segments
        .map(
          (segment) =>
              '${segment.from} → ${segment.to} (${segment.transportation})',
        )
        .join(' → ');
  }
}

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