import 'catalog_slug.dart';
import 'tourist_pricing.dart';

/// A place in the Yatra travel catalog (a destination attraction).
///
/// Places are administered through the Firestore `places` collection. [id] is
/// that document's id and is empty for the static catalog that the tourist
/// planner still reads in this phase. [active] is soft-removal metadata:
/// inactive places are hidden from the tourist catalog but are never deleted,
/// so booking snapshots that reference them stay resolvable.
class Place {
  /// Firestore registry id. Empty for static (not yet seeded) places.
  final String id;

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

  /// False means "removed from the tourist catalog". The document is kept.
  final bool active;

  const Place({
    this.id = '',
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
    this.active = true,
  });

  /// Resolve the entry fee that applies to [touristType].
  double entryFeeFor(String touristType) {
    return priceForTouristType(
      touristType: touristType,
      universalPrice: entryFee,
      pricing: touristEntryFee,
    );
  }

  /// Stable, human-readable registry id derived from the place itself.
  ///
  /// Used when seeding so running the seed twice cannot create duplicates.
  static String slugFor(String location, String name) {
    return catalogSlug('$location $name');
  }

  Place copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    String? imageUrl,
    double? entryFee,
    TouristPricing? touristEntryFee,
    bool clearTouristEntryFee = false,
    String? openingHours,
    String? transportation,
    String? travelTrip,
    double? recommendedHours,
    bool? active,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      entryFee: entryFee ?? this.entryFee,
      // `null` means "leave the overrides alone", so removing them needs the
      // explicit flag — otherwise switching the override off in the admin form
      // would silently keep the old rates.
      touristEntryFee: clearTouristEntryFee
          ? null
          : touristEntryFee ?? this.touristEntryFee,
      openingHours: openingHours ?? this.openingHours,
      transportation: transportation ?? this.transportation,
      travelTrip: travelTrip ?? this.travelTrip,
      recommendedHours: recommendedHours ?? this.recommendedHours,
      active: active ?? this.active,
    );
  }
}
