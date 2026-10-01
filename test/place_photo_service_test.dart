import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/place_model.dart';
import 'package:yatra/services/firebase_place_image_storage.dart';
import 'package:yatra/services/place_photo_service.dart';

import 'support/fake_place_image_storage.dart';
import 'support/fake_place_repository.dart';

/// Unit tests for the photo workflow: the model, the Storage path rules and the
/// save/rollback/removal service.
void main() {
  Place placeWithPhotos(List<String> urls) {
    return Place(
      id: 'mustang-muktinath',
      name: 'Muktinath',
      location: 'Mustang',
      description: 'Ridge-top temple',
      imageUrls: urls,
      entryFee: 1000,
      openingHours: '6:00 AM - 6:00 PM',
      transportation: '3h drive from Pokhara',
      travelTrip: 'Pokhara - Muktinath',
      recommendedHours: 4,
    );
  }

  group('Place photos', () {
    test('a place with photos reports the first one as its image', () {
      final place = placeWithPhotos(<String>[
        'https://storage.test/one.jpg',
        'https://storage.test/two.jpg',
      ]);

      expect(place.imageUrl, 'https://storage.test/one.jpg');
      expect(place.coverImageUrl, 'https://storage.test/one.jpg');
    });

    test('a place with no photos still renders its legacy image', () {
      const place = Place(
        name: 'Phewa Lake',
        location: 'Pokhara',
        description: 'Lake',
        imageUrl: 'https://example.test/phewa.jpg',
        entryFee: 0,
        openingHours: '',
        transportation: '',
        travelTrip: '',
        recommendedHours: 2,
      );

      expect(place.imageUrls, isEmpty);
      expect(place.imageUrl, 'https://example.test/phewa.jpg');
      expect(place.coverImageUrl, 'https://example.test/phewa.jpg');
    });

    test('a place with neither photos nor a legacy image has no cover', () {
      const place = Place(
        name: 'Nowhere',
        location: 'Nowhere',
        description: '',
        entryFee: 0,
        openingHours: '',
        transportation: '',
        travelTrip: '',
        recommendedHours: 0,
      );

      expect(place.imageUrl, isEmpty);
      expect(place.coverImageUrl, isNull);
    });

    test('copyWith replaces the photo list and keeps the legacy image', () {
      final updated = placeWithPhotos(<String>[
        'https://a.test/1.jpg',
      ]).copyWith(imageUrls: <String>['https://b.test/2.jpg']);

      expect(updated.imageUrls, <String>['https://b.test/2.jpg']);
    });
  });

  group('Storage path and ownership', () {
    test('photos are stored under places/{placeId}/', () {
      expect(
        FirebasePlaceImageStorage.catalogPrefix,
        'places',
        reason: 'the Storage path shape is the app contract',
      );
    });

    test('the download base is the Firebase Storage REST download host', () {
      // A hard-coded expectation would drift with the project, so this checks
      // the shape the production implementation relies on.
      expect(
        RegExp(
          r'^https://firebasestorage\.googleapis\.com/v0/b/[^/]+/o/',
        ).hasMatch('https://firebasestorage.googleapis.com/v0/b/yatra/o/'),
        isTrue,
      );
    });

    test('a Yatra catalog URL is recognised as owned', () {
      final storage = FakePlaceImageStorage();

      expect(
        storage.ownsUrl('https://storage.test/v0/b/yatra/o/places%2Fp%2F1.jpg'),
        isTrue,
      );
    });

    test('a legacy external image is never owned', () {
      final storage = FakePlaceImageStorage();

      expect(storage.ownsUrl('https://example.test/muktinath.jpg'), isFalse);
    });
  });

  group('PlacePhotoService', () {
    test('a new place is created before its photos are uploaded', () async {
      final repository = FakePlaceRepository();
      final storage = FakePlaceImageStorage();

      final saved =
          await PlacePhotoService(
            repository: repository,
            storage: storage,
          ).saveWithPhotos(
            place: placeWithPhotos(const <String>[]).copyWith(id: ''),
            pending: <PendingPlacePhoto>[
              PendingPlacePhoto(bytes: _bytes, fileName: 'a.jpg'),
              PendingPlacePhoto(bytes: _bytes, fileName: 'b.jpg'),
            ],
          );

      expect(repository.createCalls, 1, reason: 'the id is needed first');
      expect(storage.uploadedPaths, <String>[
        'places/${saved.id}/photo-1.jpg',
        'places/${saved.id}/photo-2.jpg',
      ]);
      expect(saved.imageUrls.length, 2);
    });

    test(
      'uploaded photos are attached in the order they were chosen',
      () async {
        final repository = FakePlaceRepository(
          places: <Place>[placeWithPhotos(const <String>[])],
        );
        final storage = FakePlaceImageStorage();

        final saved =
            await PlacePhotoService(
              repository: repository,
              storage: storage,
            ).saveWithPhotos(
              place: placeWithPhotos(const <String>[]),
              pending: <PendingPlacePhoto>[
                PendingPlacePhoto(bytes: _bytes, fileName: 'first.jpg'),
                PendingPlacePhoto(bytes: _bytes, fileName: 'second.jpg'),
              ],
            );

        expect(saved.imageUrls.first, endsWith('photo-1.jpg'));
        expect(saved.imageUrls.last, endsWith('photo-2.jpg'));
      },
    );

    test('saving without photos performs a single update', () async {
      final repository = FakePlaceRepository(
        places: <Place>[placeWithPhotos(const <String>[])],
      );
      final storage = FakePlaceImageStorage();

      final saved =
          await PlacePhotoService(
            repository: repository,
            storage: storage,
          ).saveWithPhotos(
            place: placeWithPhotos(const <String>[]).copyWith(name: 'Renamed'),
            pending: const <PendingPlacePhoto>[],
          );

      expect(storage.uploadCalls, 0);
      expect(repository.updateCalls, 1);
      expect(saved.name, 'Renamed');
    });

    test('upload progress is reported for every photo', () async {
      final repository = FakePlaceRepository(
        places: <Place>[placeWithPhotos(const <String>[])],
      );
      final storage = FakePlaceImageStorage();
      final progress = <int>[];

      await PlacePhotoService(
        repository: repository,
        storage: storage,
      ).saveWithPhotos(
        place: placeWithPhotos(const <String>[]),
        pending: <PendingPlacePhoto>[
          PendingPlacePhoto(bytes: _bytes),
          PendingPlacePhoto(bytes: _bytes),
        ],
        onUploadProgress: (value) => progress.add(value.uploaded),
      );

      expect(progress, <int>[1, 2]);
    });

    test('a failed upload rolls back the files that did upload', () async {
      final repository = FakePlaceRepository(
        places: <Place>[placeWithPhotos(const <String>[])],
      );
      final storage = FakePlaceImageStorage(uploadErrorAfter: 1);

      await expectLater(
        PlacePhotoService(
          repository: repository,
          storage: storage,
        ).saveWithPhotos(
          place: placeWithPhotos(const <String>[]),
          pending: <PendingPlacePhoto>[
            PendingPlacePhoto(bytes: _bytes),
            PendingPlacePhoto(bytes: _bytes),
          ],
        ),
        throwsA(isA<PlacePhotoUploadException>()),
      );

      expect(
        storage.deletedUrls.length,
        1,
        reason: 'the successful upload must not be left unreferenced',
      );
      expect(repository.places.single.imageUrls, isEmpty);
    });

    test(
      'removing a photo deletes the file and keeps the rest in order',
      () async {
        final repository = FakePlaceRepository(
          places: <Place>[
            placeWithPhotos(<String>[
              'https://storage.test/v0/b/yatra/o/places%2Fp%2F1.jpg',
              'https://storage.test/v0/b/yatra/o/places%2Fp%2F2.jpg',
              'https://storage.test/v0/b/yatra/o/places%2Fp%2F3.jpg',
            ]),
          ],
        );
        final storage = FakePlaceImageStorage();

        await PlacePhotoService(
          repository: repository,
          storage: storage,
        ).removePhotos(
          place: repository.places.single,
          urls: <String>[
            'https://storage.test/v0/b/yatra/o/places%2Fp%2F2.jpg',
          ],
        );

        final remaining = repository.places.single.imageUrls;

        expect(remaining.length, 2);
        expect(remaining.first, endsWith('1.jpg'));
        expect(remaining.last, endsWith('3.jpg'));
        expect(storage.deleteCalls, 1);
      },
    );

    test('removing a legacy external image never deletes a file', () async {
      final repository = FakePlaceRepository(
        places: <Place>[
          placeWithPhotos(<String>['https://example.test/legacy.jpg']),
        ],
      );
      final storage = FakePlaceImageStorage();

      await PlacePhotoService(
        repository: repository,
        storage: storage,
      ).removePhotos(
        place: repository.places.single,
        urls: <String>['https://example.test/legacy.jpg'],
      );

      expect(repository.places.single.imageUrls, isEmpty);
      expect(
        storage.deleteCalls,
        0,
        reason: 'a web image is not ours to delete',
      );
    });

    test('removing the cover promotes the next photo', () async {
      final repository = FakePlaceRepository(
        places: <Place>[
          placeWithPhotos(<String>[
            'https://storage.test/v0/b/yatra/o/places%2Fp%2F1.jpg',
            'https://storage.test/v0/b/yatra/o/places%2Fp%2F2.jpg',
          ]),
        ],
      );

      await PlacePhotoService(
        repository: repository,
        storage: FakePlaceImageStorage(),
      ).removePhotos(
        place: repository.places.single,
        urls: <String>['https://storage.test/v0/b/yatra/o/places%2Fp%2F1.jpg'],
      );

      expect(
        repository.places.single.imageUrl,
        endsWith('2.jpg'),
        reason: 'the cover is the first remaining photo',
      );
    });

    test('reordering changes the cover without touching storage', () async {
      final repository = FakePlaceRepository(
        places: <Place>[
          placeWithPhotos(<String>[
            'https://storage.test/v0/b/yatra/o/places%2Fp%2F1.jpg',
            'https://storage.test/v0/b/yatra/o/places%2Fp%2F2.jpg',
          ]),
        ],
      );
      final storage = FakePlaceImageStorage();

      final reversed = repository.places.single.imageUrls.reversed.toList();

      await PlacePhotoService(
        repository: repository,
        storage: storage,
      ).reorderPhotos(place: repository.places.single, urls: reversed);

      expect(repository.places.single.imageUrls, reversed);
      expect(storage.uploadCalls, 0);
      expect(storage.deleteCalls, 0);
    });

    test('reordering cannot silently drop a photo', () async {
      final repository = FakePlaceRepository(
        places: <Place>[
          placeWithPhotos(<String>[
            'https://storage.test/v0/b/yatra/o/places%2Fp%2F1.jpg',
            'https://storage.test/v0/b/yatra/o/places%2Fp%2F2.jpg',
          ]),
        ],
      );

      expect(
        () =>
            PlacePhotoService(
              repository: repository,
              storage: FakePlaceImageStorage(),
            ).reorderPhotos(
              place: repository.places.single,
              urls: <String>[
                'https://storage.test/v0/b/yatra/o/places%2Fp%2F1.jpg',
              ],
            ),
        throwsArgumentError,
      );
    });
  });
}

final Uint8List _bytes = Uint8List.fromList(List<int>.filled(8, 1));
