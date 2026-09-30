import 'package:flutter/material.dart';

import '../../models/travel_coordinator.dart';
import '../../services/coordinator_repository.dart';
import '../../services/firestore_coordinator_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_content_messages.dart';
import 'admin_coordinator_form_screen.dart';

/// Admin list of the coordinator registry.
///
/// Reads through [CoordinatorRepository] (Firestore by default). Removal is a
/// soft deactivation, so a coordinator can be restored later and historic
/// booking snapshots stay valid.
class AdminCoordinatorListScreen extends StatefulWidget {
  final CoordinatorRepository? repository;

  const AdminCoordinatorListScreen({super.key, this.repository});

  @override
  State<AdminCoordinatorListScreen> createState() =>
      _AdminCoordinatorListScreenState();
}

class _AdminCoordinatorListScreenState
    extends State<AdminCoordinatorListScreen> {
  /// Resolved lazily so an injected repository is never bypassed.
  late final CoordinatorRepository _repository =
      widget.repository ?? FirestoreCoordinatorService();

  List<TravelCoordinator> _coordinators = <TravelCoordinator>[];

  /// When true, deactivated coordinators are listed too.
  bool _includeInactive = false;

  bool _loading = true;

  /// Id of the record currently being deactivated/restored, so only that card
  /// shows a spinner and a double tap cannot fire the write twice.
  String? _busyId;

  String? _error;

  /// Guards against a stale read overwriting a newer one.
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
      final coordinators = await _repository.getCoordinators(
        includeInactive: _includeInactive,
      );

      if (!mounted || token != _loadToken) return;

      setState(() {
        _coordinators = List<TravelCoordinator>.of(coordinators);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;

      // Keep an already-rendered list when a background refresh fails.
      if (_coordinators.isNotEmpty) {
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

  Future<void> _openForm({TravelCoordinator? coordinator}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCoordinatorFormScreen(
          coordinator: coordinator,
          repository: _repository,
        ),
      ),
    );

    if (saved == true) await _load(showLoader: false);
  }

  Future<void> _setActive(TravelCoordinator coordinator, bool active) async {
    if (_busyId != null) return;

    setState(() => _busyId = coordinator.id);

    try {
      await _repository.setCoordinatorActive(coordinator.id, active);

      if (!mounted) return;

      // Patch in place so the card does not flash away on a soft removal.
      setState(() {
        _coordinators = _coordinators
            .map(
              (item) => item.id == coordinator.id
                  ? item.copyWith(active: active)
                  : item,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coordinators')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt),
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

  void _setIncludeInactive(bool value) {
    if (_includeInactive == value) return;

    setState(() {
      _includeInactive = value;
      _coordinators = <TravelCoordinator>[];
    });

    _load();
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

    if (_coordinators.isEmpty) {
      return YatraEmptyState(
        icon: Icons.support_agent_outlined,
        message: 'No coordinators',
        hint: _includeInactive
            ? 'Add a coordinator to make them available for assignment.'
            : 'No active coordinators. Switch to "All" to see deactivated '
                  'ones.',
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
            '${_coordinators.length} coordinator'
            '${_coordinators.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final coordinator in _coordinators)
            _CoordinatorCard(
              coordinator: coordinator,
              busy: _busyId == coordinator.id,
              onEdit: () => _openForm(coordinator: coordinator),
              onToggleActive: () =>
                  _setActive(coordinator, !coordinator.active),
            ),
        ],
      ),
    );
  }
}

class _CoordinatorCard extends StatelessWidget {
  final TravelCoordinator coordinator;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _CoordinatorCard({
    required this.coordinator,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
  });

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
                Expanded(
                  child: Text(coordinator.name, style: textTheme.titleMedium),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  YatraStatusBadge(
                    label: coordinator.active ? 'Active' : 'Inactive',
                    color: coordinator.active
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(coordinator.phone, style: textTheme.bodySmall),
            Text(coordinator.email, style: textTheme.bodySmall),
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
                    label: coordinator.active ? 'Deactivate' : 'Restore',
                    icon: coordinator.active
                        ? Icons.person_off_outlined
                        : Icons.person_add_alt,
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
