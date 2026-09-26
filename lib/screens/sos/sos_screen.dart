import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';

/// How an SOS share request is resolved.
typedef LocationProvider = Future<Position?> Function();
typedef PermissionCheck = Future<bool> Function();
typedef ProfileProvider = Future<UserProfile?> Function();

/// Fetches the user's position for the SOS flow.
Future<Position?> _defaultLocationProvider() =>
    LocationService.getCurrentLocation();

/// Whether location access is allowed for the SOS flow.
Future<bool> _defaultPermissionCheck() =>
    LocationService.isLocationAccessAllowed();

/// Fetches the authenticated user's saved Firestore profile.
Future<UserProfile?> _defaultProfileProvider() =>
    FirestoreService().getCurrentUserProfile();

/// Builds the shareable SOS message. Kept as a pure function so widget tests
/// can assert on it without any platform plugins.
String buildSosMessage({
  required String name,
  required String phone,
  required String emergencyContactName,
  required String emergencyContactPhone,
  required double? latitude,
  required double? longitude,
  required String destination,
}) {
  final location = latitude == null || longitude == null
      ? 'current location could not be pinned. Sharing approximate area only.'
      : 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  return [
    'URGENT — SOS HELP REQUEST from $name.',
    'Phone: $phone',
    if (emergencyContactName.isNotEmpty)
      'Emergency contact: $emergencyContactName ($emergencyContactPhone)',
    'My destination: $destination',
    'My location: $location',
  ].join('\n');
}

/// SOS screen. Location is read on-device, profile details are loaded from
/// Firestore, and the user explicitly shares the prepared message. Nothing is
/// sent automatically.
class SosScreen extends StatefulWidget {
  final LocationProvider? locationProvider;
  final PermissionCheck? permissionCheck;
  final ProfileProvider? profileProvider;

  const SosScreen({
    super.key,
    this.locationProvider,
    this.permissionCheck,
    this.profileProvider,
  });

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _loading = true;
  bool _allowed = false;
  Position? _position;
  String? _error;

  UserProfile? _profile;
  bool _profileLoading = true;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _locate();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final provider = widget.profileProvider ?? _defaultProfileProvider;

    try {
      final profile = await provider();
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _profileLoading = false;
        _profileError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _profile = null;
        _profileLoading = false;
        _profileError =
            'Saved profile information could not be loaded. You can still '
            'share your current location.';
      });
    }
  }

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final check = widget.permissionCheck ?? _defaultPermissionCheck;
    final provider = widget.locationProvider ?? _defaultLocationProvider;

    try {
      final allowed = await check();
      if (!mounted) return;

      if (!allowed) {
        setState(() {
          _loading = false;
          _allowed = false;
        });
        return;
      }

      final position = await provider();
      if (!mounted) return;

      setState(() {
        _loading = false;
        _allowed = true;
        _position = position;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not read your location. Check location permissions and try again.';
      });
    }
  }

  Future<void> _shareSos() async {
    final profile = _profile;
    final name = profile?.name.trim() ?? '';
    final phone = profile?.phone?.trim() ?? '';
    final emergencyContactName = profile?.emergencyContactName?.trim() ?? '';
    final emergencyContactPhone = profile?.emergencyContactPhone?.trim() ?? '';

    final message = buildSosMessage(
      name: name.isEmpty ? 'Yatra traveler' : name,
      phone: phone.isEmpty ? '-' : phone,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      latitude: _position?.latitude,
      longitude: _position?.longitude,
      destination: _profileDestination(),
    );

    await SharePlus.instance.share(ShareParams(text: message));
  }

  String _profileDestination() {
    return 'My planned trip in Nepal';
  }

  void _openSettings() {
    Geolocator.openAppSettings();
  }

  void _openGoogleMaps() {
    final position = _position;
    if (position == null) return;
    launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query='
        '${position.latitude},${position.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = _profile?.language ?? 'English';

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr(language, 'sos.title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YatraCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'SOS never sends anything automatically. You review '
                        'and share your location + emergency contact message '
                        'below.',
                        style: AppType.bodyEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Emergency Contact'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(child: _buildEmergencyContactCard()),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Current Location'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(child: _buildLocationCard()),

              const SizedBox(height: AppSpacing.xl),

              if (_loading)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (!_allowed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _error ??
                          'Location access is not allowed. Allow location '
                              'permission for Yatra so SOS can pin where you are.',
                      style: AppType.bodyEmphasis,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    YatraSecondaryButton(
                      label: 'Open Location Settings',
                      icon: Icons.settings,
                      onPressed: _openSettings,
                    ),
                  ],
                )
              else if (_error != null)
                Text(_error!, style: AppType.bodyEmphasis)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YatraPrimaryButton(
                      label: 'Share SOS Message',
                      icon: Icons.emergency_share,
                      onPressed: _shareSos,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    YatraSecondaryButton(
                      label: 'Open My Location in Google Maps',
                      icon: Icons.map_outlined,
                      onPressed: _openGoogleMaps,
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.xl),

              YatraSectionTitle(title: 'Emergency Numbers'),
              const SizedBox(height: AppSpacing.md),
              YatraCard(
                child: Column(
                  children: [
                    _numberRow('Police', '100'),
                    _numberRow('Fire', '101'),
                    _numberRow('Ambulance', '102'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactCard() {
    if (_profileLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.md),
          Text('Loading emergency contact…'),
        ],
      );
    }

    if (_profileError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_profileError!, style: AppType.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You can add or update an emergency contact in Profile.',
            style: AppType.caption,
          ),
        ],
      );
    }

    final contactName = _profile?.emergencyContactName?.trim() ?? '';
    if (contactName.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No emergency contact saved yet.', style: AppType.bodyEmphasis),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add one in Profile so it is included in your SOS share message.',
            style: AppType.caption,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(contactName, style: AppType.bodyEmphasis),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _profile?.emergencyContactPhone?.trim() ?? '',
          style: AppType.caption,
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    if (_loading) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.md),
          Text('Locating you…'),
        ],
      );
    }

    if (!_allowed) {
      return Row(
        children: [
          Icon(Icons.location_off, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(_error ?? 'No location access.')),
        ],
      );
    }

    final position = _position;
    if (position == null) {
      return const Row(
        children: [
          Icon(Icons.location_disabled, color: AppColors.warning),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Could not pin your exact location. Share message will note '
              'this and still work.',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.my_location, color: AppColors.success),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${position.latitude.toStringAsFixed(5)}, '
              '${position.longitude.toStringAsFixed(5)}',
              style: AppType.bodyEmphasis,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Located. Your SOS message includes a Google Maps pin.',
          style: AppType.caption,
        ),
      ],
    );
  }

  Widget _numberRow(String label, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(number, style: AppType.label),
        ],
      ),
    );
  }
}
