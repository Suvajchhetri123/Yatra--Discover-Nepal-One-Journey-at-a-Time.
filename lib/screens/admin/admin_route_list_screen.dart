import 'package:flutter/material.dart';

import '../../models/route_config.dart';
import '../../services/place_repository.dart';
import '../../services/route_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_route_form_screen.dart';

/// Admin registry for planner routes.
///
/// Routes use soft removal exactly like Places and Packages.
class AdminRouteListScreen extends StatefulWidget {
  final RouteRepository routeRepository;
  final PlaceRepository placeRepository;

  const AdminRouteListScreen({
    super.key,
    required this.routeRepository,
    required this.placeRepository,
  });

  @override
  State<AdminRouteListScreen> createState() => _AdminRouteListScreenState();
}

class _AdminRouteListScreenState extends State<AdminRouteListScreen> {
  List<RouteConfig> _routes = const <RouteConfig>[];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final routes = await widget.routeRepository.getAllRoutes(
        includeInactive: true,
      );

      if (!mounted) return;

      setState(() {
        _routes = routes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load routes. $error';
      });
    }
  }

  Future<void> _openForm({RouteConfig? route}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminRouteFormScreen(
          route: route,
          routeRepository: widget.routeRepository,
          placeRepository: widget.placeRepository,
        ),
      ),
    );

    if (changed == true) {
      await _loadRoutes();
    }
  }

  Future<void> _setActive(RouteConfig route, bool active) async {
    if (_busyId != null) return;

    setState(() {
      _busyId = route.id;
    });

    try {
      await widget.routeRepository.setRouteActive(route.id, active);

      if (!mounted) return;

      setState(() {
        _routes = [
          for (final item in _routes)
            if (item.id == route.id) item.copyWith(active: active) else item,
        ];

        _busyId = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _busyId = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update route. $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add route'),
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _loadRoutes, child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _routes.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && _routes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Icon(
            Icons.route_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton.icon(
              onPressed: _loadRoutes,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_routes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          const SizedBox(height: 160),
          const Icon(Icons.route_outlined, size: 52),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No routes yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add a route to make new destinations usable by the trip planner.',
            textAlign: TextAlign.center,
            style: AppType.caption,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.screen,
        AppSpacing.screen,
        96,
      ),
      children: [
        Text(
          '${_routes.length} route${_routes.length == 1 ? '' : 's'}',
          style: AppType.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final route in _routes) ...[
          _RouteCard(
            route: route,
            busy: _busyId == route.id,
            onEdit: () => _openForm(route: route),
            onToggleActive: () => _setActive(route, !route.active),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RouteConfig route;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _RouteCard({
    required this.route,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return YatraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${route.from} → ${route.to}',
                  style: textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(route.active ? 'Active' : 'Inactive')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('For ${route.destination}', style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final mode in route.transportModes)
                Chip(
                  avatar: const Icon(
                    Icons.directions_transit_outlined,
                    size: 16,
                  ),
                  label: Text(mode),
                ),
            ],
          ),
          if (route.bidirectional) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('↔ Bidirectional', style: textTheme.bodySmall),
          ],
          if (route.note.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(route.note, style: textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onToggleActive,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          route.active
                              ? Icons.remove_circle_outline
                              : Icons.restore,
                          color: route.active ? scheme.error : scheme.primary,
                        ),
                  label: Text(route.active ? 'Remove' : 'Restore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
