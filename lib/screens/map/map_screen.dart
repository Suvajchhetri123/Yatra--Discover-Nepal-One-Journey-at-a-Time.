import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/travel_route_model.dart';
import '../../services/location_service.dart';

class MapScreen extends StatefulWidget {
  final String boardingPoint;
  final List<String> destinations;

  /// When supplied, the map uses the real Yatra route segments, including
  /// selected transportation and return segments.
  final TravelRoute? travelRoute;

  /// Used by the small "View Map" button for a single itinerary travel leg.
  final String? singleLegTransportation;

  const MapScreen({
    super.key,
    required this.boardingPoint,
    required this.destinations,
    this.travelRoute,
    this.singleLegTransportation,
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

    // "Mustang" is a district rather than a single map point.
    // For Yatra's Mustang destination marker, use Lo Manthang as the
    // concrete destination in Upper Mustang so routing services receive
    // a real settlement endpoint instead of an arbitrary district-center
    // coordinate.
    'Mustang': LatLng(29.18284, 83.95630),
    'Lo Manthang': LatLng(29.18284, 83.95630),
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

  // Stored route corridor for remote Upper Mustang where the public
  // OSRM driving service may not return usable geometry.
  //
  // This is NOT turn-by-turn navigation. It is a structured visual
  // corridor using known settlements along the Jomsom -> Lo Manthang
  // journey so the map does not fall back to one unrealistic straight line.
  static const List<LatLng> _jomsomToMustangCorridor = [
    LatLng(28.7804, 83.7223), // Jomsom
    LatLng(28.83776, 83.78431), // Kagbeni
    LatLng(28.91437, 83.81992), // Chhusang
    LatLng(28.93106, 83.82700), // Chele
    LatLng(28.96293, 83.80367), // Samar
    LatLng(28.99124, 83.83855), // Syangboche (Mustang)
    LatLng(29.06498, 83.86935), // Ghami
    LatLng(29.09261, 83.93227), // Charang
    LatLng(29.18284, 83.95630), // Lo Manthang / Yatra "Mustang"
  ];

  List<_MapLeg> get _legs {
    final travelRoute = widget.travelRoute;

    if (travelRoute != null && travelRoute.completeSegments.isNotEmpty) {
      return travelRoute.completeSegments
          .map(
            (segment) => _MapLeg(
              from: segment.from,
              to: segment.to,
              transportation: segment.transportation,
            ),
          )
          .toList();
    }

    final names = <String>[widget.boardingPoint, ...widget.destinations];

    final result = <_MapLeg>[];

    for (int i = 0; i < names.length - 1; i++) {
      result.add(
        _MapLeg(
          from: names[i],
          to: names[i + 1],
          transportation: widget.singleLegTransportation ?? 'Road',
        ),
      );
    }

    return result;
  }

  List<String> get _orderedLocationNames {
    final travelRoute = widget.travelRoute;

    if (travelRoute != null) {
      if (travelRoute.completeSegments.isEmpty) {
        return <String>[travelRoute.destination];
      }

      return <String>[
        travelRoute.completeSegments.first.from,
        ...travelRoute.completeSegments.map((segment) => segment.to),
      ];
    }

    return <String>[widget.boardingPoint, ...widget.destinations];
  }

  List<LatLng> get _knownRoutePoints {
    final points = <LatLng>[];

    for (final name in _orderedLocationNames) {
      final coordinate = locationCoordinates[name];

      if (coordinate == null) {
        continue;
      }

      if (points.isNotEmpty &&
          points.last.latitude == coordinate.latitude &&
          points.last.longitude == coordinate.longitude) {
        continue;
      }

      points.add(coordinate);
    }

    return points;
  }

  List<String> get _unknownLocations {
    return _orderedLocationNames
        .where((name) => locationCoordinates[name] == null)
        .toSet()
        .toList();
  }

  bool get _hasNonRoadTransportation {
    return _legs.any((leg) => !_isRoadTransportation(leg.transportation));
  }

  /// The live GPS position, when it should replace the fixed boarding
  /// coordinate as the real start of the very first outbound road leg.
  ///
  /// Returns the GPS point only when:
  ///   * the first leg is a road mode (Bus/Jeep/Car/Taxi/Motorbike), so
  ///     Flight and Trek behavior is never changed;
  ///   * the leg is an actual intercity journey (start != end city);
  ///   * the tourist is reasonably close to the selected boarding city
  ///     (within [boardingGpsRadiusMeters]).
  LatLng? get _gpsBoardStart {
    final legs = _legs;

    if (legs.isEmpty) {
      return null;
    }

    final firstLeg = legs.first;

    if (!_isRoadTransportation(firstLeg.transportation)) {
      return null;
    }

    if (firstLeg.from.trim().toLowerCase() ==
        firstLeg.to.trim().toLowerCase()) {
      return null;
    }

    final cityCoordinate = locationCoordinates[firstLeg.from];
    final gps = _currentLatLng;

    if (cityCoordinate == null || gps == null) {
      return null;
    }

    final distanceMeters = Geolocator.distanceBetween(
      cityCoordinate.latitude,
      cityCoordinate.longitude,
      gps.latitude,
      gps.longitude,
    );

    if (distanceMeters > boardingGpsRadiusMeters) {
      return null;
    }

    return gps;
  }

  bool get _isStartingFromGps => _gpsBoardStart != null;

  /// Known route points used to frame the whole trip, with the fixed boarding
  /// point replaced by the real GPS departure when one is being used.
  List<LatLng> get _fittedRoutePoints {
    final points = _knownRoutePoints;

    final gpsStart = _gpsBoardStart;

    if (gpsStart == null || points.isEmpty) {
      return points;
    }

    final fitted = List<LatLng>.from(points);
    fitted[0] = gpsStart;
    return fitted;
  }

  final List<Polyline> _routePolylines = [];
  final List<String> _routeWarnings = [];

  double? _distanceKm;
  double? _durationMinutes;

  bool _isLoadingRoute = false;

  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationMessage;

  /// Radius within which the tourist's real GPS position counts as "at" the
  /// selected boarding city. Inside this radius the first outbound road leg
  /// may start from the live GPS point instead of the fixed city coordinate.
  ///
  /// A larger distance (e.g. the ~8 km from Balaju to central Kathmandu)
  /// violates the rule, but a genuinely far-away tourist (e.g. planning a
  /// Kathmandu trip while physically in Pokhara) keeps the fixed boarding
  /// point.
  static const double boardingGpsRadiusMeters = 30000;

  /// Useful navigation zoom used when following the tourist's live movement.
  static const double _followZoom = 15;

  StreamSubscription<Position>? _positionStreamSubscription;

  /// When true, the camera stays centred on the live blue marker.
  bool _followMe = false;

  bool _mapReady = false;

  LatLng? get _currentLatLng {
    final position = _currentPosition;

    if (position == null) {
      return null;
    }

    return LatLng(position.latitude, position.longitude);
  }

  LatLng get _initialCenter {
    final points = _knownRoutePoints;

    if (points.isNotEmpty) {
      return points.first;
    }

    return const LatLng(27.7172, 85.3240);
  }

  double get _initialZoom {
    final points = _knownRoutePoints;

    if (points.length <= 1) {
      return 13;
    }

    return 8;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialiseMap();
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  /// Initialisation order matters because the first route leg may need GPS.
  ///
  /// 1. Read the current GPS position once (with a short timeout) so it can
  ///    be used as the real start of the first road leg.
  /// 2. Start the continuous position stream for the blue live-location
  ///    marker.
  /// 3. Load the planned route. It stays stable afterwards while the live
  ///    marker keeps moving.
  ///
  /// If GPS is unavailable the map never waits forever: the planned route
  /// simply uses the fixed city boarding coordinate, as before.
  Future<void> _initialiseMap() async {
    try {
      await _loadCurrentLocation().timeout(const Duration(seconds: 8));
    } catch (_) {
      // GPS did not answer in time; the planned route still loads below.
    }

    if (!mounted) {
      return;
    }

    if (_isLoadingLocation) {
      setState(() {
        _isLoadingLocation = false;
      });
    }

    unawaited(_startPositionStream());

    await _loadRoute();
  }

  /// Listens to GPS updates while the map is open so the blue marker moves
  /// with the tourist without reopening the screen.
  Future<void> _startPositionStream() async {
    if (_positionStreamSubscription != null) {
      return;
    }

    if (!await LocationService.isLocationAccessAllowed()) {
      return;
    }

    if (!mounted) {
      return;
    }

    _positionStreamSubscription = LocationService.livePositionStream().listen(
      (position) {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentPosition = position;
          _locationMessage = null;
        });

        // Follow Me only moves the camera; it never re-requests the route.
        if (_followMe && _mapReady) {
          final camera = _mapController.camera;
          final zoom = camera.zoom < _followZoom ? _followZoom : camera.zoom;
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            zoom,
          );
        }
      },
      onError: (Object _) {
        if (!mounted) {
          return;
        }

        setState(() {
          _locationMessage =
              'Live location tracking is temporarily unavailable.';
        });
      },
    );
  }

