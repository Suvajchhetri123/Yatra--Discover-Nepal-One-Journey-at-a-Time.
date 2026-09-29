import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/itinerary_booking.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/models/user_profile.dart';
import 'package:yatra/screens/admin/admin_screen.dart';
import 'package:yatra/screens/profile/profile_screen.dart';
import 'package:yatra/services/demo_profile_store.dart';
import 'package:yatra/services/firestore_service.dart';
import 'package:yatra/services/recommendation_service.dart';

import 'support/fake_admin_booking_repository.dart';

const _route = TravelRoute(
  boardingPoint: 'Kathmandu',
  destination: 'Pokhara',
  segments: [
    RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
  ],
  tripDirection: TripDirection.oneWay,
);

/// Builds a stored booking. [id] is the Firestore document ID; the booking code
/// is what the UI is expected to display.
ItineraryBooking _itineraryBooking({
  required String id,
  String destination = 'Pokhara',
  BookingStatus status = BookingStatus.pending,
  int groupSize = 2,
  DateTime? createdAt,
}) {
  return ItineraryBooking(
    id: id,
    bookingCode: 'YT-2026-${id.toUpperCase()}',
    userId: 'tourist-uid',
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
  );
}

UserProfile _profile({
  required String role,
  String uid = 'test-uid',
  String name = 'Sita Sharma',
  String email = 'sita@example.com',
}) {
  return UserProfile(uid: uid, name: name, email: email, role: role);
}

UserProfileLoader _adminLoader() =>
    () async => _profile(role: 'admin');

UserProfileLoader _touristLoader() =>
    () async => _profile(role: 'tourist');

