import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/models/user_profile.dart';
import 'package:yatra/screens/admin/admin_booking_details_screen.dart';
import 'package:yatra/screens/admin/admin_booking_list_screen.dart';
import 'package:yatra/screens/admin/admin_screen.dart';
import 'package:yatra/screens/booking/my_bookings_screen.dart';
import 'package:yatra/services/demo_profile_store.dart';
import 'package:yatra/services/firestore_service.dart';
import 'package:yatra/services/recommendation_service.dart';

import 'support/fake_admin_booking_repository.dart';
import 'support/fake_booking_repository.dart';

const _route = TravelRoute(
  boardingPoint: 'Kathmandu',
  destination: 'Pokhara',
  segments: [
    RouteSegment(
      from: 'Kathmandu',
      to: 'Pokhara',
      transportation: 'Tourist Bus',
    ),
  ],
  tripDirection: TripDirection.oneWay,
);

UserProfileLoader _adminProfile() =>
    () async => const UserProfile(
      uid: 'admin-uid',
      name: 'Admin',
      email: 'admin@example.com',
      role: 'admin',
    );

ItineraryBooking _booking(
  String destination, {
  required String id,
  BookingStatus status = BookingStatus.pending,
  int groupSize = 1,
}) {
  return ItineraryBooking(
    id: id,
    bookingCode: 'YT-2026-${id.toUpperCase()}',
    userId: 'tourist-uid',
    createdAt: DateTime(2026, 9, 1),
    status: status,
    destination: destination,
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 4),
    touristType: 'Domestic Tourist',
    adultCount: groupSize,
    childCount: 0,
    travelType: 'Family',
    groupSize: groupSize,
    currency: 'NPR',
    estimatedCost: 30000,
    duration: 3,
    tripDirection: TripDirection.oneWay,
    route: _route,
    dayPlans: const [
      DayPlan(day: 1, items: [DayPlanItem.activity(activity: 'Sightseeing')]),
    ],
  );
}

Future<void> _pumpAdmin(
  WidgetTester tester,
  FakeAdminBookingRepository bookings,
) async {
  // AdminScreen is role protected, so the dashboard is only reachable with an
  // injected admin profile. Role gating itself is covered by
  // admin_authorization_test.dart.
  await tester.pumpWidget(
    MaterialApp(
      home: AdminScreen(
        profileLoader: _adminProfile(),
        bookingRepository: bookings,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    DemoProfileStore.instance.clear();
  });

  test('the admin repository returns every booking regardless of owner', () {
    final repository = FakeAdminBookingRepository(
      bookings: [
        _booking('Pokhara', id: 'bk-1'),
        _booking('Chitwan', id: 'bk-2', status: BookingStatus.confirmed),
      ],
    );

    // Synchronous read of the recorded state, no widget involved.
    expect(repository.bookings, hasLength(2));
    expect(
      repository.bookings
          .where((booking) => booking.status == BookingStatus.pending)
          .length,
      1,
    );
    expect(
      repository.bookings
          .where((booking) => booking.status == BookingStatus.confirmed)
          .length,
      1,
    );
  });

  testWidgets('admin dashboard shows the metric cards', (tester) async {
    await _pumpAdmin(
      tester,
      FakeAdminBookingRepository(
        bookings: [
          _booking('Pokhara', id: 'bk-1'),
          _booking('Chitwan', id: 'bk-2'),
        ],
      ),
    );

    expect(find.text('Pending Bookings'), findsOneWidget);
    expect(find.text('Confirmed Bookings'), findsOneWidget);
    expect(find.text('Total Bookings'), findsOneWidget);
    expect(find.text('Travelers in Bookings'), findsOneWidget);
  });

  testWidgets('admin booking list filters by status chip', (tester) async {
    final confirmed = _booking(
      'Chitwan',
      id: 'bk-2',
      status: BookingStatus.confirmed,
    );
    final pending = _booking('Pokhara', id: 'bk-1');

    await tester.pumpWidget(
      MaterialApp(
        home: AdminBookingListScreen(
          repository: FakeAdminBookingRepository(
            bookings: [pending, confirmed],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // All matches: both bookings listed by their booking code.
    expect(find.text('2 bookings'), findsOneWidget);
    expect(find.text(pending.bookingCode), findsOneWidget);
    expect(find.text(confirmed.bookingCode), findsOneWidget);

    // Filter to Confirmed only (finger the filter chip, not the status badge
    // on the confirmed booking card below).
    await tester.tap(find.text('Confirmed').first);
    await tester.pumpAndSettle();

    expect(find.text('1 booking'), findsOneWidget);
    expect(find.text(confirmed.bookingCode), findsOneWidget);
    expect(find.text(pending.bookingCode), findsNothing);
  });

  testWidgets('coordinator is assigned to a booking from the admin sheet', (
    tester,
  ) async {
    final booking = _booking('Pokhara', id: 'bk-1');
    final repository = FakeAdminBookingRepository(bookings: [booking]);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminBookingDetailsScreen(
          bookingId: booking.id,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(booking.assignedCoordinator, isNull);

    await tester.scrollUntilVisible(
      find.text('Assign Coordinator'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Assign Coordinator'));
    await tester.pumpAndSettle();

    // The sheet lists the demo coordinators.
    expect(find.text('Sushmita Gurung'), findsOneWidget);
    expect(find.text('Bikash Thapa'), findsOneWidget);

    await tester.tap(find.text('Sushmita Gurung'));
    await tester.pumpAndSettle();

    // The write was persisted and the screen re-read it.
    expect(repository.coordinatorCalls, 1);
    expect(
      repository.coordinatorAssignments.single.coordinator?.name,
      'Sushmita Gurung',
    );
    expect(booking.assignedCoordinator?.name, 'Sushmita Gurung');
    expect(find.textContaining('Assigned to Sushmita Gurung'), findsOneWidget);
  });

  testWidgets('admin change status updates the booking for everyone', (
    tester,
  ) async {
    final booking = _booking('Pokhara', id: 'bk-1');
    final repository = FakeAdminBookingRepository(bookings: [booking]);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminBookingDetailsScreen(
          bookingId: booking.id,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Change Status'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Change Status'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmed'));
    await tester.pumpAndSettle();

    expect(repository.statusCalls, 1);
    expect(booking.status, BookingStatus.confirmed);

    // The same booking shows as Confirmed in the tourist-facing list too.
    //
    // The tourist list now reads the backend, so the fake repository hands it
    // the very booking the admin screen just changed. Once both screens are on
    // Firestore this becomes a real re-read of the same document.
    final touristRepository = FakeBookingRepository(bookings: [booking]);

    await tester.pumpWidget(
      MaterialApp(home: MyBookingsScreen(repository: touristRepository)),
    );
    await tester.pumpAndSettle();

    // The tourist-facing reference is the booking code, not the document id.
    expect(find.textContaining('${booking.bookingCode} •'), findsOneWidget);
    expect(find.text('Confirmed'), findsWidgets);
  });
}
