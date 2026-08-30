import 'package:flutter/material.dart';

import '../../models/package_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import '../age/age_screen.dart';

/// Travel Group — wizard step 2 of 4.
///
/// Redesigned on the central Yatra design system. All travel-type selection,
/// group-size counters and their limits are unchanged.
class TravelGroupScreen extends StatefulWidget {
  final DateTime departureDate;
  final DateTime returnDate;
  final TourPackage? package;

  const TravelGroupScreen({
    super.key,
    required this.departureDate,
    required this.returnDate,
    this.package,
  });

  @override
  State<TravelGroupScreen> createState() => _TravelGroupScreenState();
}

class _TravelGroupScreenState extends State<TravelGroupScreen> {
  String? selectedTravelType;
  int adultCount = 1;
  int childCount = 0;

  int get groupSize => adultCount + childCount;

  void selectTravelType(String type) {
    setState(() {
      selectedTravelType = type;

      if (type == 'Solo') {
        adultCount = 1;
        childCount = 0;
      } else {
        adultCount = 2;
        childCount = 0;
      }
    });
  }

  void continueToAgeScreen() {
    if (selectedTravelType == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgeScreen(
          travelType: selectedTravelType!,
          adultCount: adultCount,
          childCount: childCount,
          departureDate: widget.departureDate,
          returnDate: widget.returnDate,
          package: widget.package,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Travel Group')),
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
                      step: 2,
                      totalSteps: 4,
                      title: 'How are you travelling?',
                      subtitle: 'Tell us who you are travelling with.',
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    YatraSelectionCard(
                      selected: selectedTravelType == 'Solo',
                      leadingIcon: Icons.person,
                      onTap: () => selectTravelType('Solo'),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Solo', style: AppType.bodyEmphasis),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'I am travelling alone',
                            style: AppType.body,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    YatraSelectionCard(
                      selected: selectedTravelType == 'Group',
                      leadingIcon: Icons.groups,
                      onTap: () => selectTravelType('Group'),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Group', style: AppType.bodyEmphasis),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'I am travelling with others',
                            style: AppType.body,
                          ),
                        ],
                      ),
                    ),

                    if (selectedTravelType == 'Group') ...[
                      const SizedBox(height: AppSpacing.xxl),
                      Text('Who is travelling?', style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      _TravellerCounter(
                        label: 'Adults',
                        subtitle: '18 years and above',
                        value: adultCount,
                        onRemove: adultCount > 1
                            ? () => setState(() => adultCount--)
                            : null,
                        onAdd: groupSize < 20
                            ? () => setState(() => adultCount++)
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _TravellerCounter(
                        label: 'Children',
                        subtitle: 'Under 18 years',
                        value: childCount,
                        onRemove: childCount > 0
                            ? () => setState(() => childCount--)
                            : null,
                        onAdd: groupSize < 20
                            ? () => setState(() => childCount++)
                            : null,
                      ),
                    ],
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
                onPressed:
                    selectedTravelType == null ? null : continueToAgeScreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravellerCounter extends StatelessWidget {
  final String label;
  final String subtitle;
  final int value;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;

  const _TravellerCounter({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return YatraCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.bodyEmphasis),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          _CounterButton(
            icon: Icons.remove,
            onPressed: onRemove,
            enabled: onRemove != null,
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppType.label.copyWith(fontSize: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _CounterButton(
            icon: Icons.add,
            onPressed: onAdd,
            enabled: onAdd != null,
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  const _CounterButton({
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: enabled
          ? scheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? scheme.primary : scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
