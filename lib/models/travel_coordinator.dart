/// A travel coordinator who will represent Yatra for a booking.
///
/// The *directory* is currently demo data (lib/data/mock_coordinators.dart) and
/// is still resolved from that list. An assignment made by an admin is however
/// persisted on the booking document, so it survives restarts.
class TravelCoordinator {
  final String id;
  final String name;
  final String phone;
  final String email;

  const TravelCoordinator({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });
}
