import 'package:flutter/widgets.dart';

import '../models/package_model.dart';
import '../models/place_model.dart';
import 'package_repository.dart';
import 'place_repository.dart';

/// Where a catalog load currently stands.
///
/// A single enum (rather than three ad-hoc booleans) keeps the impossible
/// combinations unrepresentable: there is never "loading and error", and a
/// "ready" state always carries a result.
enum CatalogStatus { idle, loading, ready, error }

/// Read model for the places and packages the tourist app is allowed to see.
///
/// This is the runtime replacement for reading `places_data.dart` /
/// `packages_data.dart` directly in a screen. Both catalogs come from
/// [PlaceRepository] and [PackageRepository], which are Firestore-backed in
/// production, so an admin edit is visible to the tourist without a code
/// change or an app release.
///
/// Design decisions worth stating:
///
///   - **Load is explicit, not implicit.** [load] is called from `initState`,
///     never from `build`, so navigation does not re-query Firestore and the
///     widget cannot be mutated while the tree is building.
///   - **Only active records are visible.** Both repositories default to
///     `includeInactive: false`, and that default is deliberately *not*
///     overridden here: the tourist catalog must never surface something an
///     admin removed.
///   - **A failed refresh keeps the last good catalog.** When a reload fails
///     the previously loaded data stays readable and [status] becomes
///     [CatalogStatus.error] with [errorMessage] set, so the UI can show a
///     retry affordance instead of blanking the screen.
///   - **Data is injected.** The repositories are constructor parameters, so
///     widget and unit tests pass fakes and never boot Firebase.
class TouristCatalogController extends ChangeNotifier {
  TouristCatalogController({
    PlaceRepository? placeRepository,
    PackageRepository? packageRepository,
  }) : _places = placeRepository,
       _packages = packageRepository;

  final PlaceRepository? _places;
  final PackageRepository? _packages;

  CatalogStatus _status = CatalogStatus.idle;
  CatalogStatus _refreshStatus = CatalogStatus.idle;

  List<Place> _placeCatalog = const <Place>[];
  List<TourPackage> _packageCatalog = const <TourPackage>[];

  String? _errorMessage;

  /// How the current data set was obtained.
  CatalogStatus get status => _status;

  /// Status of a *background refresh* on top of already-loaded data.
  ///
  /// Separate from [status] so a pull-to-refresh can show a spinner without
  /// the screen falling back to its loading skeleton.
  CatalogStatus get refreshStatus => _refreshStatus;

  /// Active places, sorted by name. Empty until the first successful load.
  List<Place> get places => _placeCatalog;

  /// Active packages, sorted by title. Empty until the first successful load.
  List<TourPackage> get packages => _packageCatalog;

  /// Regions that actually have an active package, alphabetically.
  ///
  /// Derived from the loaded packages rather than a static list, so a region
  /// only appears once an admin has published a package for it and disappears
  /// again when its last package is removed.
  List<String> get regions {
    final seen = <String>{};

    for (final package in _packageCatalog) {
      seen.add(package.region);
    }

    final regions = seen.toList()..sort();

    return regions;
  }

  /// True once a load has completed, whether or not it produced records.
  bool get isReady => _status == CatalogStatus.ready;

  /// True during the very first load, when there is nothing to show yet.
  bool get isLoading =>
      _status == CatalogStatus.loading && _placeCatalog.isEmpty;

  /// True when a load completed but the catalog is genuinely empty.
  bool get isEmpty =>
      _status == CatalogStatus.ready &&
      _placeCatalog.isEmpty &&
      _packageCatalog.isEmpty;

  /// Human-readable failure text for [CatalogStatus.error], else null.
  String? get errorMessage => _errorMessage;

  /// True while a refresh runs over an already-visible catalog.
  bool get isRefreshing => _refreshStatus == CatalogStatus.loading;

