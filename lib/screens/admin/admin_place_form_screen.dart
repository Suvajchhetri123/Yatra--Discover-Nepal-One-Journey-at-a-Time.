import 'package:flutter/material.dart';

import '../../models/place_model.dart';
import '../../models/tourist_pricing.dart';
import '../../services/firestore_place_service.dart';
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
/// `imageUrl` is a plain URL text field. The project has no Firebase Storage or
/// image picker dependency, so upload is deliberately out of scope.
class AdminPlaceFormScreen extends StatefulWidget {
  final Place? place;
  final PlaceRepository? repository;

  const AdminPlaceFormScreen({super.key, this.place, this.repository});

  @override
  State<AdminPlaceFormScreen> createState() => _AdminPlaceFormScreenState();
}

class _AdminPlaceFormScreenState extends State<AdminPlaceFormScreen> {
  late final PlaceRepository _repository =
      widget.repository ?? FirestorePlaceService();

  late final TextEditingController _nameController = TextEditingController(
    text: widget.place?.name ?? '',
  );

  late final TextEditingController _locationController = TextEditingController(
    text: widget.place?.location ?? '',
  );

  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.place?.description ?? '');

  late final TextEditingController _imageUrlController = TextEditingController(
    text: widget.place?.imageUrl ?? '',
  );

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

  bool get _isEditing => widget.place != null;

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
    _imageUrlController,
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

    final imageUrl = _imageUrlController.text.trim();

    if (imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://')) {
      errors['imageUrl'] = 'Use a full http:// or https:// link.';
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
              imageUrl: _imageUrlController.text.trim(),
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

    try {
      if (_isEditing) {
        await _repository.updatePlace(place);
      } else {
        await _repository.createPlace(place);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() => _saving = false);

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
            _field(
              key: 'imageUrl',
              controller: _imageUrlController,
              label: 'Image URL',
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),
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
