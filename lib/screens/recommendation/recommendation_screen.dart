import 'package:flutter/material.dart';

import '../../services/recommendation_service.dart';
import '../../data/places_data.dart';
import '../place_details/place_details_screen.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Recommendation'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recommendation.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                recommendation.summary,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // OVERALL TRIP SUITABILITY
              // ==================================================
              const Text(
                'Overall Trip Suitability',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics_outlined, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            recommendation.overallSuitability,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${recommendation.overallScore}/100',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    ...recommendation.suitabilityFactors.map((factor) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 19),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                factor,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                               ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // BUDGET
              // ==================================================
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
                    ? Colors.red
                    : Colors.green,
              ),

              const SizedBox(height: 30),

              // ==================================================
              // OVERVIEW
              // ==================================================
              const Text(
                'Trip Overview',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              _InfoRow(label: 'Destination', value: destination),

              _InfoRow(label: 'Season', value: season),

              _InfoRow(label: 'Suitability', value: suitability),

              _InfoRow(
                label: 'Budget',
                value: '$currency ${budget.toStringAsFixed(0)}',
              ),

              _InfoRow(
                label: 'Transportation',
                value: route.transportationDescription,
              ),

              _InfoRow(label: 'Travel Type', value: travelType),

              const SizedBox(height: 15),

              const Text(
                'Your Travel Route',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${route.boardingPoint} → ${route.destination}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    ...route.segments.map(
                      (segment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.directions, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${segment.from} → ${segment.to}\n'
                                '${segment.transportation}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (recommendation.routeDestinations.length > 1) ...[
                      const Divider(height: 24),
                      Text(
                        'Recommendations include stops in: '
                        '${recommendation.routeDestinations.join(', ')}',
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              _InfoRow(label: 'Travellers', value: '$groupSize'),

              _InfoRow(label: 'Age', value: ageDisplay),

              _InfoRow(label: 'Selected Duration', value: '$duration days'),

              const SizedBox(height: 30),

              // ==================================================
              // DURATION
              // ==================================================
              const Text(
                'Recommended Travel Duration',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

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
                    ? Colors.red
                    : recommendation.durationIsTooLong
                    ? Colors.orange
                    : Colors.green,
              ),

              const SizedBox(height: 25),

              Text(
                seasonMessage,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // REMAINING DAYS
              // ==================================================
              const Text(
                'What About the Remaining Days?',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.explore_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Additional Destination Suggestions',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      recommendation.remainingDaysMessage,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),

                    if (recommendation.additionalDestinations.isNotEmpty) ...[
                      const SizedBox(height: 15),

                      ...recommendation.additionalDestinations.map(
                        (place) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                place,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // DAY PLAN
              // ==================================================
              const Text(
                'Your Day-by-Day Plan',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              if (recommendation.dayPlans.isEmpty)
                const Text('No route plan is currently available.'),

              ...recommendation.dayPlans.map((dayPlan) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day ${dayPlan.day}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        ...dayPlan.items.map((item) {
                          final place = item.type == DayPlanItemType.attraction
                              ? findPlaceByName(item.title)
                              : null;

                          final isTravelItem =
                              item.type == DayPlanItemType.travel;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                isTravelItem
                                    ? Icons.directions_bus
                                    : Icons.location_on,
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: item.subtitle == null
                                  ? null
                                  : Text(item.subtitle!),
                              trailing: place == null
                                  ? null
                                  : const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 15,
                                    ),
                              onTap: place == null
                                  ? null
                                  : () {
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
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // ==================================================
              // WHY THIS TRIP
              // ==================================================
              const Text(
                'Why This Trip?',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              ...recommendation.reasons.map((reason) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),

              // ==================================================
              // SUGGESTED PLACES
              // ==================================================
              const Text(
                'Places You Can Visit',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),
              const Text(
                'Here are some places you can visit during your trip.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 15),

              if (recommendation.suggestedPlaces.isEmpty)
                const Text('No attraction data is currently available.'),

              ...recommendation.suggestedPlaces.map((placeName) {
                final place = findPlaceByName(placeName);

                if (place == null) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(placeName),
                    ),
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(place.name),
                    subtitle: Text(place.location),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================
// STATUS CARD
// ==================================================

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(fontSize: 14, height: 1.5),
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
// INFO ROW
// ==================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
