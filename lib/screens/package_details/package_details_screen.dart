import 'package:flutter/material.dart';

import '../../data/places_data.dart';
import '../../models/package_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/yatra_components.dart';
import '../place_details/place_details_screen.dart';
import '../travel_dates/travel_dates_screen.dart';

/// Premium Package / Destination Details screen.
///
/// Redesigned on the central Yatra design system and visually consistent with
/// the redesigned Home screen (same colours, typography, card radius, spacing,
/// chips and button language).
///
/// All navigation is preserved:
///   - back button / hero            -> pop
///   - included place chip           -> PlaceDetailsScreen
///   - "Plan This Trip" CTA          -> TravelDatesScreen(package)
class PackageDetailsScreen extends StatelessWidget {
  final TourPackage package;

  const PackageDetailsScreen({super.key, required this.package});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(package: package),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuickFacts(package: package),
                  const SizedBox(height: AppSpacing.xxl),

                  const YatraSectionTitle(
                    title: 'About this trip',
                    subtitle: 'A closer look at what this trip includes.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    package.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  const YatraSectionTitle(title: 'Highlights'),
                  const SizedBox(height: AppSpacing.md),
                  ...package.highlights.map(
                    (highlight) => _BulletRow(
                      icon: Icons.check_circle_outline,
                      text: highlight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const YatraSectionTitle(title: 'Included Places'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tap a place to see more details.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildPlaceChips(context),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
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
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TravelDatesScreen(package: package),
                ),
              );
            },
            icon: const Icon(Icons.rocket_launch_outlined, size: 20),
            label: const Text('Plan This Trip'),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceChips(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: package.includedPlaces.map((name) {
        final place = findPlaceByName(name);

        return ActionChip(
          avatar: Icon(
            place != null ? Icons.place : Icons.place_outlined,
            size: 18,
          ),
          label: Text(name),
          onPressed: place == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceDetailsScreen(place: place),
                    ),
                  );
                },
        );
      }).toList(),
    );
  }
}

// ==================================================
// HERO
// ==================================================

class _Hero extends StatelessWidget {
  final TourPackage package;

  const _Hero({required this.package});

  static const double _heroHeight = 320;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.xl),
      ),
      child: SizedBox(
        height: _heroHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              package.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primaryContainer, scheme.primary],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.landscape,
                    color: scheme.onPrimary,
                    size: 56,
                  ),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _RoundButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.screen,
              right: AppSpacing.screen,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        package.region,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        package.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${package.durationDays} days',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ==================================================
// QUICK FACTS
// ==================================================

class _QuickFacts extends StatelessWidget {
  final TourPackage package;

  const _QuickFacts({required this.package});

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 175,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.5,
      ),
      children: [
        _FactCard(
          icon: Icons.calendar_today_outlined,
          value: '${package.durationDays} days',
          label: 'Duration',
        ),
        _FactCard(
          icon: Icons.terrain_outlined,
          value: package.difficulty,
          label: 'Difficulty',
          valueColor: difficultyColor(package.difficulty),
        ),
        _FactCard(
          icon: Icons.payments_outlined,
          value: formatNpr(package.price),
          label: 'Price',
        ),
        _FactCard(
          icon: Icons.place_outlined,
          value: package.region,
          label: 'Destination',
        ),
      ],
    );
  }
}

class _FactCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;

  const _FactCard({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return YatraCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: valueColor ?? scheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.bodyEmphasis.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ==================================================
// BULLET ROW
// ==================================================

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BulletRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
