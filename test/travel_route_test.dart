import 'package:flutter_test/flutter_test.dart';
import 'package:yatra/models/travel_route_model.dart';

void main() {
  test('each outgoing and return RouteSegment retains its own transportation',
      () {
    final route = TravelRoute(
      boardingPoint: 'Kathmandu',
      destination: 'Mustang',
      tripDirection: TripDirection.roundTrip,
      segments: const [
        RouteSegment(
            from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
        RouteSegment(
            from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
      ],
      returnSegments: const [
        RouteSegment(
            from: 'Mustang', to: 'Pokhara', transportation: 'Flight'),
        RouteSegment(
            from: 'Pokhara', to: 'Kathmandu', transportation: 'Bus'),
      ],
    );

    // Outgoing transports are preserved per segment.
    expect(route.segments[0].transportation, 'Bus');
    expect(route.segments[1].transportation, 'Jeep');

    // Return transports are preserved per segment (not derived/overwritten).
    expect(route.returnSegments[0].from, 'Mustang');
    expect(route.returnSegments[0].to, 'Pokhara');
    expect(route.returnSegments[0].transportation, 'Flight');
    expect(route.returnSegments[1].from, 'Pokhara');
    expect(route.returnSegments[1].to, 'Kathmandu');
    expect(route.returnSegments[1].transportation, 'Bus');

    // The combined route respects the same order and transports.
    expect(route.completeSegments.length, 4);
    expect(
      route.completeSegments.map((s) => s.transportation).toList(),
      ['Bus', 'Jeep', 'Flight', 'Bus'],
    );
  });

  test('round trip without explicit return segments derives them from outgoing',
      () {
    final route = TravelRoute(
      boardingPoint: 'Kathmandu',
      destination: 'Mustang',
      tripDirection: TripDirection.roundTrip,
      segments: const [
        RouteSegment(
            from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
        RouteSegment(
            from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
      ],
    );

    expect(route.returnSegments[0].from, 'Mustang');
    expect(route.returnSegments[0].transportation, 'Jeep');
    expect(route.returnSegments[1].to, 'Kathmandu');
  });
}