  Future<void> _loadCurrentLocation() async {
    if (_isLoadingLocation) {
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    try {
      final position = await LocationService.getCurrentLocation();

      if (!mounted) {
        return;
      }

      if (position == null) {
        setState(() {
          _isLoadingLocation = false;
          _locationMessage =
              'Current location is unavailable. Check GPS and location permission.';
        });
        return;
      }

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
        _locationMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLocation = false;
        _locationMessage = 'Could not read the current device location.';
      });
    }
  }

  bool _routeGeometryMatchesRequestedLeg(
    LatLng requestedStart,
    LatLng requestedEnd,
    List<LatLng> geometryPoints,
  ) {
    if (geometryPoints.isEmpty) {
      return false;
    }

    final first = geometryPoints.first;
    final last = geometryPoints.last;

    final startGapMeters = Geolocator.distanceBetween(
      requestedStart.latitude,
      requestedStart.longitude,
      first.latitude,
      first.longitude,
    );

    final endGapMeters = Geolocator.distanceBetween(
      requestedEnd.latitude,
      requestedEnd.longitude,
      last.latitude,
      last.longitude,
    );

    // OSRM can sometimes snap remote Nepal locations to unrelated roads.
    // Reject such geometry and use the selected Yatra leg as a direct
    // connection instead.
    const maxSnapDistanceMeters = 12000.0;

    return startGapMeters <= maxSnapDistanceMeters &&
        endGapMeters <= maxSnapDistanceMeters;
  }

  List<LatLng>? _storedRemoteRouteForLeg(String from, String to) {
    final a = from.trim().toLowerCase();
    final b = to.trim().toLowerCase();

    final isForward = a == 'jomsom' && (b == 'mustang' || b == 'lo manthang');

    final isReverse = (a == 'mustang' || a == 'lo manthang') && b == 'jomsom';

    if (isForward) {
      return List<LatLng>.from(_jomsomToMustangCorridor);
    }

    if (isReverse) {
      return _jomsomToMustangCorridor.reversed.toList();
    }

    return null;
  }

  Future<_RouteGeometry?> _loadRoadGeometry(LatLng start, LatLng end) async {
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
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'];

    if (routes is! List || routes.isEmpty) {
      return null;
    }

    final firstRoute = routes.first as Map<String, dynamic>;
    final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'];

    if (coordinates is! List || coordinates.isEmpty) {
      return null;
    }

    final points = <LatLng>[];

    for (final coordinate in coordinates) {
      if (coordinate is List && coordinate.length >= 2) {
        final longitude = (coordinate[0] as num).toDouble();
        final latitude = (coordinate[1] as num).toDouble();

        points.add(LatLng(latitude, longitude));
      }
    }

    if (points.isEmpty) {
      return null;
    }

    if (!_routeGeometryMatchesRequestedLeg(start, end, points)) {
      return null;
    }

    final distanceMeters = (firstRoute['distance'] as num?)?.toDouble();
    final durationSeconds = (firstRoute['duration'] as num?)?.toDouble();

    return _RouteGeometry(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  Future<void> _loadRoute() async {
    final legs = _legs;

    setState(() {
      _isLoadingRoute = true;
      _routePolylines.clear();
      _routeWarnings.clear();
      _distanceKm = null;
      _durationMinutes = null;
    });

    if (legs.isEmpty) {
      setState(() {
        _isLoadingRoute = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitRoute();
        }
      });
      return;
    }

    final polylines = <Polyline>[];
    final warnings = <String>[];

    double roadDistanceMeters = 0;
    double roadDurationSeconds = 0;
    bool allRoadLegsResolved = true;

    // Only the very first outbound road leg may start from the tourist's
    // live GPS position (when they are close to the boarding city). Every
    // later leg -- including all return segments -- keeps its planned
    // city-to-city coordinates.
    final gpsBoardStart = _gpsBoardStart;

    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final isFirstLeg = i == 0;
      final start = locationCoordinates[leg.from];
      final end = locationCoordinates[leg.to];

      if (start == null || end == null) {
        warnings.add(
          '${leg.from} → ${leg.to}: map coordinates are unavailable.',
        );
        allRoadLegsResolved = false;
        continue;
      }

      if (_isRoadTransportation(leg.transportation)) {
        final routeStart = isFirstLeg && gpsBoardStart != null
            ? gpsBoardStart
            : start;

        try {
          final geometry = await _loadRoadGeometry(routeStart, end);

          if (geometry != null) {
            polylines.add(
              Polyline(
                points: geometry.points,
                strokeWidth: 5,
                color: Colors.teal,
              ),
            );

            if (geometry.distanceMeters != null) {
              roadDistanceMeters += geometry.distanceMeters!;
            } else {
              allRoadLegsResolved = false;
            }

            if (geometry.durationSeconds != null) {
              roadDurationSeconds += geometry.durationSeconds!;
            } else {
              allRoadLegsResolved = false;
            }

            continue;
          }
        } catch (_) {
          // The direct-line fallback below keeps the selected leg visible.
        }

        final storedRemoteRoute = _storedRemoteRouteForLeg(leg.from, leg.to);

        if (storedRemoteRoute != null) {
          // Do not count this as a map error. Yatra has a structured
          // Upper Mustang corridor specifically for this remote leg.
          polylines.add(
            Polyline(
              points: storedRemoteRoute,
              strokeWidth: 6,
              color: Colors.orange,
              borderStrokeWidth: 2,
              borderColor: Colors.white,
            ),
          );

          // Road distance/time from OSRM is intentionally not added because
          // this stored corridor is for route visualization, not navigation.
          allRoadLegsResolved = false;
          continue;
        }

        allRoadLegsResolved = false;
        warnings.add(
          '${leg.from} → ${leg.to}: a reliable road route was not '
          'available, so the selected leg is shown as a direct connection.',
        );

        polylines.add(
          Polyline(
            points: [routeStart, end],
            strokeWidth: 6,
            color: Colors.orange,
            borderStrokeWidth: 2,
            borderColor: Colors.white,
          ),
        );
      } else {
        // Flight and trekking/walking legs should not be sent to a driving
        // router because that would create a misleading road route.
        polylines.add(
          Polyline(
            points: [start, end],
            strokeWidth: 5,
            color: _transportColor(leg.transportation),
            borderStrokeWidth: 2,
            borderColor: Colors.white,
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _routePolylines
        ..clear()
        ..addAll(polylines);

      _routeWarnings
        ..clear()
        ..addAll(warnings);

      if (!_hasNonRoadTransportation && allRoadLegsResolved) {
        _distanceKm = roadDistanceMeters / 1000;
        _durationMinutes = roadDurationSeconds / 60;
      }

      _isLoadingRoute = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitRoute();
      }
    });
  }

  bool _isRoadTransportation(String value) {
    final transport = value.toLowerCase().trim();

    if (transport.contains('flight') || transport.contains('air')) {
      return false;
    }

    if (transport.contains('trek') ||
        transport.contains('hike') ||
        transport.contains('walk')) {
      return false;
    }

    return true;
  }

  Color _transportColor(String value) {
    final transport = value.toLowerCase().trim();

    if (transport.contains('flight') || transport.contains('air')) {
      return Colors.deepPurple;
    }

    if (transport.contains('trek') ||
        transport.contains('hike') ||
        transport.contains('walk')) {
      return Colors.orange;
    }

    return Colors.teal;
  }

  IconData _transportIcon(String value) {
    final transport = value.toLowerCase().trim();

    if (transport.contains('flight') || transport.contains('air')) {
      return Icons.flight;
    }

    if (transport.contains('trek') ||
        transport.contains('hike') ||
        transport.contains('walk')) {
      return Icons.hiking;
    }

    if (transport.contains('bus')) {
      return Icons.directions_bus;
    }

    if (transport.contains('jeep') ||
        transport.contains('car') ||
        transport.contains('vehicle') ||
        transport.contains('taxi')) {
      return Icons.directions_car;
    }

    if (transport.contains('motor')) {
      return Icons.two_wheeler;
    }

    return Icons.directions;
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
    // Fitting the whole route is an explicit "view everything" request, so
    // the camera stops following the tourist.
    if (_followMe) {
      _followMe = false;
      if (mounted) {
        setState(() {});
      }
    }

    final points = _fittedRoutePoints;

    if (points.isEmpty) {
      final current = _currentLatLng;

      if (current != null) {
        _mapController.move(current, _followZoom);
      }

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

  Future<void> _goToCurrentLocation() async {
    if (_currentLatLng == null) {
      await _loadCurrentLocation();
      unawaited(_startPositionStream());
    }

    final current = _currentLatLng;

    if (current != null) {
      if (_mapReady) {
        _mapController.move(current, _followZoom);
      }

      if (mounted) {
        setState(() {
          _followMe = true;
        });
      }

      return;
    }

    if (!mounted) {
      return;
    }

    await _showLocationHelp();
  }

  void _toggleFollowMe() {
    setState(() {
      _followMe = !_followMe;
    });

    if (_followMe) {
      final current = _currentLatLng;

      if (current != null && _mapReady) {
        _mapController.move(current, _followZoom);
      }
    }
  }

  Future<void> _showLocationHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Location unavailable'),
          content: const Text(
            'Make sure location services are turned on and Yatra has '
            'permission to access your location.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Geolocator.openLocationSettings();
              },
              child: const Text('Location Settings'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Geolocator.openAppSettings();
              },
              child: const Text('App Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
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

  List<Marker> _buildRouteMarkers() {
    final markers = <Marker>[];
    final usedNames = <String>{};
    final destination =
        widget.travelRoute?.destination ??
        (widget.destinations.isNotEmpty ? widget.destinations.last : null);

    for (int i = 0; i < _orderedLocationNames.length; i++) {
      final name = _orderedLocationNames[i];

      if (usedNames.contains(name)) {
        continue;
      }

      final point = locationCoordinates[name];

      if (point == null) {
        continue;
      }

      usedNames.add(name);

      final isStart = name == widget.boardingPoint;
      final isMainDestination = destination != null && name == destination;

      markers.add(
        Marker(
          point: point,
          width: 58,
          height: 58,
          child: Tooltip(
            message:
                isStart &&
                    widget.travelRoute?.isRoundTrip == true &&
                    _orderedLocationNames.last == widget.boardingPoint
                ? '$name · Start / Finish'
                : name,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  isStart
                      ? Icons.trip_origin
                      : isMainDestination
                      ? Icons.location_on
                      : Icons.place,
                  size: isStart || isMainDestination ? 44 : 36,
                  color: isStart
                      ? Colors.green
                      : isMainDestination
                      ? Colors.red
                      : Colors.orange,
                ),
                if (!isStart && !isMainDestination)
                  Positioned(
                    top: 8,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  String get _routeTitle {
    final travelRoute = widget.travelRoute;

    if (travelRoute != null) {
      if (travelRoute.isLocalExploration) {
        return 'Explore ${travelRoute.destination}';
      }

      if (travelRoute.isRoundTrip) {
        return '${travelRoute.boardingPoint} ↔ ${travelRoute.destination}';
      }

      return '${travelRoute.boardingPoint} → ${travelRoute.destination}';
    }

    if (widget.destinations.isEmpty) {
      return widget.boardingPoint;
    }

    return '${widget.boardingPoint} → ${widget.destinations.last}';
  }

  String get _routeTypeText {
    final travelRoute = widget.travelRoute;

    if (travelRoute == null) {
      return _legs.length == 1 ? 'Travel leg' : '${_legs.length} route legs';
    }

    if (travelRoute.isLocalExploration) {
      return 'Local exploration';
    }

    return '${travelRoute.tripDirectionDescription} · ${_legs.length} leg(s)';
  }

  void _showRouteDetails() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final legs = _legs;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _routeTypeText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),

                  if (legs.isEmpty)
                    Text(
                      'No intercity route is required for this local trip.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                  ...legs.asMap().entries.map((entry) {
                    final number = entry.key + 1;
                    final leg = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 16, child: Text('$number')),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${leg.from} → ${leg.to}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      _transportIcon(leg.transportation),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(leg.transportation)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (_hasNonRoadTransportation) ...[
                    const Divider(),
                    const SizedBox(height: 6),
                    Text(
                      'Flight and trekking/walking sections are shown as '
                      'direct map connections because the road-routing service '
                      'does not represent those travel modes.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],

                  if (_legs.any(
                    (leg) => _storedRemoteRouteForLeg(leg.from, leg.to) != null,
                  )) ...[
                    const Divider(),
                    const SizedBox(height: 6),
                    Text(
                      'Upper Mustang note: Jomsom ↔ Mustang is displayed '
                      'using Yatra\'s stored route corridor through known '
                      'settlements. It is for trip visualization, not '
                      'turn-by-turn navigation.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],

                  if (_routeWarnings.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 6),
                    Text(
                      'Map Notes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._routeWarnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $warning'),
                      ),
                    ),
                  ],

                  if (_unknownLocations.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 6),
                    Text(
                      'Coordinates are not yet available for: '
                      '${_unknownLocations.join(', ')}.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPoint = _currentLatLng;

    return Scaffold(
      appBar: AppBar(title: Text(_routeTitle)),
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
                _mapReady = true;
                _fitRoute();
              },
              onPositionChanged: (camera, hasGesture) {
                // A manual drag or pinch means the user is looking around, so
                // the camera should stop jumping back to the tourist.
                if (hasGesture && _followMe) {
                  _followMe = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {});
                    }
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.yatra',
              ),

              if (_routePolylines.isNotEmpty)
                PolylineLayer(polylines: _routePolylines),

              MarkerLayer(
                markers: [
                  ..._buildRouteMarkers(),

                  if (currentPoint != null)
                    Marker(
                      point: currentPoint,
                      width: 64,
                      height: 64,
                      child: const Tooltip(
                        message: 'Your live location',
                        child: _LiveLocationIndicator(),
                      ),
                    ),
                ],
              ),

              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          if (_isLoadingRoute)
            Positioned(
              top: 16,
              left: 16,
              right: 80,
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
                          'Loading route map...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
                  icon: Icons.route,
                  tooltip: 'Fit route',
                  onPressed: _fitRoute,
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: _followMe ? Icons.gps_fixed : Icons.gps_not_fixed,
                  tooltip: _followMe ? 'Follow me · on' : 'Follow me · off',
                  onPressed: _toggleFollowMe,
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: _isLoadingLocation
                      ? Icons.hourglass_top
                      : Icons.my_location,
                  tooltip: 'My current location',
                  onPressed: _isLoadingLocation
                      ? () {}
                      : () {
                          _goToCurrentLocation();
                        },
                ),
              ],
            ),
          ),

          if (_locationMessage != null)
            Positioned(
              left: 16,
              right: 80,
              top: _isLoadingRoute ? 86 : 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _locationMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.route, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _routeTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _routeTypeText,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),

                              if (_isStartingFromGps) ...[
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.my_location,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'This trip starts from your current '
                                        'location.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_distanceKm != null && _durationMinutes != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.straighten, size: 18),
                          const SizedBox(width: 5),
                          Text(_formatDistance()),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('•'),
                          ),
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 5),
                          Text(_formatDuration()),
                        ],
                      ),
                    ],

                    if (_hasNonRoadTransportation) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Mixed transportation route · road-only distance/time '
                        'is not shown as a total.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],

                    if (_routeWarnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_routeWarnings.length} map note(s) available.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _showRouteDetails,
                        icon: const Icon(Icons.list_alt_outlined),
                        label: const Text('Route Details'),
                      ),
                    ),
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

class _MapLeg {
  final String from;
  final String to;
  final String transportation;

  const _MapLeg({
    required this.from,
    required this.to,
    required this.transportation,
  });
}

class _RouteGeometry {
  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;

  const _RouteGeometry({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
  });
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

/// Blue "You are here" indicator used for the tourist's live GPS position.
///
/// Kept visually distinct from the green boarding, red destination and orange
/// intermediate markers so the live marker cannot be mistaken for a planned
/// route stop.
class _LiveLocationIndicator extends StatelessWidget {
  const _LiveLocationIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}
