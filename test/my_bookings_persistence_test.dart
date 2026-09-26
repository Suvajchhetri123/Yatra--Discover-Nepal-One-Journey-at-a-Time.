import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/screens/booking/booking_details_screen.dart';
import 'package:yatra/screens/booking/my_bookings_screen.dart';
import 'package:yatra/services/booking_repository.dart';
import 'package:yatra/services/recommendation_service.dart';

import 'support/fake_booking_repository.dart';

/// Firestore-style document IDs. Deliberately not readable YT-* values so a
/// test fails if the document id ever reaches the tourist.
const String kDocumentId = 'CkQ7dXbZmN3pVrT1';
const String kBookingCode = 'YT-2026-CKQ7DX';

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

/// A booking as the backend returns it from the `bookings` collection: a
/// document [ItineraryBooking.id] plus a separate user-facing
/// [ItineraryBooking.bookingCode].
ItineraryBooking _booking({
  String id = kDocumentId,
  String bookingCode = kBookingCode,
  String destination = 'Pokhara',
  BookingStatus status = BookingStatus.pending,
  int groupSize = 3,
  double estimatedCost = 30000,
  String? packageTitle = 'Annapurna Explorer',
}) {
  return ItineraryBooking(
    id: id,
    bookingCode: bookingCode,
    userId: 'user-uid-1',
    createdAt: DateTime(2026, 9, 20),
    updatedAt: DateTime(2026, 9, 20),
    status: status,
    destination: destination,
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 4),
    touristType: 'Domestic Tourist',
    adultCount: 2,
    childCount: 1,
    travelType: 'Family',
    groupSize: groupSize,
    currency: 'NPR',
    estimatedCost: estimatedCost,
    duration: 3,
    packageTitle: packageTitle,
    tripDirection: TripDirection.oneWay,
    route: _route,
    dayPlans: const [
      DayPlan(day: 1, items: [DayPlanItem.activity(activity: 'Sightseeing')]),
    ],
  );
}

Future<void> _pumpMyBookings(
  WidgetTester tester,
  FakeBookingRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: MyBookingsScreen(repository: repository)),
  );
}

