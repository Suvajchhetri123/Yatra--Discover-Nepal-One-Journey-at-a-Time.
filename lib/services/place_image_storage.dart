import 'place_image_picker.dart';

/// A place photo, together with whether Yatra owns the underlying file.
///
/// The ownership flag is what makes photo deletion safe. Yatra can delete a
/// file it uploaded; a legacy or externally hosted image is left completely
/// alone.
class PlaceImage {
  const PlaceImage({required this.url, this.storageOwned = false});

  final String url;

  /// True when this URL points at a Yatra-managed Storage object.
  final bool storageOwned;

  @override
  bool operator ==(Object other) =>
      other is PlaceImage &&
      other.url == url &&
      other.storageOwned == storageOwned;

  @override
  int get hashCode => Object.hash(url, storageOwned);

  @override
  String toString() => 'PlaceImage(owned: $storageOwned)';
}

/// Progress of a single upload, reported 0..1.
typedef PlaceImageUploadProgress = void Function(double progress);

/// Storage for admin-managed place photos.
///
/// Screens depend on this interface only, so no widget ever uploads a file or
/// knows a Storage path, and tests inject a fake instead of touching Firebase.
abstract class PlaceImageStorage {
  /// Uploads [image] for [placeId] and returns the stored photo.
  ///
  /// Implementations must generate a unique file name; callers must never pass
  /// or receive a path.
  Future<PlaceImage> uploadPlaceImage({
    required String placeId,
    required PickedImage image,
    PlaceImageUploadProgress? onProgress,
  });

  /// Deletes a Yatra-owned object.
  ///
  /// Implementations must refuse to delete anything they do not own, so a
  /// legacy `https://` image from the seed data is never touched.
  Future<void> deletePlaceImage(PlaceImage image);

  /// True when [url] is a Yatra-managed Storage object.
  ///
  /// Used by the admin UI to decide whether removing a photo may also remove
  /// the stored file.
  bool ownsUrl(String url);
}
