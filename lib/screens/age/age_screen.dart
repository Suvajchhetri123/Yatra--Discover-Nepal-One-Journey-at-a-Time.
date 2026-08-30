import 'package:flutter/material.dart';

import '../../models/package_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import '../budget/budget_screen.dart';

/// Traveller Ages — wizard step 3 of 4.
///
/// Redesigned on the central Yatra design system. All age values, validation
/// and age categories are unchanged.
class AgeScreen extends StatefulWidget {
  final String travelType;
  final int adultCount;
  final int childCount;
  final DateTime departureDate;
  final DateTime returnDate;
  final TourPackage? package;

  const AgeScreen({
    super.key,
    required this.travelType,
    required this.adultCount,
    required this.childCount,
    required this.departureDate,
    required this.returnDate,
    this.package,
  });

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  late List<TextEditingController> ageControllers;

  @override
  void initState() {
    super.initState();

    ageControllers = List.generate(
      widget.adultCount + widget.childCount,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final controller in ageControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  String getAgeCategory(int age) {
    if (age < 18) return 'Under 18';
    if (age <= 30) return '18–30';
    if (age <= 45) return '31–45';
    if (age <= 60) return '46–60';
    return '60+';
  }

  bool _isValidAge(String value, int index) {
    final age = int.tryParse(value.trim());

    if (age == null) return false;

    if (index < widget.adultCount) {
      return age >= 18 && age <= 120;
    }

    return age >= 1 && age < 18;
  }

  bool get _allAgesValid {
    return ageControllers.indexed.every(
      (entry) => _isValidAge(entry.$2.text, entry.$1),
    );
  }

  void _continue() {
    if (!_allAgesValid) return;

    final ages = ageControllers
        .map((controller) => int.parse(controller.text.trim()))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BudgetScreen(
          ages: ages,
          travelType: widget.travelType,
          groupSize: widget.adultCount + widget.childCount,
          departureDate: widget.departureDate,
          returnDate: widget.returnDate,
          package: widget.package,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSolo = widget.travelType == 'Solo';
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Traveller Ages')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YatraWizardHeader(
                      step: 3,
                      totalSteps: 4,
                      title: isSolo
                          ? 'How old are you?'
                          : 'How old are the travellers?',
                      subtitle: isSolo
                          ? 'Your age helps Yatra suggest a suitable '
                              'travel pace and experience.'
                          : 'The ages of all travellers help Yatra '
                              'calculate a suitable travel pace and duration '
                              'for the whole group.',
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    for (var index = 0; index < ageControllers.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: _AgeField(
                          controller: ageControllers[index],
                          index: index,
                          isSolo: isSolo,
                          adultCount: widget.adultCount,
                          isValidAge: (value) =>
                              _isValidAge(value, index),
                          theme: textTheme,
                          scheme: scheme,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: YatraPrimaryButton(
                label: 'Continue',
                onPressed: _allAgesValid ? _continue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgeField extends StatelessWidget {
  final TextEditingController controller;
  final int index;
  final bool isSolo;
  final int adultCount;
  final bool Function(String value) isValidAge;
  final TextTheme theme;
  final ColorScheme scheme;
  final VoidCallback onChanged;

  const _AgeField({
    required this.controller,
    required this.index,
    required this.isSolo,
    required this.adultCount,
    required this.isValidAge,
    required this.theme,
    required this.scheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enteredAge = int.tryParse(controller.text.trim());
    final isEmpty = controller.text.trim().isEmpty;
    final valid = enteredAge != null && isValidAge(controller.text);

    final title = isSolo
        ? 'Your Age'
        : index < adultCount
            ? 'Adult ${index + 1}'
            : 'Child ${index - adultCount + 1}';

    final hint =
        index < adultCount ? 'Enter adult age' : 'Enter child age';

    final errorText = (isEmpty || valid)
        ? null
        : index < adultCount
            ? 'Adults must be 18 or older'
            : 'Children must be aged 1–17';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: errorText != null
                  ? scheme.error
                  : valid
                      ? scheme.primary
                      : scheme.outlineVariant,
              width: errorText != null || valid ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 3,
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              suffixIcon: valid
                  ? Icon(Icons.check_circle, color: scheme.primary, size: 20)
                  : null,
              errorText: errorText,
              fillColor: Colors.transparent,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        if (valid)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Age group: ${getAgeCategory(enteredAge)}',
              style: theme.bodyMedium?.copyWith(color: scheme.primary),
            ),
          ),
      ],
    );
  }

  String getAgeCategory(int age) {
    if (age < 18) return 'Under 18';
    if (age <= 30) return '18–30';
    if (age <= 45) return '31–45';
    if (age <= 60) return '46–60';
    return '60+';
  }
}
