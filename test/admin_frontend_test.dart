import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/screens/admin/admin_booking_details_screen.dart';
import 'package:yatra/screens/admin/admin_booking_list_screen.dart';
import 'package:yatra/screens/admin/admin_screen.dart';
import 'package:yatra/screens/booking/my_bookings_screen.dart';
import 'package:yatra/services/demo_booking_store.dart';
import 'package:yatra/services/recommendation_service.dart';

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

ItineraryBooking _booking(String destination) {
  return DemoBookingStore.instance.create(
    destination: destination,
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 4),
    touristType: 'Domestic Tourist',
    adultCount: 1,
    childCount: 0,
    travelType: 'Family',
    groupSize: 1,
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

Future<void> _pumpAdmin(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    DemoBookingStore.instance.clear();
  });

  test('admin dashboard drives counts from the shared demo store', () {
    _booking('Pokhara');
    final confirmed = _booking('Chitwan');
    DemoBookingStore.instance.updateStatus(
      confirmed.id,
      BookingStatus.confirmed,
    );

    expect(DemoBookingStore.instance.bookings.length, 2);
    expect(
      DemoBookingStore.instance.bookingsWithStatus(BookingStatus.pending),
      hasLength(1),
    );
    expect(
      DemoBookingStore.instance.bookingsWithStatus(BookingStatus.confirmed),
      hasLength(1),
    );
  });

  testWidgets('admin dashboard shows the metric cards', (tester) async {
    _booking('Pokhara');
    _booking('Chitwan');

    await _pumpAdmin(tester);

    expect(find.text('Pending Bookings'), findsOneWidget);
    expect(find.text('Confirmed Bookings'), findsOneWidget);
    expect(find.text('Total Demo Bookings'), findsOneWidget);
    expect(find.text('Travelers in Demo Bookings'), findsOneWidget);
  });

  testWidgets('admin booking list filters by status chip', (tester) async {
    final confirmed = _booking('Chitwan');
    DemoBookingStore.instance.updateStatus(
      confirmed.id,
      BookingStatus.confirmed,
    );
    final pending = _booking('Pokhara');

    await tester.pumpWidget(const MaterialApp(home: AdminBookingListScreen()));
    await tester.pumpAndSettle();

    // All matches: both bookings listed.
    expect(find.text('2 bookings'), findsOneWidget);
    expect(find.text(pending.id), findsOneWidget);
    expect(find.text(confirmed.id), findsOneWidget);

    // Filter to Confirmed only (finger the filter chip, not the status badge
    // on the confirmed booking card below).
    await tester.tap(find.text('Confirmed').first);
    await tester.pumpAndSettle();

    expect(find.text('1 booking'), findsOneWidget);
    expect(find.text(confirmed.id), findsOneWidget);
    expect(find.text(pending.id), findsNothing);
  });

  testWidgets('coordinator is assigned to a booking from the admin sheet', (
    tester,
  ) async {
    final booking = _booking('Pokhara');

    await tester.pumpWidget(
      MaterialApp(home: AdminBookingDetailsScreen(bookingId: booking.id)),
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

    // The shared store now has the coordinator; the details screen reflects it.
    expect(booking.assignedCoordinator?.name, 'Sushmita Gurung');
    expect(find.textContaining('Assigned to Sushmita Gurung'), findsOneWidget);
  });

  testWidgets('admin change status updates the booking for everyone', (
    tester,
  ) async {
    final booking = _booking('Pokhara');

    await tester.pumpWidget(
      MaterialApp(home: AdminBookingDetailsScreen(bookingId: booking.id)),
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

    expect(booking.status, BookingStatus.confirmed);

    // The same booking shows as Confirmed in the tourist-facing list too.
    //
    // The tourist list now reads the backend, so the fake repository hands it
    // the very booking the admin screen just changed. Once admin persistence
    // lands, this becomes a real Firestore re-read.
    final repository = FakeBookingRepository(bookings: [booking]);

    await tester.pumpWidget(
      MaterialApp(home: MyBookingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    // The tourist-facing reference is the booking code, not the document id.
    expect(find.textContaining('${booking.bookingCode} •'), findsOneWidget);
    expect(find.text('Confirmed'), findsWidgets);
  });
}
