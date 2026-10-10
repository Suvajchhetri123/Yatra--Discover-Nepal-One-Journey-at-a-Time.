import '../models/route_config.dart';

/// Pure helpers that turn active admin route records into a planner graph.
///
/// A destination switches to this graph only when at least one active
/// [RouteConfig] exists for that destination. Screens can therefore keep
/// their legacy route data as a controlled fallback during migration.
class RouteCatalogPlanner {
  const RouteCatalogPlanner._();

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  static List<RouteConfig> routesForDestination(
    Iterable<RouteConfig> routes,
    String destination,
  ) {
    final normalizedDestination = _normalize(destination);

    return [
      for (final route in routes)
        if (route.active &&
            _normalize(route.destination) == normalizedDestination)
          route,
    ];
  }

  /// Builds the directed planner graph.
  ///
  /// Every route contributes from -> to. A reverse edge is created only when
  /// that record is explicitly marked bidirectional.
  static Map<String, List<String>> buildGraph(Iterable<RouteConfig> routes) {
    final names = <String, String>{};
    final edges = <String, Set<String>>{};

    void register(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;

      names.putIfAbsent(_normalize(trimmed), () => trimmed);
    }

    void connect(String from, String to) {
      register(from);
      register(to);

      final fromKey = _normalize(from);
      final toKey = _normalize(to);

      edges.putIfAbsent(fromKey, () => <String>{}).add(toKey);
    }

    for (final route in routes) {
      if (!route.active) continue;

      connect(route.from, route.to);

      if (route.bidirectional) {
        connect(route.to, route.from);
      }
    }

    final result = <String, List<String>>{};

    for (final entry in edges.entries) {
      final fromName = names[entry.key];
      if (fromName == null) continue;

      final next = [
        for (final key in entry.value)
          if (names[key] != null) names[key]!,
      ]..sort();

      result[fromName] = List<String>.unmodifiable(next);
    }

    return Map<String, List<String>>.unmodifiable(result);
  }

  static List<String> locationsForRoutes(
    Iterable<RouteConfig> routes, {
    String? destination,
  }) {
    final canonical = <String, String>{};

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;

      canonical.putIfAbsent(_normalize(trimmed), () => trimmed);
    }

    for (final route in routes) {
      if (!route.active) continue;

      add(route.from);
      add(route.to);
    }

    if (destination != null) {
      add(destination);
    }

    final result = canonical.values.toList()..sort();
    return result;
  }

  /// Modes that can legally travel [from] -> [to].
  ///
  /// A reverse lookup only matches records marked bidirectional.
  static List<String> transportModesForLeg(
    Iterable<RouteConfig> routes,
    String from,
    String to,
  ) {
    final normalizedFrom = _normalize(from);
    final normalizedTo = _normalize(to);
    final result = <String>[];

    void addMode(String mode) {
      final trimmed = mode.trim();
      if (trimmed.isEmpty) return;

      if (!result.any(
        (existing) => _normalize(existing) == _normalize(trimmed),
      )) {
        result.add(trimmed);
      }
    }

    for (final route in routes) {
      if (!route.active) continue;

      final direct =
          _normalize(route.from) == normalizedFrom &&
          _normalize(route.to) == normalizedTo;

      final reverse =
          route.bidirectional &&
          _normalize(route.to) == normalizedFrom &&
          _normalize(route.from) == normalizedTo;

      if (!direct && !reverse) continue;

      for (final mode in route.transportModes) {
        addMode(mode);
      }
    }

    return result;
  }

  /// Unique transportation modes used anywhere in this destination graph.
  static List<String> transportModesForDestination(
    Iterable<RouteConfig> routes,
  ) {
    final result = <String>[];

    for (final route in routes) {
      if (!route.active) continue;

      for (final mode in route.transportModes) {
        final trimmed = mode.trim();
        if (trimmed.isEmpty) continue;

        if (!result.any(
          (existing) => _normalize(existing) == _normalize(trimmed),
        )) {
          result.add(trimmed);
        }
      }
    }

    return result;
  }

  /// Direct neighbors that can legally be travelled to from [from].
  static List<String> connectedFrom(Iterable<RouteConfig> routes, String from) {
    final graph = buildGraph(routes);
    final normalizedFrom = _normalize(from);

    for (final entry in graph.entries) {
      if (_normalize(entry.key) == normalizedFrom) {
        return entry.value;
      }
    }

    return const <String>[];
  }
}
