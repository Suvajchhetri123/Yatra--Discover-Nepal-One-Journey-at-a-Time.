import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../services/google_maps_launcher.dart';
import '../../services/recommendation_service.dart';
import '../../services/trip_cost_estimator.dart';
import '../../data/places_data.dart';
import '../../widgets/yatra_components.dart';
import '../booking/booking_review_screen.dart';
import '../place_details/place_details_screen.dart';
import '../../models/package_model.dart';
import '../../models/place_model.dart';
import '../../models/travel_route_model.dart';

class RecommendationScreen extends StatefulWidget {
  final String touristType;
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final String season;
  final String suitability;
  final String currency;
  final double budget;
  final List<int> ages;
  final int adultCount;
  final int childCount;
  final String travelType;
  final int groupSize;
  final String seasonMessage;
  final TravelRoute route;

  /// The package this itinerary was planned from, when planning started from
  /// a package (used to keep the package title on the booking request).
  final TourPackage? package;

  const RecommendationScreen({
    super.key,
    required this.touristType,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.season,
    required this.suitability,
    required this.currency,
    required this.budget,
    required this.ages,
    this.adultCount = 1,
    this.childCount = 0,
    required this.travelType,
    required this.groupSize,
    required this.seasonMessage,
    required this.route,
    this.package,
  });

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  // Shadow copies of the widget's planning fields so the rest of this file
  // can keep using them without a widget. prefix.
  late final String touristType = widget.touristType;
  late final String destination = widget.destination;
  late final DateTime departureDate = widget.departureDate;
  late final DateTime returnDate = widget.returnDate;
  late final String season = widget.season;
  late final String suitability = widget.suitability;
  late final String currency = widget.currency;
  late final double budget = widget.budget;
  late final List<int> ages = widget.ages;
  late final int adultCount = widget.adultCount;
  late final int childCount = widget.childCount;
  late final String travelType = widget.travelType;
  late final int groupSize = widget.groupSize;
  late final String seasonMessage = widget.seasonMessage;
  late final TravelRoute route = widget.route;
  late final TourPackage? package = widget.package;

  late final RecommendationResult _recommendation;

  late final int _duration;

  /// Pristine generated plans, kept separate so edits can be undone.
  late final List<DayPlan> _recommendedDayPlans;

  /// Plans currently displayed; replaced when the tourist saves an edit.
  late final List<DayPlan> _displayedDayPlans;

  /// Working copy while editing; discarded on cancel.
  List<DayPlan> _draftDayPlans = [];

