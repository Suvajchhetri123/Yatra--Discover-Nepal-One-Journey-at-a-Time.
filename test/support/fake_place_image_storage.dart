import 'package:yatra/services/place_image_picker.dart';
import 'package:yatra/services/place_image_storage.dart';

/// In-memory [PlaceImageStorage] for tests.
///
/// Returns predictable `places/{placeId}/...` URLs so ownership, deletion and
/// rollback can be asserted without a bucket.
class FakePlaceImageStorage implements PlaceImageStorage {
  FakePlaceImageStorage({
    this.uploadError,
    this.deleteError,
    this.ownsAll = false,
    this.uploadErrorAfter,
  });

  /// Fails an upload once the given number of photos have succeeded, so a
  /// mid-way failure and its rollback can be tested.
  Object? uploadError;
  int? uploadErrorAfter;

  Object? deleteError;

  /// Treats every URL as Yatra-owned, for tests that do not care about
  /// ownership.
  bool ownsAll;

  final List<String> uploadedPaths = <String>[];
  final List<String> deletedUrls = <String>[];

  int uploadCalls = 0;
  int deleteCalls = 0;

  @override
  Future<PlaceImage> uploadPlaceImage({
    required String placeId,
    required PickedImage image,
    PlaceImageUploadProgress? onProgress,
  }) async {
    uploadCalls += 1;

    if (uploadErrorAfter != null && uploadCalls > uploadErrorAfter!) {
      throw StateError('upload failed');
    }

    if (uploadError != null) throw uploadError!;

    onProgress?.call(0.5);
    onProgress?.call(1);

    final path = 'places/$placeId/photo-$uploadCalls.jpg';

    uploadedPaths.add(path);

    return PlaceImage(url: _urlFor(path), storageOwned: true);
  }

  @override
  Future<void> deletePlaceImage(PlaceImage image) async {
    deleteCalls += 1;

    deletedUrls.add(image.url);

    if (deleteError != null) throw deleteError!;
  }

  @override
  bool ownsUrl(String url) {
    if (ownsAll) return true;

    return url.startsWith(_base);
  }

  static const String _base = 'https://storage.test/v0/b/yatra/o/';

  static String _urlFor(String path) {
    return '$_base${Uri.encodeComponent(path)}';
  }

  /// The storage path behind a URL produced by this fake.
  static String pathFor(String url) {
    return Uri.decodeComponent(url.substring(_base.length));
  }
}
