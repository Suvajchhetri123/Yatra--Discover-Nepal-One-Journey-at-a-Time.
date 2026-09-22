import '../models/destination_cost_profile.dart';
import '../models/tourist_pricing.dart';

/// Mustang region destinations share a profile, so Jomsom is listed explicitly
/// to give intermediate stops stable per-day rates of their own.
const List<DestinationCostProfile> _destinationCostProfiles = [
  DestinationCostProfile(
    location: 'Jomsom',
    stayPerDay: 3500,
    activityPerDay: 800,
    stayPricing: TouristPricing(domestic: 3500, international: 6500),
    activityPricing: TouristPricing(domestic: 800, international: 2500),
  ),
  DestinationCostProfile(
    location: 'Mustang',
    stayPerDay: 3500,
    activityPerDay: 800,
    stayPricing: TouristPricing(domestic: 3500, international: 6500),
    activityPricing: TouristPricing(domestic: 800, international: 2500),
  ),
  DestinationCostProfile(
    location: 'Annapurna',
    stayPerDay: 4000,
    activityPerDay: 800,
    stayPricing: TouristPricing(domestic: 4000, international: 6500),
    activityPricing: TouristPricing(domestic: 800, international: 2500),
  ),
  DestinationCostProfile(
    location: 'Everest',
    stayPerDay: 4500,
    activityPerDay: 800,
    stayPricing: TouristPricing(domestic: 4500, international: 7500),
    activityPricing: TouristPricing(domestic: 800, international: 3000),
  ),
  DestinationCostProfile(
    location: 'Chitwan',
    stayPerDay: 3000,
    activityPerDay: 800,
    stayPricing: TouristPricing(domestic: 3000, international: 5000),
    activityPricing: TouristPricing(domestic: 800, international: 2000),
  ),
  DestinationCostProfile(
    location: 'Pokhara',
    stayPerDay: 2500,
    activityPerDay: 800,
    stayPricing: TouristPricing(domestic: 2500, international: 4000),
    activityPricing: TouristPricing(domestic: 800, international: 1500),
  ),
  DestinationCostProfile(
    location: 'Kathmandu',
    stayPerDay: 2500,
    activityPerDay: 800,
    stayPricing: TouristPricing(domestic: 2500, international: 4500),
    activityPricing: TouristPricing(domestic: 800, international: 1500),
  ),
];

/// Universal fallback for destinations without a dedicated profile.
const DestinationCostProfile _defaultProfile = DestinationCostProfile(
  location: 'Default',
  stayPerDay: 2500,
  activityPerDay: 800,
  stayPricing: TouristPricing(domestic: 2500, international: 4000),
  activityPricing: TouristPricing(domestic: 800, international: 1500),
);

/// Look up the cost profile whose location token appears in [name].
///
/// Matching is substring-based (mirroring the estimator's legacy keyword
/// checks) so `Everest Base Camp Trek` still finds the `Everest` profile.
DestinationCostProfile destinationCostProfileFor(String name) {
  final normalized = name.toLowerCase();

  for (final profile in _destinationCostProfiles) {
    if (normalized.contains(profile.location.toLowerCase())) {
      return profile;
    }
  }

  return _defaultProfile;
}
