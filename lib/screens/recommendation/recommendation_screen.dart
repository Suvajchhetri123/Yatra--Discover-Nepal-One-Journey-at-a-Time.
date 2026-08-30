import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../services/recommendation_service.dart';
import '../../data/places_data.dart';
import '../../widgets/yatra_components.dart';
import '../place_details/place_details_screen.dart';
import '../../models/place_model.dart';
import '../../models/travel_route_model.dart';

class RecommendationScreen extends StatelessWidget {
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final String season;
  final String suitability;
  final String currency;
  final double budget;
  final List<int> ages;
  final String travelType;
  final int groupSize;
  final String seasonMessage;
  final TravelRoute route;

  const RecommendationScreen({
    super.key,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.season,
    required this.suitability,
    required this.currency,
    required this.budget,
    required this.ages,
    required this.travelType,
    required this.groupSize,
    required this.seasonMessage,
    required this.route,
  });

  static const _days = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime date) {
    final weekday = _days[date.weekday - 1];
    final month = _months[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final duration = returnDate.difference(departureDate).inDays + 1;

    final recommendation = RecommendationService.generate(
      destination: destination,
      season: season,
      suitability: suitability,
      budget: budget,
      currency: currency,
      ages: ages,
      travelType: travelType,
      groupSize: groupSize,
      duration: duration,
      route: route,
    );

    final ageDisplay = travelType == 'Solo'
        ? '${ages.isNotEmpty ? ages.first : 18} years'
        : ages.join(', ');

    // A local-exploration route (e.g. "already in Kathmandu") has no intercity
    // segments and the same boarding point and destination, so it must not be
    // rendered as a pointless "Kathmandu → Kathmandu" journey.
    final isLocalExploration = route.segments.isEmpty &&
        route.boardingPoint.toLowerCase().trim() ==
            route.destination.toLowerCase().trim();

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Journey')),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              Text(
                'Your Recommended Journey',
                style: textTheme.headlineMedium,
              ),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'This itinerary has been personalized from your trip '
                'preferences — destination, dates, budget and travel style.',
                style: textTheme.bodyLarge,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // TRIP SUMMARY
              // ==================================================

              YatraSectionTitle(
                title: 'Trip Summary',
                subtitle: recommendation.title,
              ),

              const SizedBox(height: AppSpacing.md),

              YatraCard(
                child: Column(
                  children: [
                    YatraInfoRow(label: 'Destination', value: destination),
                    YatraInfoRow(
                      label: 'Dates',
                      value:
                          '${_formatDate(departureDate)} – '
                          '${_formatDate(returnDate)}',
                    ),
                    YatraInfoRow(
                      label: 'Duration',
                      value: '$duration days',
                    ),
                    YatraInfoRow(label: 'Travelers', value: '$groupSize'),
                    YatraInfoRow(label: 'Travel Type', value: travelType),
                    YatraInfoRow(
                      label: 'Budget',
                      value: '$currency ${budget.toStringAsFixed(0)}',
                    ),
                    YatraInfoRow(label: 'Season', value: season),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // OVERALL TRIP SUITABILITY
              // ==================================================

              YatraSectionTitle(
                title: 'Overall Trip Suitability',
                subtitle:
                    'A summary of how well this trip fits your selections.',
              ),

              const SizedBox(height: AppSpacing.md),

              YatraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.analytics_outlined,
                            size: 26,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            recommendation.overallSuitability,
                            style: textTheme.titleLarge,
                          ),
                        ),
                        YatraStatusBadge(
                          label: '${recommendation.overallScore}/100',
                          color: AppColors.primary,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    ...recommendation.suitabilityFactors.map((factor) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 19,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                factor,
                                style: textTheme.bodyMedium
                                    ?.copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // BUDGET
              // ==================================================

              _StatusCard(
                title: recommendation.budgetIsLow
                    ? 'Budget Warning'
                    : 'Budget Check',
                message: recommendation.budgetMessage,
                icon: recommendation.budgetIsLow
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                iconColor: recommendation.budgetIsLow
                    ? AppColors.danger
                    : AppColors.success,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // OVERVIEW
              // ==================================================

              YatraSectionTitle(title: 'Trip Overview'),

              const SizedBox(height: AppSpacing.md),

              YatraCard(
                child: Column(
                  children: [
                    YatraInfoRow(label: 'Destination', value: destination),
                    YatraInfoRow(label: 'Season', value: season),
                    YatraInfoRow(label: 'Suitability', value: suitability),
                    YatraInfoRow(
                      label: 'Budget',
                      value: '$currency ${budget.toStringAsFixed(0)}',
                    ),
                    YatraInfoRow(
                      label: 'Transportation',
                      value: route.transportationDescription,
                    ),
                    YatraInfoRow(label: 'Travel Type', value: travelType),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // YOUR TRAVEL ROUTE
              // ==================================================

              YatraSectionTitle(title: 'Your Travel Route'),

              const SizedBox(height: AppSpacing.md),

              YatraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLocalExploration) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.explore_outlined,
                               size: 20, color: scheme.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Local exploration in '
                              '${route.destination}',
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'You are already in ${route.destination} — '
                        'exploring the area locally, with no intercity '
                        'transportation required.',
                        style: textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ] else ...[
                      Text(
                        '${route.boardingPoint} → ${route.destination}',
                        style: textTheme.titleMedium,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      ...route.segments.map(
                        (segment) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.directions,
                                size: 20,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  '${segment.from} → ${segment.to}\n'
                                  '${segment.transportation}',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (route.isRoundTrip &&
                        route.returnSegments.isNotEmpty) ...[
                      const Divider(height: AppSpacing.xxl),
                      Text(
                        'Return Journey',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...route.returnSegments.map(
                        (segment) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.directions,
                                size: 20,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  '${segment.from} → ${segment.to}\n'
                                  '${segment.transportation}',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (recommendation.routeDestinations.length > 1) ...[
                      const Divider(height: AppSpacing.xxl),
                      Text(
                        'Recommendations include stops in: '
                        '${recommendation.routeDestinations.join(', ')}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraCard(
                child: Column(
                  children: [
                    YatraInfoRow(label: 'Travelers', value: '$groupSize'),
                    YatraInfoRow(label: 'Age', value: ageDisplay),
                    YatraInfoRow(
                      label: 'Selected Duration',
                      value: '$duration days',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // DURATION
              // ==================================================

              YatraSectionTitle(title: 'Recommended Travel Duration'),

              const SizedBox(height: AppSpacing.md),

              _StatusCard(
                title: recommendation.recommendedDurationTitle,
                message:
                    '${recommendation.recommendedDurationMessage}\n\n'
                    '${recommendation.durationMessage}',
                icon: recommendation.durationIsTooShort
                    ? Icons.warning_amber_rounded
                    : recommendation.durationIsTooLong
                    ? Icons.info_outline
                    : Icons.check_circle,
                iconColor: recommendation.durationIsTooShort
                    ? AppColors.danger
                    : recommendation.durationIsTooLong
                    ? AppColors.accent
                    : AppColors.success,
              ),

              const SizedBox(height: AppSpacing.xl),

              YatraCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        seasonMessage,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // REMAINING DAYS
              // ==================================================

              YatraSectionTitle(title: 'What About the Remaining Days?'),

              const SizedBox(height: AppSpacing.md),

              YatraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.explore_outlined),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Additional Destination Suggestions',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Text(
                      recommendation.remainingDaysMessage,
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),

                    if (recommendation.additionalDestinations.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),

                      ...recommendation.additionalDestinations.map(
                        (place) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                place,
                                style: textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // DAY PLAN
              // ==================================================

              YatraSectionTitle(
                title: 'Your Day-by-Day Plan',
                subtitle:
                    'A day-by-day breakdown of your journey and sightseeing.',
              ),

              const SizedBox(height: AppSpacing.md),

              if (recommendation.dayPlans.isEmpty)
                const YatraEmptyState(
                  icon: Icons.map_outlined,
                  message: 'No route plan is currently available.',
                ),

              ...recommendation.dayPlans.map((dayPlan) {
                final dayDate =
                    departureDate.add(Duration(days: dayPlan.day - 1));
                return YatraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.sm,
                              ),
                            ),
                            child: Text(
                              '${dayPlan.day}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Day ${dayPlan.day}',
                                  style: textTheme.titleLarge,
                                ),
                                Text(
                                  _formatDate(dayDate),
                                  style: AppType.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      ...dayPlan.items.map((item) {
                        final isTravel =
                            item.type == DayPlanItemType.travel;
                        final isActivity =
                            item.type == DayPlanItemType.activity;
                        final place = item.type ==
                                    DayPlanItemType.attraction
                            ? item.place
                            : null;

                        if (isTravel) {
                          return _travelItem(
                            context,
                            from: item.from,
                            to: item.to,
                            transportation: item.transportation,
                          );
                        }

                        if (isActivity) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    item.activity ?? 'Recommended activity',
                                    style: textTheme.bodyMedium
                                        ?.copyWith(height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Attraction item.
                        if (place == null) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Text(
                              item.title,
                              style: textTheme.titleMedium,
                            ),
                          );
                        }

                        return _attractionItem(
                          context,
                          item: item,
                          place: place,
                        );
                      }),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // WHY THIS TRIP
              // ==================================================

              YatraSectionTitle(title: 'Why This Trip?'),

              const SizedBox(height: AppSpacing.md),

              ...recommendation.reasons.map((reason) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          reason,
                          style: textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xl),

              // ==================================================
              // SUGGESTED PLACES
              // ==================================================

              YatraSectionTitle(title: 'Places You Can Visit'),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Here are some places you can visit during your trip.',
                style: textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.md),

              if (recommendation.suggestedPlaces.isEmpty)
                const YatraEmptyState(
                  icon: Icons.place_outlined,
                  message: 'No attraction data is currently available.',
                ),

              ...recommendation.suggestedPlaces.map((placeName) {
                final place = findPlaceByName(placeName);

                if (place == null) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(placeName),
                      subtitle: const Text('Details unavailable'),
                    ),
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: scheme.primary,
                    ),
                    title: Text(place.name),
                    subtitle: Text(place.location),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PlaceDetailsScreen(place: place),
                        ),
                      );
                    },
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xxl),

              // ==================================================
              // RESTART
              // ==================================================

              YatraPrimaryButton(
                label: 'Plan Another Trip',
                icon: Icons.home_outlined,
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),

              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TRAVEL ITEM
  // ============================================================

  Widget _travelItem(
    BuildContext context, {
    required String? from,
    required String? to,
    required String? transportation,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final fromText = from ?? '';
    final toText = to ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.directions_bus, size: 20, color: scheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Travel · $fromText → $toText',
                    style: textTheme.titleMedium,
                  ),
                  if (transportation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        transportation,
                        style: textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ATTRACTION ITEM
  // ============================================================

  Widget _attractionItem(
    BuildContext context, {
    required DayPlanItem item,
    required Place place,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaceDetailsScreen(place: place),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  place.imageUrl,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 120,
                      color: scheme.primary.withValues(alpha: 0.1),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.landscape,
                        size: 40,
                        color: scheme.primary,
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.name,
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      if (place.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          place.location,
                          style: AppType.caption,
                        ),
                      ],
                      if (place.description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          place.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                      ],
                      if (item.subtitle != null &&
                          place.description.isEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          item.subtitle!,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STATUS CARD
// ============================================================

class _StatusCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;

  const _StatusCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return YatraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: textTheme.bodyMedium?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
