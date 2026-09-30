import 'package:flutter/material.dart';

import '../../models/package_model.dart';
import '../../models/tourist_pricing.dart';
import '../../services/firestore_package_service.dart';
import '../../services/package_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_content_messages.dart';
import 'admin_tourist_pricing_field.dart';

/// The difficulty values the catalog uses.
const List<String> kPackageDifficultyOptions = <String>[
  'Easy',
  'Moderate',
  'Challenging',
];

/// Add / edit form for a tour package.
///
/// [package] is null when adding and the record being edited otherwise. The id
/// is not editable: on create the repository derives it from the title, and on
/// edit it must stay stable because itineraries reference it.
class AdminPackageFormScreen extends StatefulWidget {
  final TourPackage? package;
  final PackageRepository? repository;

  const AdminPackageFormScreen({super.key, this.package, this.repository});

  @override
  State<AdminPackageFormScreen> createState() => _AdminPackageFormScreenState();
}

class _AdminPackageFormScreenState extends State<AdminPackageFormScreen> {
  late final PackageRepository _repository =
      widget.repository ?? FirestorePackageService();

  late final TextEditingController _titleController = TextEditingController(
    text: widget.package?.title ?? '',
  );

  late final TextEditingController _regionController = TextEditingController(
    text: widget.package?.region ?? '',
  );

