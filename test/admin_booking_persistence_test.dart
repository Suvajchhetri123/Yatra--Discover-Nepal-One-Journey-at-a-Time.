import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/mock_coordinators.dart';
import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_coordinator.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/models/user_profile.dart';
import 'package:yatra/screens/admin/admin_booking_details_screen.dart';
import 'package:yatra/screens/admin/admin_booking_list_screen.dart';
import 'package:yatra/screens/admin/admin_screen.dart';
import 'package:yatra/services/demo_profile_store.dart';
import 'package:yatra/services/firestore_service.dart';
import 'package:yatra/services/recommendation_service.dart';

import 'support/fake_admin_booking_repository.dart';
import 'support/fake_coordinator_repository.dart';

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

UserProfileLoader _touristProfile() =>
    () async => const UserProfile(
      uid: 'tourist-uid',
      name: 'Sita',
      email: 'sita@example.com',
      role: 'tourist',
    );

/// Builds a stored booking.
///
/// [id] is the Firestore document ID and is deliberately very different from
/// [bookingCode], so tests can prove which one the UI renders.
ItineraryBooking _booking({
  required String id,
  String destination = 'Pokhara',
  BookingStatus status = BookingStatus.pending,
  int groupSize = 2,
  String userId = 'tourist-a',
  DateTime? createdAt,
  TravelCoordinator? assignedCoordinator,
}) {
  return ItineraryBooking(
    id: id,
    bookingCode: 'YT-2026-${id.toUpperCase()}',
    userId: userId,
    createdAt: createdAt ?? DateTime(2026, 9, 1),
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
    assignedCoordinator: assignedCoordinator,
  );
}

/// Default assignable staff for the booking tests.
///
/// The picker now reads the coordinator registry, so tests that only care about
/// the *booking* write still get a populated registry. Tests about the registry
/// itself inject their own.
FakeCoordinatorRepository _defaultCoordinators() =>
    FakeCoordinatorRepository(coordinators: kMockCoordinators);

