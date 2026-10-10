import '../models/package_model.dart';
import '../models/place_model.dart';
import '../models/route_config.dart';
import '../models/tourist_pricing.dart';
import 'yatra_local_database.dart';

/// Converts Yatra's strongly typed catalog models to/from the generic
/// [LocalCatalogRecord] persisted by SQLite.
///
/// This codec is deliberately independent from Firestore. SQLite payloads are
/// an application-owned format rather than Firestore documents copied blindly
/// into local storage.
class LocalCatalogCodec {
  const LocalCatalogCodec._();

  static LocalCatalogRecord placeToRecord(Place place) {
    return LocalCatalogRecord(
      kind: LocalCatalogKind.place,
      id: place.id,
      active: place.active,
      payload: <String, dynamic>{
        'name': place.name,
        'location': place.location,
        'description': place.description,
        'imageUrls': List<String>.of(place.imageUrls),

        // Keep the original fallback separately. place.imageUrl may currently
        // resolve to the first uploaded photo.
        'legacyImageUrl': place.legacyImageUrl,

        'entryFee': place.entryFee,
        'touristEntryFee': _pricingToMap(place.touristEntryFee),
        'openingHours': place.openingHours,
        'transportation': place.transportation,
        'travelTrip': place.travelTrip,
        'recommendedHours': place.recommendedHours,
      },
    );
  }

  static Place placeFromRecord(LocalCatalogRecord record) {
    _requireKind(record, LocalCatalogKind.place);

    final data = record.payload;

    return Place(
      id: record.id,
      name: _string(data['name']),
      location: _string(data['location']),
      description: _string(data['description']),
      imageUrls: _strings(data['imageUrls']),
      imageUrl: _string(
        data.containsKey('legacyImageUrl')
            ? data['legacyImageUrl']
            : data['imageUrl'],
      ),
      entryFee: _double(data['entryFee']),
      touristEntryFee: _pricingFromMap(data['touristEntryFee']),
      openingHours: _string(data['openingHours']),
      transportation: _string(data['transportation']),
      travelTrip: _string(data['travelTrip']),
      recommendedHours: _double(data['recommendedHours']),
      active: record.active,
    );
  }

  static LocalCatalogRecord packageToRecord(TourPackage package) {
    return LocalCatalogRecord(
      kind: LocalCatalogKind.package,
      id: package.id,
      active: package.active,
      payload: <String, dynamic>{
        'title': package.title,
        'region': package.region,
        'summary': package.summary,
        'description': package.description,
        'durationDays': package.durationDays,
        'price': package.price,
        'touristPrice': _pricingToMap(package.touristPrice),
        'difficulty': package.difficulty,
        'rating': package.rating,
        'imageUrl': package.imageUrl,
        'highlights': List<String>.of(package.highlights),
        'includedPlaces': List<String>.of(package.includedPlaces),
      },
    );
  }

  static TourPackage packageFromRecord(LocalCatalogRecord record) {
    _requireKind(record, LocalCatalogKind.package);

    final data = record.payload;

    return TourPackage(
      id: record.id,
      title: _string(data['title']),
      region: _string(data['region']),
      summary: _string(data['summary']),
      description: _string(data['description']),
      durationDays: _int(data['durationDays']),
      price: _double(data['price']),
      touristPrice: _pricingFromMap(data['touristPrice']),
      difficulty: _string(data['difficulty'], fallback: 'Easy'),
      rating: _double(data['rating']),
      imageUrl: _string(data['imageUrl']),
      highlights: _strings(data['highlights']),
      includedPlaces: _strings(data['includedPlaces']),
      active: record.active,
    );
  }

  static LocalCatalogRecord routeToRecord(RouteConfig route) {
    return LocalCatalogRecord(
      kind: LocalCatalogKind.route,
      id: route.id,
      active: route.active,
      payload: <String, dynamic>{
        'destination': route.destination,
        'from': route.from,
        'to': route.to,
        'transportModes': List<String>.of(route.transportModes),
        'bidirectional': route.bidirectional,
        'note': route.note,
      },
    );
  }

  static RouteConfig routeFromRecord(LocalCatalogRecord record) {
    _requireKind(record, LocalCatalogKind.route);

    final data = record.payload;

    return RouteConfig(
      id: record.id,
      destination: _string(data['destination']),
      from: _string(data['from']),
      to: _string(data['to']),
      transportModes: _strings(data['transportModes']),
      bidirectional: _bool(data['bidirectional']) ?? true,
      note: _string(data['note']),
      active: record.active,
    );
  }

  static Map<String, dynamic>? _pricingToMap(TouristPricing? pricing) {
    if (pricing == null) {
      return null;
    }

    return <String, dynamic>{
      'domestic': pricing.domestic,
      'international': pricing.international,
    };
  }

  static TouristPricing? _pricingFromMap(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final data = Map<String, dynamic>.from(value);

    final domestic = _nullableDouble(data['domestic']);
    final international = _nullableDouble(data['international']);

    if (domestic == null && international == null) {
      return null;
    }

    return TouristPricing(domestic: domestic, international: international);
  }

  static void _requireKind(
    LocalCatalogRecord record,
    LocalCatalogKind expected,
  ) {
    if (record.kind == expected) {
      return;
    }

    throw ArgumentError(
      'Expected ${expected.storageName} record but received '
      '${record.kind.storageName}.',
    );
  }

  static String _string(dynamic value, {String fallback = ''}) {
    return value is String ? value : fallback;
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

  static double? _nullableDouble(dynamic value) {
    return value is num ? value.toDouble() : null;
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
}
