import '../models/route_config.dart';

/// Persistence boundary for Admin-managed planner routes.
abstract class RouteRepository {
  /// Returns routes sorted by destination, start and end location.
  ///
  /// Tourist callers leave [includeInactive] false.
  Future<List<RouteConfig>> getAllRoutes({bool includeInactive = false});

  Future<RouteConfig?> getRouteById(String routeId);

  /// Creates a route and returns the stored record.
  ///
  /// [id] is optional and mainly useful for deterministic seed data.
  Future<RouteConfig> createRoute(RouteConfig route, {String? id});

  /// Updates route business fields.
  ///
  /// `active` is managed only through [setRouteActive].
  Future<void> updateRoute(RouteConfig route);

  /// Soft-removes or restores a route.
  Future<void> setRouteActive(String routeId, bool active);
}