  late final TextEditingController _summaryController = TextEditingController(
    text: widget.package?.summary ?? '',
  );

  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.package?.description ?? '');

  late final TextEditingController _durationController = TextEditingController(
    text: widget.package == null ? '' : '${widget.package!.durationDays}',
  );

  late final TextEditingController _priceController = TextEditingController(
    text: _formatAmount(widget.package?.price),
  );

  late final TextEditingController _domesticPriceController =
      TextEditingController(
        text: _formatAmount(widget.package?.touristPrice?.domestic),
      );

  late final TextEditingController _internationalPriceController =
      TextEditingController(
        text: _formatAmount(widget.package?.touristPrice?.international),
      );

  late String _difficulty =
      kPackageDifficultyOptions.contains(widget.package?.difficulty)
      ? widget.package!.difficulty
      : kPackageDifficultyOptions.first;

  late final TextEditingController _ratingController = TextEditingController(
    text: widget.package == null ? '' : _formatAmount(widget.package!.rating),
  );

  late final TextEditingController _imageUrlController = TextEditingController(
    text: widget.package?.imageUrl ?? '',
  );

  late final TextEditingController _highlightsController =
      TextEditingController(text: widget.package?.highlights.join('\n') ?? '');

  late final TextEditingController _includedPlacesController =
      TextEditingController(
        text: widget.package?.includedPlaces.join('\n') ?? '',
      );

  late bool _useTouristPricing = widget.package?.touristPrice != null;

  final Map<String, String> _fieldErrors = <String, String>{};

  bool _saving = false;

  bool get _isEditing => widget.package != null;

  @override
  void initState() {
    super.initState();

    for (final controller in _controllers) {
      controller.addListener(_onFieldChanged);
    }
  }

  List<TextEditingController> get _controllers => [
    _titleController,
    _regionController,
    _summaryController,
    _descriptionController,
    _durationController,
    _priceController,
    _domesticPriceController,
    _internationalPriceController,
    _ratingController,
    _imageUrlController,
    _highlightsController,
    _includedPlacesController,
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

  static double? _parseAmount(String text) {
    final trimmed = text.trim();

    if (trimmed.isEmpty) return null;

    final parsed = double.tryParse(trimmed);

    if (parsed == null || parsed.isNaN || parsed < 0) return null;

    return parsed;
  }

  /// Splits a one-per-line textarea into a trimmed, non-empty list.
  static List<String> _parseLines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  bool _validate() {
    final errors = <String, String>{};

    if (_titleController.text.trim().isEmpty) {
      errors['title'] = 'Enter a package title.';
    }

    if (_regionController.text.trim().isEmpty) {
      errors['region'] = 'Enter a region.';
    }

    final imageUrl = _imageUrlController.text.trim();

    if (imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://')) {
      errors['imageUrl'] = 'Use a full http:// or https:// link.';
    }

    final days = int.tryParse(_durationController.text.trim());

    if (days == null || days < 1) {
      errors['duration'] = 'Enter at least 1 day.';
    }

    if (_priceController.text.trim().isEmpty) {
      errors['price'] = 'Enter the universal price.';
    } else if (_parseAmount(_priceController.text) == null) {
      errors['price'] = kAdminCatalogInvalidNumberMessage;
    }

    if (_ratingController.text.trim().isNotEmpty) {
      final rating = _parseAmount(_ratingController.text);

      if (rating == null || rating > 5) {
        errors['rating'] = 'Enter a rating between 0 and 5.';
      }
    }

    if (_useTouristPricing) {
      final domestic = _domesticPriceController.text.trim();
      final international = _internationalPriceController.text.trim();

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

  TouristPricing? _readTouristPricing() {
    if (!_useTouristPricing) return null;

    return TouristPricing(
      domestic: _parseAmount(_domesticPriceController.text),
      international: _parseAmount(_internationalPriceController.text),
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

    final package =
        (widget.package ??
                const TourPackage(
                  id: '',
                  title: '',
                  region: '',
                  summary: '',
                  description: '',
                  durationDays: 1,
                  price: 0,
                  difficulty: 'Easy',
                  rating: 0,
                  imageUrl: '',
                  highlights: <String>[],
                  includedPlaces: <String>[],
                ))
            .copyWith(
              title: _titleController.text.trim(),
              region: _regionController.text.trim(),
              summary: _summaryController.text.trim(),
              description: _descriptionController.text.trim(),
              durationDays: int.parse(_durationController.text.trim()),
              price: _parseAmount(_priceController.text) ?? 0,
              clearTouristPrice: !_useTouristPricing,
              touristPrice: _readTouristPricing(),
              difficulty: _difficulty,
              rating: _parseAmount(_ratingController.text) ?? 0,
              imageUrl: _imageUrlController.text.trim(),
              highlights: _parseLines(_highlightsController.text),
              includedPlaces: _parseLines(_includedPlacesController.text),
            );

    try {
      if (_isEditing) {
        await _repository.updatePackage(package);
      } else {
        await _repository.createPackage(package);
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit package' : 'Add package')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('Package details', style: AppType.bodyEmphasis),
            const SizedBox(height: AppSpacing.sm),
            _field(
              key: 'title',
              controller: _titleController,
              label: 'Title',
              hint: 'e.g. Kathmandu Valley Classic',
              textCapitalization: TextCapitalization.words,
            ),
            _field(
              key: 'region',
              controller: _regionController,
              label: 'Region',
              hint: 'e.g. Kathmandu Valley',
              textCapitalization: TextCapitalization.words,
            ),
            _field(
              key: 'summary',
              controller: _summaryController,
              label: 'Summary',
              hint: 'One line shown in listings',
              textCapitalization: TextCapitalization.sentences,
            ),
            _field(
              key: 'description',
              controller: _descriptionController,
              label: 'Description',
              hint: 'What the trip includes day by day',
              maxLines: 4,
            ),
            _field(
              key: 'duration',
              controller: _durationController,
              label: 'Duration (days)',
              hint: 'e.g. 5',
              keyboardType: TextInputType.number,
            ),
            _field(
              key: 'price',
              controller: _priceController,
              label: 'Universal price (NPR)',
              hint: '0',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            AdminTouristPricingField(
              enabled: _useTouristPricing,
              onEnabledChanged: (value) =>
                  setState(() => _useTouristPricing = value),
              domesticController: _domesticPriceController,
              internationalController: _internationalPriceController,
              domesticError: _fieldErrors['domestic'],
              internationalError: _fieldErrors['international'],
            ),
            const SizedBox(height: AppSpacing.md),
            _difficultyPicker(),
            const SizedBox(height: AppSpacing.md),
            _field(
              key: 'rating',
              controller: _ratingController,
              label: 'Rating (0 - 5)',
              hint: 'e.g. 4.5',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            _field(
              key: 'imageUrl',
              controller: _imageUrlController,
              label: 'Image URL',
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),
            _field(
              key: 'highlights',
              controller: _highlightsController,
              label: 'Highlights',
              hint: 'One per line',
              maxLines: 4,
            ),
            _field(
              key: 'includedPlaces',
              controller: _includedPlacesController,
              label: 'Included places',
              hint: 'One place name per line',
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.md),
            YatraPrimaryButton(
              label: _isEditing ? 'Save changes' : 'Add package',
              icon: Icons.check,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyPicker() {
    return DropdownButtonFormField<String>(
      initialValue: _difficulty,
      decoration: const InputDecoration(
        labelText: 'Difficulty',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final option in kPackageDifficultyOptions)
          DropdownMenuItem<String>(value: option, child: Text(option)),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() => _difficulty = value);
      },
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
