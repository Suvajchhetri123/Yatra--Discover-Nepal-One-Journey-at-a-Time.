import 'package:flutter/material.dart';

import '../../models/travel_coordinator.dart';
import '../../services/coordinator_repository.dart';
import '../../services/firestore_coordinator_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_content_messages.dart';

/// Add / edit form for a coordinator in the admin registry.
///
/// [coordinator] is null when adding a new coordinator and the record being
/// edited otherwise. The Firestore document id is never editable: it is
/// supplied by the repository on create and read-only on edit, because
/// booking snapshots reference it.
class AdminCoordinatorFormScreen extends StatefulWidget {
  final TravelCoordinator? coordinator;
  final CoordinatorRepository? repository;

  const AdminCoordinatorFormScreen({
    super.key,
    this.coordinator,
    this.repository,
  });

  @override
  State<AdminCoordinatorFormScreen> createState() =>
      _AdminCoordinatorFormScreenState();
}

class _AdminCoordinatorFormScreenState
    extends State<AdminCoordinatorFormScreen> {
  late final CoordinatorRepository _repository =
      widget.repository ?? FirestoreCoordinatorService();

  late final TextEditingController _nameController = TextEditingController(
    text: widget.coordinator?.name ?? '',
  );

  late final TextEditingController _phoneController = TextEditingController(
    text: widget.coordinator?.phone ?? '',
  );

  late final TextEditingController _emailController = TextEditingController(
    text: widget.coordinator?.email ?? '',
  );

  /// Field-level messages, cleared as the admin types.
  final Map<String, String> _fieldErrors = <String, String>{};

  bool _saving = false;

  /// Blocks a second submit while the first write is still in flight.
  bool get _isSubmitting => _saving;

  bool get _isEditing => widget.coordinator != null;

  @override
  void initState() {
    super.initState();

    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _phoneController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _emailController
      ..removeListener(_onFieldChanged)
      ..dispose();

    super.dispose();
  }

  /// Clears stale validation messages, but only while some are showing, so
  /// typing does not trigger a setState per keystroke.
  void _onFieldChanged() {
    if (_fieldErrors.isEmpty) return;

    setState(_fieldErrors.clear);
  }

  /// Validates the typed values. Returns true when the form may be saved.
  bool _validate() {
    final errors = <String, String>{};

    if (_nameController.text.trim().isEmpty) {
      errors['name'] = 'Enter a name.';
    }

    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      errors['phone'] = 'Enter a phone number.';
    } else if (phone.replaceAll(RegExp(r'[0-9+\-\s]'), '').isNotEmpty) {
      errors['phone'] = 'Use digits, spaces and + only.';
    }

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      errors['email'] = 'Enter an email address.';
    } else if (!email.contains('@') || !email.contains('.')) {
      errors['email'] = 'Enter a valid email address.';
    }

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
    });

    return errors.isEmpty;
  }

  Future<void> _save() async {
    if (_isSubmitting) return;

    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kAdminCatalogRequiredFieldsMessage)),
      );

      return;
    }

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        await _repository.updateCoordinator(
          id: widget.coordinator!.id,
          name: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
        );
      } else {
        await _repository.createCoordinator(
          name: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
        );
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit coordinator' : 'Add coordinator'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            YatraSectionTitle(
              title: _isEditing ? 'Update details' : 'New coordinator',
              subtitle: _isEditing
                  ? 'Changes apply to future assignments only. Bookings that '
                        'already reference this coordinator keep their saved '
                        'contact details.'
                  : 'This coordinator becomes available in the booking '
                        'assignment picker.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _field(
              key: 'name',
              controller: _nameController,
              label: 'Full name',
              hint: 'e.g. Sushmita Gurung',
              textCapitalization: TextCapitalization.words,
            ),
            _field(
              key: 'phone',
              controller: _phoneController,
              label: 'Phone',
              hint: 'e.g. +977 98XXXXXXXX',
              keyboardType: TextInputType.phone,
            ),
            _field(
              key: 'email',
              controller: _emailController,
              label: 'Email',
              hint: 'name@yatra.app',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.lg),
            YatraPrimaryButton(
              label: _isEditing ? 'Save changes' : 'Add coordinator',
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
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
