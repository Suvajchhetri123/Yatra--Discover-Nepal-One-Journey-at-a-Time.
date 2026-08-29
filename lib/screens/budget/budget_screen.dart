import 'package:flutter/material.dart';

import '../../models/package_model.dart';

import '../destination/destination_screen.dart';

import '../season_analysis/season_analysis_screen.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Travel Budget'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What is your travel budget?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                'Enter the total amount you are comfortable '
                'spending on this trip.',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),

              const SizedBox(height: 30),

              const Text(
                'Currency',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
                decoration: const InputDecoration(border: OutlineInputBorder()),
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
                  DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
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

              const SizedBox(height: 25),

              const Text(
                'Total Budget',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: '$selectedCurrency ',
                  hintText: 'Enter your total budget',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),

              const SizedBox(height: 25),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trip Profile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      widget.travelType == 'Solo'
                          ? 'Age: ${_ageText()}'
                          : 'Traveller ages: ${_ageText()}',
                    ),

                    Text('Travel type: ${widget.travelType}'),

                    Text('Travellers: ${widget.groupSize}'),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: !isValidBudget
                      ? null
                      : () {
                          if (widget.package != null) {
                            // Package booking:
                            // Skip DestinationScreen because the
                            // destination is already known.
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
                            // Custom trip:
                            // Continue to DestinationScreen.
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
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
