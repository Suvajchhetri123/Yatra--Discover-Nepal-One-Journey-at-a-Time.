import 'package:flutter/material.dart';

import '../../models/package_model.dart';
import '../../services/firestore_package_service.dart';
import '../../services/package_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_content_messages.dart';
import 'admin_package_form_screen.dart';

/// Admin list of the tour package registry.
///
/// Reads through [PackageRepository] (Firestore by default). Removal is a soft
/// deactivation, so a package already chosen by a traveller is not destroyed.
class AdminPackageListScreen extends StatefulWidget {
  final PackageRepository? repository;

  const AdminPackageListScreen({super.key, this.repository});

  @override
  State<AdminPackageListScreen> createState() => _AdminPackageListScreenState();
}

class _AdminPackageListScreenState extends State<AdminPackageListScreen> {
  late final PackageRepository _repository =
      widget.repository ?? FirestorePackageService();

  List<TourPackage> _packages = <TourPackage>[];

  bool _includeInactive = false;

  bool _loading = true;

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
      final packages = await _repository.getAllPackages(
        includeInactive: _includeInactive,
      );

      if (!mounted || token != _loadToken) return;

      setState(() {
        _packages = List<TourPackage>.of(packages);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;

      if (_packages.isNotEmpty) {
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

  Future<void> _openForm({TourPackage? package}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminPackageFormScreen(package: package, repository: _repository),
      ),
    );

    if (saved == true) await _load(showLoader: false);
  }

  Future<void> _setActive(TourPackage package, bool active) async {
    if (_busyId != null) return;

    setState(() => _busyId = package.id);

    try {
      await _repository.setPackageActive(package.id, active);

      if (!mounted) return;

      setState(() {
        _packages = _packages
            .map(
              (item) =>
                  item.id == package.id ? item.copyWith(active: active) : item,
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
      _packages = <TourPackage>[];
    });

    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Packages')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_business_outlined),
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

    if (_packages.isEmpty) {
      return YatraEmptyState(
        icon: Icons.luggage_outlined,
        message: 'No packages',
        hint: _includeInactive
            ? 'Add a package to start curating trips.'
            : 'No active packages. Switch to "All" to see removed ones.',
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
            '${_packages.length} package${_packages.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final package in _packages)
            _PackageCard(
              package: package,
              busy: _busyId == package.id,
              onEdit: () => _openForm(package: package),
              onToggleActive: () => _setActive(package, !package.active),
            ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final TourPackage package;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _PackageCard({
    required this.package,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
  });

  static String _amount(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  /// Universal price, or the explicit segment rates when the package has
  /// domestic/international overrides.
  static String _priceSummary(TourPackage package) {
    final pricing = package.touristPrice;

    if (pricing == null) {
      return 'NPR ${_amount(package.price)} for every tourist';
    }

    final domestic = pricing.domestic;
    final international = pricing.international;

    return 'Domestic ${domestic == null ? 'universal' : 'NPR ${_amount(domestic)}'}'
        ' · International '
        '${international == null ? 'universal' : 'NPR ${_amount(international)}'}';
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
                Expanded(
                  child: Text(package.title, style: textTheme.titleMedium),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  YatraStatusBadge(
                    label: package.active ? 'Active' : 'Inactive',
                    color: package.active
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${package.region} · ${package.durationDays} day'
              '${package.durationDays == 1 ? '' : 's'} · ${package.difficulty}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(_priceSummary(package), style: textTheme.bodySmall),
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
                    label: package.active ? 'Remove' : 'Restore',
                    icon: package.active
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
