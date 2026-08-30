import 'package:flutter/material.dart';

import '../../services/season_service.dart';
import '../boarding/boarding_screen.dart';

class SeasonAnalysisScreen extends StatelessWidget {
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final String currency;
  final double budget;
  final List<int> ages;
  final String travelType;
  final int groupSize;

  const SeasonAnalysisScreen({
    super.key,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.currency,
    required this.budget,
    required this.ages,
    required this.travelType,
    required this.groupSize,
  });

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final result = SeasonService.analyze(
      destination: destination,
      departureDate: departureDate,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Overview'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Trip',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),

              _InfoItem(
                title: 'Destination',
                value: destination,
              ),

              const SizedBox(height: 15),

              _InfoItem(
                title: 'Travel Dates',
                value:
                    '${formatDate(departureDate)} - '
                    '${formatDate(returnDate)}',
              ),

              const SizedBox(height: 15),

              _InfoItem(
                title: 'Travel Type',
                value: travelType,
              ),

              const SizedBox(height: 15),

              _InfoItem(
                title: 'Travellers',
                value: '$groupSize',
              ),

              const SizedBox(height: 25),

              const Text(
                'Season Advisory',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.season,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      result.suitability,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      result.message,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BoardingScreen(
                          destination: destination,
                          departureDate: departureDate,
                          returnDate: returnDate,
                          season: result.season,
                          suitability: result.suitability,
                          seasonMessage: result.message,
                          currency: currency,
                          budget: budget,
                          ages: ages,
                          travelType: travelType,
                          groupSize: groupSize,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Continue to Boarding',
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

class _InfoItem extends StatelessWidget {
  final String title;
  final String value;

  const _InfoItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}