import 'package:flutter/material.dart';

import '../../models/package_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import '../travel_group/travel_group_screen.dart';

/// Travel Dates — wizard step 1 of 4.
///
/// Redesigned on the central Yatra design system. All date selection and
/// validation logic is unchanged.
class TravelDatesScreen extends StatefulWidget {
  final TourPackage? package;

  const TravelDatesScreen({super.key, this.package});

  @override
  State<TravelDatesScreen> createState() => _TravelDatesScreenState();
}

class _TravelDatesScreenState extends State<TravelDatesScreen> {
  DateTime? departureDate;
  DateTime? returnDate;

  Future<void> selectDepartureDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() {
        departureDate = selectedDate;

        if (returnDate != null && returnDate!.isBefore(selectedDate)) {
          returnDate = null;
        }
      });
    }
  }

  Future<void> selectReturnDate() async {
    if (departureDate == null) return;

    final selectedDate = await showDatePicker(
      context: context,
      firstDate: departureDate!,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: departureDate!.add(const Duration(days: 1)),
    );

    if (selectedDate != null) {
      setState(() {
        returnDate = selectedDate;
      });
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Select date';

    return '${date.day}/${date.month}/${date.year}';
  }

  int? get tripDuration {
    if (departureDate == null || returnDate == null) {
      return null;
    }

    return returnDate!.difference(departureDate!).inDays + 1;
  }

  bool get _canContinue => departureDate != null && returnDate != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Travel Dates')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const YatraWizardHeader(
                      step: 1,
                      totalSteps: 4,
                      title: 'When are you travelling?',
                      subtitle: 'Select your departure and return dates.',
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    Text('Departure Date', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    _DateSelectorCard(
                      icon: Icons.flight_takeoff,
                      label: 'Departure',
                      value: formatDate(departureDate),
                      selected: departureDate != null,
                      onTap: selectDepartureDate,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Text('Return Date', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    _DateSelectorCard(
                      icon: Icons.flight_land,
                      label: 'Return',
                      value: formatDate(returnDate),
                      selected: returnDate != null,
                      enabled: departureDate != null,
                      onTap: selectReturnDate,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (tripDuration != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            color: scheme.primary.withValues(alpha: 0.1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_bottom,
                                  size: 20, color: scheme.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Trip Duration: $tripDuration '
                                '${tripDuration == 1 ? 'day' : 'days'}',
                                style: AppType.bodyEmphasis.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
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
        onPressed: _canContinue
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TravelGroupScreen(
                      departureDate: departureDate!,
                      returnDate: returnDate!,
                      package: widget.package,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }
}

class _DateSelectorCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _DateSelectorCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Opacity(
        opacity: 0.5,
        child: _buildContent(
          context,
          selected: false,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: _buildContent(context, selected: selected),
    );
  }

  Widget _buildContent(BuildContext context, {required bool selected}) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppType.bodyEmphasis,
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.chevron_right,
            color: selected ? scheme.primary : scheme.outline,
            size: 24,
          ),
        ],
      ),
    );
  }
}
