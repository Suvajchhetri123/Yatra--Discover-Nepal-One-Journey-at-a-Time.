import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Domestic / international price override editor.
///
/// The universal price is always edited by the parent form; this widget only
/// handles the optional explicit per-segment rates, so a place or package can
/// charge tourists differently without any global multiplier.
///
/// State (enabled flag, controllers, validation) is owned by the parent so the
/// same widget can be reused by the place and package forms.
class AdminTouristPricingField extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final TextEditingController domesticController;
  final TextEditingController internationalController;
  final String? domesticError;
  final String? internationalError;

  const AdminTouristPricingField({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.domesticController,
    required this.internationalController,
    this.domesticError,
    this.internationalError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: onEnabledChanged,
          title: Text(
            'Domestic / international rates',
            style: AppType.bodyEmphasis,
          ),
          subtitle: Text(
            'Off means every tourist pays the universal price.',
            style: AppType.caption,
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: domesticController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Domestic price',
              hintText: 'NPR rate for domestic tourists',
              errorText: domesticError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: internationalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'International price',
              hintText: 'NPR rate for international tourists',
              errorText: internationalError,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}
