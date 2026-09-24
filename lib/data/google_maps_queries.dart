/// Canonical Google Maps place-name queries for Yatra locations.
///
/// External navigation no longer relies on the in-app coordinate table
/// ([locationCoordinates]) because Google Maps snaps raw coordinates to the
/// nearest point of interest (businesses, houses), which produces unrelated
/// origins/destinations such as a local news office instead of Kathmandu.
///
/// Instead every route endpoint is converted to a textual query that Google
/// Maps can resolve itself. Keys are normalized (trimmed + lowercased); the
/// unknown-location fallback is simply `"$location, Nepal"`.
///
/// Region-level Yatra destinations whose plain name would be ambiguous are
/// mapped to the concrete settlement that Yatra actually means:
///   * "Mustang"   -> Lo Manthang (Upper Mustang's principal settlement)
///   * "Annapurna" -> Annapurna Base Camp (end of the ABC trek)
///   * "Everest"   -> Everest Base Camp (end of the EBC trek)
const Map<String, String> canonicalGoogleMapsQueries = {
  // ========================================================
  // DESTINATIONS / CITIES
  // ========================================================
  'kathmandu': 'Kathmandu, Nepal',
  'pokhara': 'Pokhara, Nepal',
  'chitwan': 'Chitwan, Nepal',
  'tansen': 'Tansen, Nepal',
  'rasuwa': 'Rasuwa, Nepal',

  // ========================================================
  // MUSTANG ROUTE
  // ========================================================
  // Yatra's "Mustang" destination is Upper Mustang, whose principal
  // settlement is Lo Manthang. The district name alone would route users
  // to the lower Mustang/Ben area instead.
  'mustang': 'Lo Manthang, Mustang, Nepal',
  'lo manthang': 'Lo Manthang, Mustang, Nepal',
  'jomsom': 'Jomsom, Mustang, Nepal',
  'marpha': 'Marpha, Mustang, Nepal',
  'kagbeni': 'Kagbeni, Mustang, Nepal',
  'muktinath': 'Muktinath, Mustang, Nepal',

  // ========================================================
  // ANNAPURNA ROUTE
  // ========================================================
  // "Annapurna" is a mountain range/region, not a drivable endpoint.
  // Yatra's Annapurna route ends at Annapurna Base Camp.
  'annapurna': 'Annapurna Base Camp, Nepal',
  'annapurna base camp': 'Annapurna Base Camp, Nepal',
  'ghandruk': 'Ghandruk, Nepal',
  'poon hill': 'Poon Hill, Nepal',

  // ========================================================
  // EVEREST ROUTE
  // ========================================================
  // "Everest" alone resolves to the mountain itself. Yatra's Everest route
  // ends at Everest Base Camp.
  'everest': 'Everest Base Camp, Nepal',
  'everest base camp': 'Everest Base Camp, Nepal',
  'lukla': 'Lukla, Nepal',
  'namche bazaar': 'Namche Bazaar, Nepal',
};

/// Resolves a Yatra location name to the textual query best used as a
/// Google Maps origin/destination.
///
/// Known Yatra route locations use their curated canonical query. Any other
/// name falls back to a canonical Nepal query (`"$location, Nepal"`).
/// Coordinates are intentionally never produced here.
String googleMapsQueryFor(String location) {
  final raw = location.trim();

  if (raw.isEmpty) {
    return raw;
  }

  final canonical = canonicalGoogleMapsQueries[raw.toLowerCase()];

  if (canonical != null) {
    return canonical;
  }

  return '$raw, Nepal';
}
