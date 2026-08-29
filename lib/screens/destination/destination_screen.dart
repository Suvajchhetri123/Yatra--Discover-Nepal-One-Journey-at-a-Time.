import 'package:flutter/material.dart';

import '../season_analysis/season_analysis_screen.dart';

class DestinationScreen extends StatefulWidget {
  final String currency;
  final double budget;
  final List<int> ages;
  final String travelType;
  final int groupSize;
  final DateTime departureDate;
  final DateTime returnDate;

  const DestinationScreen({
    super.key,
    required this.currency,
    required this.budget,
    required this.ages,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Destination'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Where would you like to go?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose a destination for your journey.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 25),
              const Text(
                'Popular Destinations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: destinations.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.4,
                  ),
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    final isSelected =
                        selectedDestination == destination;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDestination = destination;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          color: isSelected
                              ? Colors.deepPurple.withValues(alpha: 0.05)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            destination,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: selectedDestination == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SeasonAnalysisScreen(
                                destination: selectedDestination!,
                                departureDate: widget.departureDate,
                                returnDate: widget.returnDate,
                                currency: widget.currency,
                                budget: widget.budget,
                                ages: widget.ages,
                                travelType: widget.travelType,
                                groupSize: widget.groupSize,
                              ),
                            ),
                          );
                        },
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