import 'package:image_picker/image_picker.dart';

import 'place_image_picker.dart';

/// Production [PlaceImagePicker] backed by the device's image picker.
///
/// The native plugin is confined to this file so widget tests never need a
/// platform channel, a camera or a gallery.
class DeviceImagePicker implements PlaceImagePicker {
  DeviceImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int _maxImageDimension = 1600;

  @override
  Future<PickedImage?> pickFromGallery() {
    return _pick(ImageSource.gallery);
  }

  @override
  Future<PickedImage?> takePhoto() {
    return _pick(ImageSource.camera);
  }

  Future<PickedImage?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      // Admin photos are displayed as catalog thumbnails, so a large
      // full-resolution original would only cost upload time.
      maxWidth: _maxImageDimension.toDouble(),
      maxHeight: _maxImageDimension.toDouble(),
      imageQuality: 85,
    );

    if (file == null) return null;

    return PickedImage(bytes: await file.readAsBytes(), fileName: file.name);
  }
}
