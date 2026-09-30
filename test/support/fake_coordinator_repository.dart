import 'dart:async';

import 'package:yatra/models/travel_coordinator.dart';
import 'package:yatra/services/coordinator_repository.dart';

/// A recorded coordinator create.
typedef CoordinatorCreate = ({
  String? id,
  String name,
  String phone,
  String email,
});

/// In-memory [CoordinatorRepository] used by admin widget and unit tests.
///
/// Records every call, can be made to fail or held open to model a slow
/// network, and applies successful writes to its in-memory registry so a later
/// read reflects the "persisted" state the way Firestore would. No admin test
/// ever talks to Firestore.
class FakeCoordinatorRepository implements CoordinatorRepository {
  FakeCoordinatorRepository({
    List<TravelCoordinator>? coordinators,
    this.listError,
    this.createError,
    this.updateError,
    this.activeError,
    this.listGate,
  }) : coordinators = List<TravelCoordinator>.of(coordinators ?? const []);

  final List<TravelCoordinator> coordinators;

  Object? listError;
  Object? createError;
  Object? updateError;
  Object? activeError;

  /// Fails a single create, chosen by the record's name.
  ///
  /// [createError] fails every create; this is for partial-failure runs such
  /// as the catalog migration, where only one record must fail.
  Object? Function(String name)? createErrorFor;

  Completer<void>? listGate;

  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int activeCalls = 0;

  /// The [includeInactive] value of every [getCoordinators] call.
  final List<bool> listIncludeInactiveCalls = <bool>[];

  final List<CoordinatorCreate> creates = <CoordinatorCreate>[];

  /// Every `setCoordinatorActive(id, active)` call, in order.
  final List<({String id, bool active})> activeWrites =
      <({String id, bool active})>[];

  @override
  Future<List<TravelCoordinator>> getCoordinators({
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

    final visible = coordinators
        .where((coordinator) => includeInactive || coordinator.active)
        .toList();

    visible.sort((a, b) => a.name.compareTo(b.name));

    return visible;
  }

  @override
  Future<TravelCoordinator?> getCoordinatorById(String id) async {
    if (listError != null) {
      throw listError!;
    }

    for (final coordinator in coordinators) {
      if (coordinator.id == id) return coordinator;
    }

    return null;
  }

  @override
  Future<TravelCoordinator> createCoordinator({
    required String name,
    required String phone,
    required String email,
    String? id,
  }) async {
    createCalls += 1;
    creates.add((id: id, name: name, phone: phone, email: email));

    final recordError = createErrorFor?.call(name) ?? createError;

    if (recordError != null) {
      throw recordError;
    }

    final documentId = id?.trim().isNotEmpty == true
        ? id!.trim()
        : 'coord-${coordinators.length + 1}';

    // The service trims before writing, so the fake mirrors that contract.
    final created = TravelCoordinator(
      id: documentId,
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      active: true,
    );

    coordinators.add(created);

    return created;
  }

  @override
  Future<void> updateCoordinator({
    required String id,
    required String name,
    required String phone,
    required String email,
  }) async {
    updateCalls += 1;

    if (updateError != null) {
      throw updateError!;
    }

    final index = coordinators.indexWhere(
      (coordinator) => coordinator.id == id,
    );

    if (index == -1) return;

    // `active` is untouched, mirroring the service contract.
    coordinators[index] = coordinators[index].copyWith(
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
    );
  }

  @override
  Future<void> setCoordinatorActive(String id, bool active) async {
    activeCalls += 1;
    activeWrites.add((id: id, active: active));

    if (activeError != null) {
      throw activeError!;
    }

    final index = coordinators.indexWhere(
      (coordinator) => coordinator.id == id,
    );

    if (index == -1) return;

    coordinators[index] = coordinators[index].copyWith(active: active);
  }
}
