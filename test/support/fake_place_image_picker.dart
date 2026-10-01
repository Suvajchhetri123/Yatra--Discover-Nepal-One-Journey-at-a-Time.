import 'dart:typed_data';

import 'package:yatra/services/place_image_picker.dart';

/// In-memory [PlaceImagePicker] for widget tests.
///
/// Returns queued images instead of opening the native picker, so no test
/// needs a camera, a gallery or a platform channel.
class FakePlaceImagePicker implements PlaceImagePicker {
  FakePlaceImagePicker({List<PickedImage>? images})
    : _queue = List<PickedImage>.of(images ?? const <PickedImage>[]);

  final List<PickedImage> _queue;

  int pickCalls = 0;

  Object? error;

  /// Queues an image for the next pick.
  void enqueue(PickedImage image) => _queue.add(image);

  /// Queues a tiny PNG so tests do not have to build real image bytes.
  void enqueueSample({String fileName = 'photo.png'}) {
    enqueue(PickedImage(bytes: _onePixelPng, fileName: fileName));
  }

  @override
  Future<PickedImage?> takePhoto() => pickFromGallery();

  @override
  Future<PickedImage?> pickFromGallery() async {
    pickCalls += 1;

    if (error != null) throw error!;

    if (_queue.isEmpty) return null;

    return _queue.removeAt(0);
  }

  /// A valid 1x1 PNG, used wherever a test only needs "some image bytes".
  static final Uint8List _onePixelPng = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);
}
