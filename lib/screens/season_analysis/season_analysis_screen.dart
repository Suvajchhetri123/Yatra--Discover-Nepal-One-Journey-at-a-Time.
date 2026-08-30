import 'package:flutter/material.dart';

import '../../data/packages_data.dart';
import '../../services/season_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import '../transportation/transportation_screen.dart';

/// Trip Overview / Season Analysis — the user's final review before the route
/// builder.
///
/// Redesigned on the central Yatra design system. All season calculation,
/// suitability result, constructor parameters and navigation are unchanged.
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

  int get _tripDuration =>
      returnDate.difference(departureDate).inDays + 1;

  /// Reuses an existing package image for this destination region, if any.
  /// Returns null when no reference image exists (hero falls back to a
  /// branded gradient placeholder).
  String? _imageForDestination() {
    for (final package in tourPackages) {
      if (package.region == destination) {
        return package.imageUrl;
      }
    }
    return null;
  }

  String _packageTitleForDestination() {
    for (final package in tourPackages) {
      if (package.region == destination) {
        return package.title;
      }
    }
    return '';
  }

  String get _ageText {
    if (ages.isEmpty) return '—';
    if (travelType == 'Solo') return '${ages.first} years';
    return ages.join(', ');
  }

  String _formatAmount(double amount) {
    final digits = amount.toStringAsFixed(0);
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final result = SeasonService.analyze(
      destination: destination,
      departureDate: departureDate,
    );

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Overview')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Trip Overview',
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Yatra has prepared your trip based on your '
                      'selections. Review it before building your route.',
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _DestinationHero(
                      destination: destination,
                      packageTitle: _packageTitleForDestination(),
                      imageUrl: _imageForDestination(),
                      season: result.season,
                      suitability: result.suitability,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    const YatraSectionTitle(title: 'Trip Summary'),
                    const SizedBox(height: AppSpacing.md),
                    YatraCard(
                      child: Column(
                        children: [
                          YatraInfoRow(
                            label: 'Destination',
                            value: destination,
                            emphasized: true,
                          ),
                          YatraInfoRow(
                            label: 'Travel dates',
                            value:
                                '${formatDate(departureDate)} – '
                                '${formatDate(returnDate)}',
                          ),
                          YatraInfoRow(
                            label: 'Trip duration',
                            value: '$_tripDuration '
                                '${_tripDuration == 1 ? 'day' : 'days'}',
                          ),
                          YatraInfoRow(
                            label: 'Travel type',
                            value: travelType,
                          ),
                          YatraInfoRow(
                            label: 'Travellers',
                            value: '$groupSize',
                          ),
                          YatraInfoRow(
                            label: 'Ages',
                            value: _ageText,
                          ),
                          YatraInfoRow(
                            label: 'Budget',
                            value: '$currency ${_formatAmount(budget)}',
                            emphasized: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    const YatraSectionTitle(title: 'Season Analysis'),
                    const SizedBox(height: AppSpacing.md),
                    _SeasonCard(result: result),
                    const SizedBox(height: AppSpacing.lg),
                    _SeasonAdvisory(result: result),
                    const SizedBox(height: AppSpacing.xxl),

                    const YatraSectionTitle(title: 'Trip Profile'),
                    const SizedBox(height: AppSpacing.md),
                    _TripProfileGrid(
                      departureDate: departureDate,
                      returnDate: returnDate,
                      groupSize: groupSize,
                      travelType: travelType,
                      budget: budget,
                      currency: currency,
                      season: result.season,
                      scheme: scheme,
                      textTheme: textTheme,
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
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: YatraPrimaryButton(
                label: 'Continue to Transportation',
                icon: Icons.arrow_forward,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransportationScreen(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// DESTINATION HERO
// ==================================================

class _DestinationHero extends StatelessWidget {
  final String destination;
  final String packageTitle;
  final String? imageUrl;
  final String season;
  final String suitability;

  const _DestinationHero({
    required this.destination,
    required this.packageTitle,
    required this.imageUrl,
    required this.season,
    required this.suitability,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.asset(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(scheme),
              )
            else
              _placeholder(scheme),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (packageTitle.isNotEmpty)
                    Text(
                      packageTitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    destination,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  YatraStatusBadge(
                    label: '$season · $suitability',
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.primary],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.landscape, color: scheme.onPrimary, size: 56),
    );
  }
}

// ==================================================
// SEASON STATUS + ADVISORY
// ==================================================

class _SeasonCard extends StatelessWidget {
  final SeasonResult result;

  const _SeasonCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = _suitabilityColor(result.suitability);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _suitabilityIcon(result.suitability),
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.season} Season',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  result.suitability,
                  style: AppType.label.copyWith(
                    fontSize: 20,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _suitabilityColor(String suitability) {
    switch (suitability) {
      case 'Highly Suitable':
        return AppColors.success;
      case 'Suitable':
        return AppColors.primary;
      case 'Moderately Suitable':
        return AppColors.warning;
      case 'Less Suitable':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  IconData _suitabilityIcon(String suitability) {
    switch (suitability) {
      case 'Highly Suitable':
        return Icons.verified;
      case 'Suitable':
        return Icons.check_circle;
      case 'Moderately Suitable':
        return Icons.thumbs_up_down;
      case 'Less Suitable':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }
}

class _SeasonAdvisory extends StatelessWidget {
  final SeasonResult result;

  const _SeasonAdvisory({required this.result});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lessSuitable =
        result.suitability == 'Less Suitable' ||
        result.suitability == 'Moderately Suitable';
    final accent = lessSuitable ? AppColors.warning : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: accent.withValues(alpha: lessSuitable ? 0.5 : 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            lessSuitable ? Icons.info_outline : Icons.tips_and_updates_outlined,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Season Advisory', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  result.message,
                  style: textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// TRIP PROFILE GRID
// ==================================================

class _TripProfileGrid extends StatelessWidget {
  final DateTime departureDate;
  final DateTime returnDate;
  final int groupSize;
  final String travelType;
  final double budget;
  final String currency;
  final String season;
  final ColorScheme scheme;
  final TextTheme textTheme;

  const _TripProfileGrid({
    required this.departureDate,
    required this.returnDate,
    required this.groupSize,
    required this.travelType,
    required this.budget,
    required this.currency,
    required this.season,
    required this.scheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${departureDate.day}/${departureDate.month} – '
        '${returnDate.day}/${returnDate.month}/${returnDate.year}';

    final budgetText = '$currency ${budget.toStringAsFixed(0)}';

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.9,
      ),
      children: [
        _ProfileTile(icon: Icons.calendar_month, value: dateRange, label: 'Dates'),
        _ProfileTile(
          icon: Icons.groups,
          value: '$groupSize ${groupSize == 1 ? 'traveller' : 'travellers'}',
          label: 'Travelers',
        ),
        _ProfileTile(
          icon: Icons.luggage,
          value: travelType,
          label: 'Travel Type',
        ),
        _ProfileTile(icon: Icons.payments, value: budgetText, label: 'Budget'),
        _ProfileTile(
          icon: Icons.landscape_outlined,
          value: season,
          label: 'Season',
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ProfileTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyEmphasis.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
