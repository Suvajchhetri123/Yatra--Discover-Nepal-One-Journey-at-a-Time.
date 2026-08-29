import 'package:flutter/material.dart';

import '../../models/package_model.dart';
import '../budget/budget_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveller Ages'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSolo
                    ? 'How old are you?'
                    : 'How old are the travellers?',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                isSolo
                    ? 'Your age helps Yatra suggest a suitable '
                        'travel pace and experience.'
                    : 'The ages of all travellers help Yatra '
                        'calculate a suitable travel pace and duration '
                        'for the whole group.',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 25),

              Expanded(
                child: ListView.builder(
                  itemCount: ageControllers.length,
                  itemBuilder: (context, index) {
                    final controller = ageControllers[index];

                    final enteredAge =
                        int.tryParse(controller.text.trim());

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSolo
                                ? 'Your Age'
                                : index < widget.adultCount
                                    ? 'Adult ${index + 1}'
                                    : 'Child ${index - widget.adultCount + 1}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            decoration: InputDecoration(
                              hintText: index < widget.adultCount
                                  ? 'Enter adult age'
                                  : 'Enter child age',
                              border: const OutlineInputBorder(),
                              suffixText: 'years',
                            ),
                            onChanged: (_) {
                              setState(() {});
                            },
                          ),

                          if (enteredAge != null &&
                              _isValidAge(controller.text, index))
                            Text(
                              'Age group: ${getAgeCategory(enteredAge)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _allAgesValid ? _continue : null,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
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