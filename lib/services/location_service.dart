import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Live-tracking settings for the map's blue "You are here" marker.
  ///
  /// High accuracy gives a usable fix while the ~10 m distance filter means
  /// the marker updates as the tourist actually moves, without spamming the
  /// app with near-duplicate positions (and without re-requesting OSRM).
  static const LocationSettings liveTrackingSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  /// True when location services are switched on and Yatra has permission.
  static Future<bool> isLocationAccessAllowed() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<Position?> getCurrentLocation() async {
    if (!await isLocationAccessAllowed()) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      // A last-known position is preferable to an empty map marker when
      // the device temporarily cannot obtain a fresh GPS fix.
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Continuous stream of position updates while the map is open.
  static Stream<Position> livePositionStream() {
    return Geolocator.getPositionStream(locationSettings: liveTrackingSettings);
  }
}
