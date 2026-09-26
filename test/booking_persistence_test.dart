import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/screens/booking/booking_details_screen.dart';
import 'package:yatra/screens/booking/booking_review_screen.dart';
import 'package:yatra/services/recommendation_service.dart';
import 'package:yatra/services/trip_cost_estimator.dart';

import 'support/fake_booking_repository.dart';

/// Firestore-style document ID. Deliberately not a readable YT-* value so the
/// tests fail if the tourist ever sees it.
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

const _dayPlans = [
  DayPlan(day: 1, items: [DayPlanItem.activity(activity: 'Sightseeing')]),
];

const _estimate = TripCostEstimate(
  minimum: 20000,
  recommended: 30000,
  transport: 5000,
  stay: 12000,
  activity: 3000,
  packagePrice: 10000,
  total: 30000,
);

/// A booking as it comes back from Firestore: a document [id] plus a separate
/// user-facing [bookingCode].
ItineraryBooking _booking({
  BookingStatus status = BookingStatus.pending,
  String destination = 'Pokhara',
}) {
  return ItineraryBooking(
    id: kDocumentId,
    bookingCode: kBookingCode,
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
    travelType: 'Solo',
    groupSize: 3,
    currency: 'NPR',
    estimatedCost: 30000,
    duration: 3,
    packageTitle: 'Annapurna Explorer',
    tripDirection: TripDirection.oneWay,
    route: _route,
    dayPlans: _dayPlans,
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
        estimate: _estimate,
        duration: 3,
        travelType: 'Solo',
        adultCount: 2,
        childCount: 1,
        groupSize: 3,
        packageTitle: 'Annapurna Explorer',
        route: _route,
        dayPlans: _dayPlans,
        repository: repository,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _submitFromReview(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Submit Booking Request'),
    300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.tap(find.text('Submit Booking Request'));
  await tester.pump();
}

Future<void> _pumpDetails(
  WidgetTester tester,
  FakeBookingRepository repository, {
  String bookingId = kDocumentId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BookingDetailsScreen(bookingId: bookingId, repository: repository),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _openCancelDialog(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Cancel Booking Request'),
    300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.tap(find.text('Cancel Booking Request'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'TEST 1: booking submission calls the backend once even with repeated '
    'interaction',
    (tester) async {
      final gate = Completer<void>();

      final repository = FakeBookingRepository(
        createdBooking: _booking(),
        createGate: gate,
      );

      await _pumpReview(tester, repository);
      await _submitFromReview(tester);

      // Rapid repeat taps while the write is still in flight.
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pump();
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(find.text('Booking request submitted.'), findsOneWidget);
    },
  );

  testWidgets('TEST 1b: the trip snapshots are submitted without recalculating '
      'pricing, routing or the itinerary', (tester) async {
    final repository = FakeBookingRepository(createdBooking: _booking());

    await _pumpReview(tester, repository);
    await _submitFromReview(tester);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.lastDestination, 'Pokhara');
    expect(repository.lastStartDate, DateTime(2026, 9, 1));
    expect(repository.lastEndDate, DateTime(2026, 9, 4));
    expect(repository.lastTouristType, 'Domestic Tourist');
    expect(repository.lastAdultCount, 2);
    expect(repository.lastChildCount, 1);
    expect(repository.lastTravelType, 'Solo');
    expect(repository.lastGroupSize, 3);
    expect(repository.lastCurrency, 'NPR');
    expect(repository.lastDuration, 3);
    expect(repository.lastPackageTitle, 'Annapurna Explorer');

    // estimate.total is stored verbatim.
    expect(repository.lastEstimatedCost, _estimate.total);
    expect(repository.lastRoute, same(_route));
    expect(repository.lastDayPlans, same(_dayPlans));
  });

  testWidgets(
    'TEST 2: a successful submission opens Booking Details with the Firestore '
    'document id',
    (tester) async {
      final booking = _booking();

      final repository = FakeBookingRepository(
        createdBooking: booking,
        fetchedBooking: booking,
      );

      await _pumpReview(tester, repository);
      await _submitFromReview(tester);
      await tester.pumpAndSettle();

      expect(find.text('Booking request submitted.'), findsOneWidget);
      expect(find.textContaining('Status: Pending'), findsOneWidget);
      expect(
        find.textContaining(
          'A travel coordinator will be assigned after the booking is '
          'reviewed.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('View Booking'));
      await tester.pumpAndSettle();

      expect(find.byType(BookingDetailsScreen), findsOneWidget);

      final details = tester.widget<BookingDetailsScreen>(
        find.byType(BookingDetailsScreen),
      );

      // The document ID is used for the lookup, never the booking code.
      expect(details.bookingId, kDocumentId);
      expect(details.bookingId, isNot(kBookingCode));
      expect(find.text('Booking Reference: $kBookingCode'), findsOneWidget);
    },
  );

  testWidgets(
    'TEST 3: a failed submission does not navigate and shows a friendly '
    'failure state',
    (tester) async {
      final repository = FakeBookingRepository(
        createError: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'PERMISSION_DENIED: Missing or insufficient permissions.',
        ),
      );

      await _pumpReview(tester, repository);
      await _submitFromReview(tester);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);

      // No navigation, no success dialog.
      expect(find.byType(BookingDetailsScreen), findsNothing);
      expect(find.text('Booking request submitted.'), findsNothing);
      expect(find.text('View Booking'), findsNothing);

      // Friendly message, no raw backend text.
      expect(
        find.text(
          'Could not submit your booking request. Please check your '
          'connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
      expect(find.textContaining('permission-denied'), findsNothing);

      // The button is usable again, so the tourist can retry.
      expect(find.text('Submit Booking Request'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit Booking Request'),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('TEST 4: booking details show a loader and then the booking', (
    tester,
  ) async {
    final gate = Completer<void>();

    final repository = FakeBookingRepository(
      fetchedBooking: _booking(),
      fetchGate: gate,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BookingDetailsScreen(
          bookingId: kDocumentId,
          repository: repository,
        ),
      ),
    );

    await tester.pump();

    expect(repository.fetchCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Booking Reference: $kBookingCode'), findsNothing);
    expect(find.text('Destination'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Booking Reference: $kBookingCode'), findsOneWidget);
    expect(find.text('Pokhara'), findsWidgets);
  });

  testWidgets(
    'TEST 5: booking details show the booking code, never the document id',
    (tester) async {
      final repository = FakeBookingRepository(fetchedBooking: _booking());

      await _pumpDetails(tester, repository);

      expect(find.text('Booking Reference: $kBookingCode'), findsOneWidget);
      expect(find.textContaining(kDocumentId), findsNothing);
      expect(find.text('Booking ID: $kDocumentId'), findsNothing);
    },
  );

  testWidgets('TEST 6: a missing booking shows the unavailable state', (
    tester,
  ) async {
    // fetchedBooking stays null: missing document or not owned.
    final repository = FakeBookingRepository();

    await _pumpDetails(tester, repository, bookingId: 'deleted-doc-id');

    expect(find.text('This booking is no longer available.'), findsOneWidget);
    expect(find.text('Booking Reference: $kBookingCode'), findsNothing);
    expect(find.text('Try Again'), findsNothing);
  });

  testWidgets('TEST 7: a failed load shows a friendly retry state', (
    tester,
  ) async {
    final repository = FakeBookingRepository(
      fetchError: FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'UNAVAILABLE: the service is currently unavailable.',
      ),
    );

    await _pumpDetails(tester, repository);

    expect(
      find.text('Could not load this booking. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('UNAVAILABLE'), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);

    // Retry re-reads the backend and recovers.
    repository.fetchError = null;
    repository.fetchedBooking = _booking();

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(find.text('Booking Reference: $kBookingCode'), findsOneWidget);
  });

  testWidgets('TEST 8: cancelling a pending booking calls the backend', (
    tester,
  ) async {
    final booking = _booking();

    final repository = FakeBookingRepository(fetchedBooking: booking);

    await _pumpDetails(tester, repository);
    await _openCancelDialog(tester);

    // The dialog no longer claims the booking is removed from a demo list.
    expect(find.text('Keep Booking'), findsOneWidget);
    expect(find.text('Cancel Booking'), findsOneWidget);
    expect(
      find.textContaining('remain in your booking history'),
      findsOneWidget,
    );
    expect(find.textContaining('demo list'), findsNothing);

    await tester.tap(find.text('Cancel Booking'));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);

    // The Firestore document id is what gets cancelled.
    expect(repository.cancelledBookingIds, <String>[kDocumentId]);
    expect(repository.cancelledBookingIds.single, isNot(kBookingCode));
    expect(find.text('Booking request cancelled.'), findsOneWidget);
  });

  testWidgets('TEST 9: a successful cancellation shows the Cancelled status', (
    tester,
  ) async {
    final repository = FakeBookingRepository(fetchedBooking: _booking());

    await _pumpDetails(tester, repository);
    expect(find.text('Pending'), findsOneWidget);
    expect(repository.fetchCalls, 1);

    await _openCancelDialog(tester);
    await tester.tap(find.text('Cancel Booking'));
    await tester.pumpAndSettle();

    // The booking is re-read from the backend, not patched locally only.
    expect(repository.fetchCalls, greaterThanOrEqualTo(2));
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);

    // The pending-only action disappears with the pending status.
    expect(find.text('Cancel Booking Request'), findsNothing);
  });

  testWidgets(
    'TEST 10: a non-pending booking does not expose the tourist cancellation '
    'action',
    (tester) async {
      final repository = FakeBookingRepository(
        fetchedBooking: _booking(status: BookingStatus.confirmed),
      );

      await _pumpDetails(tester, repository);

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Cancel Booking Request'), findsNothing);
      expect(repository.cancelCalls, 0);
    },
  );

  testWidgets('TEST 10b: a confirmed booking still shows the coordinator and '
      'trip details', (tester) async {
    final repository = FakeBookingRepository(
      fetchedBooking: _booking(status: BookingStatus.confirmed),
    );

    await _pumpDetails(tester, repository);

    expect(find.text('Trip Summary'), findsOneWidget);
    expect(find.text('Trip Route'), findsOneWidget);
    expect(find.text('Itinerary'), findsOneWidget);
    expect(find.textContaining('Not assigned yet'), findsOneWidget);
    expect(find.text('Day 1 — Sightseeing'), findsOneWidget);
    expect(find.textContaining('View in Google Maps'), findsWidgets);
  });
}
