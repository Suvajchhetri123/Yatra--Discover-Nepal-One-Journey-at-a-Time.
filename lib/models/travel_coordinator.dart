/// A travel coordinator who will represent Yatra for a booking.
///
/// Currently populated from demo mock data (lib/data/mock_coordinators.dart).
/// Not persisted anywhere yet — assignment only lives in the in-memory
/// DemoBookingStore for the current runtime session.
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
