/// A travel coordinator who will represent Yatra for a booking.
///
/// Coordinators are administered through the Firestore `coordinators`
/// collection. [id] is that document's id, so a booking's coordinator snapshot
/// can be traced back to the registry record it came from.
///
/// The *assignment* stored on a booking document is a snapshot
/// (id/name/phone/email) rather than a live reference, so historical bookings
/// keep the contact details that were actually assigned even after a
/// coordinator is renamed or deactivated. [active] is therefore registry
/// metadata: it decides whether the coordinator can be picked for a *new*
/// assignment, and is not written into booking snapshots.
class TravelCoordinator {
  final String id;
  final String name;
  final String phone;
  final String email;

  /// False means "deactivated". Inactive coordinators stay in the registry so
  /// historic booking snapshots and reports remain meaningful.
  final bool active;

  const TravelCoordinator({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.active = true,
  });

  TravelCoordinator copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    bool? active,
  }) {
    return TravelCoordinator(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TravelCoordinator &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.email == email &&
        other.active == active;
  }

  @override
  int get hashCode => Object.hash(id, name, phone, email, active);
}