void main() {
  testWidgets('TEST 1: a loading state appears before the repository result', (
    tester,
  ) async {
    final gate = Completer<void>();

    final repository = FakeBookingRepository(
      bookings: [_booking()],
      listGate: gate,
    );

    await _pumpMyBookings(tester, repository);
    await tester.pump();

    expect(repository.listCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The empty state must never stand in for a pending request.
    expect(find.text('No bookings yet'), findsNothing);
    expect(find.text('0 bookings'), findsNothing);
    expect(find.text('Pokhara'), findsNothing);
    expect(find.text('Try Again'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Pokhara'), findsWidgets);
  });

  testWidgets('TEST 2: returned Firestore bookings render as booking cards', (
    tester,
  ) async {
    final repository = FakeBookingRepository(
      bookings: [
        _booking(),
        _booking(
          id: 'T4mZq0WvB8nKc2R',
          bookingCode: 'YT-2026-T4MZQ0W',
          destination: 'Chitwan',
          packageTitle: 'Jungle Safari',
        ),
      ],
    );

    await _pumpMyBookings(tester, repository);
    await tester.pumpAndSettle();

    // Both cards.
    expect(find.text('Pokhara'), findsOneWidget);
    expect(find.text('Chitwan'), findsOneWidget);

    // Persistent wording, not session wording.
    expect(find.text('2 bookings'), findsOneWidget);
    expect(find.textContaining('this session'), findsNothing);

    // Card details.
    expect(find.text('Annapurna Explorer'), findsOneWidget);
    expect(find.text('Jungle Safari'), findsOneWidget);
    expect(find.textContaining('1/9/2026 – 4/9/2026'), findsNWidgets(2));
    expect(find.text('3 travelers'), findsNWidgets(2));
    expect(find.text('NPR 30,000'), findsNWidgets(2));
    expect(find.text('Pending'), findsNWidgets(2));
  });

  testWidgets(
    'TEST 3: the card shows bookingCode and never the Firestore document id',
    (tester) async {
      final repository = FakeBookingRepository(bookings: [_booking()]);

      await _pumpMyBookings(tester, repository);
      await tester.pumpAndSettle();

      expect(find.textContaining('$kBookingCode •'), findsOneWidget);
      expect(find.textContaining(kDocumentId), findsNothing);
    },
  );

  testWidgets('TEST 4: an empty booking history shows the empty state', (
    tester,
  ) async {
    final repository = FakeBookingRepository();

    await _pumpMyBookings(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(find.text('No bookings yet'), findsOneWidget);
    expect(
      find.text('Your booked itineraries will appear here.'),
      findsOneWidget,
    );
    expect(find.text('Plan a Trip'), findsOneWidget);
    expect(find.textContaining('0 bookings'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Try Again'), findsNothing);
  });

  testWidgets('TEST 5: a repository failure shows a friendly error, not the '
      'empty state', (tester) async {
    final repository = FakeBookingRepository(
      listError: FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'UNAVAILABLE: the service is currently unavailable.',
      ),
    );

    await _pumpMyBookings(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load your bookings. Please try again.'),
      findsOneWidget,
    );

    // Never the empty state, and never raw backend text.
    expect(find.text('No bookings yet'), findsNothing);
    expect(find.text('Plan a Trip'), findsNothing);
    expect(find.textContaining('UNAVAILABLE'), findsNothing);
    expect(find.textContaining('unavailable'), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('TEST 6: Try Again reloads after a failed request', (
    tester,
  ) async {
    final repository = FakeBookingRepository(
      listError: FirebaseException(
        plugin: 'cloud_firestore',
        code: 'deadline-exceeded',
        message: 'DEADLINE_EXCEEDED raw backend text',
      ),
    );

    await _pumpMyBookings(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(find.text('Try Again'), findsOneWidget);

    // The connection recovers and now returns a booking.
    repository.listError = null;
    repository.bookings.add(_booking());

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(find.text('Pokhara'), findsOneWidget);
    expect(find.text('1 booking'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing);
  });

  testWidgets('TEST 7: pull-to-refresh re-reads the backend', (tester) async {
    final repository = FakeBookingRepository(bookings: [_booking()]);

    await _pumpMyBookings(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1200);

    // The existing list is preserved while the refresh runs: no full-screen
    // spinner replaces it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Pokhara'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);

    // The refreshed result is what stays on screen.
    repository.bookings.add(_booking(destination: 'Bhaktapur'));

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1200);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 3);
    expect(find.text('2 bookings'), findsOneWidget);
    expect(find.text('Bhaktapur'), findsOneWidget);
  });

  testWidgets('TEST 8: opening a booking sends the document id to the details '
      'screen', (tester) async {
    final booking = _booking();

    final repository = FakeBookingRepository(
      bookings: [booking],
      fetchedBooking: booking,
    );

    await _pumpMyBookings(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pokhara'));
    await tester.pumpAndSettle();

    expect(find.byType(BookingDetailsScreen), findsOneWidget);

    final details = tester.widget<BookingDetailsScreen>(
      find.byType(BookingDetailsScreen),
    );

    // The document id is the lookup key, and the same repository is forwarded
    // so the child never falls back to a production Firestore dependency.
    expect(details.bookingId, kDocumentId);
    expect(details.bookingId, isNot(kBookingCode));
    expect(details.repository, same(repository));
    expect(details.repository, isA<BookingRepository>());
  });

  testWidgets('TEST 9: returning from booking details re-reads the backend', (
    tester,
  ) async {
    // Two distinct instances model a read-only screen cache versus the stored
    // document, so only a real reload can reconcile them.
    final staleBooking = _booking(destination: 'Pokhara');

    final repository = FakeBookingRepository(
      bookings: [staleBooking],
      fetchedBooking: _booking(destination: 'Pokhara'),
    );

    await _pumpMyBookings(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);

    await tester.tap(find.text('Pokhara'));
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 1);
    expect(find.byType(BookingDetailsScreen), findsOneWidget);

    // Model the persisted cancellation: the document now reads back cancelled.
    repository.bookings
      ..clear()
      ..add(
        _booking(status: BookingStatus.cancelled, destination: 'Bhaktapur'),
      );

    await tester.pageBack();
    await tester.pumpAndSettle();

    // A real repository reload happened, not just a local setState.
    expect(repository.listCalls, 2);

    // And the list now shows what the backend returns.
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Bhaktapur'), findsOneWidget);
    expect(find.text('Pokhara'), findsNothing);
    expect(find.text('Pending'), findsNothing);
    expect(find.byType(BookingDetailsScreen), findsNothing);
  });

  testWidgets('TEST 10: all four booking statuses render their own chip', (
    tester,
  ) async {
    final repository = FakeBookingRepository(
      bookings: [
        _booking(destination: 'Pokhara', status: BookingStatus.pending),
        _booking(
          id: 'doc-confirmed',
          bookingCode: 'YT-2026-CONFRM',
          destination: 'Chitwan',
          status: BookingStatus.confirmed,
        ),
        _booking(
          id: 'doc-cancelled',
          bookingCode: 'YT-2026-CANCEL',
          destination: 'Lumbini',
          status: BookingStatus.cancelled,
        ),
        _booking(
          id: 'doc-completed',
          bookingCode: 'YT-2026-COMPLT',
          destination: 'Bhaktapur',
          status: BookingStatus.completed,
        ),
      ],
    );

    await _pumpMyBookings(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('4 bookings'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);

    expect(find.text('Pokhara'), findsOneWidget);
    expect(find.text('Chitwan'), findsOneWidget);
    expect(find.text('Lumbini'), findsOneWidget);
    expect(find.text('Bhaktapur'), findsOneWidget);

    // Every card shows its own user-facing reference.
    expect(find.textContaining('YT-2026-CONFRM •'), findsOneWidget);
    expect(find.textContaining('YT-2026-CANCEL •'), findsOneWidget);
    expect(find.textContaining('YT-2026-COMPLT •'), findsOneWidget);
  });

  test('TEST 11: my_bookings_screen.dart no longer uses DemoBookingStore', () {
    final source = File(
      'lib/screens/booking/my_bookings_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('DemoBookingStore')));
    expect(source, isNot(contains('demo_booking_store')));
    expect(source, contains('getCurrentUserBookings'));
  });
}
