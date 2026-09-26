import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/screens/booking/booking_details_screen.dart';
import 'package:yatra/screens/booking/booking_review_screen.dart';
import 'package:yatra/screens/booking/my_bookings_screen.dart';
import 'package:yatra/services/demo_booking_store.dart';
import 'package:yatra/services/recommendation_service.dart';
import 'package:yatra/services/trip_cost_estimator.dart';

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

ItineraryBooking _createBooking({
  String destination = 'Pokhara',
  BookingStatus? status,
  String? packageTitle,
}) {
  final booking = DemoBookingStore.instance.create(
    destination: destination,
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 4),
    touristType: 'Domestic Tourist',
    adultCount: 2,
    childCount: 0,
    travelType: 'Solo',
    groupSize: 2,
    currency: 'NPR',
    estimatedCost: 30000,
    duration: 3,
    packageTitle: packageTitle,
    tripDirection: TripDirection.oneWay,
    route: _route,
    dayPlans: const [
      DayPlan(day: 1, items: [DayPlanItem.activity(activity: 'Sightseeing')]),
    ],
  );

  if (status != null) {
    DemoBookingStore.instance.updateStatus(booking.id, status);
  }

  return booking;
}

/// A booking as the backend returns it: a Firestore document id plus a
/// separate user-facing booking code.
ItineraryBooking _persistedBooking() {
  return ItineraryBooking(
    id: 'CkQ7dXbZmN3pVrT1',
    bookingCode: 'YT-2026-CKQ7DX',
    userId: 'user-uid-1',
    createdAt: DateTime(2026, 9, 20),
    status: BookingStatus.pending,
    destination: 'Pokhara',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 4),
    touristType: 'Domestic Tourist',
    adultCount: 2,
    childCount: 0,
    travelType: 'Solo',
    groupSize: 2,
    currency: 'NPR',
    estimatedCost: 30000,
    duration: 3,
    packageTitle: 'Annapurna Explorer',
    tripDirection: TripDirection.oneWay,
    route: _route,
    dayPlans: const [
      DayPlan(day: 1, items: [DayPlanItem.activity(activity: 'Sightseeing')]),
    ],
  );
}

Future<void> _pumpReview(
  WidgetTester tester,
  FakeBookingRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BookingReviewScreen(
        touristType: 'Domestic Tourist',
        destination: 'Pokhara',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 4),
        currency: 'NPR',
        estimate: const TripCostEstimate(
          minimum: 20000,
          recommended: 30000,
          transport: 5000,
          stay: 12000,
          activity: 3000,
          packagePrice: 10000,
          total: 30000,
        ),
        duration: 3,
        travelType: 'Solo',
        adultCount: 1,
        childCount: 0,
        groupSize: 1,
        packageTitle: 'Annapurna Explorer',
        route: _route,
        dayPlans: const [
          DayPlan(
            day: 1,
            items: [DayPlanItem.activity(activity: 'Sightseeing')],
          ),
        ],
        repository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    DemoBookingStore.instance.clear();
  });

  test(
    'booking request is created as pending with a demo id YT-<year>-NNN',
    () {
      final booking = _createBooking();

      expect(booking.status, BookingStatus.pending);
      expect(booking.id, matches(RegExp(r'^YT-\d{4}-\d{3}$')));
    },
  );

  test('booking ids are sequential and unique', () {
    final first = _createBooking();
    final second = _createBooking();

    expect(first.id, isNot(second.id));
    expect(first.id, matches(RegExp(r'-001$')));
    expect(second.id, matches(RegExp(r'-002$')));
  });

  test('booking stores the trip summary details', () {
    final booking = _createBooking(packageTitle: 'Annapurna Explorer');

    expect(booking.destination, 'Pokhara');
    expect(booking.startDate, DateTime(2026, 9, 1));
    expect(booking.endDate, DateTime(2026, 9, 4));
    expect(booking.estimatedCost, 30000);
    expect(booking.currency, 'NPR');
    expect(booking.groupSize, 2);
    expect(booking.duration, 3);
    expect(booking.packageTitle, 'Annapurna Explorer');
  });

  test('booking request is request-only, never a confirmed payment', () {
    // A freshly created booking is always pending, never confirmed/completed.
    final booking = _createBooking();

    expect(
      DemoBookingStore.instance
          .bookingsWithStatus(BookingStatus.pending)
          .map((b) => b.id),
      contains(booking.id),
    );
    expect(booking.status, isNot(BookingStatus.confirmed));
    expect(
      DemoBookingStore.instance.bookingsWithStatus(BookingStatus.confirmed),
      isEmpty,
    );
  });

  testWidgets(
    'review screen shows an estimate and a Submit Booking Request action',
    (tester) async {
      final repository = FakeBookingRepository(
        createdBooking: _persistedBooking(),
      );

      await _pumpReview(tester, repository);

      expect(find.text('Review Your Trip'), findsOneWidget);
      expect(find.text('Estimated Trip Cost'), findsWidgets);
      expect(find.text('Submit Booking Request'), findsOneWidget);
      // No payment copy anywhere on the review step.
      expect(find.textContaining('Pay now'), findsNothing);
      expect(find.textContaining('Buy Ticket'), findsNothing);

      // Submitting persists exactly one booking through the backend.
      await tester.scrollUntilVisible(
        find.text('Submit Booking Request'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(find.text('Booking request submitted.'), findsOneWidget);
      expect(find.text('View Booking'), findsOneWidget);

      // The demo store is not dual-written: it stays empty until the
      // My Bookings migration step.
      expect(DemoBookingStore.instance.bookings, isEmpty);
    },
  );

  test('booking can be cancelled from pending', () {
    final booking = _createBooking();

    DemoBookingStore.instance.updateStatus(booking.id, BookingStatus.cancelled);

    expect(
      DemoBookingStore.instance.byId(booking.id)?.status,
      BookingStatus.cancelled,
    );
    expect(
      DemoBookingStore.instance.bookingsWithStatus(BookingStatus.cancelled),
      hasLength(1),
    );
  });

  testWidgets('booking details show route, pending state and cancel action', (
    tester,
  ) async {
    final booking = _createBooking();
    final repository = FakeBookingRepository(fetchedBooking: booking);

    await tester.pumpWidget(
      MaterialApp(
        home: BookingDetailsScreen(
          bookingId: booking.id,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking Details'), findsOneWidget);
    expect(
      find.text('Booking Reference: ${booking.bookingCode}'),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Pokhara'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Cancel Booking Request'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cancel Booking Request'), findsOneWidget);
    expect(find.textContaining('Not assigned yet'), findsOneWidget);
  });

  testWidgets('pending booking appears in My Bookings with a status chip', (
    tester,
  ) async {
    // My Bookings reads the tourist's persistent booking history from the
    // backend, so the list is served by the repository rather than the demo
    // store.
    final repository = FakeBookingRepository(bookings: [_persistedBooking()]);

    await tester.pumpWidget(
      MaterialApp(home: MyBookingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(find.text('1 booking'), findsOneWidget);
    expect(find.text('Pokhara'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('YT-2026-CKQ7DX •'), findsOneWidget);
  });
}
