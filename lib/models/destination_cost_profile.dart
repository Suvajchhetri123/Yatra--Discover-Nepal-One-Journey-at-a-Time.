import 'tourist_pricing.dart';

/// Daily stay and activity rates for a destination.
///
/// [stayPerDay] and [activityPerDay] are the universal (shared) rates. When a
/// destination charges domestic and international tourists differently, the
/// differentials live in [stayPricing] / [activityPricing] as explicit values.
///
/// Callers resolve the applicable rate via `priceForTouristType` so there is a
/// single pricing path shared by every consumer.
class DestinationCostProfile {
  /// Canonical destination name, e.g. `Kathmandu` or `Jomsom`.
  final String location;

  /// Universal base accommodation rate (NPR / adult / day).
  final double stayPerDay;

  /// Universal base activity budget (NPR / day).
  final double activityPerDay;

  /// Optional domestic/international overrides for accommodation.
  final TouristPricing? stayPricing;

  /// Optional domestic/international overrides for daily activities.
  final TouristPricing? activityPricing;

  const DestinationCostProfile({
    required this.location,
    required this.stayPerDay,
    required this.activityPerDay,
    this.stayPricing,
    this.activityPricing,
  });
}
