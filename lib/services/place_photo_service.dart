import 'dart:typed_data';

import '../models/place_model.dart';
import 'place_image_picker.dart';
import 'place_image_storage.dart';
import 'place_repository.dart';

/// A photo the admin added in the form but has not uploaded yet.
///
/// Bytes are held in memory so the admin sees a real preview immediately, and
/// nothing is written to Storage until the place itself is saved.
class PendingPlacePhoto {
  const PendingPlacePhoto({required this.bytes, this.fileName});

  final Uint8List bytes;
  final String? fileName;
}

/// One photo row in the admin form: either stored or still pending.
class PlacePhotoEntry {
  const PlacePhotoEntry.stored(this.url, {this.storageOwned = false})
    : bytes = null,
      fileName = null;

  const PlacePhotoEntry.pending(this.bytes, {this.fileName})
    : url = null,
      storageOwned = false;

  /// Stored photo URL, or null for a pending upload.
  final String? url;

  final Uint8List? bytes;
  final String? fileName;

  /// True when the stored file belongs to Yatra and may be deleted.
  final bool storageOwned;

  bool get isPending => url == null;

  /// The URL to persist, or null while the photo is pending.
  String? get storedUrl => url;
}

/// Progress and state of the photo part of a save.
class PlacePhotoSaveProgress {
  const PlacePhotoSaveProgress({required this.uploaded, required this.total});

  final int uploaded;
  final int total;

  double get fraction => total == 0 ? 1 : uploaded / total;
}

/// Raised when the place document was saved but its photos were not.
///
/// The two failures are deliberately different types, because they are
/// different outcomes for the administrator: a document failure means nothing
/// was saved, while this one means the place exists and the photos need to be
/// added again. Collapsing them into one message would either lie about the
/// state of the catalog or panic about a place that is actually fine.
class PlacePhotoUploadException implements Exception {
  const PlacePhotoUploadException(this.placeId);

  /// The place that was saved without its new photos.
  final String placeId;

  @override
  String toString() => 'PlacePhotoUploadException($placeId)';
}

/// Reports how many of the chosen photos have finished uploading.
typedef PlaceImageProgressCallback =
    void Function(PlacePhotoSaveProgress progress);

/// Saves a place together with its uploaded photos.
///
/// The order matters and is not obvious:
///
///   1. the place document is created or updated first, because the Storage
///      path needs the real place id;
///   2. the chosen images are uploaded to `places/{placeId}/...`;
///   3. the place is updated with the resulting URLs.
///
/// A failure during step 2 therefore leaves a place without the new photos
/// rather than photos nobody references, and the admin is told so plainly.
class PlacePhotoService {
  const PlacePhotoService({
    required this.repository,
    required this.storage,
    this.maxPhotos = 5,
  });

  final PlaceRepository repository;
  final PlaceImageStorage storage;

  /// Maximum photos a place may carry.
  final int maxPhotos;

  static const String kUploadFailureMessage =
      'The place was saved, but its photos could not be uploaded. '
      'Please try adding them again.';

  static const String kSaveFailureMessage =
      'Could not save your changes. Please try again.';

  /// Creates or updates [place] and attaches the pending photos in [pending].
  ///
  /// Returns the place as it now stands in the catalog.
  Future<Place> saveWithPhotos({
    required Place place,
    required List<PendingPlacePhoto> pending,
    PlaceImageProgressCallback? onUploadProgress,
  }) async {
    final isEditing = place.id.isNotEmpty;

    final saved = isEditing
        ? await _update(place)
        : await repository.createPlace(place);

    if (pending.isEmpty) {
      return saved;
    }

    final urls = <String>[];

    try {
      for (var index = 0; index < pending.length; index++) {
        final photo = pending[index];

        final image = await storage.uploadPlaceImage(
          placeId: saved.id,
          image: PickedImage(bytes: photo.bytes, fileName: photo.fileName),
        );

        urls.add(image.url);

        onUploadProgress?.call(
          PlacePhotoSaveProgress(uploaded: index + 1, total: pending.length),
        );
      }
    } catch (_) {
      // Roll back the objects that did upload, so a failed attempt cannot leave
      // unreferenced files behind.
      await _deleteQuietly(urls);

      throw PlacePhotoUploadException(saved.id);
    }

    return _update(
      saved.copyWith(imageUrls: <String>[...saved.imageUrls, ...urls]),
    );
  }

  /// Removes [urls] from the place and deletes the Yatra-owned files.
  ///
  /// The remaining order is preserved, so the cover photo only changes when the
  /// cover itself is removed. Deletion is conservative: a URL that the place
  /// still references, or that Yatra does not own (a legacy web image), is
  /// never deleted.
  Future<void> removePhotos({
    required Place place,
    required List<String> urls,
  }) async {
    final dropped = urls.toSet();
    final remaining = place.imageUrls
        .where((url) => !dropped.contains(url))
        .toList();

    await _update(place.copyWith(imageUrls: remaining));

    for (final url in dropped) {
      // Still referenced by another photo of this place, or not ours: skip.
      if (remaining.contains(url)) continue;

      if (!storage.ownsUrl(url)) continue;

      await _deleteQuietly(<String>[url]);
    }
  }

  /// True when [url] is a photo Yatra uploaded and may therefore delete.
  ///
  /// The form asks the service rather than the storage directly, so a widget
  /// test that injects a fake service never constructs a real Storage client.
  bool ownsPhotoUrl(String url) => storage.ownsUrl(url);

  /// Persists a new photo order, which is how the cover image is chosen.
  ///
  /// Reordering never uploads or deletes anything, so it is a plain update. The
  /// length check guards against a caller silently dropping a photo.
  Future<void> reorderPhotos({
    required Place place,
    required List<String> urls,
  }) async {
    if (urls.length != place.imageUrls.length) {
      throw ArgumentError('reorderPhotos must keep every photo');
    }

    await _update(place.copyWith(imageUrls: List<String>.unmodifiable(urls)));
  }

  Future<Place> _update(Place place) async {
    await repository.updatePlace(place);

    return place;
  }

  Future<void> _deleteQuietly(List<String> urls) async {
    for (final url in urls) {
      if (!storage.ownsUrl(url)) continue;

      try {
        await storage.deletePlaceImage(
          PlaceImage(url: url, storageOwned: true),
        );
      } catch (_) {
        // A failed cleanup must not mask the original error.
      }
    }
  }
}
