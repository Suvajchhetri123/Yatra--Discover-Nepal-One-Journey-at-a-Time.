import 'package:flutter/material.dart';

import '../../models/place_model.dart';
import '../../models/tourist_pricing.dart';
import '../../services/device_image_picker.dart';
import '../../services/firebase_place_image_storage.dart';
import '../../services/firestore_place_service.dart';
import '../../services/place_image_picker.dart';
import '../../services/place_photo_service.dart';
import '../../services/place_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_content_messages.dart';
import 'admin_tourist_pricing_field.dart';

/// Add / edit form for a place in the admin registry.
///
/// [place] is null when adding and the record being edited otherwise. The
/// Firestore document id is never editable: the repository generates it and
/// booking snapshots reference it.
///
/// Photos are managed through [photoService] and [picker]; the form never
/// shows a raw URL and never touches Storage itself. A legacy place keeps the
/// image it was seeded with until a real photo is added, so nothing has to be
/// re-uploaded.
class AdminPlaceFormScreen extends StatefulWidget {
  final Place? place;
  final PlaceRepository? repository;

  /// Saves the place together with its photos.
  ///
  /// Defaults to a [PlacePhotoService] over the same repository. Tests inject a
  /// service backed by fakes, so no widget test needs a picker or a bucket.
  final PlacePhotoService? photoService;

  /// Photo source. Defaults to [DeviceImagePicker].
  final PlaceImagePicker? picker;

  const AdminPlaceFormScreen({
    super.key,
    this.place,
    this.repository,
    this.photoService,
    this.picker,
  });

  @override
  State<AdminPlaceFormScreen> createState() => _AdminPlaceFormScreenState();
}

class _AdminPlaceFormScreenState extends State<AdminPlaceFormScreen> {
  late final PlaceRepository _repository =
      widget.repository ?? FirestorePlaceService();

  /// Resolved lazily so an injected fake is never bypassed.
  ///
  /// The Firebase Storage client is only ever constructed when no service was
  /// injected, so a widget test never touches a real bucket.
  late final PlacePhotoService _photoService =
      widget.photoService ??
      PlacePhotoService(
        repository: _repository,
        storage: FirebasePlaceImageStorage(),
      );

  /// Resolved lazily so an injected fake is never bypassed.
  late final PlaceImagePicker _picker = widget.picker ?? DeviceImagePicker();

  late final TextEditingController _nameController = TextEditingController(
    text: widget.place?.name ?? '',
  );

