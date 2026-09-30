import 'package:cloud_firestore/cloud_firestore.dart';

/// Resolves a free document id for a new catalog record.
///
/// [base] is usually a slug such as `kathmandu-valley-classic`. It is returned
/// untouched when the slot is free, otherwise `-2`, `-3`, ... are tried so two
/// records that slug to the same value never overwrite each other. Only when
/// every candidate is taken does it fall back to a generated Firestore id, so
/// creation can never fail or clobber existing data.
Future<String> resolveCatalogDocumentId({
  required CollectionReference<Map<String, dynamic>> collection,
  required String base,
  int maxAttempts = 50,
}) async {
  final candidate = base.trim();

  if (candidate.isEmpty) {
    return collection.doc().id;
  }

  if (!(await collection.doc(candidate).get()).exists) {
    return candidate;
  }

  for (var suffix = 2; suffix <= maxAttempts; suffix++) {
    final next = '$candidate-$suffix';

    if (!(await collection.doc(next).get()).exists) {
      return next;
    }
  }

  return collection.doc().id;
}
