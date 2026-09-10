import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final String boardingPoint;
  final List<String> destinations;

  const MapScreen({
    super.key,
    required this.boardingPoint,
    required this.destinations,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  static const Map<String, LatLng> locationCoordinates = {
    'Kathmandu': LatLng(27.7172, 85.3240),
    'Pokhara': LatLng(28.2096, 83.9856),
    'Chitwan': LatLng(27.5291, 84.3542),

    'Mustang': LatLng(28.9985, 83.8473),
    'Jomsom': LatLng(28.7804, 83.7223),
    'Marpha': LatLng(28.7515, 83.6835),
    'Kagbeni': LatLng(28.8358, 83.7828),
    'Muktinath': LatLng(28.8167, 83.8710),
    'Kali Gandaki Gorge': LatLng(28.7000, 83.7500),

    'Everest': LatLng(27.9881, 86.9250),
    'Lukla': LatLng(27.6869, 86.7310),
    'Namche Bazaar': LatLng(27.8050, 86.7140),
    'Everest View Hotel': LatLng(27.8035, 86.7155),

    'Annapurna': LatLng(28.5300, 84.0700),
    'Ghandruk': LatLng(28.3739, 83.8063),
    'Poon Hill': LatLng(28.4000, 83.7000),
    'Annapurna Base Camp': LatLng(28.5300, 84.0700),

    'Swayambhunath': LatLng(27.7149, 85.2906),
    'Pashupatinath Temple': LatLng(27.7101, 85.3488),
    'Boudhanath Stupa': LatLng(27.7215, 85.3620),
    'Kathmandu Durbar Square': LatLng(27.7048, 85.3096),

    'Phewa Lake': LatLng(28.2156, 83.9440),
    'World Peace Pagoda': LatLng(28.1900, 83.9440),
    'Davis Falls': LatLng(28.1895, 83.9590),
    'International Mountain Museum': LatLng(28.1919, 83.9690),

    'Chitwan National Park': LatLng(27.5000, 84.3500),
    'Sauraha': LatLng(27.5817, 84.4950),
  };

  List<LatLng> get _locationPoints {
    final points = <LatLng>[];

    final boardingPoint = locationCoordinates[widget.boardingPoint];

    if (boardingPoint != null) {
      points.add(boardingPoint);
    }

    for (final destination in widget.destinations) {
      final coordinate = locationCoordinates[destination];

      if (coordinate != null) {
        points.add(coordinate);
      }
    }

    return points;
  }

  List<LatLng> _routePoints = [];

  double? _distanceKm;
  double? _durationMinutes;

  bool _isLoadingRoute = false;
  bool _routeError = false;

  LatLng get _initialCenter {
    final points = _locationPoints;

    if (points.isNotEmpty) {
      return points.first;
    }

    return const LatLng(27.7172, 85.3240);
  }

  double get _initialZoom {
    final points = _locationPoints;

    if (points.length <= 1) {
      return 13;
    }

    return 8;
  }

  @override
  void initState() {
    super.initState();

    _routePoints = _locationPoints;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoute();
    });
  }

  Future<void> _loadRoute() async {
    final points = _locationPoints;

    if (points.length < 2) {
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = false;
    });

    try {
      final start = points.first;
      final end = points.last;

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'Yatra Travel App'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Routing service returned '
          '${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final routes = data['routes'];

      if (routes is! List || routes.isEmpty) {
        throw Exception('No route found.');
      }

      final firstRoute = routes.first as Map<String, dynamic>;

      final geometry = firstRoute['geometry'] as Map<String, dynamic>?;

      final coordinates = geometry?['coordinates'];

      if (coordinates is! List || coordinates.isEmpty) {
        throw Exception('Route geometry unavailable.');
      }

      final routeCoordinates = <LatLng>[];

      for (final coordinate in coordinates) {
        if (coordinate is List && coordinate.length >= 2) {
          final longitude = (coordinate[0] as num).toDouble();

          final latitude = (coordinate[1] as num).toDouble();

          routeCoordinates.add(LatLng(latitude, longitude));
        }
      }

      final distanceMeters = (firstRoute['distance'] as num?)?.toDouble();

      final durationSeconds = (firstRoute['duration'] as num?)?.toDouble();

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = routeCoordinates.isNotEmpty ? routeCoordinates : points;

        _distanceKm = distanceMeters != null ? distanceMeters / 1000 : null;

        _durationMinutes = durationSeconds != null
            ? durationSeconds / 60
            : null;

        _isLoadingRoute = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitRoute();
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = points;
        _routeError = true;
        _isLoadingRoute = false;
      });
    }
  }

  void _zoomIn() {
    final camera = _mapController.camera;

    _mapController.move(camera.center, camera.zoom + 1);
  }

  void _zoomOut() {
    final camera = _mapController.camera;

    _mapController.move(camera.center, camera.zoom - 1);
  }

  void _fitRoute() {
    final points = _locationPoints;

    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 13);

      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(80),
        maxZoom: 13,
      ),
    );
  }

  String _formatDistance() {
    if (_distanceKm == null) {
      return 'Distance unavailable';
    }

    if (_distanceKm! < 1) {
      return '${(_distanceKm! * 1000).round()} m';
    }

    return '${_distanceKm!.toStringAsFixed(1)} km';
  }

  String _formatDuration() {
    if (_durationMinutes == null) {
      return 'Travel time unavailable';
    }

    final totalMinutes = _durationMinutes!.round();

    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours hr';
    }

    return '$hours hr $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final locationPoints = _locationPoints;

    final startPoint = locationPoints.isNotEmpty ? locationPoints.first : null;

    final endPoint = locationPoints.length > 1 ? locationPoints.last : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.boardingPoint} → '
          '${widget.destinations.isNotEmpty ? widget.destinations.last : ''}',
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapReady: () {
                if (locationPoints.length > 1) {
                  _fitRoute();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/'
                    '{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.yatra',
              ),

              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [Polyline(points: _routePoints, strokeWidth: 5)],
                ),

              if (startPoint != null || endPoint != null)
                MarkerLayer(
                  markers: [
                    if (startPoint != null)
                      Marker(
                        point: startPoint,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          size: 42,
                          color: Colors.green,
                        ),
                      ),

                    if (endPoint != null)
                      Marker(
                        point: endPoint,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          size: 42,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
            ],
          ),

          // =====================================================
          // LOADING INDICATOR
          // =====================================================
          if (_isLoadingRoute)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Finding the best road route...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // =====================================================
          // MAP CONTROLS
          // =====================================================
          Positioned(
            right: 16,
            top: _isLoadingRoute ? 86 : 16,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onPressed: _zoomOut,
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.my_location,
                  tooltip: 'Fit route',
                  onPressed: _fitRoute,
                ),
              ],
            ),
          ),

          // =====================================================
          // ROUTE INFORMATION
          // =====================================================
          if (locationPoints.length >= 2)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                elevation: 5,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${widget.boardingPoint} → '
                              '${widget.destinations.last}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_distanceKm != null || _durationMinutes != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (_distanceKm != null) ...[
                              const Icon(Icons.straighten, size: 18),
                              const SizedBox(width: 5),
                              Text(_formatDistance()),
                            ],

                            if (_distanceKm != null && _durationMinutes != null)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('•'),
                              ),

                            if (_durationMinutes != null) ...[
                              const Icon(Icons.access_time, size: 18),
                              const SizedBox(width: 5),
                              Text(_formatDuration()),
                            ],
                          ],
                        ),
                      ],

                      if (_routeError) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Road route could not be loaded. '
                          'Showing the direct route instead.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 25)),
        ),
      ),
    );
  }
}
