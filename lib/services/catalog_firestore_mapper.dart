import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/package_model.dart';
import '../models/place_model.dart';
import '../models/tourist_pricing.dart';
import '../models/travel_coordinator.dart';
import 'booking_firestore_mapper.dart';

/// Converts the admin-managed travel catalogs between their application models
/// and Firestore documents.
///
/// Three collections are covered:
///
///   coordinators/{coordinatorId}
///   places/{placeId}
///   packages/{packageId}
///
/// Shared business-field encoding is deliberately delegated to
/// [BookingFirestoreMapper] so the registry document and the snapshot stored
/// inside a booking always agree on shape. This mapper only adds the
/// registry-specific metadata (`active`) and the document id, and parses
/// defensively so an older or hand-edited document can never crash a screen.
class CatalogFirestoreMapper {
  const CatalogFirestoreMapper._();

  // ============================================================
  // COORDINATORS
  // ============================================================

  static Map<String, dynamic> coordinatorFieldsToMap(
    TravelCoordinator coordinator,
  ) {
    return {
      'name': coordinator.name,
      'phone': coordinator.phone,
      'email': coordinator.email,
    };
  }

  static Map<String, dynamic> coordinatorDocumentToMap(
    TravelCoordinator coordinator,
  ) {
    return {
      ...coordinatorFieldsToMap(coordinator),
      'active': coordinator.active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update payload: business fields plus `updatedAt` only.
  ///
  /// `active` and `createdAt` are intentionally absent so a rename can never
  /// re-activate a coordinator or rewrite when the record was created.
  static Map<String, dynamic> coordinatorUpdateToMap(
    TravelCoordinator coordinator,
  ) {
    return {
      ...coordinatorFieldsToMap(coordinator),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static TravelCoordinator coordinatorDocumentFromMap({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return TravelCoordinator(
      id: documentId,
      name: _string(data['name']) ?? '',
      phone: _string(data['phone']) ?? '',
      email: _string(data['email']) ?? '',
      // A document without the flag predates the registry; treat it as active
      // rather than silently hiding a working coordinator.
      active: _bool(data['active']) ?? true,
    );
  }

  // ============================================================
  // PLACES
  // ============================================================

  /// The business fields shared with a booking's day-plan snapshot.
  static Map<String, dynamic> placeFieldsToMap(Place place) {
    // Reuses the exact place encoding used by booking day-plan snapshots, so
    // the catalog and the snapshot never drift apart.
    return BookingFirestoreMapper.placeToMap(place);
  }

  /// Catalog-only photo fields.
  ///
  /// Two keys are written on purpose:
  ///
  ///   - `imageUrls` is the source of truth for admin-managed photos;
  ///   - `imageUrl` keeps the resolved cover (first photo, else the legacy URL)
  ///     so an older reader still finds an image.
  ///
  /// Writing the cover on every save is what stops an edit to a seeded place
  /// from dropping its legacy image: the legacy URL is copied forward instead
  /// of being cleared.
  static Map<String, dynamic> placePhotoFieldsToMap(Place place) {
    return {
      'imageUrls': List<String>.of(place.imageUrls),
      'imageUrl': place.imageUrl,
    };
  }

  static Map<String, dynamic> placeDocumentToMap(Place place) {
    return {
      ...placeFieldsToMap(place),
      ...placePhotoFieldsToMap(place),
      'active': place.active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update payload: business fields plus `updatedAt` only.
  static Map<String, dynamic> placeUpdateToMap(Place place) {
    return {
      ...placeFieldsToMap(place),
      ...placePhotoFieldsToMap(place),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Place placeDocumentFromMap({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    // The snapshot decoder understands the legacy `imageUrl` field only; the
    // photo list is layered on top here.
    final place = BookingFirestoreMapper.placeFromMap(data);
    final pricing = place.touristEntryFee;

    return place.copyWith(
      id: documentId,
      imageUrls: _strings(data['imageUrls']),
      active: _bool(data['active']) ?? true,
      // An override object with no usable number is the same as no override.
      clearTouristEntryFee:
          pricing != null &&
          pricing.domestic == null &&
          pricing.international == null,
    );
  }

  // ============================================================
  // PACKAGES
  // ============================================================

  static Map<String, dynamic> packageFieldsToMap(TourPackage package) {
    return {
      'title': package.title,
      'region': package.region,
      'summary': package.summary,
      'description': package.description,
      'durationDays': package.durationDays,
      'price': package.price,
      'touristPrice': package.touristPrice == null
          ? null
          : BookingFirestoreMapper.touristPricingToMap(package.touristPrice!),
      'difficulty': package.difficulty,
      'rating': package.rating,
      'imageUrl': package.imageUrl,
      'highlights': List<String>.of(package.highlights),
      'includedPlaces': List<String>.of(package.includedPlaces),
    };
  }

  static Map<String, dynamic> packageDocumentToMap(TourPackage package) {
    return {
      ...packageFieldsToMap(package),
      'active': package.active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update payload: business fields plus `updatedAt` only.
  static Map<String, dynamic> packageUpdateToMap(TourPackage package) {
    return {
      ...packageFieldsToMap(package),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static TourPackage packageDocumentFromMap({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return TourPackage(
      // The document id *is* the package id, so it is the canonical identity.
      id: documentId,
      title: _string(data['title']) ?? '',
      region: _string(data['region']) ?? '',
      summary: _string(data['summary']) ?? '',
      description: _string(data['description']) ?? '',
      durationDays: _int(data['durationDays']),
      price: _double(data['price']),
      touristPrice: _pricing(data['touristPrice']),
      difficulty: _string(data['difficulty']) ?? 'Easy',
      rating: _double(data['rating']),
      imageUrl: _string(data['imageUrl']) ?? '',
      highlights: _strings(data['highlights']),
      includedPlaces: _strings(data['includedPlaces']),
      active: _bool(data['active']) ?? true,
    );
  }

  // ============================================================
  // SAFE PARSING HELPERS
  // ============================================================

  static String? _string(dynamic value) {
    return value is String ? value : null;
  }

  static int _int(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  static bool? _bool(dynamic value) {
    return value is bool ? value : null;
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.whereType<String>().toList();
  }

  static TouristPricing? _pricing(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(value);

    // Reuse the shared pricing parser, but treat a map with no usable numbers
    // as "no overrides" so a stray empty object cannot hide the universal price.
    if (map['domestic'] is! num && map['international'] is! num) {
      return null;
    }

    return BookingFirestoreMapper.touristPricingFromMap(map);
  }
}
