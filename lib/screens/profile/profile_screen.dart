import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/demo_booking_store.dart';
import '../../services/demo_profile_store.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sos_action.dart';
import '../../widgets/yatra_components.dart';
import '../admin/admin_screen.dart';
import '../auth/login_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../offline/offline_access_screen.dart';

/// Profile screen backed by the authenticated user's Firestore profile.
///
/// DemoProfileStore is temporarily kept as a compatibility cache because
/// several language-aware and fallback screens still depend on it.
/// It will be removed after those screens are migrated to Firestore.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = const AuthService();

  FirestoreService? _firestore;
  UserProfile? _profile;

  bool _loadingProfile = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _initializeProfileBackend();
  }

  /// Creates the Firestore service when Firebase is available.
  ///
  /// Widget tests currently run without a Firebase app, so in that
  /// environment the screen falls back to DemoProfileStore.
  Future<void> _initializeProfileBackend() async {
    try {
      _firestore = FirestoreService();
    } catch (_) {
      return;
    }

    await _loadProfile();
  }

  /// Loads the authenticated user's profile from:
  ///
  /// users/{firebaseUid}
  Future<void> _loadProfile() async {
    final firestore = _firestore;

    if (firestore == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _loadingProfile = true;
        _profileError = null;
      });
    }

    try {
      final profile = await firestore.getCurrentUserProfile();

      if (!mounted) return;

      if (profile != null) {
        _syncDemoProfile(profile);
      }

      setState(() {
        _profile = profile;
        _loadingProfile = false;
        _profileError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _profileError = 'Unable to load your profile.';
        _loadingProfile = false;
      });
    }
  }

  /// Temporary bridge while the rest of the frontend is still using
  /// DemoProfileStore for language compatibility.
  void _syncDemoProfile(UserProfile profile) {
    final demo = DemoProfileStore.instance;

    demo.setProfile(
      name: profile.name,
      phone: profile.phone,
      clearMissing: true,
    );

    demo.setEmergencyContact(
      name: profile.emergencyContactName,
      phone: profile.emergencyContactPhone,
      clearMissing: true,
    );

    demo.setTouristType(profile.touristType);
    demo.setLanguage(profile.language);
  }

  Future<void> _editProfile() async {
    final demo = DemoProfileStore.instance;

    final currentName = _profile?.name.isNotEmpty == true
        ? _profile!.name
        : demo.name ?? _firebaseName();

    final currentPhone = _profile?.phone ?? demo.phone ?? '';

    final result = await _showTextFields(
      title: 'Edit Profile',
      fields: (label: 'Name', initial: currentName, icon: Icons.person_outline),
      fieldsB: (
        label: 'Phone',
        initial: currentPhone,
        icon: Icons.phone_outlined,
      ),
    );

    if (result == null) {
      return;
    }

    final firestore = _firestore;

    // Used by widget tests or environments without initialized Firebase.
    if (firestore == null) {
      demo.setProfile(name: result.$1, phone: result.$2);

      if (mounted) {
        setState(() {});
      }

      return;
    }

    try {
      await firestore.updatePersonalInfo(name: result.$1, phone: result.$2);

      await _loadProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update profile. Please try again.'),
        ),
      );
    }
  }

  Future<void> _editEmergencyContact() async {
    final demo = DemoProfileStore.instance;

    final result = await _showTextFields(
      title: 'Emergency Contact',
      fields: (
        label: 'Name',
        initial:
            _profile?.emergencyContactName ?? demo.emergencyContactName ?? '',
        icon: Icons.person_outline,
      ),
      fieldsB: (
        label: 'Phone',
        initial:
            _profile?.emergencyContactPhone ?? demo.emergencyContactPhone ?? '',
        icon: Icons.phone_outlined,
      ),
    );

    if (result == null) {
      return;
    }

    final firestore = _firestore;

    // Used by widget tests or environments without initialized Firebase.
    if (firestore == null) {
      demo.setEmergencyContact(name: result.$1, phone: result.$2);

      if (mounted) {
        setState(() {});
      }

      return;
    }

    try {
      await firestore.updateEmergencyContact(name: result.$1, phone: result.$2);

      await _loadProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency contact updated.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update emergency contact. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _changeLanguage(String language) async {
    final firestore = _firestore;

    // Test/frontend fallback.
    if (firestore == null) {
      DemoProfileStore.instance.setLanguage(language);

      if (mounted) {
        setState(() {});
      }

      return;
    }

    try {
      await firestore.updateLanguage(language);

      // Temporary compatibility cache for screens that have not yet
      // migrated away from DemoProfileStore.
      DemoProfileStore.instance.setLanguage(language);

      await _loadProfile();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save language preference.')),
      );
    }
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

    if (confirmed != true || !mounted) {
      return;
    }

    await _auth.signOut();

    // These are only local runtime caches.
    // Firestore profile data is NOT deleted on logout.
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
    final demoProfile = DemoProfileStore.instance;

    final language = _profile?.language ?? demoProfile.language;

    final displayName = _profile?.name.isNotEmpty == true
        ? _profile!.name
        : demoProfile.name ?? _firebaseName();

    final email = (_profile?.email.isNotEmpty == true)
        ? _profile!.email
        : _firebaseEmail();

    final phone = _profile?.phone ?? demoProfile.phone;

    final touristType = _profile?.touristType ?? demoProfile.touristType;

    final emergencyContactName =
        _profile?.emergencyContactName ?? demoProfile.emergencyContactName;

    final emergencyContactPhone =
        _profile?.emergencyContactPhone ?? demoProfile.emergencyContactPhone;

    final displayPhone = phone == null || phone.trim().isEmpty
        ? 'Not set'
        : phone;

    final displayEmergencyPhone =
        emergencyContactPhone == null || emergencyContactPhone.trim().isEmpty
        ? 'Not set'
        : emergencyContactPhone;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'profile.title')),
        actions: const [YatraSosAction()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (_loadingProfile) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_profileError != null) ...[
              YatraCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cloud_off_outlined),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(_profileError!, style: AppType.caption),
                    ),
                    TextButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            _HeaderCard(name: displayName, email: email),

            const SizedBox(height: AppSpacing.xxl),

            const YatraSectionTitle(
              title: 'Personal Info',
              subtitle:
                  'Your account information is saved to your Yatra profile.',
            ),

            const SizedBox(height: AppSpacing.md),

            YatraCard(
              child: Column(
                children: [
                  YatraInfoRow(label: 'Name', value: displayName),
                  YatraInfoRow(label: 'Phone', value: displayPhone),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            YatraSecondaryButton(
              label: 'Edit Profile',
              icon: Icons.edit_outlined,
              onPressed: _loadingProfile ? null : _editProfile,
            ),

            const SizedBox(height: AppSpacing.xxl),

            const YatraSectionTitle(title: 'Travel Preferences'),

            const SizedBox(height: AppSpacing.md),

            YatraCard(
              child: Column(
                children: [
                  YatraInfoRow(
                    label: 'Tourist Type',
                    value: touristType ?? 'Not set yet',
                    emphasized:
                        touristType != null && touristType.trim().isNotEmpty,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: YatraInfoRow(
                      label: 'Note',
                      value:
                          'Your default tourist type is used to personalize pricing. '
                          'Each planned trip keeps its own tourist type.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            const YatraSectionTitle(
              title: 'Emergency Contact',
              subtitle: 'Included in your SOS share message.',
            ),

            const SizedBox(height: AppSpacing.md),

            YatraCard(
              child: (emergencyContactName ?? '').trim().isEmpty
                  ? const Text(
                      'No emergency contact saved. '
                      'Add one so SOS can include it.',
                      style: AppType.caption,
                    )
                  : Column(
                      children: [
                        YatraInfoRow(
                          label: 'Name',
                          value: emergencyContactName!,
                        ),
                        YatraInfoRow(
                          label: 'Phone',
                          value: displayEmergencyPhone,
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: AppSpacing.md),

            YatraSecondaryButton(
              label: 'Edit Emergency Contact',
              icon: Icons.person_add_alt_outlined,
              onPressed: _loadingProfile ? null : _editEmergencyContact,
            ),

            const SizedBox(height: AppSpacing.xxl),

            const YatraSectionTitle(
              title: 'Language',
              subtitle:
                  'Select the UI language for the new screens. '
                  'Full app translation is not available yet.',
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
                      onTap: _loadingProfile
                          ? null
                          : () => _changeLanguage(supported),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            const YatraSectionTitle(title: 'Your Stuff'),

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

            const YatraSectionTitle(
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
      // Firebase is not initialized in some widget tests.
      return 'Yatra traveler';
    }
  }

  String _firebaseEmail() {
    try {
      return FirebaseAuth.instance.currentUser?.email ?? '';
    } catch (_) {
      // Firebase is not initialized in some widget tests.
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
