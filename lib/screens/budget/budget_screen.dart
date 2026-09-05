import 'package:flutter/material.dart';

import '../../models/package_model.dart';
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
  final String travelType;
  final int groupSize;
  final DateTime departureDate;
  final DateTime returnDate;
  final TourPackage? package;

  const BudgetScreen({
    super.key,
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
                      subtitle: 'Enter the total amount you are comfortable '
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
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedCurrency = value;
                          });
                        }
                      },
                    ),
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
                    const SizedBox(height: AppSpacing.xl),

                    InfoBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trip Profile', style: textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.md),
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
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: YatraPrimaryButton(
                label: 'Continue',
                onPressed: !isValidBudget
                    ? null
                    : () {
                        if (widget.package != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SeasonAnalysisScreen(
                                destination: widget.package!.region,
                                departureDate: widget.departureDate,
                                returnDate: widget.returnDate, 
                                currency: selectedCurrency,
                                budget: enteredBudget,
                                ages: widget.ages,
                                travelType: widget.travelType,
                                groupSize: widget.groupSize,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationScreen(
                                currency: selectedCurrency,
                                budget: enteredBudget,
                                ages: widget.ages,
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
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
