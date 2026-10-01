import 'dart:typed_data';

/// A single image the admin chose, held in memory until it is uploaded.
///
/// Only bytes and an optional file name travel through the app. No device
/// path, bucket or Storage path is ever surfaced to an administrator.
class PickedImage {
  const PickedImage({required this.bytes, this.fileName});

  final Uint8List bytes;

  /// Original file name, used only to keep a sensible file extension.
  final String? fileName;

  int get byteLength => bytes.length;
}

/// Where an admin picks a place photo from.
///
/// The interface exists so widget tests never touch the native picker: they
/// inject a fake that returns bytes directly. Production uses
/// `image_picker` behind [DeviceImagePicker].
abstract class PlaceImagePicker {
  /// Picks an existing image from the device.
  ///
  /// Returns null when the admin cancels, so cancelling is not an error.
  Future<PickedImage?> pickFromGallery();

  /// Takes a new photo. Optional feature; callers must handle a null result
  /// (for example on a device without a camera, or an emulator).
  Future<PickedImage?> takePhoto() async => null;
}
