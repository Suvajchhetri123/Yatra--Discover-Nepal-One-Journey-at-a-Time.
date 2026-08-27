/// A curated, bookable tour package: a bundled multi-day trip with a price,
/// duration, difficulty and the places it covers.
class TourPackage {
  final String id;
  final String title;
  final String region;
  final String summary;
  final String description;
  final int durationDays;
  final double price; // in NPR
  final String difficulty; // 'Easy' | 'Moderate' | 'Challenging'
  final double rating;
  final String imageUrl;
  final List<String> highlights;
  final List<String> includedPlaces;

  const TourPackage({
    required this.id,
    required this.title,
    required this.region,
    required this.summary,
    required this.description,
    required this.durationDays,
    required this.price,
    required this.difficulty,
    required this.rating,
    required this.imageUrl,
    required this.highlights,
    required this.includedPlaces,
  });
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
