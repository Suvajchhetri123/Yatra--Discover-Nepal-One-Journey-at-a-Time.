import '../models/travel_coordinator.dart';

/// Demo travel coordinators assigned to bookings by the admin frontend.
///
/// DEMO DATA ONLY — replace with a managed coordinator registry once the
/// admin backend exists. Do not scatter fake people across UI widgets;
/// always resolve coordinators through this list (or the booking store).
const kMockCoordinators = <TravelCoordinator>[
  TravelCoordinator(
    id: 'coord-001',
    name: 'Sushmita Gurung',
    phone: '+977 9841 000001',
    email: 'sushmita@yatra.demo',
  ),
  TravelCoordinator(
    id: 'coord-002',
    name: 'Bikash Thapa',
    phone: '+977 9841 000002',
    email: 'bikash@yatra.demo',
  ),
  TravelCoordinator(
    id: 'coord-003',
    name: 'Anjali Shrestha',
    phone: '+977 9841 000003',
    email: 'anjali@yatra.demo',
  ),
];
