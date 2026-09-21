import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/place_model.dart';
import '../../widgets/yatra_components.dart';

class PlaceDetailsScreen extends StatelessWidget {
  final Place place;

  const PlaceDetailsScreen({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================================================
                // HERO
                // ================================================

                SizedBox(
                  height: 360,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        place.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: scheme.primary.withValues(alpha: 0.12),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.landscape,
                              size: 64,
                              color: scheme.primary,
                            ),
                          );
                        },
                      ),

                      // Stronger bottom scrim so the title/location remain
                      // readable while staying completely inside the image.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black26,
                              Colors.black87,
                            ],
                            stops: [0.0, 0.48, 0.7, 1.0],
                          ),
                        ),
                      ),

                      // Keep the title and location INSIDE the hero image.
                      // Previously these were placed below the image and moved
                      // upward with Transform.translate, which allowed the
                      // white location text to fall onto the white page.
                      Positioned(
                        left: AppSpacing.screen,
                        right: AppSpacing.screen,
                        bottom: 28,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    place.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
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

                // ================================================
                // CONTENT
                // ================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.xl,
                    AppSpacing.screen,
                    AppSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==========================================
                      // ABOUT THIS PLACE
                      // ==========================================

                      YatraSectionTitle(title: 'About This Place'),

                      const SizedBox(height: AppSpacing.md),

                      YatraCard(
                        child: Text(
                          place.description,
                          style: textTheme.bodyLarge?.copyWith(height: 1.6),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ==========================================
                      // VISITOR INFORMATION
                      // ==========================================

                      YatraSectionTitle(title: 'Visitor Information'),

                      const SizedBox(height: AppSpacing.md),

                      YatraCard(
                        child: Column(
                          children: [
                            YatraInfoRow(
                              label: 'Entry Fee',
                              value: place.entryFee == 0
                                  ? 'Free'
                                  : 'NPR ${place.entryFee.toStringAsFixed(0)}',
                            ),
                            YatraInfoRow(
                              label: 'Opening Hours',
                              value: place.openingHours,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ==========================================
                      // GETTING THERE
                      // ==========================================

                      if (place.transportation.isNotEmpty) ...[
                        YatraSectionTitle(title: 'How to Get There'),

                        const SizedBox(height: AppSpacing.md),

                        YatraCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.directions,
                                size: 22,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  place.transportation,
                                  style:
                                      textTheme.bodyMedium?.copyWith(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),
                      ],

                      // ==========================================
                      // TRAVEL / TRIP INFORMATION
                      // ==========================================

                      if (place.travelTrip.isNotEmpty) ...[
                        YatraSectionTitle(title: 'Recommended Trip'),

                        const SizedBox(height: AppSpacing.md),

                        YatraCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.luggage_outlined,
                                size: 22,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  place.travelTrip,
                                  style:
                                      textTheme.bodyMedium?.copyWith(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ================================================
          // FLOATING BACK BUTTON
          // ================================================

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.of(context).maybePop();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
