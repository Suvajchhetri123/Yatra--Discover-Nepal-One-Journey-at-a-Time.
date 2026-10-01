import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';

import 'place_image_picker.dart';
import 'place_image_storage.dart';

/// Production [PlaceImageStorage] backed by Firebase Storage.
///
/// Responsibilities that deliberately live here and not in a widget:
///
///   - a fixed, non-colliding path shape: `places/{placeId}/{fileName}`;
///   - a unique, sanitised file name per upload;
///   - refusing to delete anything Yatra does not own.
///
/// Administrators never see a path, a bucket or a document id: the UI only
/// ever handles the resulting [PlaceImage].
class FirebasePlaceImageStorage implements PlaceImageStorage {
  FirebasePlaceImageStorage({FirebaseStorage? storage, Random? random})
    : _storage = storage ?? FirebaseStorage.instance,
      _random = random ?? Random.secure();

  final FirebaseStorage _storage;
  final Random _random;

  /// Maximum number of photos a place may show.
  static const int maxPhotosPerPlace = 5;

  /// Path prefix for every catalog image, which is also how a Yatra-owned URL
  /// is recognised later.
  static const String catalogPrefix = 'places';

  static const List<String> _allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  ];

  Reference get _bucketRoot => _storage.ref();

  String get _downloadBase =>
      'https://firebasestorage.googleapis.com/v0/b/${_bucketRoot.bucket}/o/';

  @override
  Future<PlaceImage> uploadPlaceImage({
    required String placeId,
    required PickedImage image,
    PlaceImageUploadProgress? onProgress,
  }) async {
    final safePlaceId = _sanitiseSegment(placeId);

    if (safePlaceId.isEmpty) {
      throw ArgumentError('A place id is required to store an image.');
    }

    final reference = _bucketRoot.child(
      '$catalogPrefix/$safePlaceId/${_generateFileName(image.fileName)}',
    );

    final snapshot = await reference.putData(
      image.bytes,
      SettableMetadata(contentType: _contentTypeFor(image.fileName)),
    );

    onProgress?.call(1);

    return PlaceImage(
      url: await snapshot.ref.getDownloadURL(),
      storageOwned: true,
    );
  }

  @override
  Future<void> deletePlaceImage(PlaceImage image) async {
    // A legacy or externally hosted image is never deleted from Storage: it is
    // not ours, and the URL may be used by historical booking snapshots.
    if (!image.storageOwned || !ownsUrl(image.url)) {
      return;
    }

    await _bucketRoot.child(_pathFromUrl(image.url)).delete();
  }

  @override
  bool ownsUrl(String url) {
    if (!url.startsWith(_downloadBase)) return false;

    return _decodePathFromUrl(url).startsWith('$catalogPrefix/');
  }

  /// Unique, collision-free file name that keeps a safe extension.
  String _generateFileName(String? originalName) {
    final extension = _extensionOf(originalName);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final entropy = _random.nextInt(0x7FFFFFFF).toRadixString(36);

    return extension == null ? '$stamp-$entropy' : '$stamp-$entropy.$extension';
  }

  /// Lower-cased extension, or null when it is missing or not an image type.
  String? _extensionOf(String? fileName) {
    if (fileName == null) return null;

    final dot = fileName.lastIndexOf('.');

    if (dot < 0 || dot == fileName.length - 1) return null;

    final extension = fileName.substring(dot + 1).toLowerCase();

    return _allowedExtensions.contains(extension) ? extension : null;
  }

  String? _contentTypeFor(String? fileName) {
    switch (_extensionOf(fileName)) {
      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'heic':
        return 'image/heic';

      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      default:
        // A file with no usable extension is still an image as far as the app
        // is concerned; let Storage serve it as a binary blob.
        return 'application/octet-stream';
    }
  }

  /// Strips anything that could escape the `places/{placeId}/` prefix.
  String _sanitiseSegment(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-_]'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _decodePathFromUrl(String url) {
    final withoutBase = url.substring(_downloadBase.length);
    final path = withoutBase.split('?').first;

    return Uri.decodeComponent(path);
  }

  String _pathFromUrl(String url) => _decodePathFromUrl(url);
}
