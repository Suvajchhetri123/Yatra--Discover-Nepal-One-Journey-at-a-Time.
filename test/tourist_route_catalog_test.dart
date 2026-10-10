import 'package:flutter_test/flutter_test.dart';
import 'package:yatra/models/route_config.dart';
import 'package:yatra/services/route_repository.dart';
import 'package:yatra/services/tourist_catalog_controller.dart';

class _FakeRouteRepository implements RouteRepository {
  final List<RouteConfig> stored;

  _FakeRouteRepository(this.stored);

  @override
  Future<List<RouteConfig>> getAllRoutes({bool includeInactive = false}) async {
    return stored.where((route) => includeInactive || route.active).toList();
  }

  @override
  Future<RouteConfig?> getRouteById(String routeId) async {
    for (final route in stored) {
      if (route.id == routeId) return route;
    }
    return null;
  }

  @override
  Future<RouteConfig> createRoute(RouteConfig route, {String? id}) async {
    return route;
  }

  @override
  Future<void> updateRoute(RouteConfig route) async {}

  @override
  Future<void> setRouteActive(String routeId, bool active) async {}
}

void main() {
  test('tourist catalog loads only active injected routes', () async {
    final repository = _FakeRouteRepository([
      const RouteConfig(
        id: 'active-ilam',
        destination: 'Ilam',
        from: 'Kathmandu',
        to: 'Ilam',
        transportModes: ['Bus', 'Jeep'],
        bidirectional: true,
        note: 'Active route',
        active: true,
      ),
      const RouteConfig(
        id: 'inactive-ilam',
        destination: 'Ilam',
        from: 'Birtamod',
        to: 'Ilam',
        transportModes: ['Bus'],
        bidirectional: true,
        note: 'Inactive route',
        active: false,
      ),
    ]);

    final controller = TouristCatalogController(routeRepository: repository);

    await controller.load();

    expect(controller.status, CatalogStatus.ready);
    expect(controller.routes, hasLength(1));
    expect(controller.routes.single.id, 'active-ilam');
    expect(controller.routes.single.destination, 'Ilam');

    controller.dispose();
  });
}
