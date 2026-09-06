import 'package:flutter/material.dart';

import '../travel_dates/travel_dates_screen.dart';

class TouristTypeScreen extends StatefulWidget {
  const TouristTypeScreen({super.key});

  @override
  State<TouristTypeScreen> createState() => _TouristTypeScreenState();
}

class _TouristTypeScreenState extends State<TouristTypeScreen> {
  String? selectedTouristType;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final bool canContinue = selectedTouristType != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourist Type'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Text(
                'Who are you travelling as?',
                style: textTheme.headlineMedium,
              ),

              const SizedBox(height: 12),

              Text(
                'Choose the option that best describes your trip.',
                style: textTheme.bodyLarge,
              ),

              const SizedBox(height: 32),

              _touristTypeCard(
                context: context,
                title: 'Domestic Tourist',
                description:
                    'I am travelling within Nepal as a domestic tourist.',
                icon: Icons.location_on_outlined,
                value: 'Domestic Tourist',
                scheme: scheme,
              ),

              const SizedBox(height: 16),

              _touristTypeCard(
                context: context,
                title: 'International Tourist',
                description:
                    'I am visiting Nepal from another country.',
                icon: Icons.public,
                value: 'International Tourist',
                scheme: scheme,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canContinue
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TravelDatesScreen(
                                touristType: selectedTouristType!,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _touristTypeCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required String value,
    required ColorScheme scheme,
  }) {
    final bool isSelected = selectedTouristType == value;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          selectedTouristType = value;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 42,
              color: isSelected
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: isSelected
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}