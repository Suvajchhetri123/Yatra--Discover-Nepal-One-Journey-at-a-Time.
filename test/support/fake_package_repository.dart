import 'dart:async';

import 'package:yatra/models/package_model.dart';
import 'package:yatra/services/package_repository.dart';

/// In-memory [PackageRepository] used by admin widget and unit tests.
///
/// Applies successful writes to its in-memory catalog, records every call and
/// can be made to fail or held open. No admin test ever talks to Firestore.
class FakePackageRepository implements PackageRepository {
  FakePackageRepository({
    List<TourPackage>? packages,
    this.listError,
    this.createError,
    this.updateError,
    this.activeError,
    this.listGate,
  }) : packages = List<TourPackage>.of(packages ?? const []);

  final List<TourPackage> packages;

  Object? listError;
  Object? createError;
  Object? updateError;
  Object? activeError;

  /// Fails a single create, chosen by the record's title. See the coordinator
  /// fake for why this exists alongside [createError].
  Object? Function(String title)? createErrorFor;

  Completer<void>? listGate;

  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int activeCalls = 0;

  /// The [includeInactive] value of every [getAllPackages] call.
  final List<bool> listIncludeInactiveCalls = <bool>[];

  final List<TourPackage> creates = <TourPackage>[];

  final List<({String id, bool active})> activeWrites =
      <({String id, bool active})>[];

  @override
  Future<List<TourPackage>> getAllPackages({
    bool includeInactive = false,
  }) async {
    listCalls += 1;
    listIncludeInactiveCalls.add(includeInactive);

    final gate = listGate;

    if (gate != null) {
      await gate.future;
    }

    if (listError != null) {
      throw listError!;
    }

    final visible = packages
        .where((package) => includeInactive || package.active)
        .toList();

    visible.sort((a, b) => a.title.compareTo(b.title));

    return visible;
  }

  @override
  Future<TourPackage?> getPackageById(String id) async {
    if (listError != null) {
      throw listError!;
    }

    for (final package in packages) {
      if (package.id == id) return package;
    }

    return null;
  }

  @override
  Future<TourPackage> createPackage(TourPackage package) async {
    createCalls += 1;
    creates.add(package);

    final recordError = createErrorFor?.call(package.title) ?? createError;

    if (recordError != null) {
      throw recordError;
    }

    final base = package.id.trim().isEmpty
        ? package.title
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
              .replaceAll(RegExp(r'^-+|-+$'), '')
        : package.id;

    final stored = package.copyWith(id: _uniqueId(base), active: true);

    packages.add(stored);

    return stored;
  }

  @override
  Future<void> updatePackage(TourPackage package) async {
    updateCalls += 1;

    if (updateError != null) {
      throw updateError!;
    }

    final index = packages.indexWhere((item) => item.id == package.id);

    if (index == -1) return;

    // `active` is untouched, mirroring the service contract.
    packages[index] = package.copyWith(active: packages[index].active);
  }

  @override
  Future<void> setPackageActive(String id, bool active) async {
    activeCalls += 1;
    activeWrites.add((id: id, active: active));

    if (activeError != null) {
      throw activeError!;
    }

    final index = packages.indexWhere((package) => package.id == id);

    if (index == -1) return;

    packages[index] = packages[index].copyWith(active: active);
  }

  /// Mirrors the service's id-collision handling so tests exercise the same
  /// contract: a taken slug becomes `<slug>-2` rather than overwriting.
  String _uniqueId(String base) {
    final taken = packages.map((package) => package.id).toSet();

    if (!taken.contains(base)) return base;

    for (var suffix = 2; suffix < 100; suffix++) {
      final candidate = '$base-$suffix';

      if (!taken.contains(candidate)) return candidate;
    }

    return base;
  }
}
