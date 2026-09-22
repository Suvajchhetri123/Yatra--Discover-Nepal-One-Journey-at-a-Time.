import 'package:flutter/material.dart';

import '../../models/travel_route_model.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import '../season_analysis/season_analysis_screen.dart';

class DestinationScreen extends StatefulWidget {
  final String touristType;
  final String currency;
  final double budget;
  final List<int> ages;
  final int adultCount;
  final int childCount;
  final String travelType;
  final int groupSize;
  final DateTime departureDate;
  final DateTime returnDate;

  const DestinationScreen({
    super.key,
    required this.touristType,
    required this.currency,
    required this.budget,
    required this.ages,
    required this.adultCount,
    required this.childCount,
    required this.travelType,
    required this.groupSize,
    required this.departureDate,
    required this.returnDate,
  });

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  String? selectedDestination;

  final List<String> destinations = [
    'Kathmandu',
    'Pokhara',
    'Chitwan',
    'Mustang',
    'Everest',
    'Annapurna',
  ];

  // ============================================================
  // BUDGET GATE
  // ============================================================

  int get _tripDuration {
    final days = widget.returnDate.difference(widget.departureDate).inDays + 1;
    return days > 0 ? days : 1;
  }

  TripCostEstimate? get _selectedEstimate {
    final destination = selectedDestination;

    if (destination == null) {
      return null;
    }

    return TripCostEstimator.estimate(
      touristType: widget.touristType,
      destination: destination,
      durationDays: _tripDuration,
      adultCount: widget.adultCount,
      childCount: widget.childCount,
      childAges: TripCostEstimator.childAgesFrom(
        ages: widget.ages,
        adultCount: widget.adultCount,
        childCount: widget.childCount,
      ),
      route: TravelRoute(
        boardingPoint: destination,
        destination: destination,
        segments: const [],
      ),
    );
  }

  BudgetVerdict? get _budgetVerdict {
    final estimate = _selectedEstimate;

    if (estimate == null) {
      return null;
    }

    final budgetNpr = TripCostEstimator.toNpr(widget.budget, widget.currency);

    return TripCostEstimator.evaluateBudget(
      budgetNpr: budgetNpr,
      estimate: estimate,
    );
  }

  bool get _budgetPasses {
    final verdict = _budgetVerdict;

    return verdict == null ||
        verdict == BudgetVerdict.suitable ||
        verdict == BudgetVerdict.excessive;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Destination')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ============================================
                    // HEADER
                    // ============================================
                    Text(
                      'Choose Your Destination',
                      style: textTheme.headlineMedium,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      'Where would you like to journey in Nepal? '
                      'Pick a destination and we\'ll tailor the rest '
                      'of your trip around it.',
                      style: textTheme.bodyLarge,
                    ),

                    if (destinations.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),

                      YatraSectionTitle(
                        title: 'Popular Destinations',
                        subtitle: 'Tap a destination to select it.',
                      ),
                    ],

                    const SizedBox(height: AppSpacing.md),

                    if (destinations.isEmpty)
                      const YatraEmptyState(
                        icon: Icons.place_outlined,
                        message: 'No destinations available yet.',
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth > 600 ? 3 : 2;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: destinations.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: AppSpacing.md,
                                  mainAxisSpacing: AppSpacing.md,
                                  childAspectRatio: 1.55,
                                ),
                            itemBuilder: (context, index) {
                              final destination = destinations[index];
                              final isSelected =
                                  selectedDestination == destination;

                              return YatraSelectionCard(
                                selected: isSelected,
                                leadingIcon: Icons.place_outlined,
                                onTap: () {
                                  setState(() {
                                    selectedDestination = destination;
                                  });
                                },
                                child: Text(
                                  destination,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: isSelected
                                      ? Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        )
                                      : textTheme.titleMedium,
                                ),
                              );
                            },
                          );
                        },
                      ),

                    if (selectedDestination != null &&
                        _budgetVerdict != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _BudgetStatusCard(
                        verdict: _budgetVerdict!,
                        estimate: _selectedEstimate!,
                        budget: widget.budget,
                        currency: widget.currency,
                        adultCount: widget.adultCount,
                        childCount: widget.childCount,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ============================================
            // BOTTOM CTA
            // ============================================
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: YatraPrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: selectedDestination == null || !_budgetPasses
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SeasonAnalysisScreen(
                                touristType: widget.touristType,
                                destination: selectedDestination!,
                                departureDate: widget.departureDate,
                                returnDate: widget.returnDate,
                                currency: widget.currency,
                                budget: widget.budget,
                                ages: widget.ages,
                                adultCount: widget.adultCount,
                                childCount: widget.childCount,
                                travelType: widget.travelType,
                                groupSize: widget.groupSize,
                              ),
                            ),
                          );
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BUDGET STATUS CARD
// ============================================================

class _BudgetStatusCard extends StatelessWidget {
  final BudgetVerdict verdict;
  final TripCostEstimate estimate;
  final double budget;
  final String currency;
  final int adultCount;
  final int childCount;

  const _BudgetStatusCard({
    required this.verdict,
    required this.estimate,
    required this.budget,
    required this.currency,
    required this.adultCount,
    required this.childCount,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isInsufficient = verdict == BudgetVerdict.insufficient;
    final accent = isInsufficient ? AppColors.danger : AppColors.success;
    final icon = isInsufficient
        ? Icons.warning_amber_rounded
        : Icons.check_circle;

    final budgetNpr = TripCostEstimator.toNpr(budget, currency);

    final message = TripCostEstimator.verdictMessage(
      verdict: verdict,
      budgetNpr: budgetNpr,
      estimate: estimate,
      currency: currency,
      adultCount: adultCount,
      childCount: childCount,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  TripCostEstimator.verdictTitle(verdict),
                  style: textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Estimated total for this trip: '
            '${TripCostEstimator.formatNprAmount(estimate.total)}.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: textTheme.bodyMedium?.copyWith(height: 1.5)),
          if (isInsufficient) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Increase the budget above or choose a shorter trip.',
              style: textTheme.bodySmall?.copyWith(color: accent),
            ),
          ],
        ],
      ),
    );
  }
}
