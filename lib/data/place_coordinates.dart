import 'package:latlong2/latlong.dart';

/// Canonical coordinates for Yatra destinations.
///
/// Shared by the in-app flutter_map screen and the "View in Google Maps"
/// directions launcher so navigation always prefers precise coordinates for
/// known places and only falls back to a canonical location name otherwise.
///
/// "Mustang" is a district rather than a single map point. For Yatra's
/// Mustang destination, Lo Manthang is used as the concrete settlement in
/// Upper Mustang so routing services receive a real endpoint.
const Map<String, LatLng> locationCoordinates = {
  'Kathmandu': LatLng(27.7172, 85.3240),
  'Pokhara': LatLng(28.2096, 83.9856),
  'Chitwan': LatLng(27.5291, 84.3542),

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
