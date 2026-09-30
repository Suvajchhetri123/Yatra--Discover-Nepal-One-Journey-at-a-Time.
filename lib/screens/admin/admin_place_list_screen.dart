import 'package:flutter/material.dart';

import '../../models/place_model.dart';
import '../../services/firestore_place_service.dart';
import '../../services/place_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_content_messages.dart';
import 'admin_place_form_screen.dart';

/// Admin list of the place registry.
///
/// Reads through [PlaceRepository] (Firestore by default). Removal is a soft
/// deactivation, so a place referenced by a historic booking or itinerary is
/// never destroyed.
class AdminPlaceListScreen extends StatefulWidget {
  final PlaceRepository? repository;

  const AdminPlaceListScreen({super.key, this.repository});

  @override
  State<AdminPlaceListScreen> createState() => _AdminPlaceListScreenState();
}

class _AdminPlaceListScreenState extends State<AdminPlaceListScreen> {
  late final PlaceRepository _repository =
      widget.repository ?? FirestorePlaceService();

  List<Place> _places = <Place>[];

  bool _includeInactive = false;

  bool _loading = true;

  /// Id of the record currently being deactivated/restored, so only that card
  /// shows a spinner and a double tap cannot fire the write twice.
  String? _busyId;

  String? _error;

  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final token = ++_loadToken;

    try {
      final places = await _repository.getAllPlaces(
        includeInactive: _includeInactive,
      );

      if (!mounted || token != _loadToken) return;

      setState(() {
        _places = List<Place>.of(places);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;

      if (_places.isNotEmpty) {
        setState(() => _loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kAdminCatalogLoadFailureMessage)),
        );

        return;
      }

      setState(() {
        _error = kAdminCatalogLoadFailureMessage;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Place? place}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminPlaceFormScreen(place: place, repository: _repository),
      ),
    );

    if (saved == true) await _load(showLoader: false);
  }

  Future<void> _setActive(Place place, bool active) async {
    if (_busyId != null) return;

    setState(() => _busyId = place.id);

    try {
      await _repository.setPlaceActive(place.id, active);

      if (!mounted) return;

      setState(() {
        _places = _places
            .map(
              (item) =>
                  item.id == place.id ? item.copyWith(active: active) : item,
            )
            .where((item) => _includeInactive || item.active)
            .toList();
        _busyId = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _busyId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kAdminCatalogSaveFailureMessage)),
      );
    }
  }

  void _setIncludeInactive(bool value) {
    if (_includeInactive == value) return;

    setState(() {
      _includeInactive = value;
      _places = <Place>[];
    });

    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Places')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  YatraChip(
                    label: 'Active',
                    selected: !_includeInactive,
                    onSelected: (_) => _setIncludeInactive(false),
                    isFilter: true,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  YatraChip(
                    label: 'All',
                    selected: _includeInactive,
                    onSelected: (_) => _setIncludeInactive(true),
                    isFilter: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              YatraEmptyState(icon: Icons.cloud_off_outlined, message: error),
              const SizedBox(height: AppSpacing.lg),
              YatraPrimaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    if (_places.isEmpty) {
      return YatraEmptyState(
        icon: Icons.place_outlined,
        message: 'No places',
        hint: _includeInactive
            ? 'Add a place to start curating destinations.'
            : 'No active places. Switch to "All" to see deactivated ones.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoader: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          96,
        ),
        children: [
          Text(
            '${_places.length} place${_places.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final place in _places)
            _PlaceCard(
              place: place,
              busy: _busyId == place.id,
              onEdit: () => _openForm(place: place),
              onToggleActive: () => _setActive(place, !place.active),
            ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Place place;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _PlaceCard({
    required this.place,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
  });

  /// Shows the universal price, or the explicit segment rates when the place
  /// has domestic/international overrides.
  static String _feeSummary(Place place) {
    final pricing = place.touristEntryFee;

    if (pricing == null) {
      return 'NPR ${_amount(place.entryFee)} for every tourist';
    }

    return 'Domestic ${_optionalAmount(pricing.domestic)} · '
        'International ${_optionalAmount(pricing.international)}';
  }

  static String _amount(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  static String _optionalAmount(double? value) {
    if (value == null) return 'universal';

    return 'NPR ${_amount(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: YatraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(place.name, style: textTheme.titleMedium)),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  YatraStatusBadge(
                    label: place.active ? 'Active' : 'Inactive',
                    color: place.active
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(place.location, style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(_feeSummary(place), style: textTheme.bodySmall),
            if (place.recommendedHours > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'About ${_amount(place.recommendedHours)} h',
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: YatraSecondaryButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onPressed: busy ? null : onEdit,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: YatraSecondaryButton(
                    label: place.active ? 'Remove' : 'Restore',
                    icon: place.active
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    onPressed: busy ? null : onToggleActive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
