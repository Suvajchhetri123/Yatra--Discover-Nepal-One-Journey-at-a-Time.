import 'package:flutter/material.dart';

import '../../data/packages_data.dart';
import '../../models/package_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/yatra_components.dart';
import '../package_details/package_details_screen.dart';
import '../plan_trip/plan_trip_screen.dart';

/// Home landing page: hero, plan-trip CTA, destination discovery and popular
/// packages. Redesigned on the central Yatra design system.
///
/// All navigation is unchanged:
///   - hero / plan CTA             -> PlanTripScreen
///   - destination card / chip     -> filters packages in place (no route)
///   - package card                -> PackageDetailsScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _allRegions = 'All';

  String _selectedRegion = _allRegions;

  List<String> get _regions => [_allRegions, ...packageRegions];

  List<TourPackage> get _visiblePackages => _selectedRegion == _allRegions
      ? tourPackages
      : tourPackages
          .where((package) => package.region == _selectedRegion)
          .toList();

  /// Distinct destinations (one per region) derived from real package data —
  /// never invented. Each carries the image of its first package.
  List<_Destination> get _destinations {
    final seen = <String>[];
    final result = <_Destination>[];

    for (final package in tourPackages) {
      if (!seen.contains(package.region)) {
        seen.add(package.region);
        result.add(
          _Destination(
            name: package.region,
            imageUrl: package.imageUrl,
            packageCount: tourPackages
                .where((p) => p.region == package.region)
                .length,
          ),
        );
      }
    }

    return result;
  }

  void _selectRegion(String region) {
    setState(() => _selectedRegion = region);
  }

  void _openPlanTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlanTripScreen()),
    );
  }

  void _openPackage(TourPackage package) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackageDetailsScreen(package: package),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Hero(onPlanTrip: _openPlanTrip),
            const SizedBox(height: AppSpacing.xl),
            _PlanTripCard(onTap: _openPlanTrip),
            const SizedBox(height: AppSpacing.xxl),
            _buildDestinationSection(),
            const SizedBox(height: AppSpacing.xl),
            _buildPackagesSection(),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationSection() {
    final destinations = _destinations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: YatraSectionTitle(
            title: 'Explore Destinations',
            subtitle: 'Tap a destination to discover its packages',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            itemCount: destinations.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.lg),
            itemBuilder: (context, index) {
              final destination = destinations[index];
              final selected = destination.name == _selectedRegion;

              return _DestinationCard(
                destination: destination,
                selected: selected,
                onTap: () => _selectRegion(destination.name),
              );
            },
          ),
        ),
        if (destinations.isEmpty)
          const YatraEmptyState(
            icon: Icons.place_outlined,
            message: 'No destinations are available right now.',
          ),
      ],
    );
  }

  Widget _buildPackagesSection() {
    final packages = _visiblePackages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: YatraSectionTitle(
            title: 'Popular Packages',
            subtitle: 'Handpicked journeys across Nepal',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildRegionChips(),
        const SizedBox(height: AppSpacing.lg),
        if (packages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: YatraEmptyState(
              icon: Icons.luggage_outlined,
              message: 'No packages in this region yet.',
              hint: 'Try another destination.',
            ),
          )
        else
          SizedBox(
            height: 330,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              itemCount: packages.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.lg),
              itemBuilder: (context, index) {
                final package = packages[index];
                return _PackageCard(
                  package: package,
                  onTap: () => _openPackage(package),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRegionChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: _regions.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final region = _regions[index];

          return YatraChip(
            label: region,
            selected: region == _selectedRegion,
            onSelected: (_) => _selectRegion(region),
            isFilter: true,
          );
        },
      ),
    );
  }
}

// ==================================================
// HERO
// ==================================================

class _Hero extends StatelessWidget {
  final VoidCallback onPlanTrip;

  const _Hero({required this.onPlanTrip});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 340,
      width: double.infinity,
      clipBehavior: Clip.none,
      decoration: const BoxDecoration(),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/places/AnnapurnaBaseCamp.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.asset(
                        'assets/images/yatra_logo.jpeg',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 34,
                            height: 34,
                            color: Colors.white.withValues(alpha: 0.2),
                            alignment: Alignment.center,
                            child: Icon(Icons.explore,
                                color: Colors.white, size: 22),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    const Text(
                      'YATRA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Explore Nepal.\nPlan Your Journey.',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'From the Everest trails to the jungles of '
                  'Chitwan — build your perfect trip.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPlanTrip,
                    icon: const Icon(Icons.travel_explore, size: 20),
                    label: const Text('Plan Your Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: scheme.primary,
                    ),
                  ),
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
// PLAN TRIP CTA CARD
// ==================================================

class _PlanTripCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PlanTripCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: YatraCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.route, color: scheme.primary, size: 30),
            ),
            const SizedBox(width: AppSpacing.lg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan your own trip',
                    style: AppType.bodyEmphasis,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Get a personalized plan for your journey',
                    style: AppType.body,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: scheme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// DESTINATION CARD
// ==================================================

class _DestinationCard extends StatelessWidget {
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  const _DestinationCard({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      destination.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: scheme.primaryContainer,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.landscape,
                            color: scheme.primary,
                            size: 40,
                          ),
                        );
                      },
                    ),
                    if (selected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.sm,
                            20,
                            AppSpacing.sm,
                            AppSpacing.sm,
                          ),
                          child: Text(
                            destination.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${destination.packageCount} '
              '${destination.packageCount == 1 ? 'package' : 'packages'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// PACKAGE CARD
// ==================================================

class _PackageCard extends StatelessWidget {
  final TourPackage package;
  final VoidCallback onTap;

  const _PackageCard({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 280,
      child: YatraCard(
        padded: false,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _CoverThumb(imageUrl: package.imageUrl),
                Positioned(
                  top: AppSpacing.sm + 2,
                  left: AppSpacing.sm + 2,
                  child: _RegionPill(region: package.region),
                ),
                Positioned(
                  top: AppSpacing.sm + 2,
                  right: AppSpacing.sm + 2,
                  child: _Rating(rating: package.rating, onDark: true),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyEmphasis.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      package.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 15, color: AppColors.onSurfaceHint),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Text(
                          '${package.durationDays} days',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        DifficultyBadge(difficulty: package.difficulty),
                        const Spacer(),
                        Text(
                          formatNpr(package.price),
                          style: AppType.label.copyWith(
                            fontSize: 15,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  final String imageUrl;

  const _CoverThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: scheme.primaryContainer,
            alignment: Alignment.center,
            child: Icon(Icons.landscape, color: scheme.primary, size: 40),
          );
        },
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  final double rating;
  final bool onDark;

  const _Rating({required this.rating, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : AppColors.onSurface;
    final shadow =
        onDark ? Colors.black.withValues(alpha: 0.4) : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: onDark ? 0.45 : 0.0),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              shadows: [
                Shadow(color: shadow, blurRadius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionPill extends StatelessWidget {
  final String region;

  const _RegionPill({required this.region});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 13, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            region,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Difficulty label with a semantic color: Easy (green), Moderate (orange),
/// Challenging (red).
class DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const DifficultyBadge({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final color = difficultyColor(difficulty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Destination {
  final String name;
  final String imageUrl;
  final int packageCount;

  const _Destination({
    required this.name,
    required this.imageUrl,
    required this.packageCount,
  });
}
