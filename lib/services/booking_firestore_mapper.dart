import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/itinerary_booking.dart';
import '../models/journey_stop_plan.dart';
import '../models/place_model.dart';
import '../models/tourist_pricing.dart';
import '../models/travel_coordinator.dart';
import '../models/travel_route_model.dart';
import 'recommendation_service.dart';

/// Converts Yatra booking snapshots between the application's Dart models
/// and Firestore-compatible Maps.
///
/// Core trip-planner models intentionally remain Firebase-independent.
class BookingFirestoreMapper {
  const BookingFirestoreMapper._();

  // ============================================================
  // COMPLETE BOOKING
  // ============================================================

  static Map<String, dynamic> bookingToMap(ItineraryBooking booking) {
    return {
      'bookingCode': booking.bookingCode,
      'userId': booking.userId,
      'status': booking.status.name,
      'destination': booking.destination,
      'startDate': Timestamp.fromDate(booking.startDate),
      'endDate': Timestamp.fromDate(booking.endDate),
      'touristType': booking.touristType,
      'adultCount': booking.adultCount,
      'childCount': booking.childCount,
      'travelType': booking.travelType,
      'groupSize': booking.groupSize,
      'currency': booking.currency,
      'estimatedCost': booking.estimatedCost,
      'duration': booking.duration,
      'packageTitle': booking.packageTitle,
      'tripDirection': booking.tripDirection.name,
      'route': routeToMap(booking.route),
      'dayPlans': booking.dayPlans.map(dayPlanToMap).toList(),
      'assignedCoordinator': booking.assignedCoordinator == null
          ? null
          : coordinatorToMap(booking.assignedCoordinator!),
      'createdAt': Timestamp.fromDate(booking.createdAt),
      'updatedAt': booking.updatedAt == null
          ? null
          : Timestamp.fromDate(booking.updatedAt!),
    };
  }