  /// Loads both catalogs.
  ///
  /// [force] re-queries even when a good result is already cached, which is
  /// what an explicit user-triggered refresh wants; without it a cached result
  /// is reused so returning to a screen does not hit Firestore again.
  Future<void> load({bool force = false}) async {
    if (_status == CatalogStatus.ready && !force) return;

    if (_status == CatalogStatus.loading) return;

    // A refresh over existing data keeps the current lists visible.
    final bool isRefresh = _status == CatalogStatus.ready;

    if (isRefresh) {
      _refreshStatus = CatalogStatus.loading;
    } else {
      _status = CatalogStatus.loading;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final loadedPlaces = _places == null
          ? const <Place>[]
          : await _places.getAllPlaces();

      final loadedPackages = _packages == null
          ? const <TourPackage>[]
          : await _packages.getAllPackages();

      _placeCatalog = List<Place>.unmodifiable(loadedPlaces);
      _packageCatalog = List<TourPackage>.unmodifiable(loadedPackages);
      _status = CatalogStatus.ready;
      _refreshStatus = CatalogStatus.idle;
      _errorMessage = null;
    } catch (_) {
      // The previously loaded catalogs deliberately stay in place.
      _status = _placeCatalog.isEmpty && _packageCatalog.isEmpty
          ? CatalogStatus.error
          : CatalogStatus.ready;
      _refreshStatus = CatalogStatus.idle;
      _errorMessage = 'Unable to load travel information. Please try again.';
    }

    notifyListeners();
  }

  /// Explicit user-triggered reload, used by pull-to-refresh and retry.
  Future<void> refresh() => load(force: true);

  /// Finds a place by its display name, case- and whitespace-insensitively.
  ///
  /// Replaces the old static `findPlaceByName` helper. Only the loaded
  /// catalog is searched, so an attraction that is inactive (or was never
  /// published) resolves to null and the UI shows its "details unavailable"
  /// state instead of linking to stale content.
  Place? findPlaceByName(String name) {
    final target = name.trim().toLowerCase();

    if (target.isEmpty) return null;

    for (final place in _placeCatalog) {
      if (place.name.trim().toLowerCase() == target) return place;
    }

    return null;
  }

  /// Looks up a package by id, or null when it is not in the catalog.
  TourPackage? packageById(String id) {
    for (final package in _packageCatalog) {
      if (package.id == id) return package;
    }

    return null;
  }

  /// Active packages for [region].
  List<TourPackage> packagesForRegion(String region) {
    return _packageCatalog
        .where((package) => package.region == region)
        .toList();
  }

  @override
  void dispose() {
    _placeCatalog = const <Place>[];
    _packageCatalog = const <TourPackage>[];
    super.dispose();
  }
}

/// Provides the [TouristCatalogController] to the tourist subtree.
///
/// Wrapping the tourist entry point (rather than each screen creating its own)
/// means one load serves Home, packages, planner and preview, and a refresh
/// anywhere updates all of them.
class TouristCatalogScope extends InheritedNotifier<TouristCatalogController> {
  const TouristCatalogScope({
    super.key,
    required TouristCatalogController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The nearest catalog controller, subscribing the caller to its changes.
  ///
  /// Use inside `build`/`didChangeDependencies` so the widget rebuilds when an
  /// admin edit lands.
  static TouristCatalogController? controllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TouristCatalogScope>()
        ?.notifier;
  }

  /// The nearest catalog controller *without* subscribing.
  ///
  /// Use from event handlers and plain getters, where registering a dependency
  /// would be illegal. Returns null outside a scope, so a screen rendered in
  /// isolation (widget test) degrades to "no data" rather than throwing.
  static TouristCatalogController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<TouristCatalogScope>()
        ?.notifier;
  }

  /// The active place catalog in scope, or an empty list.
  ///
  /// Convenience for the many read-only call sites (itinerary generation,
  /// attraction lookups) that only need the data, never the loading state.
  static List<Place> placesOf(BuildContext context) {
    return maybeOf(context)?.places ?? const <Place>[];
  }

  /// The active package catalog in scope, or an empty list.
  static List<TourPackage> packagesOf(BuildContext context) {
    return maybeOf(context)?.packages ?? const <TourPackage>[];
  }
}
