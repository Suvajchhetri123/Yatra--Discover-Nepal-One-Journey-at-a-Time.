import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_coordinator.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/services/recommendation_service.dart';
import 'package:yatra/screens/admin/admin_booking_details_screen.dart';
import 'package:yatra/screens/admin/admin_coordinator_form_screen.dart';
import 'package:yatra/screens/admin/admin_coordinator_list_screen.dart';

import 'support/fake_admin_booking_repository.dart';
import 'support/fake_coordinator_repository.dart';

const _sushmita = TravelCoordinator(
  id: 'coord-1',
  name: 'Sushmita Gurung',
  phone: '+977 9800000000',
  email: 'sushmita@yatra.app',
);

const _bikash = TravelCoordinator(
  id: 'coord-2',
  name: 'Bikash Thapa',
  phone: '+977 9811111111',
  email: 'bikash@yatra.app',
);

/// Retired, so it must never be offered for a new assignment.
const _retired = TravelCoordinator(
  id: 'coord-3',
  name: 'Retired Coordinator',
  phone: '+977 9822222222',
  email: 'retired@yatra.app',
  active: false,
);

Future<void> _pumpList(
  WidgetTester tester,
  FakeCoordinatorRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: AdminCoordinatorListScreen(repository: repository)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(
  WidgetTester tester,
  FakeCoordinatorRepository repository, {
  TravelCoordinator? coordinator,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminCoordinatorFormScreen(
        coordinator: coordinator,
        repository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ItineraryBooking _booking({TravelCoordinator? assignedCoordinator}) {
  return ItineraryBooking(
    id: 'bk-1',
    bookingCode: 'YT-2026-BK1',
    userId: 'tourist-a',
    createdAt: DateTime(2026, 9, 1),
    status: BookingStatus.pending,
    destination: 'Pokhara',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 4),
    touristType: 'Domestic Tourist',
    adultCount: 2,
    childCount: 0,
    travelType: 'Family',
    groupSize: 2,
    currency: 'NPR',
    estimatedCost: 28000,
    duration: 3,
    tripDirection: TripDirection.oneWay,
    dayPlans: const [
      DayPlan(day: 1, items: [DayPlanItem.activity(activity: 'Sightseeing')]),
    ],
    route: const TravelRoute(
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
    ),
    assignedCoordinator: assignedCoordinator,
  );
}

Future<void> _openPicker(
  WidgetTester tester, {
  TravelCoordinator? assigned,
  FakeCoordinatorRepository? coordinators,
  FakeAdminBookingRepository? bookings,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminBookingDetailsScreen(
        bookingId: 'bk-1',
        repository:
            bookings ?? FakeAdminBookingRepository(bookings: [_booking()]),
        coordinatorRepository:
            coordinators ??
            FakeCoordinatorRepository(
              coordinators: const [_sushmita, _bikash, _retired],
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text(assigned == null ? 'Assign Coordinator' : 'Change Coordinator'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(
    find.text(assigned == null ? 'Assign Coordinator' : 'Change Coordinator'),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('coordinator registry list', () {
    testWidgets('reads the registry, not a bundled list', (tester) async {
      final repository = FakeCoordinatorRepository(
        coordinators: const [_bikash, _sushmita, _retired],
      );

      await _pumpList(tester, repository);

      expect(repository.listCalls, 1);
      expect(find.text('Sushmita Gurung'), findsOneWidget);
      expect(find.text('Bikash Thapa'), findsOneWidget);

      // The default filter is active-only.
      expect(repository.listIncludeInactiveCalls, [false]);
      expect(find.text('Retired Coordinator'), findsNothing);
      expect(find.text('2 coordinators'), findsOneWidget);
    });

    testWidgets('the All filter reveals deactivated records', (tester) async {
      final repository = FakeCoordinatorRepository(
        coordinators: const [_sushmita, _retired],
      );

      await _pumpList(tester, repository);

      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();

      expect(repository.listIncludeInactiveCalls, [false, true]);
      expect(find.text('Retired Coordinator'), findsOneWidget);
      expect(find.text('2 coordinators'), findsOneWidget);
    });

    testWidgets('deactivating writes active=false and updates the list', (
      tester,
    ) async {
      final repository = FakeCoordinatorRepository(
        coordinators: const [_sushmita, _bikash],
      );

      await _pumpList(tester, repository);

      final bikashCard = find.ancestor(
        of: find.text('Bikash Thapa'),
        matching: find.byType(Card),
      );

      await tester.tap(
        find.descendant(
          of: bikashCard,
          matching: find.widgetWithText(OutlinedButton, 'Deactivate'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.activeWrites, [(id: 'coord-2', active: false)]);

      // Gone from the active list without a full reload.
      expect(find.text('Bikash Thapa'), findsNothing);
      expect(find.text('1 coordinator'), findsOneWidget);
    });

    testWidgets('restoring a deactivated coordinator writes active=true', (
      tester,
    ) async {
      final repository = FakeCoordinatorRepository(
        coordinators: const [_sushmita, _retired],
      );

      await _pumpList(tester, repository);
      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();

      final card = find.ancestor(
        of: find.text('Retired Coordinator'),
        matching: find.byType(Card),
      );

      await tester.tap(
        find.descendant(
          of: card,
          matching: find.widgetWithText(OutlinedButton, 'Restore'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.activeWrites, [(id: 'coord-3', active: true)]);

      // The "All" filter keeps it on screen, now as an active record.
      expect(repository.coordinators.last.active, isTrue);
      expect(find.text('Retired Coordinator'), findsOneWidget);
    });

    testWidgets('a failed deactivation is reported and not faked', (
      tester,
    ) async {
      final repository = FakeCoordinatorRepository(
        coordinators: const [_sushmita],
      )..activeError = Exception('PERMISSION_DENIED: rules');

      await _pumpList(tester, repository);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Deactivate').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save your changes. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);

      // Still shown as active, because nothing was persisted.
      expect(find.text('Sushmita Gurung'), findsOneWidget);
      expect(repository.coordinators.single.active, isTrue);
    });

    testWidgets('a load failure offers a retry that recovers', (tester) async {
      final repository = FakeCoordinatorRepository(
        coordinators: const [_sushmita],
        listError: Exception('unavailable'),
      );

      await _pumpList(tester, repository);

      expect(
        find.text(
          'Could not load the travel catalog. Check your connection and try '
          'again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('unavailable'), findsNothing);

      repository.listError = null;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Sushmita Gurung'), findsOneWidget);
    });

    testWidgets('an empty registry explains what to do', (tester) async {
      await _pumpList(tester, FakeCoordinatorRepository());

      expect(find.text('No coordinators'), findsOneWidget);
      expect(
        find.text(
          'No active coordinators. Switch to "All" to see deactivated '
          'ones.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('opening the form returns to a refreshed list', (tester) async {
      final repository = FakeCoordinatorRepository();

      await _pumpList(tester, repository);
      expect(find.text('No coordinators'), findsOneWidget);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Asha Rai');
      await tester.enterText(find.byType(TextField).at(1), '+977 9833333333');
      await tester.enterText(find.byType(TextField).at(2), 'asha@yatra.app');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add coordinator'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.creates.single.name, 'Asha Rai');
      expect(find.text('Asha Rai'), findsOneWidget);
    });
  });

  group('coordinator form', () {
    testWidgets('refuses to save an empty form', (tester) async {
      final repository = FakeCoordinatorRepository();

      await _pumpForm(tester, repository);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add coordinator'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Please fill in the required fields.'), findsOneWidget);
      expect(find.byType(AdminCoordinatorListScreen), findsNothing);
    });

    testWidgets('rejects a malformed phone and email', (tester) async {
      final repository = FakeCoordinatorRepository();

      await _pumpForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Asha Rai');
      await tester.enterText(find.byType(TextField).at(1), 'call me');
      await tester.enterText(find.byType(TextField).at(2), 'asha.at.yatra');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add coordinator'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      expect(find.text('Use digits, spaces and + only.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('creates a coordinator with trimmed values', (tester) async {
      final repository = FakeCoordinatorRepository();

      await _pumpForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), '  Asha Rai  ');
      await tester.enterText(find.byType(TextField).at(1), ' +977 9833333333 ');
      await tester.enterText(find.byType(TextField).at(2), ' asha@yatra.app ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add coordinator'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      // A normal admin entry never invents an id.
      expect(repository.creates.single.id, isNull);

      // Values are stored trimmed, so the registry stays clean.
      final stored = repository.coordinators.single;
      expect(stored.name, 'Asha Rai');
      expect(stored.phone, '+977 9833333333');
      expect(stored.email, 'asha@yatra.app');
      expect(stored.active, isTrue);
    });

    testWidgets('editing keeps the id and never changes the active flag', (
      tester,
    ) async {
      final repository = FakeCoordinatorRepository(
        coordinators: const [_retired],
      );

      await _pumpForm(tester, repository, coordinator: _retired);
      expect(find.text('Edit coordinator'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).at(0),
        'Retired Coordinator (renamed)',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(
        repository.coordinators.single.name,
        'Retired Coordinator (renamed)',
      );

      // Still deactivated: an edit must not resurrect a coordinator.
      expect(repository.coordinators.single.active, isFalse);
    });

    testWidgets('a failed save is reported and the form stays open', (
      tester,
    ) async {
      final repository = FakeCoordinatorRepository()
        ..createError = Exception('PERMISSION_DENIED: rules');

      await _pumpForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Asha Rai');
      await tester.enterText(find.byType(TextField).at(1), '+977 9833333333');
      await tester.enterText(find.byType(TextField).at(2), 'asha@yatra.app');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add coordinator'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save your changes. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('rapid taps cannot create the coordinator twice', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repository = FakeCoordinatorRepository();

      await _pumpForm(tester, repository);
      await tester.enterText(find.byType(TextField).at(0), 'Asha Rai');
      await tester.enterText(find.byType(TextField).at(1), '+977 9833333333');
      await tester.enterText(find.byType(TextField).at(2), 'asha@yatra.app');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add coordinator'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Add coordinator'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(repository.createCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
    });
  });

  group('booking assignment picker', () {
    testWidgets('offers only active coordinators from the registry', (
      tester,
    ) async {
      final coordinators = FakeCoordinatorRepository(
        coordinators: const [_sushmita, _bikash, _retired],
      );

      await _openPicker(tester, coordinators: coordinators);

      expect(coordinators.listCalls, 1);
      expect(coordinators.listIncludeInactiveCalls, [false]);
      expect(find.text('Sushmita Gurung'), findsOneWidget);
      expect(find.text('Bikash Thapa'), findsOneWidget);
      expect(find.text('Retired Coordinator'), findsNothing);
    });

    testWidgets('selecting a coordinator persists it as a snapshot', (
      tester,
    ) async {
      final booking = _booking();
      final bookings = FakeAdminBookingRepository(bookings: [booking]);
      final coordinators = FakeCoordinatorRepository(
        coordinators: const [_sushmita, _bikash],
      );

      await _openPicker(tester, bookings: bookings, coordinators: coordinators);

      await tester.tap(find.text('Bikash Thapa'));
      await tester.pumpAndSettle();

      expect(bookings.coordinatorAssignments.single.bookingId, 'bk-1');
      expect(bookings.coordinatorAssignments.single.coordinator?.id, 'coord-2');
      expect(booking.assignedCoordinator?.phone, '+977 9811111111');
      expect(find.text('Assigned to Bikash Thapa.'), findsOneWidget);
    });

    testWidgets('a deactivated current coordinator is only reported, never '
        're-selected', (tester) async {
      await _openPicker(
        tester,
        assigned: _retired,
        bookings: FakeAdminBookingRepository(
          bookings: [_booking(assignedCoordinator: _retired)],
        ),
      );

      // The active-only registry is still what the picker asks for.
      expect(find.text('Sushmita Gurung'), findsOneWidget);
      expect(find.text('Retired Coordinator'), findsOneWidget);
      expect(
        find.text('Currently assigned, but no longer active'),
        findsOneWidget,
      );
    });

    testWidgets('removing the assignment is still offered', (tester) async {
      final booking = _booking(assignedCoordinator: _sushmita);
      final bookings = FakeAdminBookingRepository(bookings: [booking]);

      await _openPicker(tester, assigned: _sushmita, bookings: bookings);

      await tester.tap(find.text('Remove coordinator'));
      await tester.pumpAndSettle();

      expect(bookings.coordinatorAssignments.single.coordinator, isNull);
      expect(booking.assignedCoordinator, isNull);
    });

    testWidgets('a registry failure is reported and can be retried', (
      tester,
    ) async {
      final coordinators = FakeCoordinatorRepository(
        coordinators: const [_sushmita],
        listError: Exception('PERMISSION_DENIED: rules'),
      );

      await _openPicker(tester, coordinators: coordinators);

      expect(
        find.text('Could not load coordinators. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);

      coordinators.listError = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Sushmita Gurung'), findsOneWidget);
    });

    testWidgets('an empty registry explains the next step', (tester) async {
      await _openPicker(tester, coordinators: FakeCoordinatorRepository());

      expect(find.text('No active coordinators'), findsOneWidget);
      expect(
        find.text('Add one in the admin coordinator registry first.'),
        findsOneWidget,
      );
    });
  });
}