Future<void> _pumpProfile(WidgetTester tester, UserProfileLoader loader) async {
  await tester.pumpWidget(
    MaterialApp(home: ProfileScreen(profileLoader: loader)),
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

Map<String, String> _libSources() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  return {
    for (final file in files) file.path: _stripped(file.readAsStringSync()),
  };
}

/// Removes whole-line `//` comments so assertions only inspect real code.
String _stripped(String source) {
  return source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

String _slice(String source, int start, [int length = 400]) {
  return source.substring(start, (start + length).clamp(0, source.length));
}

void main() {
  setUp(() {
    DemoProfileStore.instance.clear();
  });

  testWidgets('TEST 1: a tourist profile has no Admin entry', (tester) async {
    await _pumpProfile(tester, _touristLoader());

    await _scrollTo(tester, find.text('Offline Access'));

    expect(find.text('Offline Access'), findsOneWidget);
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Admin (Demo)'), findsNothing);
    expect(find.text('Role-protected admin dashboard'), findsNothing);
  });

  testWidgets('TEST 2: an admin profile sees the Admin entry', (tester) async {
    await _pumpProfile(tester, _adminLoader());

    await _scrollTo(tester, find.text('Admin'));

    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Role-protected admin dashboard'), findsOneWidget);
    expect(find.text('Admin (Demo)'), findsNothing);
  });

  testWidgets('TEST 3: the Admin entry opens the admin dashboard', (
    tester,
  ) async {
    await _pumpProfile(tester, _adminLoader());

    await _scrollTo(tester, find.text('Admin'));
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminScreen), findsOneWidget);
    // Admin role verified, so the dashboard (not the lock screen) is shown.
    expect(find.text('Admin access required.'), findsNothing);
  });

  testWidgets('TEST 4: direct navigation as a tourist stays locked', (
    tester,
  ) async {
    final bookings = FakeAdminBookingRepository(
      bookings: [_itineraryBooking(id: 'bk-1')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          profileLoader: _touristLoader(),
          bookingRepository: bookings,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    // No booking metrics or admin actions leak through, and no booking data
    // is even requested.
    expect(bookings.listCalls, 0);
    expect(find.text('Pending Bookings'), findsNothing);
    expect(find.text('Confirmed Bookings'), findsNothing);
    expect(find.text('Total Bookings'), findsNothing);
    expect(find.text('Travelers in Bookings'), findsNothing);
    expect(find.text('Booking Requests'), findsNothing);
  });

  testWidgets('TEST 5: direct navigation as an admin renders the dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          profileLoader: _adminLoader(),
          bookingRepository: FakeAdminBookingRepository(
            bookings: [
              _itineraryBooking(id: 'bk-1', groupSize: 2),
              _itineraryBooking(
                id: 'bk-2',
                groupSize: 3,
                status: BookingStatus.confirmed,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending Bookings'), findsOneWidget);
    expect(find.text('Confirmed Bookings'), findsOneWidget);
    expect(find.text('Total Bookings'), findsOneWidget);
    expect(find.text('Travelers in Bookings'), findsOneWidget);

    await _scrollTo(tester, find.text('Booking Requests'));
    expect(find.text('Booking Requests'), findsOneWidget);
    expect(find.text('Admin access required.'), findsNothing);
  });

  testWidgets('TEST 6: a pending role lookup shows a loading indicator', (
    tester,
  ) async {
    final completer = Completer<UserProfile?>();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          profileLoader: () => completer.future,
          bookingRepository: FakeAdminBookingRepository(
            bookings: [_itineraryBooking(id: 'bk-1')],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Pending Bookings'), findsNothing);
    expect(find.text('Admin access required.'), findsNothing);
    expect(
      find.text('Could not verify admin access. Please try again.'),
      findsNothing,
    );

    completer.complete(_profile(role: 'admin'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Pending Bookings'), findsOneWidget);
  });

  testWidgets('TEST 7: a failed lookup shows a friendly error only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          profileLoader: () async =>
              throw FirebaseExceptionStub('PERMISSION_DENIED: missing index'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not verify admin access. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    // Raw Firebase detail must not reach the user.
    expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
    expect(find.text('Admin access required.'), findsNothing);
    expect(find.text('Pending Bookings'), findsNothing);
  });

  testWidgets('TEST 8: retry recovers from a failed lookup', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          profileLoader: () async {
            attempts += 1;
            if (attempts == 1) {
              throw FirebaseExceptionStub('UNAVAILABLE: try later');
            }
            return _profile(role: 'admin');
          },
          bookingRepository: FakeAdminBookingRepository(
            bookings: [_itineraryBooking(id: 'bk-1')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not verify admin access. Please try again.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(
      find.text('Could not verify admin access. Please try again.'),
      findsNothing,
    );
    expect(find.text('Pending Bookings'), findsOneWidget);
  });

  testWidgets('a missing profile (logged out) is treated as unauthorized', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminScreen(profileLoader: () async => null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.text('Pending Bookings'), findsNothing);
  });

  test('a near-miss role never grants admin access', () async {
    for (final role in [
      'Admin',
      'ADMIN',
      'admin ',
      'superadmin',
      'admin.readonly',
    ]) {
      expect(_profile(role: role).isAdmin, isFalse, reason: role);
    }

    expect(_profile(role: 'admin').isAdmin, isTrue);
    expect(_profile(role: 'tourist').isAdmin, isFalse);
  });

  test('TEST 9: no hard-coded admin email or uid gates access', () {
    final sources = _libSources();

    for (final entry in sources.entries) {
      expect(entry.value, isNot(contains('admin@')), reason: entry.key);
      expect(entry.value, isNot(contains('makeMeAdmin')), reason: entry.key);
      expect(entry.value, isNot(contains('setAdmin')), reason: entry.key);
      expect(entry.value, isNot(contains('updateRole')), reason: entry.key);

      // Role matching must be exact, never substring based.
      expect(
        entry.value,
        isNot(contains("contains('admin')")),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('contains("admin")')),
        reason: entry.key,
      );
    }

    // The single admin decision lives on the model as an exact comparison.
    final model = sources['lib/models/user_profile.dart']!;
    expect(model, contains('bool get isAdmin => role == kAdminRole;'));

    // The admin screen only asks the profile; it never inspects identity.
    final admin = sources['lib/screens/admin/admin_screen.dart']!;
    expect(admin, contains('profile?.isAdmin ?? false'));
    expect(admin, isNot(contains('.email')));
    expect(admin, isNot(contains('.uid')));
    expect(admin, isNot(contains('touristType')));

    // The profile entry point is gated on the same exact role.
    final profile = sources['lib/screens/profile/profile_screen.dart']!;
    expect(profile, contains('if (_profile?.isAdmin ?? false)'));
  });

  test('TEST 10: signup and profile updates cannot choose or change role', () {
    // A profile document without a role is a tourist, never an admin.
    final defaultProfile = UserProfile.fromFirestore('uid-1', {
      'name': 'Bikash',
      'email': 'bikash@example.com',
    });
    expect(defaultProfile.role, 'tourist');
    expect(defaultProfile.isAdmin, isFalse);

    final sources = _libSources();
    final service = sources['lib/services/firestore_service.dart']!;

    // Signup has no role parameter and stamps new documents as tourists.
    final createSignature = _slice(
      service,
      service.indexOf('createOrUpdateUserProfile({'),
      120,
    );
    expect(createSignature, contains('String? touristType,'));
    expect(createSignature, isNot(contains('role')));
    expect(service, contains("'role': kTouristRole"));

    // The per-field profile writers never send a role.
    for (final method in [
      'updatePersonalInfo',
      'updateEmergencyContact',
      'updateLanguage',
    ]) {
      final start = service.indexOf('Future<void> $method');
      expect(start, greaterThan(-1), reason: method);
      final body = _slice(service, start, 500);
      expect(body, isNot(contains('role')), reason: method);
    }

    // The signup screen only sends a display name.
    final signup = sources['lib/screens/auth/signup_screen.dart']!;
    final call = _slice(
      signup,
      signup.indexOf('createOrUpdateUserProfile('),
      160,
    );
    expect(call, isNot(contains('role')));
    expect(call, contains('name:'));

    // Firestore rules remain the real boundary and were not weakened.
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains("request.resource.data.role == 'tourist'"));

    final updateStart = rules.indexOf('allow update: if isOwner(userId)');
    expect(updateStart, greaterThan(-1));
    final updateCondition = _slice(rules, updateStart);
    final allowedKeys = updateCondition.substring(
      0,
      updateCondition.indexOf(']);'),
    );
    expect(allowedKeys, isNot(contains("'role'")));
  });
}

/// Stands in for a raw Firebase failure so tests can prove the raw message is
/// never rendered.
class FirebaseExceptionStub implements Exception {
  FirebaseExceptionStub(this.message);

  final String message;

  @override
  String toString() => 'FirebaseException: $message';
}