  late final TextEditingController _locationController = TextEditingController(
    text: widget.place?.location ?? '',
  );

  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.place?.description ?? '');

  late final TextEditingController _entryFeeController = TextEditingController(
    text: _formatAmount(widget.place?.entryFee),
  );

  late final TextEditingController _domesticFeeController =
      TextEditingController(
        text: _formatAmount(widget.place?.touristEntryFee?.domestic),
      );

  late final TextEditingController _internationalFeeController =
      TextEditingController(
        text: _formatAmount(widget.place?.touristEntryFee?.international),
      );

  late final TextEditingController _openingHoursController =
      TextEditingController(text: widget.place?.openingHours ?? '');

  late final TextEditingController _transportationController =
      TextEditingController(text: widget.place?.transportation ?? '');

  late final TextEditingController _travelTripController =
      TextEditingController(text: widget.place?.travelTrip ?? '');

  late final TextEditingController _hoursController = TextEditingController(
    text: _formatAmount(widget.place?.recommendedHours),
  );

  late bool _useTouristPricing = widget.place?.touristEntryFee != null;

  final Map<String, String> _fieldErrors = <String, String>{};

  bool _saving = false;

  /// True while the native picker is open, so it cannot be opened twice.
  bool _picking = false;

  /// The index of a photo whose removal is in flight.
  int? _removingIndex;

  /// Non-null while photos upload, so the admin sees real progress.
  PlacePhotoSaveProgress? _uploadProgress;

  /// Photo problems are shown inline rather than as a snack bar, because a
  /// failed upload is something the admin usually retries immediately.
  String? _photosError;

  /// The place's photos: stored entries plus anything chosen but not yet
  /// uploaded. The first entry is the cover image.
  late List<PlacePhotoEntry> _photos = _initialPhotos();

  bool get _isEditing => widget.place != null;

  /// The pre-photos image a seeded place still uses.
  String get _legacyImageUrl => widget.place?.legacyImageUrl ?? '';

  bool get _photoBusy =>
      _saving || _picking || _removingIndex != null || _uploadProgress != null;

  /// Seeds the photo list from the place being edited.
  ///
  /// Ownership is resolved through the storage abstraction, so a legacy
  /// external image is shown but never offered for deletion.
  List<PlacePhotoEntry> _initialPhotos() {
    final stored = widget.place?.imageUrls ?? const <String>[];

    return stored
        .map(
          (url) => PlacePhotoEntry.stored(
            url,
            storageOwned: _photoService.ownsPhotoUrl(url),
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();

    for (final controller in _controllers) {
      controller.addListener(_onFieldChanged);
    }
  }

  List<TextEditingController> get _controllers => [
    _nameController,
    _locationController,
    _descriptionController,
    _entryFeeController,
    _domesticFeeController,
    _internationalFeeController,
    _openingHoursController,
    _transportationController,
    _travelTripController,
    _hoursController,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_onFieldChanged)
        ..dispose();
    }

    super.dispose();
  }

  void _onFieldChanged() {
    if (_fieldErrors.isEmpty) return;

    setState(_fieldErrors.clear);
  }

  static String _formatAmount(double? value) {
    if (value == null) return '';

    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  /// Parses a non-negative number, returning null when the text is not a
  /// usable amount.
  static double? _parseAmount(String text) {
    final trimmed = text.trim();

    if (trimmed.isEmpty) return null;

    final parsed = double.tryParse(trimmed);

    if (parsed == null || parsed.isNaN || parsed < 0) return null;

    return parsed;
  }

  bool _validate() {
    final errors = <String, String>{};

    if (_nameController.text.trim().isEmpty) {
      errors['name'] = 'Enter a place name.';
    }

    if (_locationController.text.trim().isEmpty) {
      errors['location'] = 'Enter a location.';
    }

    if (_entryFeeController.text.trim().isEmpty) {
      errors['entryFee'] = 'Enter the universal entry fee.';
    } else if (_parseAmount(_entryFeeController.text) == null) {
      errors['entryFee'] = kAdminCatalogInvalidNumberMessage;
    }

    if (_hoursController.text.trim().isNotEmpty &&
        _parseAmount(_hoursController.text) == null) {
      errors['hours'] = kAdminCatalogInvalidNumberMessage;
    }

    if (_useTouristPricing) {
      final domestic = _domesticFeeController.text.trim();
      final international = _internationalFeeController.text.trim();

      if (domestic.isEmpty && international.isEmpty) {
        errors['domestic'] = 'Enter at least one segment rate.';
      } else {
        if (domestic.isNotEmpty && _parseAmount(domestic) == null) {
          errors['domestic'] = kAdminCatalogInvalidNumberMessage;
        }

        if (international.isNotEmpty && _parseAmount(international) == null) {
          errors['international'] = kAdminCatalogInvalidNumberMessage;
        }
      }
    }

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
    });

    return errors.isEmpty;
  }

  /// Adds a photo chosen from the device.
  ///
  /// Cancelling the picker is a no-op rather than an error, and the five-photo
  /// limit is enforced here so the admin is told before a file is read.
  Future<void> _addPhoto() async {
    if (_photoBusy) return;

    if (_photos.length >= _photoService.maxPhotos) {
      setState(() {
        _photosError =
            'A place can have up to ${_photoService.maxPhotos} photos.';
      });

      return;
    }

    setState(() {
      _picking = true;
      _photosError = null;
    });

    try {
      final image = await _picker.pickFromGallery();

      if (!mounted) return;

      if (image == null) return;

      setState(() {
        _photos = <PlacePhotoEntry>[
          ..._photos,
          PlacePhotoEntry.pending(image.bytes, fileName: image.fileName),
        ];
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _photosError = 'Could not open your photos. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  /// Removes one photo, deleting the stored file only when Yatra owns it.
  Future<void> _removePhoto(int index) async {
    if (_photoBusy) return;

    final entry = _photos[index];

    if (entry.isPending) {
      setState(() {
        _photos = List<PlacePhotoEntry>.of(_photos)..removeAt(index);
        _photosError = null;
      });

      return;
    }

    final place = widget.place;

    // A pending photo is never persisted, so removing it needs no write.
    if (place == null || entry.url == null) {
      setState(() {
        _photos = List<PlacePhotoEntry>.of(_photos)..removeAt(index);
      });

      return;
    }

    setState(() {
      _removingIndex = index;
      _photosError = null;
    });

    try {
      await _photoService.removePhotos(
        place: place,
        urls: <String>[entry.url!],
      );

      if (!mounted) return;

      setState(() {
        _photos = List<PlacePhotoEntry>.of(_photos)..removeAt(index);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _photosError = 'Could not remove that photo. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _removingIndex = null);
      }
    }
  }

  /// Promotes a photo to the cover position.
  ///
  /// Only meaningful for a place that already exists, because a pending photo
  /// has no stored order yet; the save writes the chosen order.
  Future<void> _makeCover(int index) async {
    if (_photoBusy || index == 0) return;

    final reordered = List<PlacePhotoEntry>.of(_photos);

    final chosen = reordered.removeAt(index);

    reordered.insert(0, chosen);

    final place = widget.place;
    final urls = reordered.map((entry) => entry.storedUrl).toList();

    setState(() {
      _photos = reordered;
      _photosError = null;
    });

    if (place == null || urls.any((url) => url == null)) return;

    try {
      await _photoService.reorderPhotos(
        place: place,
        urls: urls.cast<String>(),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _photosError = 'Could not change the cover photo. Please try again.';
      });
    }
  }

  /// Reads the override fields, returning null when the switch is off or no
  /// segment rate was entered.
  TouristPricing? _readTouristPricing() {
    if (!_useTouristPricing) return null;

    return TouristPricing(
      domestic: _parseAmount(_domesticFeeController.text),
      international: _parseAmount(_internationalFeeController.text),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kAdminCatalogRequiredFieldsMessage)),
      );

      return;
    }

    setState(() => _saving = true);

    // The photo fields are deliberately absent: they are owned by
    // [PlacePhotoService], which needs the saved document id before it can
    // upload anything.
    final place =
        (widget.place ??
                Place(
                  name: '',
                  location: '',
                  description: '',
                  imageUrl: '',
                  entryFee: 0,
                  openingHours: '',
                  transportation: '',
                  travelTrip: '',
                  recommendedHours: 0,
                ))
            .copyWith(
              name: _nameController.text.trim(),
              location: _locationController.text.trim(),
              description: _descriptionController.text.trim(),
              entryFee: _parseAmount(_entryFeeController.text) ?? 0,
              clearTouristEntryFee: !_useTouristPricing,
              touristEntryFee: _readTouristPricing(),
              openingHours: _openingHoursController.text.trim(),
              transportation: _transportationController.text.trim(),
              travelTrip: _travelTripController.text.trim(),
              recommendedHours:
                  _parseAmount(_hoursController.text) ??
                  widget.place?.recommendedHours ??
                  0,
            );

    final pending = _photos
        .where((entry) => entry.isPending)
        .map(
          (entry) =>
              PendingPlacePhoto(bytes: entry.bytes!, fileName: entry.fileName),
        )
        .toList();

    try {
      await _photoService.saveWithPhotos(
        place: place,
        pending: pending,
        onUploadProgress: pending.isEmpty
            ? null
            : (progress) {
                if (mounted) {
                  setState(() => _uploadProgress = progress);
                }
              },
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on PlacePhotoUploadException {
      // The place itself is saved, so the admin is told exactly that instead of
      // being sent back to a form that looks like nothing happened.
      if (!mounted) return;

      setState(() {
        _saving = false;
        _uploadProgress = null;
        _photosError = PlacePhotoService.kUploadFailureMessage;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _uploadProgress = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kAdminCatalogSaveFailureMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit place' : 'Add place')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('Place details', style: AppType.bodyEmphasis),
            const SizedBox(height: AppSpacing.sm),
            _field(
              key: 'name',
              controller: _nameController,
              label: 'Name',
              hint: 'e.g. Muktinath',
              textCapitalization: TextCapitalization.words,
            ),
            _field(
              key: 'location',
              controller: _locationController,
              label: 'Location',
              hint: 'e.g. Mustang',
              textCapitalization: TextCapitalization.words,
            ),
            _field(
              key: 'description',
              controller: _descriptionController,
              label: 'Description',
              hint: 'What makes this place worth visiting?',
              maxLines: 3,
            ),
            _photoSection(context),
            _field(
              key: 'entryFee',
              controller: _entryFeeController,
              label: 'Universal entry fee (NPR)',
              hint: '0',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            AdminTouristPricingField(
              enabled: _useTouristPricing,
              onEnabledChanged: (value) =>
                  setState(() => _useTouristPricing = value),
              domesticController: _domesticFeeController,
              internationalController: _internationalFeeController,
              domesticError: _fieldErrors['domestic'],
              internationalError: _fieldErrors['international'],
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              key: 'openingHours',
              controller: _openingHoursController,
              label: 'Opening hours',
              hint: 'e.g. 6:00 AM - 6:00 PM',
            ),
            _field(
              key: 'transportation',
              controller: _transportationController,
              label: 'How to reach',
              hint: 'e.g. 3h drive from Pokhara',
            ),
            _field(
              key: 'travelTrip',
              controller: _travelTripController,
              label: 'Recommended trip route',
              hint: 'e.g. Pokhara - Muktinath - Jomsom',
            ),
            _field(
              key: 'hours',
              controller: _hoursController,
              label: 'Recommended hours',
              hint: 'e.g. 4',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            YatraPrimaryButton(
              label: _isEditing ? 'Save changes' : 'Add place',
              icon: Icons.check,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  /// The photo area: existing photos, an add button, and upload progress.
  ///
  /// There is no URL field. An admin picks an image, sees it immediately, and
  /// only the app ever learns where it was stored.
  Widget _photoSection(BuildContext context) {
    final progress = _uploadProgress;
    final maxPhotos = _photoService.maxPhotos;
    final full = _photos.length >= maxPhotos;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photos', style: AppType.bodyEmphasis),
          const SizedBox(height: AppSpacing.xs),
          Text(
            full
                ? 'The first photo is the cover. Remove one to add another.'
                : 'Up to $maxPhotos photos. The first photo is the cover.',
            style: AppType.caption,
          ),
          const SizedBox(height: AppSpacing.sm),

          if (_photos.isEmpty && _legacyImageUrl.isNotEmpty)
            // A seeded place already shows an image. It is displayed rather
            // than hidden so an admin knows what travellers see, and it carries
            // no delete control because Yatra does not own that file.
            _legacyPhotoTile(context)
          else if (_photos.isEmpty)
            Text('No photos yet.', style: AppType.caption)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (var index = 0; index < _photos.length; index++)
                  _photoTile(context, index),
              ],
            ),

          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            // Real progress, not a spinner: an upload of five photographs can
            // take a while on a slow connection.
            LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Uploading photo ${progress.uploaded} of ${progress.total}…',
              style: AppType.caption,
            ),
          ],

          if (_photosError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _photosError!,
              style: AppType.caption.copyWith(color: AppColors.danger),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
          YatraSecondaryButton(
            label: _picking
                ? 'Opening photos…'
                : (full ? 'Photo limit reached' : 'Add photo'),
            icon: Icons.add_a_photo_outlined,
            onPressed: _photoBusy || full ? null : _addPhoto,
          ),
        ],
      ),
    );
  }

  /// One photo with its cover marker, remove action and reorder control.
  Widget _photoTile(BuildContext context, int index) {
    final entry = _photos[index];
    final isCover = index == 0;
    final removing = _removingIndex == index;

    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: entry.isPending
                    ? Image.memory(
                        entry.bytes!,
                        width: 104,
                        height: 78,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        entry.url!,
                        width: 104,
                        height: 78,
                        fit: BoxFit.cover,
                        // A missing legacy image must not break the form.
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 104,
                          height: 78,
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
              ),
              if (removing)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCover
                        ? AppColors.primary
                        : Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    entry.isPending
                        ? 'New'
                        : (isCover ? 'Cover' : '${index + 1}'),
                    style: AppType.caption.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (!isCover && !entry.isPending)
                Expanded(
                  child: TextButton(
                    onPressed: _photoBusy ? null : () => _makeCover(index),
                    child: const Text('Cover'),
                  ),
                ),
              Expanded(
                child: TextButton(
                  onPressed: _photoBusy ? null : () => _removePhoto(index),
                  child: Text(entry.storageOwned ? 'Remove' : 'Remove link'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The read-only tile for a place that still uses its legacy image.
  Widget _legacyPhotoTile(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _legacyImageUrl,
              width: 104,
              height: 78,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 104,
                height: 78,
                color: AppColors.primary.withValues(alpha: 0.08),
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Current image', style: AppType.caption),
        ],
      ),
    );
  }

  Widget _field({
    required String key,
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: _fieldErrors[key],
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
