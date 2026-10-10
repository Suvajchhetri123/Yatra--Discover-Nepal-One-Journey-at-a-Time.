import 'package:flutter_test/flutter_test.dart';
import 'package:yatra/models/package_model.dart';
import 'package:yatra/models/place_model.dart';
import 'package:yatra/models/route_config.dart';
import 'package:yatra/models/tourist_pricing.dart';
import 'package:yatra/services/local_catalog_codec.dart';

void main() {
  test('Place survives a local codec round trip', () {
    const original = Place(
      id: 'ilam-tea-garden',
      name: 'Ilam Tea Garden',
      location: 'Ilam',
      description: 'Green tea gardens.',
      imageUrls: <String>[
        'https://example.test/cover.jpg',
        'https://example.test/second.jpg',
      ],
      imageUrl: 'assets/images/places/ilam.jpg',
      entryFee: 100,
      touristEntryFee: TouristPricing(domestic: 50, international: 200),
      openingHours: '6:00 AM - 6:00 PM',
      transportation: 'Bus or Jeep',
      travelTrip: 'Tea garden visit',
      recommendedHours: 3.5,
      active: false,
    );

    final record = LocalCatalogCodec.placeToRecord(original);
    final restored = LocalCatalogCodec.placeFromRecord(record);

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.location, original.location);
    expect(restored.description, original.description);
    expect(restored.imageUrls, original.imageUrls);

    // Important: the original fallback remains distinct from the current
    // resolved cover image.
    expect(restored.legacyImageUrl, original.legacyImageUrl);
    expect(restored.imageUrl, original.imageUrl);

    expect(restored.entryFee, original.entryFee);
    expect(
      restored.touristEntryFee?.domestic,
      original.touristEntryFee?.domestic,
    );
    expect(
      restored.touristEntryFee?.international,
      original.touristEntryFee?.international,
    );
    expect(restored.openingHours, original.openingHours);
    expect(restored.transportation, original.transportation);
    expect(restored.travelTrip, original.travelTrip);
    expect(restored.recommendedHours, original.recommendedHours);
    expect(restored.active, isFalse);
  });

  test('TourPackage survives a local codec round trip', () {
    const original = TourPackage(
      id: 'ilam-weekend',
      title: 'Ilam Weekend',
      region: 'Ilam',
      summary: 'A short tea-country escape.',
      description: 'Explore Ilam and nearby attractions.',
      durationDays: 3,
      price: 15000,
      touristPrice: TouristPricing(domestic: 12000, international: 20000),
      difficulty: 'Easy',
      rating: 4.7,
      imageUrl: 'https://example.test/ilam.jpg',
      highlights: <String>['Tea gardens', 'Sunrise'],
      includedPlaces: <String>['Ilam Tea Garden', 'Antu Danda'],
      active: false,
    );

    final record = LocalCatalogCodec.packageToRecord(original);
    final restored = LocalCatalogCodec.packageFromRecord(record);

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.region, original.region);
    expect(restored.summary, original.summary);
    expect(restored.description, original.description);
    expect(restored.durationDays, original.durationDays);
    expect(restored.price, original.price);
    expect(restored.touristPrice?.domestic, original.touristPrice?.domestic);
    expect(
      restored.touristPrice?.international,
      original.touristPrice?.international,
    );
    expect(restored.difficulty, original.difficulty);
    expect(restored.rating, original.rating);
    expect(restored.imageUrl, original.imageUrl);
    expect(restored.highlights, original.highlights);
    expect(restored.includedPlaces, original.includedPlaces);
    expect(restored.active, isFalse);
  });

  test('RouteConfig survives a local codec round trip', () {
    const original = RouteConfig(
      id: 'kathmandu-birtamod',
      destination: 'Ilam',
      from: 'Kathmandu',
      to: 'Birtamod',
      transportModes: <String>['Bus', 'Flight', 'Jeep'],
      bidirectional: false,
      note: 'Road connection.',
      active: false,
    );

    final record = LocalCatalogCodec.routeToRecord(original);
    final restored = LocalCatalogCodec.routeFromRecord(record);

    expect(restored.id, original.id);
    expect(restored.destination, original.destination);
    expect(restored.from, original.from);
    expect(restored.to, original.to);
    expect(restored.transportModes, original.transportModes);
    expect(restored.bidirectional, isFalse);
    expect(restored.note, original.note);
    expect(restored.active, isFalse);
  });

  test('wrong record kind is rejected', () {
    final routeRecord = LocalCatalogCodec.routeToRecord(
      const RouteConfig(
        id: 'route-1',
        destination: 'Ilam',
        from: 'Kathmandu',
        to: 'Ilam',
        transportModes: <String>['Bus'],
      ),
    );

    expect(
      () => LocalCatalogCodec.placeFromRecord(routeRecord),
      throwsArgumentError,
    );
  });
}
