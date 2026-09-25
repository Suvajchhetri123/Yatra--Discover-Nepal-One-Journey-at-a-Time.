import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/demo_profile_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sos_action.dart';
import '../../widgets/yatra_components.dart';

/// Offline Access — a placeholder for features that will ship with the
/// offline-sync phase. It explains the offline roadmap honestly instead of
/// pretending offline support exists today.
class OfflineAccessScreen extends StatelessWidget {
  const OfflineAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final language = DemoProfileStore.instance.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'offline.title')),
        actions: const [YatraSosAction()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            YatraCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'These features are coming with the offline-sync '
                      'phase. This screen is a preview of the roadmap.',
                      style: AppType.bodyEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            YatraSectionTitle(title: 'Coming with Offline Sync'),
            const SizedBox(height: AppSpacing.md),

            _OfflineCard(
              icon: Icons.map_outlined,
              title: 'Offline Google Maps',
              description:
                  'Download the Google Maps area for your destination so it '
                  'works without a connection during an emergency or in '
                  'remote areas.',
              badge: 'Coming soon',
            ),
            const SizedBox(height: AppSpacing.md),
            _OfflineCard(
              icon: Icons.route_outlined,
              title: 'Saved Tour Plans',
              description:
                  'Keep your generated itineraries readable without data — '
                  'route, stops, costs and your booked itinerary status.',
              badge: 'Coming soon',
            ),
            const SizedBox(height: AppSpacing.md),
            _OfflineCard(
              icon: Icons.emergency_outlined,
              title: 'Offline SOS Data',
              description:
                  'Keep the last-known location and emergency contact cached '
                  'so SOS guidance is available without a connection.',
              badge: 'Coming soon',
            ),

            const SizedBox(height: AppSpacing.xl),

            YatraSectionTitle(title: 'What works today'),
            const SizedBox(height: AppSpacing.md),
            YatraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TodayRow(
                    icon: Icons.check_circle_outline,
                    text: 'Google Maps links open for legs you tap.',
                  ),
                  _TodayRow(
                    icon: Icons.check_circle_outline,
                    text:
                        'View in Google Maps from both itinerary review '
                        'and booking details.',
                  ),
                  _TodayRow(
                    icon: Icons.check_circle_outline,
                    text: 'Route is generated offline, no connection needed.',
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

class _OfflineCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String badge;

  const _OfflineCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return YatraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: AppType.bodyEmphasis)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(description),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge,
                style: AppType.label.copyWith(color: AppColors.warning),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TodayRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
