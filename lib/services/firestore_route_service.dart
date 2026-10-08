import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/route_config.dart';
import 'route_firestore_mapper.dart';
import 'route_repository.dart';

/// Firestore persistence for the Admin-managed route registry.
///
/// Route documents are never deleted. They are deactivated with
/// `active: false`, matching Yatra's existing catalog behaviour.
class FirestoreRouteService implements RouteRepository {
  FirestoreRouteService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('routes');

  @override
  Future<List<RouteConfig>> getAllRoutes({bool includeInactive = false}) async {
    _requireUser();

    final Query<Map<String, dynamic>> query = includeInactive
        ? _collection
        : _collection.where('active', isEqualTo: true);

    final snapshot = await query.get();

    final routes = snapshot.docs
        .map(
          (document) => RouteFirestoreMapper.routeDocumentFromMap(
            documentId: document.id,
            data: document.data(),
          ),
        )
        .where((route) => includeInactive || route.active)
        .toList();

    routes.sort((a, b) {
      final destinationCompare = a.destination.toLowerCase().compareTo(
        b.destination.toLowerCase(),
      );

      if (destinationCompare != 0) {
        return destinationCompare;
      }

      final fromCompare = a.from.toLowerCase().compareTo(b.from.toLowerCase());

      if (fromCompare != 0) {
        return fromCompare;
      }

      return a.to.toLowerCase().compareTo(b.to.toLowerCase());
    });

    return routes;
  }

  @override
  Future<RouteConfig?> getRouteById(String routeId) async {
    _requireUser();

    final snapshot = await _collection.doc(routeId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return RouteFirestoreMapper.routeDocumentFromMap(
      documentId: snapshot.id,
      data: data,
    );
  }

  @override
  Future<RouteConfig> createRoute(RouteConfig route, {String? id}) async {
    _requireUser();
    _validate(route);

    final document = id == null || id.trim().isEmpty
        ? _collection.doc()
        : _collection.doc(id.trim());

    final stored = route.copyWith(id: document.id, active: true);

    await document.set(RouteFirestoreMapper.routeDocumentToMap(stored));

    return stored;
  }

  @override
  Future<void> updateRoute(RouteConfig route) async {
    _requireUser();
    _validate(route);

    if (route.id.trim().isEmpty) {
      throw ArgumentError('Cannot update a route without a registry id.');
    }

    await _collection
        .doc(route.id)
        .set(
          RouteFirestoreMapper.routeUpdateToMap(route),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> setRouteActive(String routeId, bool active) async {
    _requireUser();

    await _collection.doc(routeId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _validate(RouteConfig route) {
    final destination = route.destination.trim();
    final from = route.from.trim();
    final to = route.to.trim();

    if (destination.isEmpty || from.isEmpty || to.isEmpty) {
      throw ArgumentError('A route needs destination, from and to locations.');
    }

    if (from.toLowerCase() == to.toLowerCase()) {
      throw ArgumentError('A route leg must connect two different locations.');
    }

    if (route.transportModes.isEmpty) {
      throw ArgumentError('A route needs at least one transportation mode.');
    }

    for (final mode in route.transportModes) {
      if (!kRouteTransportModes.contains(mode)) {
        throw ArgumentError('Unsupported transportation mode: $mode');
      }
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user;
  }
}