  bool _editing = false;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime date) {
    final weekday = _days[date.weekday - 1];
    final month = _months[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  /// Plans shown for the current mode: the edit draft while editing,
  /// otherwise the committed display plans.
  List<DayPlan> get _visibleDayPlans =>
      _editing ? _draftDayPlans : _displayedDayPlans;

  static List<DayPlan> _copyDayPlans(List<DayPlan> plans) {
    return [
      for (final plan in plans)
        DayPlan(day: plan.day, items: List.of(plan.items)),
    ];
  }

  @override
  void initState() {
    super.initState();

    final rawDuration = returnDate.difference(departureDate).inDays + 1;
    _duration = rawDuration > 0 ? rawDuration : 1;

    _recommendation = RecommendationService.generate(
      touristType: touristType,
      destination: destination,
      season: season,
      suitability: suitability,
      budget: budget,
      currency: currency,
      ages: ages,
      adultCount: adultCount,
      childCount: childCount,
      travelType: travelType,
      groupSize: groupSize,
      duration: _duration,
      route: route,
    );

    _recommendedDayPlans = _copyDayPlans(_recommendation.dayPlans);
    _displayedDayPlans = _copyDayPlans(_recommendation.dayPlans);
  }

  // ============================================================
  // ITINERARY EDITING
  // ============================================================

  void _beginEditing() {
    setState(() {
      _draftDayPlans = _copyDayPlans(_displayedDayPlans);
      _editing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _draftDayPlans = [];
      _editing = false;
    });
  }

  void _saveChanges() {
    if (_draftDayPlans.isEmpty) {
      _cancelEditing();
      return;
    }

    setState(() {
      _editing = false;
      // _displayedDayPlans is final; commit through the reference.
      _displayedDayPlans.clear();
      _displayedDayPlans.addAll(_draftDayPlans);
      _draftDayPlans = [];
    });
  }

  void _resetToRecommended() {
    setState(() {
      _editing = false;
      _draftDayPlans = [];
      _displayedDayPlans.clear();
      _displayedDayPlans.addAll(_copyDayPlans(_recommendedDayPlans));
    });
  }

  bool _canMoveInDay(DayPlan day, int itemIndex, int delta) {
    final positions = <int>[];
    for (var i = 0; i < day.items.length; i++) {
      if (day.items[i].type != DayPlanItemType.travel) {
        positions.add(i);
      }
    }

    final position = positions.indexOf(itemIndex);
    if (position < 0) return false;

    final target = position + delta;
    return target >= 0 && target < positions.length;
  }

  /// Moves a non-travel item within the non-travel slots of its day so
  /// travel legs stay pinned in place.
  void _moveItem(DayPlan dayPlan, int itemIndex, int delta) {
    final dayIndex = _visibleDayPlans.indexOf(dayPlan);
    if (dayIndex < 0 || !_editing) return;

    final day = _draftDayPlans[dayIndex];
    final items = List.of(day.items);

    final positions = <int>[];
    for (var i = 0; i < items.length; i++) {
      if (items[i].type != DayPlanItemType.travel) {
        positions.add(i);
      }
    }

    final position = positions.indexOf(itemIndex);
    if (position < 0) return;

    final targetPosition = position + delta;
    if (targetPosition < 0 || targetPosition >= positions.length) return;

    final a = positions[position];
    final b = positions[targetPosition];
    final temp = items[a];
    items[a] = items[b];
    items[b] = temp;

    setState(() {
      _draftDayPlans[dayIndex] = day.replaceItems(items);
    });
  }

  void _removeItem(DayPlan dayPlan, int itemIndex) {
    final dayIndex = _visibleDayPlans.indexOf(dayPlan);
    if (dayIndex < 0 || !_editing) return;

    final day = _draftDayPlans[dayIndex];
    final item = day.items[itemIndex];
    if (item.type == DayPlanItemType.travel) return;

    final items = List.of(day.items)..removeAt(itemIndex);

    setState(() {
      _draftDayPlans[dayIndex] = day.replaceItems(items);
    });
  }

  int _insertionIndex(DayPlan day) {
    int index = day.items.length;
    for (var i = day.items.length - 1; i >= 0; i--) {
      if (day.items[i].type != DayPlanItemType.travel) {
        index = i + 1;
        break;
      }
    }
    return index;
  }

  void _addActivity(DayPlan dayPlan) {
    final dayIndex = _visibleDayPlans.indexOf(dayPlan);
    if (dayIndex < 0 || !_editing) return;

    final day = _draftDayPlans[dayIndex];
    final insertAt = _insertionIndex(day);
    final items = List.of(day.items);
    items.insert(insertAt, const DayPlanItem.activity(activity: ''));

    setState(() {
      _draftDayPlans[dayIndex] = day.replaceItems(items);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openItemEditor(dayIndex, insertAt);
    });
  }

  void _addAttraction(DayPlan dayPlan) {
    final dayIndex = _visibleDayPlans.indexOf(dayPlan);
    if (dayIndex < 0 || !_editing) return;

    final places = <Place>[];
    for (final name in _recommendation.suggestedPlaces) {
      final place = findPlaceByName(name);
      if (place != null) {
        places.add(place);
      }
    }

    if (places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attractions are available to add.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Add an attraction',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: places.length,
                  itemBuilder: (listContext, index) {
                    final place = places[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(place.name),
                      subtitle: Text(place.location),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _insertItem(
                          dayIndex,
                          DayPlanItem.attraction(place: place),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _insertItem(int dayIndex, DayPlanItem item) {
    final day = _draftDayPlans[dayIndex];
    final items = List.of(day.items);
    items.insert(_insertionIndex(day), item);

    setState(() {
      _draftDayPlans[dayIndex] = day.replaceItems(items);
    });
  }

  void _openItemEditor(int dayIndex, int itemIndex) {
    if (!_editing) return;
    final day = _draftDayPlans[dayIndex];
    final item = day.items[itemIndex];
    if (item.type == DayPlanItemType.travel) return;

    final initialTitle = item.type == DayPlanItemType.attraction
        ? (item.customTitle ?? item.place?.name ?? '')
        : (item.activity ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _DayPlanItemEditor(
          initialTitle: initialTitle,
          initialNote: item.note ?? '',
          onSave: (title, note) {
            Navigator.pop(sheetContext);
            setState(() {
              final updatedDay = _draftDayPlans[dayIndex];
              final items = List.of(updatedDay.items);
              items[itemIndex] = item.copyWith(
                customTitle: title,
                note: note,
                activity: title,
              );
              _draftDayPlans[dayIndex] = updatedDay.replaceItems(items);
            });
          },
        );
      },
    );
  }

  void _confirmEditTripPlan() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Trip Plan?'),
          content: const Text(
            'You will return to the planning screens. Your saved itinerary '
            'edits are kept for this trip.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('Edit Trip Plan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int duration = _duration;

    final RecommendationResult recommendation = _recommendation;

    final ageDisplay = travelType == 'Solo'
        ? '${ages.isNotEmpty ? ages.first : 18} years'
        : ages.join(', ');

    // A local-exploration route has no intercity segments and the same
    // boarding point and destination, so it must not be rendered as
    // a pointless "Kathmandu → Kathmandu" journey.
    final isLocalExploration =
        route.segments.isEmpty &&
        route.boardingPoint.toLowerCase().trim() ==
            route.destination.toLowerCase().trim();

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Journey'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Trip Plan',
            onPressed: _confirmEditTripPlan,
          ),
        ],
      ),
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
              Text('Your Recommended Journey', style: textTheme.headlineMedium),

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
                    YatraInfoRow(label: 'Tourist Type', value: touristType),
                    YatraInfoRow(label: 'Destination', value: destination),
                    YatraInfoRow(
                      label: 'Dates',
                      value:
                          '${_formatDate(departureDate)} – '
                          '${_formatDate(returnDate)}',
                    ),
                    YatraInfoRow(label: 'Duration', value: '$duration days'),
                    YatraInfoRow(label: 'Travelers', value: '$groupSize'),
                    YatraInfoRow(label: 'Adults', value: '$adultCount'),
                    YatraInfoRow(label: 'Children', value: '$childCount'),
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
                                style: textTheme.bodyMedium?.copyWith(
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
                          Icon(
                            Icons.explore_outlined,
                            size: 20,
                            color: scheme.primary,
                          ),
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
                        (segment) => _routeLeg(
                          context,
                          from: segment.from,
                          to: segment.to,
                          transportation: segment.transportation,
                          iconColor: scheme.primary,
                        ),
                      ),
                    ],

                    if (route.isRoundTrip &&
                        route.returnSegments.isNotEmpty) ...[
                      const Divider(height: AppSpacing.xxl),
                      Text('Return Journey', style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      ...route.returnSegments.map(
                        (segment) => _routeLeg(
                          context,
                          from: segment.from,
                          to: segment.to,
                          transportation: segment.transportation,
                          iconColor: AppColors.accent,
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
                    YatraInfoRow(label: 'Adults', value: '$adultCount'),
                    YatraInfoRow(label: 'Children', value: '$childCount'),
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
                      child: Text(seasonMessage, style: textTheme.bodyMedium),
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
                              Text(place, style: textTheme.titleMedium),
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

              if (_editing) ...[
                _editingToolbar(),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _beginEditing,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Itinerary'),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              if (_visibleDayPlans.isEmpty)
                const YatraEmptyState(
                  icon: Icons.map_outlined,
                  message: 'No route plan is currently available.',
                ),

              ..._visibleDayPlans.map((dayPlan) => _dayPlanCard(dayPlan)),

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

              const SizedBox(height: AppSpacing.xxl),

              // ==================================================
              // BOOK THIS ITINERARY
              // ==================================================
              _buildBookingSection(context),

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
  // BOOKING SECTION
  // ============================================================

  /// Estimated trip cost summary plus the "Book This Itinerary" action.
  ///
  /// The cost uses the estimate already produced during generation — nothing
  /// is re-priced here. Booking submits a Pending request; no payment occurs.
  Widget _buildBookingSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final estimate = _recommendation.tripCostEstimate;
    final currency = this.currency;

    String formatAmount(double nprAmount) {
      return TripCostEstimator.formatInCurrency(nprAmount, currency);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YatraSectionTitle(
          title: 'Estimated Trip Cost',
          subtitle: 'Review the cost before submitting a booking request.',
        ),
        const SizedBox(height: AppSpacing.md),
        YatraCard(
          child: Column(
            children: [
              YatraInfoRow(
                label: 'Transport',
                value: formatAmount(estimate.transport),
              ),
              YatraInfoRow(
                label: 'Accommodation',
                value: formatAmount(estimate.stay),
              ),
              YatraInfoRow(
                label: 'Activities',
                value: formatAmount(estimate.activity),
              ),
              if (estimate.packagePrice > 0)
                YatraInfoRow(
                  label: 'Package',
                  value: formatAmount(estimate.packagePrice),
                ),
              const Divider(height: AppSpacing.xl),
              YatraInfoRow(
                label: 'Estimated Trip Cost',
                value: formatAmount(estimate.total),
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This is an estimate, not a payment. Submitting a booking request '
          'does not charge you anything.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        YatraPrimaryButton(
          label: 'Book This Itinerary',
          icon: Icons.event_available_outlined,
          onPressed: _openBookingReview,
        ),
      ],
    );
  }

  void _openBookingReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingReviewScreen(
          touristType: touristType,
          destination: destination,
          startDate: departureDate,
          endDate: returnDate,
          currency: currency,
          estimate: _recommendation.tripCostEstimate,
          duration: _duration,
          travelType: travelType,
          adultCount: adultCount,
          childCount: childCount,
          groupSize: groupSize,
          packageTitle: package?.title,
          route: route,
          dayPlans: List<DayPlan>.of(_displayedDayPlans),
        ),
      ),
    );
  }

  // ============================================================
  // ITINERARY DAY CARD
  // ============================================================

  Widget _dayPlanCard(DayPlan dayPlan) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dayDate = departureDate.add(Duration(days: dayPlan.day - 1));

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
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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
                    Text('Day ${dayPlan.day}', style: textTheme.titleLarge),
                    Text(_formatDate(dayDate), style: AppType.caption),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          ..._dayItems(dayPlan),

          if (_editing) ...[
            const Divider(height: AppSpacing.xl),
            _addItemButtons(dayPlan),
          ],
        ],
      ),
    );
  }

  List<Widget> _dayItems(DayPlan dayPlan) {
    if (!_editing) {
      return [for (final item in dayPlan.items) _itineraryItemView(item)];
    }

    final dayIndex = _visibleDayPlans.indexOf(dayPlan);

    return [
      for (var i = 0; i < dayPlan.items.length; i++)
        _editableItemRow(dayIndex, i, dayPlan.items[i]),
    ];
  }

  /// Read-only rendering of one itinerary item (travel / activity / attraction).
  Widget _itineraryItemView(DayPlanItem item) {
    final textTheme = Theme.of(context).textTheme;

    if (item.type == DayPlanItemType.travel) {
      return _travelItem(
        context,
        from: item.from,
        to: item.to,
        transportation: item.transportation,
      );
    }

    if (item.type == DayPlanItemType.activity) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    item.title,
                    style: textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
            if (item.note?.isNotEmpty ?? false) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(item.note!, style: textTheme.bodySmall),
              ),
            ],
          ],
        ),
      );
    }

    final place = item.place;

    if (place == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(item.title, style: textTheme.titleMedium),
      );
    }

    return _attractionItem(context, item: item, place: place);
  }

  /// Edit-mode row for one itinerary item. Travel legs stay read-only.
  Widget _editableItemRow(int dayIndex, int itemIndex, DayPlanItem item) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (item.type == DayPlanItemType.travel) {
      return _travelItem(
        context,
        from: item.from,
        to: item.to,
        transportation: item.transportation,
      );
    }

    final isAttraction = item.type == DayPlanItemType.attraction;

    final day = _visibleDayPlans[dayIndex];
    final canMoveUp = _canMoveInDay(day, itemIndex, -1);
    final canMoveDown = _canMoveInDay(day, itemIndex, 1);

    final icon = isAttraction ? Icons.location_on : Icons.check_circle_outline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _moveIconButton(
                icon: Icons.arrow_upward,
                tooltip: 'Move up',
                onPressed: canMoveUp
                    ? () => _requestMove(dayIndex, itemIndex, -1)
                    : null,
              ),
              _moveIconButton(
                icon: Icons.arrow_downward,
                tooltip: 'Move down',
                onPressed: canMoveDown
                    ? () => _requestMove(dayIndex, itemIndex, 1)
                    : null,
              ),
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  style: textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit text / note',
                visualDensity: VisualDensity.compact,
                onPressed: () => _openItemEditor(dayIndex, itemIndex),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _removeItem(_visibleDayPlans[dayIndex], itemIndex),
              ),
            ],
          ),
          if (item.note?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Text(
                item.note!,
                style: textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _moveIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(6),
      onPressed: onPressed,
    );
  }

  void _requestMove(int dayIndex, int itemIndex, int delta) {
    _moveItem(_visibleDayPlans[dayIndex], itemIndex, delta);
  }

  Widget _addItemButtons(DayPlan dayPlan) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _addActivity(dayPlan),
            icon: const Icon(Icons.add),
            label: const Text('Add Activity'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _addAttraction(dayPlan),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add Attraction'),
          ),
        ),
      ],
    );
  }

  Widget _editingToolbar() {
    final textTheme = Theme.of(context).textTheme;

    return YatraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Editing Mode', style: textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Refine each day\'s schedule, add or remove activities, and edit '
            'any title or note. Travel legs stay as planned and cannot be '
            'changed here.',
            style: textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelEditing,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: YatraPrimaryButton(
                  label: 'Save Changes',
                  icon: Icons.check,
                  onPressed: _saveChanges,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: _resetToRecommended,
              child: const Text('Reset to Recommended'),
            ),
          ),
        ],
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
          border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
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
                      child: Text(transportation, style: textTheme.bodySmall),
                    ),

                  const SizedBox(height: AppSpacing.sm),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: _googleMapsButton(
                      context,
                      from: fromText,
                      to: toText,
                      transportation: transportation,
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
  // GOOGLE MAPS LAUNCH BUTTON
  // ============================================================

  /// [View in Google Maps] button for one actual travel leg.
  ///
  /// Opens Google Maps directions (after an offline reminder) using the leg's
  /// real origin, destination and transportation. Hidden when the leg has no
  /// usable endpoints, so exploration-only days never show a route button.
  Widget _googleMapsButton(
    BuildContext context, {
    required String from,
    required String to,
    String? transportation,
  }) {
    if (from.trim().isEmpty || to.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: () {
        GoogleMapsLauncher.launch(
          context,
          from: from,
          to: to,
          transportation: transportation,
        );
      },
      icon: const Icon(Icons.map_outlined, size: 18),
      label: const Text('View in Google Maps'),
    );
  }

  // ============================================================
  // ROUTE LEG (ROUTE CARD)
  // ============================================================

  /// One travel leg in the "Your Travel Route" card, with its own
  /// [View in Google Maps] button.
  Widget _routeLeg(
    BuildContext context, {
    required String from,
    required String to,
    required String transportation,
    required Color iconColor,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.directions, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '$from → $to\n$transportation',
                  style: textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _googleMapsButton(
              context,
              from: from,
              to: to,
              transportation: transportation,
            ),
          ),
        ],
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
                              item.title,
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),

                      if (place.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(place.location, style: AppType.caption),
                      ],

                      if (item.note?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.note!,
                          style: textTheme.bodySmall?.copyWith(height: 1.4),
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
                        Text(item.subtitle!, style: textTheme.bodySmall),
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
                Text(
                  message,
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

// ============================================================
// DAY PLAN ITEM EDITOR
// ============================================================

class _DayPlanItemEditor extends StatefulWidget {
  final String initialTitle;
  final String initialNote;
  final void Function(String title, String note) onSave;

  const _DayPlanItemEditor({
    required this.initialTitle,
    required this.initialNote,
    required this.onSave,
  });

  @override
  State<_DayPlanItemEditor> createState() => _DayPlanItemEditorState();
}

class _DayPlanItemEditorState extends State<_DayPlanItemEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Itinerary Item',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _noteController,
            textInputAction: TextInputAction.done,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.onSave(
                    _titleController.text,
                    _noteController.text,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