  static ItineraryBooking bookingFromMap({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final routeMap = _map(data['route']);

    final route = routeFromMap(routeMap);

    final rawDayPlans = data['dayPlans'];

    final dayPlans = rawDayPlans is List
        ? rawDayPlans
              .whereType<Map>()
              .map((item) => dayPlanFromMap(Map<String, dynamic>.from(item)))
              .toList()
        : <DayPlan>[];

    final coordinatorData = data['assignedCoordinator'];

    return ItineraryBooking(
      id: documentId,
      bookingCode: _string(data['bookingCode']) ?? documentId,
      userId: _string(data['userId']) ?? '',
      createdAt:
          _date(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _date(data['updatedAt']),
      status: bookingStatusFromString(_string(data['status'])),
      destination: _string(data['destination']) ?? '',
      startDate:
          _date(data['startDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endDate: _date(data['endDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      touristType: _string(data['touristType']) ?? '',
      adultCount: _int(data['adultCount']),
      childCount: _int(data['childCount']),
      travelType: _string(data['travelType']) ?? '',
      groupSize: _int(data['groupSize']),
      currency: _string(data['currency']) ?? 'NPR',
      estimatedCost: _double(data['estimatedCost']),
      duration: _int(data['duration']),
      packageTitle: _string(data['packageTitle']),
      tripDirection: tripDirectionFromString(_string(data['tripDirection'])),
      route: route,
      dayPlans: dayPlans,
      assignedCoordinator: coordinatorData is Map
          ? coordinatorFromMap(Map<String, dynamic>.from(coordinatorData))
          : null,
    );
  }

  // ============================================================
  // ROUTE
  // ============================================================

  static Map<String, dynamic> routeToMap(TravelRoute route) {
    return {
      'boardingPoint': route.boardingPoint,
      'destination': route.destination,
      'tripDirection': route.tripDirection.name,
      'localTransportation': route.localTransportation,

      // Going route.
      'segments': route.segments.map(segmentToMap).toList(),

      // Store the resolved return route explicitly.
      //
      // This is important because an automatic return route should remain
      // exactly as it was when the booking was created even if Yatra's route
      // generation rules change later.
      'returnSegments': route.returnSegments.map(segmentToMap).toList(),

      'stopPlans': route.stopPlans.map(stopPlanToMap).toList(),

      'returnStopPlans': route.returnStopPlans.map(stopPlanToMap).toList(),
    };
  }

  static TravelRoute routeFromMap(Map<String, dynamic> data) {
    final segments = _listOfMaps(data['segments']).map(segmentFromMap).toList();

    final returnSegments = _listOfMaps(
      data['returnSegments'],
    ).map(segmentFromMap).toList();

    final stopPlans = _listOfMaps(
      data['stopPlans'],
    ).map(stopPlanFromMap).toList();

    final returnStopPlans = _listOfMaps(
      data['returnStopPlans'],
    ).map(stopPlanFromMap).toList();

    return TravelRoute(
      boardingPoint: _string(data['boardingPoint']) ?? '',
      destination: _string(data['destination']) ?? '',
      segments: segments,
      localTransportation: _string(data['localTransportation']),
      tripDirection: tripDirectionFromString(_string(data['tripDirection'])),
      stopPlans: stopPlans,
      returnStopPlans: returnStopPlans,
      returnSegments: returnSegments.isEmpty ? null : returnSegments,
    );
  }

  // ============================================================
  // ROUTE SEGMENTS
  // ============================================================

  static Map<String, dynamic> segmentToMap(RouteSegment segment) {
    return {
      'from': segment.from,
      'to': segment.to,
      'transportation': segment.transportation,
    };
  }

  static RouteSegment segmentFromMap(Map<String, dynamic> data) {
    return RouteSegment(
      from: _string(data['from']) ?? '',
      to: _string(data['to']) ?? '',
      transportation: _string(data['transportation']) ?? '',
    );
  }

  // ============================================================
  // STOP PLANS
  // ============================================================

  static Map<String, dynamic> stopPlanToMap(JourneyStopPlan plan) {
    return {'location': plan.location, 'explorationDays': plan.explorationDays};
  }

  static JourneyStopPlan stopPlanFromMap(Map<String, dynamic> data) {
    return JourneyStopPlan(
      location: _string(data['location']) ?? '',
      explorationDays: _int(data['explorationDays']),
    );
  }

  // ============================================================
  // DAY PLAN
  // ============================================================

  static Map<String, dynamic> dayPlanToMap(DayPlan plan) {
    return {
      'day': plan.day,
      'items': plan.items.map(dayPlanItemToMap).toList(),
    };
  }

  static DayPlan dayPlanFromMap(Map<String, dynamic> data) {
    return DayPlan(
      day: _int(data['day']),
      items: _listOfMaps(data['items']).map(dayPlanItemFromMap).toList(),
    );
  }

  // ============================================================
  // DAY PLAN ITEM
  // ============================================================

  static Map<String, dynamic> dayPlanItemToMap(DayPlanItem item) {
    switch (item.type) {
      case DayPlanItemType.travel:
        return {
          'type': 'travel',
          'from': item.from,
          'to': item.to,
          'transportation': item.transportation,
        };

      case DayPlanItemType.attraction:
        return {
          'type': 'attraction',
          'place': item.place == null ? null : placeToMap(item.place!),
          'customTitle': item.customTitle,
          'note': item.note,
        };

      case DayPlanItemType.activity:
        return {
          'type': 'activity',
          'activity': item.activity,
          'note': item.note,
        };
    }
  }

  static DayPlanItem dayPlanItemFromMap(Map<String, dynamic> data) {
    final type = _string(data['type']);

    switch (type) {
      case 'travel':
        return DayPlanItem.travel(
          from: _string(data['from']) ?? '',
          to: _string(data['to']) ?? '',
          transportation: _string(data['transportation']) ?? '',
        );

      case 'attraction':
        final rawPlace = data['place'];

        return DayPlanItem.attraction(
          place: rawPlace is Map
              ? placeFromMap(Map<String, dynamic>.from(rawPlace))
              : null,
          customTitle: _string(data['customTitle']),
          note: _string(data['note']),
        );

      case 'activity':
        return DayPlanItem.activity(
          activity: _string(data['activity']) ?? 'Activity',
          note: _string(data['note']),
        );

      default:
        // Safe fallback for malformed/old data.
        return DayPlanItem.activity(
          activity: 'Activity',
          note: _string(data['note']),
        );
    }
  }

  // ============================================================
  // PLACE SNAPSHOT
  // ============================================================

  static Map<String, dynamic> placeToMap(Place place) {
    return {
      'name': place.name,
      'location': place.location,
      'description': place.description,
      'imageUrl': place.imageUrl,
      'entryFee': place.entryFee,
      'touristEntryFee': place.touristEntryFee == null
          ? null
          : touristPricingToMap(place.touristEntryFee!),
      'openingHours': place.openingHours,
      'transportation': place.transportation,
      'travelTrip': place.travelTrip,
      'recommendedHours': place.recommendedHours,
    };
  }

  static Place placeFromMap(Map<String, dynamic> data) {
    final pricing = data['touristEntryFee'];

    return Place(
      name: _string(data['name']) ?? '',
      location: _string(data['location']) ?? '',
      description: _string(data['description']) ?? '',
      imageUrl: _string(data['imageUrl']) ?? '',
      entryFee: _double(data['entryFee']),
      touristEntryFee: pricing is Map
          ? touristPricingFromMap(Map<String, dynamic>.from(pricing))
          : null,
      openingHours: _string(data['openingHours']) ?? '',
      transportation: _string(data['transportation']) ?? '',
      travelTrip: _string(data['travelTrip']) ?? '',
      recommendedHours: _double(data['recommendedHours']),
    );
  }

  // ============================================================
  // TOURIST PRICING
  // ============================================================

  static Map<String, dynamic> touristPricingToMap(TouristPricing pricing) {
    return {
      'domestic': pricing.domestic,
      'international': pricing.international,
    };
  }

  static TouristPricing touristPricingFromMap(Map<String, dynamic> data) {
    return TouristPricing(
      domestic: _nullableDouble(data['domestic']),
      international: _nullableDouble(data['international']),
    );
  }

  // ============================================================
  // COORDINATOR SNAPSHOT
  // ============================================================

  static Map<String, dynamic> coordinatorToMap(TravelCoordinator coordinator) {
    return {
      'id': coordinator.id,
      'name': coordinator.name,
      'phone': coordinator.phone,
      'email': coordinator.email,
    };
  }

  static TravelCoordinator coordinatorFromMap(Map<String, dynamic> data) {
    return TravelCoordinator(
      id: _string(data['id']) ?? '',
      name: _string(data['name']) ?? '',
      phone: _string(data['phone']) ?? '',
      email: _string(data['email']) ?? '',
    );
  }

  // ============================================================
  // ENUM PARSING
  // ============================================================

  static BookingStatus bookingStatusFromString(String? value) {
    switch (value) {
      case 'confirmed':
        return BookingStatus.confirmed;

      case 'cancelled':
        return BookingStatus.cancelled;

      case 'completed':
        return BookingStatus.completed;

      case 'pending':
      default:
        return BookingStatus.pending;
    }
  }

  static TripDirection tripDirectionFromString(String? value) {
    switch (value) {
      case 'roundTrip':
        return TripDirection.roundTrip;

      case 'oneWay':
      default:
        return TripDirection.oneWay;
    }
  }

  // ============================================================
  // SAFE FIRESTORE CONVERSION HELPERS
  // ============================================================

  static String? _string(dynamic value) {
    return value is String ? value : null;
  }

  static int _int(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  static double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  static double? _nullableDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
