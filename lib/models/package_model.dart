import 'tourist_pricing.dart';

/// A curated, bookable tour package: a bundled multi-day trip with a price,
/// duration, difficulty and the places it covers.
///
/// Packages are administered through the Firestore `packages` collection, where
/// [id] is the document id. [active] is soft-removal metadata: an inactive
/// package is hidden from the tourist catalog but never deleted, so existing
/// bookings and itineraries that reference it stay resolvable.
class TourPackage {
  final String id;
  final String title;
  final String region;
  final String summary;
  final String description;
  final int durationDays;

  /// Universal package price in NPR shared by all tourists.
  final double price;

  /// Optional domestic/international price overrides. When null the universal
  /// [price] applies to every tourist segment.
  final TouristPricing? touristPrice;

  final String difficulty; // 'Easy' | 'Moderate' | 'Challenging'
  final double rating;
  final String imageUrl;
  final List<String> highlights;
  final List<String> includedPlaces;

  /// False means "removed from the tourist catalog". The document is kept.
  final bool active;

  const TourPackage({
    required this.id,
    required this.title,
    required this.region,
    required this.summary,
    required this.description,
    required this.durationDays,
    required this.price,
    this.touristPrice,
    required this.difficulty,
    required this.rating,
    required this.imageUrl,
    required this.highlights,
    required this.includedPlaces,
    this.active = true,
  });

  /// Resolve the package price that applies to [touristType].
  double priceFor(String touristType) {
    return priceForTouristType(
      touristType: touristType,
      universalPrice: price,
      pricing: touristPrice,
    );
  }

  TourPackage copyWith({
    String? id,
    String? title,
    String? region,
    String? summary,
    String? description,
    int? durationDays,
    double? price,
    TouristPricing? touristPrice,
    bool clearTouristPrice = false,
    String? difficulty,
    double? rating,
    String? imageUrl,
    List<String>? highlights,
    List<String>? includedPlaces,
    bool? active,
  }) {
    return TourPackage(
      id: id ?? this.id,
      title: title ?? this.title,
      region: region ?? this.region,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      durationDays: durationDays ?? this.durationDays,
      price: price ?? this.price,
      // `null` means "leave the overrides alone", so removing them needs the
      // explicit flag — otherwise switching the override off in the admin form
      // would silently keep the old rates.
      touristPrice: clearTouristPrice
          ? null
          : touristPrice ?? this.touristPrice,
      difficulty: difficulty ?? this.difficulty,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
      highlights: List<String>.of(highlights ?? this.highlights),
      includedPlaces: List<String>.of(includedPlaces ?? this.includedPlaces),
      active: active ?? this.active,
    );
  }
}

/// Formats an NPR amount with thousands separators, e.g. 95000 -> "NPR 95,000".
String formatNpr(double amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }

  return 'NPR ${buffer.toString()}';
}
