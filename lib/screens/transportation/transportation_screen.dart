import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../data/transportation_data.dart';
import '../../models/transportation_option_model.dart';
import '../../widgets/yatra_components.dart';
import '../boarding/boarding_screen.dart';

class TransportationScreen extends StatefulWidget {
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final String season;
  final String suitability;
  final String seasonMessage;
  final String currency;
  final double budget;
  final List<int> ages;
  final String travelType;
  final int groupSize;

  const TransportationScreen({
    super.key,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.season,
    required this.suitability,
    required this.seasonMessage,
    required this.currency,
    required this.budget,
    required this.ages,
    required this.travelType,
    required this.groupSize,
  });

  @override
  State<TransportationScreen> createState() => _TransportationScreenState();
}

class _TransportationScreenState extends State<TransportationScreen> {
  String? selectedTransportation;

  List<TransportationOption> get options {
    return transportOptionsFor(widget.destination);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Transportation'), centerTitle: true),
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
                    Text('Transportation', style: textTheme.headlineMedium),

                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      'Choose from the transportation options available '
                      'for your selected destination to plan your journey.',
                      style: textTheme.bodyLarge,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ============================================
                    // DESTINATION CONTEXT
                    // ============================================
                    YatraCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Destination', style: AppType.caption),
                                Text(
                                  widget.destination,
                                  style: textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    YatraSectionTitle(
                      title: 'Available Options',
                      subtitle: 'Tap an option to record your selection.',
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ============================================
                    // EMPTY STATE
                    // ============================================
                    if (options.isEmpty)
                      const YatraEmptyState(
                        icon: Icons.directions_bus_outlined,
                        message:
                            'No transportation options are available '
                            'for this destination yet.',
                      ),

                    // ============================================
                    // OPTIONS
                    // ============================================
                    ...options.map((option) {
                      final name = option.name;
                      final selected = selectedTransportation == name;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _TransportOptionCard(
                          option: option,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              selectedTransportation = name;
                            });
                          },
                        ),
                      );
                    }),
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
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: YatraPrimaryButton(
                  label: 'Continue to Boarding',
                  icon: Icons.arrow_forward,
                  onPressed: selectedTransportation == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BoardingScreen(
                                destination: widget.destination,
                                selectedTransport: selectedTransportation,
                                departureDate: widget.departureDate,
                                returnDate: widget.returnDate,
                                season: widget.season,
                                suitability: widget.suitability,
                                currency: widget.currency,
                                budget: widget.budget,
                                ages: widget.ages,
                                travelType: widget.travelType,
                                groupSize: widget.groupSize,
                                seasonMessage: widget.seasonMessage,
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
// TRANSPORT OPTION CARD
// ============================================================

class _TransportOptionCard extends StatelessWidget {
  final TransportationOption option;
  final bool selected;
  final VoidCallback onTap;

  const _TransportOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? scheme.primary.withValues(alpha: 0.06)
                : AppColors.surface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: selected
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  option.icon,
                  color: selected ? Colors.white : scheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            option.name,
                            style: selected
                                ? textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  )
                                : textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        YatraStatusBadge(
                          label: 'Available',
                          color: AppColors.success,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    Text(
                      option.description,
                      style: textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    Text(
                      option.details,
                      style: AppType.caption.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
