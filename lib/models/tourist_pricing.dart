/// Canonical tourist segments used by the differential pricing resolver.
enum TouristSegment { domestic, international }

/// Structured, per-service price pair.
///
/// Both rates are optional so a service can share a single universal price
/// (by leaving [pricing] null on the model) or price only one segment
/// (e.g. a service the other segment does not use).
///
/// This is deliberately *structured data, not a multiplier*: domestic and
/// international prices are explicit separate values for each service and
/// never derived from each other by a global factor.
class TouristPricing {
  final double? domestic;
  final double? international;

  const TouristPricing({this.domestic, this.international});
}

/// Classify a raw tourist type string into a canonical segment.
///
/// Returns `null` for unrecognised labels so callers fall back to the
/// universal price rather than guessing a segment.
TouristSegment? touristSegmentOf(String touristType) {
  final normalized = touristType.toLowerCase();

  if (normalized.contains('international')) {
    return TouristSegment.international;
  }

  if (normalized.contains('domestic')) {
    return TouristSegment.domestic;
  }

  return null;
}

/// The single central resolver used everywhere a service price depends on the
/// tourist type.
///
/// Rules:
///  * No [pricing]  -> the universal [universalPrice] applies to everyone.
///  * A matching segment override exists -> that explicit value is used.
///  * Otherwise -> the universal [universalPrice] is used.
double priceForTouristType({
  required String touristType,
  required double universalPrice,
  TouristPricing? pricing,
}) {
  if (pricing == null) {
    return universalPrice;
  }

  final segment = touristSegmentOf(touristType);

  if (segment == TouristSegment.domestic && pricing.domestic != null) {
    return pricing.domestic!;
  }

  if (segment == TouristSegment.international &&
      pricing.international != null) {
    return pricing.international!;
  }

  return universalPrice;
}
