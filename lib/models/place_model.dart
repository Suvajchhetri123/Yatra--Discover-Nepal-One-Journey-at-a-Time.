import 'tourist_pricing.dart';

class Place {
  final String name;
  final String location;
  final String description;
  final String imageUrl;

  /// Universal entry fee (NPR) shared by all tourists.
  final double entryFee;

  /// Optional domestic/international entry fee overrides. When null the
  /// universal [entryFee] applies to every tourist segment.
  final TouristPricing? touristEntryFee;

  final String openingHours;
  final String transportation;
  final String travelTrip;
  final double recommendedHours;

  const Place({
    required this.name,
    required this.location,
    required this.description,
    required this.imageUrl,
    required this.entryFee,
    this.touristEntryFee,
    required this.openingHours,
    required this.transportation,
    required this.travelTrip,
    required this.recommendedHours,
  });

  /// Resolve the entry fee that applies to [touristType].
  double entryFeeFor(String touristType) {
    return priceForTouristType(
      touristType: touristType,
      universalPrice: entryFee,
      pricing: touristEntryFee,
    );
  }
}
