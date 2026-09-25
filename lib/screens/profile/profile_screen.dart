import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/demo_booking_store.dart';
import '../../services/demo_profile_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sos_action.dart';
import '../../widgets/yatra_components.dart';
import '../admin/admin_screen.dart';
import '../auth/login_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../offline/offline_access_screen.dart';

/// Profile — frontend-only personal settings, SOS emergency contact, the
/// English/Nepali language selector, and entries to My Bookings / Offline /
/// the Admin demo. Logout is confirmed before signing out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = const AuthService();

  Future<void> _editProfile() async {
    final profile = DemoProfileStore.instance;

    final result = await _showTextFields(
      title: 'Edit Profile',
      fields: (
        label: 'Name',
        initial: profile.name ?? '',
        icon: Icons.person_outline,
      ),
      fieldsB: (
        label: 'Phone',
        initial: profile.phone ?? '',
        icon: Icons.phone_outlined,
      ),
    );

    if (result == null) return;

    DemoProfileStore.instance.setProfile(name: result.$1, phone: result.$2);

    if (mounted) setState(() {});
  }

  Future<void> _editEmergencyContact() async {
    final profile = DemoProfileStore.instance;

    final result = await _showTextFields(
      title: 'Emergency Contact',
      fields: (
        label: 'Name',
        initial: profile.emergencyContactName ?? '',
        icon: Icons.person_outline,
      ),
      fieldsB: (
        label: 'Phone',
        initial: profile.emergencyContactPhone ?? '',
        icon: Icons.phone_outlined,
      ),
    );

    if (result == null) return;

    DemoProfileStore.instance.setEmergencyContact(
      name: result.$1,
      phone: result.$2,
    );

    if (mounted) setState(() {});
  }

  Future<(String, String)?> _showTextFields({
    required String title,
    required ({String label, String initial, IconData icon}) fields,
    required ({String label, String initial, IconData icon}) fieldsB,
  }) {
    return showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) =>
          _EditFieldsDialog(title: title, fields: fields, fieldsB: fieldsB),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to log out?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _auth.signOut();
    DemoBookingStore.instance.clear();
    DemoProfileStore.instance.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openAdmin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminScreen()),
    );
  }

  void _openBookings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
    );
  }

  void _openOffline() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OfflineAccessScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = DemoProfileStore.instance;
    final language = profile.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'profile.title')),
        actions: const [YatraSosAction()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _HeaderCard(
              name: profile.name ?? _firebaseName(),
              email: _firebaseEmail(),
            ),
            const SizedBox(height: AppSpacing.xxl),

            YatraSectionTitle(
              title: 'Personal Info',
              subtitle:
                  'Frontend-only for now — syncs to your Firebase '
                  'profile in the backend phase.',
            ),
            const SizedBox(height: AppSpacing.md),
            YatraCard(
              child: Column(
                children: [
                  YatraInfoRow(
                    label: 'Name',
                    value: profile.name ?? _firebaseName(),
                  ),
                  YatraInfoRow(
                    label: 'Phone',
                    value: profile.phone ?? 'Not set',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            YatraSecondaryButton(
              label: 'Edit Profile',
              icon: Icons.edit_outlined,
              onPressed: _editProfile,
            ),

            const SizedBox(height: AppSpacing.xxl),

            YatraSectionTitle(title: 'Travel Preferences'),
            const SizedBox(height: AppSpacing.md),
            YatraCard(
              child: Column(
                children: [
                  YatraInfoRow(
                    label: 'Tourist Type',
                    value: profile.touristType ?? 'Not set yet',
                    emphasized: profile.touristType != null,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: YatraInfoRow(
                      label: 'Note',
                      value:
                          'Your tourist type is chosen while planning a trip '
                          'and applies to that trip only.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            YatraSectionTitle(
              title: 'Emergency Contact',
              subtitle: 'Included in your SOS share message.',
            ),
            const SizedBox(height: AppSpacing.md),
            YatraCard(
              child: (profile.emergencyContactName ?? '').isEmpty
                  ? const Text(
                      'No emergency contact saved. Add one so SOS can include '
                      'it.',
                      style: AppType.caption,
                    )
                  : Column(
                      children: [
                        YatraInfoRow(
                          label: 'Name',
                          value: profile.emergencyContactName!,
                        ),
                        YatraInfoRow(
                          label: 'Phone',
                          value: profile.emergencyContactPhone ?? 'Not set',
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            YatraSecondaryButton(
              label: 'Edit Emergency Contact',
              icon: Icons.person_add_alt_outlined,
              onPressed: _editEmergencyContact,
            ),

            const SizedBox(height: AppSpacing.xxl),

            YatraSectionTitle(
              title: 'Language',
              subtitle:
                  'Select the UI language for the new screens. Full app '
                  'translation is not available yet.',
            ),
            const SizedBox(height: AppSpacing.md),
            YatraCard(
              child: Column(
                children: [
                  for (final supported in AppStrings.supportedLanguages)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        supported == 'English'
                            ? Icons.language
                            : Icons.translate,
                        color: AppColors.primary,
                      ),
                      title: Text(supported),
                      trailing: language == supported
                          ? Icon(Icons.check_circle, color: AppColors.success)
                          : null,
                      onTap: () {
                        DemoProfileStore.instance.setLanguage(supported);
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            YatraSectionTitle(title: 'Your Stuff'),
            const SizedBox(height: AppSpacing.md),
            YatraCard(
              child: Column(
                children: [
                  _menuRow(
                    icon: Icons.confirmation_num_outlined,
                    label: 'My Bookings',
                    onTap: _openBookings,
                  ),
                  _menuRow(
                    icon: Icons.cloud_off_outlined,
                    label: 'Offline Access',
                    onTap: _openOffline,
                  ),
                  _menuRow(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Admin (Demo)',
                    caption: 'Frontend-only admin dashboard',
                    onTap: _openAdmin,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            YatraSectionTitle(
              title: 'Account',
              subtitle: 'Sign out of Yatra on this device.',
            ),
            const SizedBox(height: AppSpacing.md),
            YatraCard(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _confirmLogout,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Log Out'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _firebaseName() {
    try {
      return FirebaseAuth.instance.currentUser?.displayName ?? 'Yatra traveler';
    } catch (_) {
      // Test environment or not yet signed in.
      return 'Yatra traveler';
    }
  }

  String _firebaseEmail() {
    try {
      return FirebaseAuth.instance.currentUser?.email ?? '';
    } catch (_) {
      // Test environment or not yet signed in.
      return '';
    }
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    String? caption,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: caption == null ? null : Text(caption),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

class _EditFieldsDialog extends StatefulWidget {
  final String title;
  final ({String label, String initial, IconData icon}) fields;
  final ({String label, String initial, IconData icon}) fieldsB;

  const _EditFieldsDialog({
    required this.title,
    required this.fields,
    required this.fieldsB,
  });

  @override
  State<_EditFieldsDialog> createState() => _EditFieldsDialogState();
}

class _EditFieldsDialogState extends State<_EditFieldsDialog> {
  late final TextEditingController _controllerA;
  late final TextEditingController _controllerB;

  @override
  void initState() {
    super.initState();
    _controllerA = TextEditingController(text: widget.fields.initial);
    _controllerB = TextEditingController(text: widget.fieldsB.initial);
  }

  @override
  void dispose() {
    _controllerA.dispose();
    _controllerB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controllerA,
            decoration: InputDecoration(
              labelText: widget.fields.label,
              prefixIcon: Icon(widget.fields.icon, size: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controllerB,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: widget.fieldsB.label,
              prefixIcon: Icon(widget.fieldsB.icon, size: 20),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            _controllerA.text.trim(),
            _controllerB.text.trim(),
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String email;

  const _HeaderCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return YatraCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person, size: 32, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppType.bodyEmphasis.copyWith(fontSize: 18)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  email,
                  style: AppType.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