Future<void> _pumpDashboard(
  WidgetTester tester,
  FakeAdminBookingRepository bookings, {
  bool asAdmin = true,
  FakeCoordinatorRepository? coordinators,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminScreen(
        profileLoader: asAdmin ? _adminProfile() : _touristProfile(),
        bookingRepository: bookings,
        coordinatorRepository: coordinators ?? _defaultCoordinators(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpList(
  WidgetTester tester,
  FakeAdminBookingRepository bookings, {
  BookingStatus? initialStatus,
  FakeCoordinatorRepository? coordinators,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminBookingListScreen(
        initialStatus: initialStatus,
        repository: bookings,
        coordinatorRepository: coordinators ?? _defaultCoordinators(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetails(
  WidgetTester tester,
  FakeAdminBookingRepository bookings, {
  String? bookingId,
  FakeCoordinatorRepository? coordinators,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminBookingDetailsScreen(
        bookingId: bookingId ?? bookings.bookings.first.id,
        repository: bookings,
        coordinatorRepository: coordinators ?? _defaultCoordinators(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Reads the number rendered inside the metric card that owns [label].
String _metricValue(WidgetTester tester, String label) {
  final card = find
      .ancestor(of: find.text(label), matching: find.byType(Card))
      .first;

  final texts = tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  );

  // The value is rendered above the label inside the card.
  return texts.first.data!;
}

Map<String, String> _libSources() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  return {
    for (final file in files) file.path: _stripped(file.readAsStringSync()),
  };
}

String _stripped(String source) {
  return source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

String _slice(String source, int start, [int length = 600]) {
  return source.substring(start, (start + length).clamp(0, source.length));
}

void main() {
  setUp(() {
    DemoProfileStore.instance.clear();
  });

  testWidgets('TEST 1: an unauthorized visitor never loads bookings', (
    tester,
  ) async {
    final bookings = FakeAdminBookingRepository(
      bookings: [_booking(id: 'bk-doc-1')],
    );

    await _pumpDashboard(tester, bookings, asAdmin: false);

    expect(find.text('Admin access required.'), findsOneWidget);
    expect(bookings.listCalls, 0);
    expect(find.text('Pending Bookings'), findsNothing);
    expect(find.text('Total Bookings'), findsNothing);
  });

  testWidgets('TEST 2: an authorized admin loads bookings once', (
    tester,
  ) async {
    final bookings = FakeAdminBookingRepository(
      bookings: [_booking(id: 'bk-doc-1')],
    );

    await _pumpDashboard(tester, bookings);

    expect(bookings.listCalls, 1);
    expect(find.text('Pending Bookings'), findsOneWidget);
    expect(find.text('Admin access required.'), findsNothing);
  });

  testWidgets('TEST 3: dashboard metrics are computed from repository data', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      FakeAdminBookingRepository(
        bookings: [
          _booking(id: 'bk-a', groupSize: 2, userId: 'tourist-a'),
          _booking(
            id: 'bk-b',
            groupSize: 3,
            status: BookingStatus.confirmed,
            userId: 'tourist-b',
          ),
          _booking(
            id: 'bk-c',
            groupSize: 4,
            status: BookingStatus.cancelled,
            userId: 'tourist-c',
          ),
        ],
      ),
    );

    expect(_metricValue(tester, 'Pending Bookings'), '1');
    expect(_metricValue(tester, 'Confirmed Bookings'), '1');
    expect(_metricValue(tester, 'Total Bookings'), '3');
    expect(_metricValue(tester, 'Travelers in Bookings'), '9');
  });

  testWidgets('TEST 4: the dashboard shows a loading state while booking data '
      'is in flight', (tester) async {
    final gate = Completer<void>();
    final bookings = FakeAdminBookingRepository(
      bookings: [_booking(id: 'bk-a')],
      listGate: gate,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          profileLoader: _adminProfile(),
          bookingRepository: bookings,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The empty state must not stand in for a pending request.
    expect(find.text('No bookings yet'), findsNothing);
    expect(find.text('Pending Bookings'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Pending Bookings'), findsOneWidget);
  });

  testWidgets('TEST 5: a dashboard load failure offers a retry', (
    tester,
  ) async {
    final bookings = FakeAdminBookingRepository(
      listError: Exception('PERMISSION_DENIED'),
    );

    await _pumpDashboard(tester, bookings);

    expect(
      find.text('Could not load bookings. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    bookings.listError = null;
    bookings.bookings.add(_booking(id: 'bk-a'));

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(bookings.listCalls, 2);
    expect(find.text('Pending Bookings'), findsOneWidget);
    expect(
      find.text('Could not load bookings. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('TEST 6: the dashboard hands its repository to the list', (
    tester,
  ) async {
    final bookings = FakeAdminBookingRepository(
      bookings: [_booking(id: 'bk-a')],
    );

    await _pumpDashboard(tester, bookings);

    await _scrollTo(tester, find.text('Booking Requests'));
    await tester.tap(find.text('Booking Requests'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminBookingListScreen), findsOneWidget);

    final listScreen = tester.widget<AdminBookingListScreen>(
      find.byType(AdminBookingListScreen),
    );

    expect(listScreen.repository, same(bookings));
    expect(bookings.listCalls, 2);
  });

  testWidgets('TEST 7: the admin list shows bookings from every traveller', (
    tester,
  ) async {
    final mine = _booking(id: 'bk-doc-1', destination: 'Pokhara');
    final theirs = _booking(
      id: 'bk-doc-2',
      destination: 'Bhaktapur',
      userId: 'tourist-b',
    );

    await _pumpList(
      tester,
      FakeAdminBookingRepository(bookings: [mine, theirs]),
    );

    expect(find.text('2 bookings'), findsOneWidget);
    expect(find.text(mine.bookingCode), findsOneWidget);
    expect(find.text(theirs.bookingCode), findsOneWidget);
    expect(find.text('Bhaktapur'), findsOneWidget);
  });

  testWidgets('TEST 8: the status filter is applied locally', (tester) async {
    final bookings = FakeAdminBookingRepository(
      bookings: [
        _booking(id: 'bk-a'),
        _booking(id: 'bk-b', status: BookingStatus.confirmed),
      ],
    );

    await _pumpList(tester, bookings);
    expect(find.text('2 bookings'), findsOneWidget);

    await tester.tap(find.text('Confirmed').first);
    await tester.pumpAndSettle();

    expect(find.text('1 booking'), findsOneWidget);
    expect(find.text('YT-2026-BK-B'), findsOneWidget);
    expect(find.text('YT-2026-BK-A'), findsNothing);

    // Filtering did not re-query the backend.
    expect(bookings.listCalls, 1);
  });

  testWidgets('TEST 9: the list shows booking codes, never document ids', (
    tester,
  ) async {
    final booking = _booking(id: 'bk-doc-1');

    await _pumpList(tester, FakeAdminBookingRepository(bookings: [booking]));

    expect(find.text('YT-2026-BK-DOC-1'), findsOneWidget);
    expect(find.text('bk-doc-1'), findsNothing);
  });

  testWidgets('TEST 10: pull-to-refresh re-reads the admin repository', (
    tester,
  ) async {
    final bookings = FakeAdminBookingRepository(
      bookings: [_booking(id: 'bk-a')],
    );

    await _pumpList(tester, bookings);
    expect(bookings.listCalls, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1200);

    // The list stays on screen while the refresh runs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('1 booking'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(bookings.listCalls, 2);

    bookings.bookings.add(_booking(id: 'bk-b', destination: 'Bhaktapur'));

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1200);
    await tester.pumpAndSettle();

    expect(bookings.listCalls, 3);
    expect(find.text('2 bookings'), findsOneWidget);
    expect(find.text('Bhaktapur'), findsOneWidget);
  });

  testWidgets('TEST 11: returning from details re-reads the backend', (
    tester,
  ) async {
    final booking = _booking(id: 'bk-a');
    final bookings = FakeAdminBookingRepository(bookings: [booking]);

    await _pumpList(tester, bookings);
    expect(bookings.listCalls, 1);
    expect(find.text('YT-2026-BK-A'), findsOneWidget);

    await tester.tap(find.text('YT-2026-BK-A'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminBookingDetailsScreen), findsOneWidget);

    // Confirm the booking from the details screen.
    await _scrollTo(tester, find.text('Change Status'));
    await tester.tap(find.text('Change Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // The list did not trust its own copy: it re-read the repository and now
    // shows the persisted status.
    expect(bookings.listCalls, 2);
    expect(find.text('Confirmed'), findsWidgets);
  });

  testWidgets('TEST 12: the details screen loads one booking', (tester) async {
    final booking = _booking(
      id: 'bk-doc-1',
      destination: 'Pokhara',
      groupSize: 3,
    );
    final bookings = FakeAdminBookingRepository(bookings: [booking]);

    await _pumpDetails(tester, bookings);

    expect(bookings.fetchCalls, 1);
    expect(bookings.fetchedBookingIds, ['bk-doc-1']);

    expect(
      find.text('Booking Reference: ${booking.bookingCode}'),
      findsOneWidget,
    );

    // Trip, traveler, route and admin action UI are all preserved.
    expect(find.text('Trip Details'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Traveler Info'), findsOneWidget);
    expect(find.text('Route & Itinerary'), findsOneWidget);
    expect(find.text('Coordinator'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Day 1 — Sightseeing'), findsOneWidget);
  });

  testWidgets('TEST 13: a booking that no longer exists is reported', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      FakeAdminBookingRepository(),
      bookingId: 'bk-missing',
    );

    expect(find.text('This booking is no longer available.'), findsOneWidget);
    expect(find.text('Trip Details'), findsNothing);
  });

  testWidgets('TEST 14: a details load failure offers a retry', (tester) async {
    final booking = _booking(id: 'bk-a');
    final bookings = FakeAdminBookingRepository(
      bookings: [booking],
      fetchError: Exception('UNAVAILABLE: backend'),
    );

    await _pumpDetails(tester, bookings);

    expect(
      find.text('Could not load this booking. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('UNAVAILABLE'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Trip Details'), findsNothing);

    bookings.fetchError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(bookings.fetchCalls, 2);
    expect(
      find.text('Booking Reference: ${booking.bookingCode}'),
      findsOneWidget,
    );
  });

  testWidgets('TEST 15: a status change is keyed by the document id', (
    tester,
  ) async {
    final booking = _booking(id: 'bk-doc-1');
    final bookings = FakeAdminBookingRepository(bookings: [booking]);

    await _pumpDetails(tester, bookings);

    await _scrollTo(tester, find.text('Change Status'));
    await tester.tap(find.text('Change Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed'));
    await tester.pumpAndSettle();

    expect(bookings.statusCalls, 1);
    expect(bookings.statusUpdates.single.bookingId, 'bk-doc-1');
    expect(bookings.statusUpdates.single.status, BookingStatus.confirmed);

    // The booking code is never used as the write key.
    expect(bookings.statusUpdates.single.bookingId, isNot(booking.bookingCode));
  });

  testWidgets(
    'TEST 16: a successful status change is re-read from the backend',
    (tester) async {
      final booking = _booking(id: 'bk-doc-1');
      final bookings = FakeAdminBookingRepository(bookings: [booking]);

      await _pumpDetails(tester, bookings);
      expect(bookings.fetchCalls, 1);

      await _scrollTo(tester, find.text('Change Status'));
      await tester.tap(find.text('Change Status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmed'));
      await tester.pumpAndSettle();

      // Persisted, then re-read: the screen shows the backend's new state.
      expect(booking.status, BookingStatus.confirmed);
      expect(bookings.fetchCalls, 2);
      expect(find.text('Confirmed'), findsWidgets);
    },
  );

  testWidgets('TEST 17: a failed status change never fakes success', (
    tester,
  ) async {
    final booking = _booking(id: 'bk-doc-1');
    final bookings = FakeAdminBookingRepository(
      bookings: [booking],
      statusError: Exception('PERMISSION_DENIED: rules'),
    );

    await _pumpDetails(tester, bookings);

    await _scrollTo(tester, find.text('Change Status'));
    await tester.tap(find.text('Change Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not update this booking. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('PERMISSION_DENIED'), findsNothing);

    // Nothing was written, and no success message was shown.
    expect(bookings.statusCalls, 1);
    expect(booking.status, BookingStatus.pending);
    expect(find.textContaining('is now Confirmed'), findsNothing);
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('TEST 18: assigning a coordinator is persisted', (tester) async {
    final booking = _booking(id: 'bk-doc-1');
    final bookings = FakeAdminBookingRepository(bookings: [booking]);

    await _pumpDetails(tester, bookings);

    await _scrollTo(tester, find.text('Assign Coordinator'));
    await tester.tap(find.text('Assign Coordinator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sushmita Gurung'));
    await tester.pumpAndSettle();

    expect(bookings.coordinatorCalls, 1);
    expect(bookings.coordinatorAssignments.single.bookingId, 'bk-doc-1');
    expect(
      bookings.coordinatorAssignments.single.coordinator?.name,
      'Sushmita Gurung',
    );

    // Persisted and re-read.
    expect(booking.assignedCoordinator?.name, 'Sushmita Gurung');
    expect(find.text('Assigned to Sushmita Gurung.'), findsOneWidget);
    expect(find.text('Change Coordinator'), findsOneWidget);
  });

  testWidgets('TEST 19: removing a coordinator persists null', (tester) async {
    final booking = _booking(
      id: 'bk-doc-1',
      assignedCoordinator: kMockCoordinators.first,
    );
    final bookings = FakeAdminBookingRepository(bookings: [booking]);

    await _pumpDetails(tester, bookings);
    expect(find.text('Assigned to Sushmita Gurung.'), findsOneWidget);

    await _scrollTo(tester, find.text('Change Coordinator'));
    await tester.tap(find.text('Change Coordinator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove coordinator'));
    await tester.pumpAndSettle();

    expect(bookings.coordinatorCalls, 1);
    expect(bookings.coordinatorAssignments.single.bookingId, 'bk-doc-1');
    expect(bookings.coordinatorAssignments.single.coordinator, isNull);

    expect(booking.assignedCoordinator, isNull);
    expect(find.text('No coordinator assigned yet.'), findsOneWidget);
    expect(find.text('Assign Coordinator'), findsOneWidget);
  });

  testWidgets('TEST 20: a failed coordinator write is reported and reverted', (
    tester,
  ) async {
    final booking = _booking(id: 'bk-doc-1');
    final bookings = FakeAdminBookingRepository(
      bookings: [booking],
      coordinatorError: Exception('PERMISSION_DENIED: rules'),
    );

    await _pumpDetails(tester, bookings);

    await _scrollTo(tester, find.text('Assign Coordinator'));
    await tester.tap(find.text('Assign Coordinator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bikash Thapa'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not update this booking. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('PERMISSION_DENIED'), findsNothing);

    expect(bookings.coordinatorCalls, 1);
    expect(booking.assignedCoordinator, isNull);
    expect(find.text('No coordinator assigned yet.'), findsOneWidget);
  });

  testWidgets('TEST 21: rapid admin taps cannot double-write', (tester) async {
    final gate = Completer<void>();
    final booking = _booking(id: 'bk-doc-1');
    final bookings = FakeAdminBookingRepository(
      bookings: [booking],
      statusGate: gate,
    );

    await _pumpDetails(tester, bookings);

    await _scrollTo(tester, find.text('Change Status'));
    await tester.tap(find.text('Change Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed'));

    // The write is in flight; pump without settling (the gate is still open).
    await tester.pump();

    expect(bookings.statusCalls, 1);

    // Both admin actions are disabled while the write is pending.
    final statusButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Change Status'),
    );
    expect(statusButton.onPressed, isNull);

    final coordinatorButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Assign Coordinator'),
    );
    expect(coordinatorButton.onPressed, isNull);

    await tester.tap(find.text('Change Status'), warnIfMissed: false);
    await tester.pump();

    expect(bookings.statusCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(bookings.statusCalls, 1);
    expect(booking.status, BookingStatus.confirmed);
  });

  test('TEST 22: the three admin screens no longer use DemoBookingStore', () {
    for (final path in [
      'lib/screens/admin/admin_screen.dart',
      'lib/screens/admin/admin_booking_list_screen.dart',
      'lib/screens/admin/admin_booking_details_screen.dart',
    ]) {
      final source = _stripped(File(path).readAsStringSync());

      expect(source, isNot(contains('DemoBookingStore')), reason: path);
      expect(source, isNot(contains('demo_booking_store')), reason: path);
    }
  });

  test('TEST 23: the tourist repository stays ownership-restricted', () {
    final tourist =
        _libSources()['lib/services/firestore_booking_service.dart']!;
    final admin =
        _libSources()['lib/services/firestore_admin_booking_service.dart']!;

    // The tourist service still filters reads by the current user.
    expect(tourist, contains("where('userId', isEqualTo: user.uid)"));
    expect(tourist, contains("data['userId'] != user.uid"));

    // The admin service deliberately does not.
    expect(admin, isNot(contains('user.uid')));
    expect(admin, isNot(contains("where('userId'")));

    // The tourist repository contract is untouched by the admin work.
    final contract = _libSources()['lib/services/booking_repository.dart']!;
    expect(
      contract,
      contains('Future<List<ItineraryBooking>> getCurrentUserBookings()'),
    );
    expect(contract, isNot(contains('getAllBookings')));
  });

  test('TEST 24: the admin service writes only admin-owned fields', () {
    final admin =
        _libSources()['lib/services/firestore_admin_booking_service.dart']!;

    // Status write: status + updatedAt only.
    final statusWrite = _slice(
      admin,
      admin.indexOf('Future<void> updateBookingStatus'),
      400,
    );
    expect(statusWrite, contains("'status': status.name"));
    expect(statusWrite, contains("'updatedAt': FieldValue.serverTimestamp()"));
    expect(statusWrite, isNot(contains('assignedCoordinator')));

    // Coordinator write: assignedCoordinator + updatedAt only, mapped through
    // the shared mapper so the shape matches the tourist write.
    final coordinatorWrite = _slice(
      admin,
      admin.indexOf('Future<void> assignCoordinator'),
      600,
    );
    expect(
      coordinatorWrite,
      contains('BookingFirestoreMapper.coordinatorToMap(coordinator)'),
    );
    expect(
      coordinatorWrite,
      contains("'updatedAt': FieldValue.serverTimestamp()"),
    );
    expect(coordinatorWrite, isNot(contains("'status'")));

    // Reads cover every booking, newest first, with no ownership filter.
    final allBookings = _slice(
      admin,
      admin.indexOf('Future<List<ItineraryBooking>> getAllBookings'),
      500,
    );
    expect(allBookings, contains('_bookings.get()'));
    expect(allBookings, isNot(contains('where(')));
    expect(allBookings, contains('b.createdAt.compareTo(a.createdAt)'));

    // Bookings are never deleted, and no admin identity is hard-coded.
    expect(admin, isNot(contains('.delete(')));
    expect(admin, isNot(contains('admin@')));
    expect(admin, isNot(contains("uid ==")));
  });
}
