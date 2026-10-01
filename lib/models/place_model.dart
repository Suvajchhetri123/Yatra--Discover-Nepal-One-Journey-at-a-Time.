import 'catalog_slug.dart';
import 'tourist_pricing.dart';

/// A place in the Yatra travel catalog (a destination attraction).
///
/// Places are administered through the Firestore `places` collection. [id] is
/// that document's id and is empty for the static catalog that the tourist
/// planner still reads in this phase. [active] is soft-removal metadata:
/// inactive places are hidden from the tourist catalog but are never deleted,
/// so booking snapshots that reference them stay resolvable.
///
/// ## Photos
///
/// A place can carry several photos. [imageUrls] is the list the admin CMS
/// maintains through photo upload. [legacyImageUrl] is the single URL the
/// pre-photos catalog used, which is still what the 20 seeded places have.
///
/// [imageUrl] is a *derived* getter, not stored state, so there is exactly one
/// source of truth while every existing `place.imageUrl` call site keeps
/// working unchanged:
///
///   - photos present -> the first photo, which is also the cover image;
///   - no photos       -> the legacy URL.
class Place {
  /// Firestore registry id. Empty for static (not yet seeded) places.
  final String id;

  final String name;
  final String location;
  final String description;

  /// Photos for this place, in display order. The first entry is the cover.
  final List<String> imageUrls;

  /// The single image URL used before multi-photo support existed.
  ///
  /// Seeded and historical places keep their URL here, so nothing has to be
  /// re-uploaded when photos are introduced.
  final String legacyImageUrl;

  /// The image every existing consumer should render.
  ///
  /// Never stored separately: it is the cover photo, or the legacy URL when the
  /// place has no uploaded photo yet.
  String get imageUrl =>
      imageUrls.isNotEmpty ? imageUrls.first : legacyImageUrl;

  /// The cover photo, or null when the place has no usable image.
  String? get coverImageUrl {
    final image = imageUrl;
    return image.isEmpty ? null : image;
  }

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
    this.imageUrls = const <String>[],
    String imageUrl = '',
    required this.entryFee,
    this.touristEntryFee,
    required this.openingHours,
    required this.transportation,
    required this.travelTrip,
    required this.recommendedHours,
    this.active = true,
  }) : legacyImageUrl = imageUrl;

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
    List<String>? imageUrls,
    String? legacyImageUrl,
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
      imageUrls: imageUrls ?? this.imageUrls,
      // The constructor keeps the legacy parameter name, so this is translated
      // here rather than exposing two spellings of the same field.
      imageUrl: legacyImageUrl ?? this.legacyImageUrl,
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
