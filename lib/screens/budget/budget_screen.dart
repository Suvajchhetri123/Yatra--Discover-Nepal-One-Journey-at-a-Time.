import 'package:flutter/material.dart';

import '../../models/package_model.dart';
import '../../models/travel_route_model.dart';
import '../../services/trip_cost_estimator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/yatra_components.dart';
import '../destination/destination_screen.dart';
import '../season_analysis/season_analysis_screen.dart';

/// Travel Budget — wizard step 4 of 4.
///
/// Redesigned on the central Yatra design system. Currency selection, budget
/// validation, trip profile and both continue branches are unchanged.
class BudgetScreen extends StatefulWidget {
  final List<int> ages;
  final int adultCount;
  final int childCount;
  final String touristType;
  final String travelType;
  final int groupSize;
  final DateTime departureDate;
  final DateTime returnDate;
  final TourPackage? package;

  const BudgetScreen({
    super.key,
    required this.touristType,
    required this.adultCount,
    required this.childCount,
    required this.ages,
    required this.travelType,
    required this.groupSize,
    required this.departureDate,
    required this.returnDate,
    this.package,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final TextEditingController budgetController = TextEditingController();

  String selectedCurrency = 'NPR';

  @override
  void dispose() {
    budgetController.dispose();
    super.dispose();
  }

  // ============================================================
  // GUARDS
  // ============================================================

  /// Domestic/Nepalese travellers always plan and pay in NPR.
  bool get _isDomestic {
    return widget.touristType.toLowerCase().contains('domestic');
  }

  int get _tripDuration {
    final days = widget.returnDate.difference(widget.departureDate).inDays + 1;
    return days > 0 ? days : 1;
  }

  /// For the package flow this builds the estimated total trip cost used by
  /// the gate that blocks continue until the budget fits the estimate.
  TripCostEstimate? _packageEstimate(double? enteredBudget) {
    final package = widget.package;

    if (package == null || enteredBudget == null || enteredBudget <= 0) {
      return null;
    }

    return TripCostEstimator.estimate(
      touristType: widget.touristType,
      destination: package.region,
      durationDays: _tripDuration,
      adultCount: widget.adultCount,
      childCount: widget.childCount,
      childAges: TripCostEstimator.childAgesFrom(
        ages: widget.ages,
        adultCount: widget.adultCount,
        childCount: widget.childCount,
      ),
      route: TravelRoute(
        boardingPoint: package.region,
        destination: package.region,
        segments: const [],
      ),
      package: package,
    );
  }

  BudgetVerdict? _packageVerdictCache(double? enteredBudget) {
    final estimate = _packageEstimate(enteredBudget);

    if (estimate == null || enteredBudget == null) {
      return null;
    }

    final budgetNpr = TripCostEstimator.toNpr(enteredBudget, selectedCurrency);

    return TripCostEstimator.evaluateBudget(
      budgetNpr: budgetNpr,
      estimate: estimate,
    );
  }

  String _ageText() {
    if (widget.ages.isEmpty) {
      return 'Not provided';
    }

    if (widget.travelType == 'Solo') {
      return '${widget.ages.first} years';
    }

    return widget.ages.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final enteredBudget = double.tryParse(budgetController.text.trim());

    final isValidBudget = enteredBudget != null && enteredBudget > 0;

    final packageVerdict = _packageVerdictCache(enteredBudget);

    // The package flow blocks continue until the budget fits the estimate.
    // The custom (destination) flow validates the budget on the next screen.
    final budgetPasses =
        widget.package == null ||
        packageVerdict == null ||
        packageVerdict == BudgetVerdict.suitable ||
        packageVerdict == BudgetVerdict.excessive;

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Travel Budget')),
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
                      step: 4,
                      totalSteps: 4,
                      title: 'What is your travel budget?',
                      subtitle:
                          'Enter the total amount you are comfortable '
                          'spending on this trip.',
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    Text('Currency', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCurrency,
                      items: const [
                        DropdownMenuItem(
                          value: 'NPR',
                          child: Text('NPR - Nepalese Rupee'),
                        ),
                        DropdownMenuItem(
                          value: 'USD',
                          child: Text('USD - US Dollar'),
                        ),
                        DropdownMenuItem(
                          value: 'INR',
                          child: Text('INR - Indian Rupee'),
                        ),
                        DropdownMenuItem(
                          value: 'EUR',
                          child: Text('EUR - Euro'),
                        ),
                        DropdownMenuItem(
                          value: 'GBP',
                          child: Text('GBP - British Pound'),
                        ),
                      ],
                      onChanged: _isDomestic
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  selectedCurrency = value;
                                });
                              }
                            },
                    ),
                    if (_isDomestic) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Domestic tourists plan and pay in NPR.',
                        style: AppType.caption,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),

                    Text('Total Budget', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        prefixText: '$selectedCurrency ',
                        hintText: 'Enter your total budget',
                        suffixIcon: isValidBudget
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        errorText: budgetController.text.trim().isEmpty
                            ? null
                            : (isValidBudget
                                  ? null
                                  : 'Enter a valid budget amount'),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),

                    // ==========================================
                    // PACKAGE FLOW BUDGET CHECK
                    // ==========================================
                    if (widget.package != null &&
                        isValidBudget &&
                        packageVerdict != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _BudgetGateInfoBox(
                        verdict: packageVerdict,
                        package: widget.package!,
                        estimate: _packageEstimate(enteredBudget)!,
                        budget: enteredBudget,
                        currency: selectedCurrency,
                        touristType: widget.touristType,
                        adultCount: widget.adultCount,
                        childCount: widget.childCount,
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    InfoBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trip Profile', style: textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.md),
                          _ProfileRow(
                            label: 'Tourist type',
                            value: widget.touristType,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ProfileRow(
                            label: widget.travelType == 'Solo'
                                ? 'Age'
                                : 'Traveller ages',
                            value: _ageText(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ProfileRow(
                            label: 'Travel type',
                            value: widget.travelType,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ProfileRow(
                            label: 'Travellers',
                            value: '${widget.groupSize}',
                          ),
                        ],
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
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: YatraPrimaryButton(
                label: 'Continue',
                onPressed: !isValidBudget || !budgetPasses
                    ? null
                    : () {
                        if (widget.package != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SeasonAnalysisScreen(
                                touristType: widget.touristType,
                                destination: widget.package!.region,
                                departureDate: widget.departureDate,
                                returnDate: widget.returnDate,
                                currency: selectedCurrency,
                                budget: enteredBudget,
                                ages: widget.ages,
                                adultCount: widget.adultCount,
                                childCount: widget.childCount,
                                travelType: widget.travelType,
                                groupSize: widget.groupSize,
                                package: widget.package,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationScreen(
                                touristType: widget.touristType,
                                currency: selectedCurrency,
                                budget: enteredBudget,
                                ages: widget.ages,
                                adultCount: widget.adultCount,
                                childCount: widget.childCount,
                                travelType: widget.travelType,
                                groupSize: widget.groupSize,
                                departureDate: widget.departureDate,
                                returnDate: widget.returnDate,
                              ),
                            ),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppType.bodyEmphasis,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PACKAGE FLOW BUDGET GATE
// ============================================================

class _BudgetGateInfoBox extends StatelessWidget {
  final BudgetVerdict verdict;
  final TourPackage package;
  final TripCostEstimate estimate;
  final double budget;
  final String currency;
  final String touristType;
  final int adultCount;
  final int childCount;

  const _BudgetGateInfoBox({
    required this.verdict,
    required this.package,
    required this.estimate,
    required this.budget,
    required this.currency,
    required this.touristType,
    required this.adultCount,
    required this.childCount,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isInsufficient = verdict == BudgetVerdict.insufficient;
    final accent = isInsufficient ? AppColors.danger : AppColors.success;

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
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInsufficient
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                color: accent,
              ),
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
            'Estimated total for ${package.title}: '
            '${TripCostEstimator.formatNprAmount(estimate.total)} '
            '(package NPR ${package.priceFor(touristType).toStringAsFixed(0)} + '
            'transport + activities).',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
