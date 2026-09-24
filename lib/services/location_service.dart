import 'package:geolocator/geolocator.dart';

class LocationService {
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
      // A last-known position is preferable to nothing when the device
      // temporarily cannot obtain a fresh GPS fix.
      return Geolocator.getLastKnownPosition();
    }
  }
}
