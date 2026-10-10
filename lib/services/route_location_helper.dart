class RouteLocationHelper {
  const RouteLocationHelper._();

  static String normalize(String value) {
    return value.trim().toLowerCase();
  }

  /// Deduplicates locations case-insensitively while preserving the first
  /// human-readable spelling.
  static List<String> canonicalLocations(Iterable<String> locations) {
    final values = <String, String>{};

    for (final location in locations) {
      final trimmed = location.trim();

      if (trimmed.isEmpty) continue;

      values.putIfAbsent(normalize(trimmed), () => trimmed);
    }

    final result = values.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return result;
  }

  /// Reuses the existing canonical spelling when the entered value differs
  /// only by case or surrounding whitespace.
  static String canonicalize(String value, Iterable<String> knownLocations) {
    final trimmed = value.trim();
    final target = normalize(trimmed);

    if (target.isEmpty) return '';

    for (final location in canonicalLocations(knownLocations)) {
      if (normalize(location) == target) {
        return location;
      }
    }

    return trimmed;
  }

  /// Autocomplete options for an editable From/To field.
  static List<String> suggestions(
    String query,
    Iterable<String> knownLocations, {
    int limit = 8,
  }) {
    final locations = canonicalLocations(knownLocations);
    final target = normalize(query);

    if (target.isEmpty) {
      return locations.take(limit).toList();
    }

    final startsWith = <String>[];
    final contains = <String>[];

    for (final location in locations) {
      final normalized = normalize(location);

      if (normalized.startsWith(target)) {
        startsWith.add(location);
      } else if (normalized.contains(target)) {
        contains.add(location);
      }
    }

    return [...startsWith, ...contains].take(limit).toList();
  }

  /// Finds a likely typo of an existing location.
  ///
  /// This intentionally does not auto-correct. The Admin form asks the user
  /// whether to reuse the existing spelling or keep the new location.
  static String? nearDuplicate(String value, Iterable<String> knownLocations) {
    final target = normalize(value);

    if (target.length < 4) return null;

    String? closest;
    var closestDistance = 1 << 20;

    for (final candidate in canonicalLocations(knownLocations)) {
      final normalizedCandidate = normalize(candidate);

      // Exact matches are handled by canonicalize(), not typo detection.
      if (normalizedCandidate == target) {
        return null;
      }

      if ((normalizedCandidate.length - target.length).abs() > 2) {
        continue;
      }

      // Requiring a shared prefix reduces false positives between unrelated
      // locations while still catching examples like Biratmod/Birtamod.
      final prefixLength = target.length >= 3 ? 3 : target.length;

      if (normalizedCandidate.length < prefixLength ||
          target.substring(0, prefixLength) !=
              normalizedCandidate.substring(0, prefixLength)) {
        continue;
      }

      final distance = _levenshtein(target, normalizedCandidate);
      final threshold = target.length <= 5 ? 1 : 2;

      if (distance <= threshold && distance < closestDistance) {
        closest = candidate;
        closestDistance = distance;
      }
    }

    return closest;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (index) => index);

    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;

      for (var j = 1; j <= b.length; j++) {
        final substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1;

        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + substitutionCost;

        current[j] = _min3(deletion, insertion, substitution);
      }

      previous = current;
    }

    return previous[b.length];
  }

  static int _min3(int a, int b, int c) {
    var result = a;

    if (b < result) result = b;
    if (c < result) result = c;

    return result;
  }
}
