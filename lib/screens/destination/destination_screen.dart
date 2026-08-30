import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
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
                          final columns =
                              constraints.maxWidth > 600 ? 3 : 2;
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
                                      ? Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
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
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: YatraPrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: selectedDestination == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SeasonAnalysisScreen(
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
