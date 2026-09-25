import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/itinerary_booking.dart';
import '../../services/demo_booking_store.dart';
import '../../services/demo_profile_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_booking_list_screen.dart';

/// Admin frontend dashboard (DEMO only — no role security).
///
/// Shows counts derived from the current demo bookings. Each card opens the
/// booking list pre-filtered to that status. The admin backend (roles,
/// security rules, persistence) is a later phase.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final language = DemoProfileStore.instance.language;
    final store = DemoBookingStore.instance;
    final bookings = store.bookings;

    final total = bookings.length;
    final pending = store.bookingsWithStatus(BookingStatus.pending).length;
    final confirmed = store.bookingsWithStatus(BookingStatus.confirmed).length;
    final travellers = bookings.fold<int>(0, (sum, b) => sum + b.groupSize);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr(language, 'admin.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              'This is a frontend demo of the admin area. Bookings shown '
              'here are the same session bookings visible to the tourist.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),

            YatraSectionTitle(
              title: AppStrings.tr(language, 'admin.dashboard'),
            ),
            const SizedBox(height: AppSpacing.md),

            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.4,
              ),
              children: [
                _MetricCard(
                  label: 'Pending Bookings',
                  value: '$pending',
                  icon: Icons.pending_actions,
                  color: AppColors.warning,
                  onTap: () => _openList(context, BookingStatus.pending),
                ),
                _MetricCard(
                  label: 'Confirmed Bookings',
                  value: '$confirmed',
                  icon: Icons.verified_outlined,
                  color: AppColors.success,
                  onTap: () => _openList(context, BookingStatus.confirmed),
                ),
                _MetricCard(
                  label: 'Total Demo Bookings',
                  value: '$total',
                  icon: Icons.event_note_outlined,
                  color: AppColors.primary,
                  onTap: () => _openList(context, null),
                ),
                _MetricCard(
                  label: 'Travelers in Demo Bookings',
                  value: '$travellers',
                  icon: Icons.people_outline,
                  color: AppColors.accent,
                  onTap: () => _openList(context, null),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            YatraPrimaryButton(
              label: AppStrings.tr(language, 'admin.bookings'),
              icon: Icons.list_alt_outlined,
              onPressed: () => _openList(context, null),
            ),
          ],
        ),
      ),
    );
  }

  void _openList(BuildContext context, BookingStatus? status) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminBookingListScreen(initialStatus: status),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return YatraCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const Spacer(),
          Text(value, style: AppType.display.copyWith(fontSize: 26)),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
