import 'package:flutter_test/flutter_test.dart';
import 'package:yatra/data/transportation_data.dart';
import 'package:yatra/models/route_config.dart';
import 'package:yatra/services/route_catalog_planner.dart';

const ilamRoutes = <RouteConfig>[
  RouteConfig(
    id: 'ktm-birtamod',
    destination: 'Ilam',
    from: 'Kathmandu',
    to: 'Birtamod',
    transportModes: ['Bus', 'Private Vehicle'],
    bidirectional: true,
    note: '',
    active: true,
  ),
  RouteConfig(
    id: 'birtamod-ilam',
    destination: 'Ilam',
    from: 'Birtamod',
    to: 'Ilam',
    transportModes: ['Bus', 'Jeep'],
    bidirectional: true,
    note: '',
    active: true,
  ),
];

void main() {
  test('dynamic destination graph contains multi-leg route', () {
    final routes = RouteCatalogPlanner.routesForDestination(ilamRoutes, 'ilam');

    final graph = RouteCatalogPlanner.buildGraph(routes);

    expect(graph['Kathmandu'], contains('Birtamod'));
    expect(graph['Birtamod'], containsAll(['Kathmandu', 'Ilam']));
    expect(graph['Ilam'], contains('Birtamod'));
  });

  test('dynamic route locations include admin-created intermediate points', () {
    final locations = RouteCatalogPlanner.locationsForRoutes(
      ilamRoutes,
      destination: 'Ilam',
    );

    expect(locations, containsAll(['Kathmandu', 'Birtamod', 'Ilam']));
  });

  test('bidirectional route exposes its modes in reverse', () {
    final modes = RouteCatalogPlanner.transportModesForLeg(
      ilamRoutes,
      'Ilam',
      'Birtamod',
    );

    expect(modes, ['Bus', 'Jeep']);
  });

  test('one-way route cannot silently be reversed', () {
    const routes = <RouteConfig>[
      RouteConfig(
        id: 'one-way',
        destination: 'Ilam',
        from: 'Kathmandu',
        to: 'Ilam',
        transportModes: ['Bus'],
        bidirectional: false,
        note: '',
        active: true,
      ),
    ];

    expect(
      RouteCatalogPlanner.transportModesForLeg(routes, 'Kathmandu', 'Ilam'),
      ['Bus'],
    );

    expect(
      RouteCatalogPlanner.transportModesForLeg(routes, 'Ilam', 'Kathmandu'),
      isEmpty,
    );

    expect(RouteCatalogPlanner.connectedFrom(routes, 'Ilam'), isEmpty);
  });

  test('admin mode names map to canonical transportation options', () {
    expect(transportationOptionForMode('Bus')?.name, 'Bus');
    expect(transportationOptionForMode('Jeep')?.name, 'Jeep');
    expect(
      transportationOptionForMode('Private Vehicle')?.name,
      'Private Vehicle',
    );
    expect(transportationOptionForMode('Trek')?.name, 'Trek');
    expect(transportationOptionForMode('unknown'), isNull);
  });
}
