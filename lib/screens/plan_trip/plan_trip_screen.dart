import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../travel_dates/travel_dates_screen.dart';

class PlanTripScreen extends StatelessWidget {
  const PlanTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan Your Trip')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              Text("Let's plan your journey", style: textTheme.headlineMedium),

              const SizedBox(height: 12),

              Text(
                "We'll help you create a personalized travel plan for Nepal.",
                style: textTheme.bodyLarge,
              ),

              const SizedBox(height: 40),

              InfoBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.travel_explore, size: 42, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text('Personalized Travel Planning',
                        style: textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Text(
                      'Tell us about your journey, preferences, '
                      'budget and travel style. Yatra will then '
                      'recommend a suitable destination and travel plan.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TravelDatesScreen(),
                    ),
                  );
                },
                child: const Text('Start Planning'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
