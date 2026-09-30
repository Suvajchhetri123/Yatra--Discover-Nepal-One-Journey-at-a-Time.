/// Turns human-readable catalog text into a stable, Firestore-safe id fragment.
///
/// Used to derive deterministic document ids (for example
/// `Mustang, Muktinath` -> `mustang-muktinath`) so that seeding the same record
/// twice always resolves to the same document instead of creating a duplicate.
String catalogSlug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+'), '')
      .replaceAll(RegExp(r'-+$'), '');

  return slug;
}
