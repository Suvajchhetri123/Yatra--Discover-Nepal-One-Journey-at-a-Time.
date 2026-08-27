import 'package:flutter/material.dart';

import '../../data/packages_data.dart';
import '../../models/package_model.dart';
import '../package_details/package_details_screen.dart';
import '../plan_trip/plan_trip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _allRegions = 'All';

  String _selectedRegion = _allRegions;

  @override
  Widget build(BuildContext context) {
    final regions = [_allRegions, ...packageRegions];

    final visiblePackages = _selectedRegion == _allRegions
        ? tourPackages
        : tourPackages
            .where((package) => package.region == _selectedRegion)
            .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(context),
            _buildRegionChips(regions),
            const SizedBox(height: 12),
            ...visiblePackages.map(
              (package) => _PackageCard(package: package),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YATRA',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Discover Nepal, One Journey at a Time',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 20),

          // "Plan a trip" call to action into the existing planner.
          Material(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlanTripScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.travel_explore,
                        size: 34, color: scheme.onPrimary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan your own trip',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Get a personalized plan for your journey',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: scheme.onPrimary),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 26),

          const Text(
            'Featured Packages',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(
            'Handpicked journeys across Nepal',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionChips(List<String> regions) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: regions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final region = regions[index];

          return ChoiceChip(
            label: Text(region),
            selected: region == _selectedRegion,
            onSelected: (_) {
              setState(() => _selectedRegion = region);
            },
          );
        },
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final TourPackage package;

  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PackageDetailsScreen(package: package),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PackageCoverImage(imageUrl: package.imageUrl, height: 170),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _RegionPill(region: package.region),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          package.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Rating(rating: package.rating),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    package.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 15, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        '${package.durationDays} days',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      DifficultyBadge(difficulty: package.difficulty),
                      const Spacer(),
                      Text(
                        formatNpr(package.price),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  final double rating;

  const _Rating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 16, color: Colors.amber),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _RegionPill extends StatelessWidget {
  final String region;

  const _RegionPill({required this.region});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            region,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

Color difficultyColor(String difficulty) {
  switch (difficulty) {
    case 'Easy':
      return Colors.green.shade700;
    case 'Moderate':
      return Colors.orange.shade800;
    case 'Challenging':
      return Colors.red.shade700;
    default:
      return Colors.blueGrey;
  }
}

/// A package cover image that falls back to a branded gradient placeholder when
/// the asset is missing (only some place photos are bundled with the app).
class PackageCoverImage extends StatelessWidget {
  final String imageUrl;
  final double height;

  const PackageCoverImage({
    super.key,
    required this.imageUrl,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Image.asset(
      imageUrl,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primaryContainer, scheme.primary],
            ),
          ),
          child: Icon(
            Icons.landscape,
            size: 46,
            color: scheme.onPrimary.withValues(alpha: 0.9),
          ),
        );
      },
    );
  }
}
