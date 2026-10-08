import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/route_config.dart';

class RouteFirestoreMapper {
  const RouteFirestoreMapper._();

  static Map<String, dynamic> routeDocumentToMap(RouteConfig route) {
    return {
      ...routeFieldsToMap(route),
      'active': route.active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> routeUpdateToMap(RouteConfig route) {
    return {
      ...routeFieldsToMap(route),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> routeFieldsToMap(RouteConfig route) {
    return {
      'destination': route.destination,
      'from': route.from,
      'to': route.to,
      'transportModes': List<String>.of(route.transportModes),
      'bidirectional': route.bidirectional,
      'note': route.note,
    };
  }

  static RouteConfig routeDocumentFromMap({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return RouteConfig(
      id: documentId,
      destination: _string(data['destination']),
      from: _string(data['from']),
      to: _string(data['to']),
      transportModes: _strings(data['transportModes']),
      bidirectional: _bool(data['bidirectional']) ?? true,
      note: _string(data['note']),
      active: _bool(data['active']) ?? true,
    );
  }

  static String _string(dynamic value) {
    return value is String ? value : '';
  }

  static bool? _bool(dynamic value) {
    return value is bool ? value : null;
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.whereType<String>().toList();
  }
}
