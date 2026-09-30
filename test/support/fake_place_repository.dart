import 'dart:async';

import 'package:yatra/models/place_model.dart';
import 'package:yatra/services/place_repository.dart';

/// In-memory [PlaceRepository] used by admin widget and unit tests.
///
/// Applies successful writes to its in-memory catalog, records every call and
/// can be made to fail or held open. No admin test ever talks to Firestore.
class FakePlaceRepository implements PlaceRepository {
  FakePlaceRepository({
    List<Place>? places,
    this.listError,
    this.createError,
    this.updateError,
    this.activeError,
    this.listGate,
  }) : places = List<Place>.of(places ?? const []);

  final List<Place> places;

  Object? listError;
  Object? createError;
  Object? updateError;
  Object? activeError;

  /// Fails a single create, chosen by the record's name. See the coordinator
  /// fake for why this exists alongside [createError].
  Object? Function(String name)? createErrorFor;

  Completer<void>? listGate;

  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int activeCalls = 0;

  /// The [includeInactive] value of every [getAllPlaces] call.
  final List<bool> listIncludeInactiveCalls = <bool>[];

  /// Every place passed to [createPlace], in order.
  final List<Place> creates = <Place>[];

  /// The explicit `id` passed to [createPlace], in call order.
  final List<String?> createIds = <String?>[];

  final List<({String id, bool active})> activeWrites =
      <({String id, bool active})>[];

  @override
  Future<List<Place>> getAllPlaces({bool includeInactive = false}) async {
    listCalls += 1;
    listIncludeInactiveCalls.add(includeInactive);

    final gate = listGate;

    if (gate != null) {
      await gate.future;
    }

    if (listError != null) {
      throw listError!;
    }

    final visible = places
        .where((place) => includeInactive || place.active)
        .toList();

    visible.sort((a, b) => a.name.compareTo(b.name));

    return visible;
  }

  @override
  Future<Place?> getPlaceById(String placeId) async {
    if (listError != null) {
      throw listError!;
    }

    for (final place in places) {
      if (place.id == placeId) return place;
    }

    return null;
  }

  @override
  Future<Place> createPlace(Place place, {String? id}) async {
    createCalls += 1;
    creates.add(place);
    createIds.add(id);

    final recordError = createErrorFor?.call(place.name) ?? createError;

    if (recordError != null) {
      throw recordError;
    }

    final documentId = id?.trim().isNotEmpty == true
        ? id!.trim()
        : Place.slugFor(place.location, place.name);

    final stored = place.copyWith(id: documentId, active: true);

    places.add(stored);

    return stored;
  }

  @override
  Future<void> updatePlace(Place place) async {
    updateCalls += 1;

    if (updateError != null) {
      throw updateError!;
    }

    final index = places.indexWhere((item) => item.id == place.id);

    if (index == -1) return;

    // `active` is untouched, mirroring the service contract.
    places[index] = place.copyWith(active: places[index].active);
  }

  @override
  Future<void> setPlaceActive(String placeId, bool active) async {
    activeCalls += 1;
    activeWrites.add((id: placeId, active: active));

    if (activeError != null) {
      throw activeError!;
    }

    final index = places.indexWhere((place) => place.id == placeId);

    if (index == -1) return;

    places[index] = places[index].copyWith(active: active);
  }
}
