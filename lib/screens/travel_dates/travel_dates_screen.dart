import 'package:flutter/material.dart';

import '../../models/package_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import '../travel_group/travel_group_screen.dart';

/// Travel Dates — wizard step 1 of 4.
///
/// Both Custom Trips and Popular Packages:
///   - User selects departure date manually.
///   - User selects return date manually.
///   - Trip duration is calculated from the selected dates.
///
/// Popular packages:
///   - package.durationDays represents the package's designed/recommended
///     duration.
///   - It does NOT automatically set the user's return date.
///   - The user is free to choose a different trip duration.
class TravelDatesScreen extends StatefulWidget {
  final TourPackage? package;

  const TravelDatesScreen({
    super.key,
    this.package,
  });

  @override
  State<TravelDatesScreen> createState() => _TravelDatesScreenState();
}

class _TravelDatesScreenState extends State<TravelDatesScreen> {
  DateTime? departureDate;
  DateTime? returnDate;

  // ============================================================
  // DATE LIMITS
  // ============================================================

  DateTime get _today {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  DateTime get _lastAllowedDate {
    return _today.add(
      const Duration(days: 730),
    );
  }

  // ============================================================
  // DEPARTURE DATE
  // ============================================================

  Future<void> selectDepartureDate() async {
    final DateTime today = _today;

    final DateTime initialDate =
        departureDate != null ? departureDate! : today;

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: _lastAllowedDate,
      initialDate: initialDate,
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      departureDate = selectedDate;

      // If the user changes the departure date and the existing
      // return date is now before the new departure date,
      // clear the return date.
      if (returnDate != null &&
          returnDate!.isBefore(selectedDate)) {
        returnDate = null;
      }
    });
  }

  // ============================================================
  // RETURN DATE
  // ============================================================

  Future<void> selectReturnDate() async {
    // User must select departure first.
    if (departureDate == null) {
      return;
    }

    final DateTime firstAllowedDate = departureDate!;

    DateTime initialDate;

    // If a return date already exists and is valid,
    // use it when reopening the picker.
    if (returnDate != null &&
        !returnDate!.isBefore(firstAllowedDate)) {
      initialDate = returnDate!;
    } else {
      // Default to the day after departure.
      initialDate = departureDate!.add(
        const Duration(days: 1),
      );
    }

    // Make sure the initial date does not exceed
    // the maximum allowed date.
    if (initialDate.isAfter(_lastAllowedDate)) {
      initialDate = _lastAllowedDate;
    }

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      firstDate: firstAllowedDate,
      lastDate: _lastAllowedDate,
      initialDate: initialDate,
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      returnDate = selectedDate;
    });
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  // ============================================================
  // TRIP DURATION
  // ============================================================

  int? get tripDuration {
    if (departureDate == null || returnDate == null) {
      return null;
    }

    return returnDate!.difference(departureDate!).inDays + 1;
  }

  // ============================================================
  // CONTINUE VALIDATION
  // ============================================================

  bool get _canContinue {
    return departureDate != null &&
        returnDate != null &&
        !returnDate!.isBefore(departureDate!);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme =
        Theme.of(context).colorScheme;

    final TextTheme textTheme =
        Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Dates'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(
                  AppSpacing.screen,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    const YatraWizardHeader(
                      step: 1,
                      totalSteps: 4,
                      title: 'When are you travelling?',
                      subtitle:
                          'Select your departure and return dates.',
                    ),

                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),

                    // ==================================================
                    // DEPARTURE DATE
                    // ==================================================

                    Text(
                      'Departure Date',
                      style: textTheme.titleLarge,
                    ),

                    const SizedBox(
                      height: AppSpacing.md,
                    ),

                    _DateSelectorCard(
                      icon: Icons.flight_takeoff,
                      label: 'Departure',
                      value: formatDate(departureDate),
                      selected: departureDate != null,
                      enabled: true,
                      onTap: selectDepartureDate,
                    ),

                    const SizedBox(
                      height: AppSpacing.xl,
                    ),

                    // ==================================================
                    // RETURN DATE
                    // ==================================================

                    Text(
                      'Return Date',
                      style: textTheme.titleLarge,
                    ),

                    const SizedBox(
                      height: AppSpacing.md,
                    ),

                    _DateSelectorCard(
                      icon: Icons.flight_land,
                      label: 'Return',
                      value: formatDate(returnDate),
                      selected: returnDate != null,
                      enabled: departureDate != null,
                      onTap: selectReturnDate,
                    ),

                    const SizedBox(
                      height: AppSpacing.xl,
                    ),

                    // ==================================================
                    // TRIP DURATION
                    // ==================================================

                    if (tripDuration != null)
                      Center(
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(
                              AppRadius.md,
                            ),
                            color: scheme.primary
                                .withValues(alpha: 0.1),
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_bottom,
                                size: 20,
                                color: scheme.primary,
                              ),
                              const SizedBox(
                                width: AppSpacing.sm,
                              ),
                              Text(
                                'Trip Duration: '
                                '$tripDuration '
                                '${tripDuration == 1 ? 'day' : 'days'}',
                                style:
                                    AppType.bodyEmphasis
                                        .copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ==================================================
                    // RETURN DATE HELPER
                    // ==================================================

                    if (departureDate != null &&
                        returnDate == null)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top: AppSpacing.md,
                        ),
                        child: Center(
                          child: Text(
                            'Now select your return date.',
                            style: textTheme.bodyMedium
                                ?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ========================================================
            // BOTTOM BAR
            // ========================================================

            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
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
                    builder: (context) =>
                        TravelGroupScreen(
                      departureDate:
                          departureDate!,
                      returnDate:
                          returnDate!,
                      package:
                          widget.package,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }
}

// ================================================================
// DATE SELECTOR CARD
// ================================================================

class _DateSelectorCard
    extends StatelessWidget {
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
      borderRadius:
          BorderRadius.circular(
        AppRadius.lg,
      ),
      child: _buildContent(
        context,
        selected: selected,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool selected,
  }) {
    final ColorScheme scheme =
        Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 180),
      width: double.infinity,
      padding:
          const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary
                .withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          AppRadius.lg,
        ),
        border: Border.all(
          color: selected
              ? scheme.primary
              : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // ========================================================
          // ICON
          // ========================================================

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary
                  .withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(
                AppRadius.md,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: scheme.primary,
              size: 22,
            ),
          ),

          const SizedBox(
            width: AppSpacing.md,
          ),

          // ========================================================
          // TEXT
          // ========================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppType.bodyEmphasis,
                ),
              ],
            ),
          ),

          // ========================================================
          // TRAILING ICON
          // ========================================================

          Icon(
            selected
                ? Icons.check_circle
                : Icons.chevron_right,
            color: selected
                ? scheme.primary
                : scheme.outline,
            size: 24,
          ),
        ],
      ),
    );
  }
}