import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:yatra/screens/booking/my_bookings_screen.dart';
import 'package:yatra/screens/home/home_screen.dart';
import 'package:yatra/screens/offline/offline_access_screen.dart';
import 'package:yatra/screens/profile/profile_screen.dart';
import 'package:yatra/screens/sos/sos_screen.dart';
import 'package:yatra/services/demo_profile_store.dart';

final Position _position = Position(
  latitude: 27.7172,
  longitude: 85.324,
  timestamp: DateTime(2026, 9, 1),
  accuracy: 10,
  altitude: 1400,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Finder _sosAppBarAction() {
  return find.descendant(
    of: find.byType(AppBar),
    matching: find.byIcon(Icons.emergency_outlined),
  );
}

Future<bool> _true() async => true;

Future<bool> _false() async => false;

Future<Position?> _positionProvider() async => _position;

void main() {
  setUp(() {
    DemoProfileStore.instance.clear();
  });

  testWidgets('TEST 1: SOS lives in the main AppBar navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(_sosAppBarAction(), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
  });

  testWidgets('TEST 2: tapping SOS asks for confirmation first', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(_sosAppBarAction());
    await tester.pumpAndSettle();

    expect(find.text('Send Emergency SOS?'), findsOneWidget);
    expect(
      find.text(
        'Your current location and emergency message will be prepared for '
        'your emergency contact.',
      ),
      findsOneWidget,
    );
    expect(find.text('Send SOS'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('TEST 3: cancelling the SOS prompt stays on the current screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(_sosAppBarAction());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Send Emergency SOS?'), findsNothing);
    expect(find.byType(SosScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('TEST 4: confirming Send SOS starts the location workflow', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(_sosAppBarAction());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send SOS'));

    // The SOS flow opens (the plugin-free test environment resolves to a
    // graceful, friendly state instead of crashing).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SosScreen), findsOneWidget);
  });

  testWidgets('TEST 5: a valid location yields lat/lng and a Google Maps URL', (
    tester,
  ) async {
    DemoProfileStore.instance.setEmergencyContact(
      name: 'Maya Shrestha',
      phone: '+977 9841 000000',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SosScreen(
          permissionCheck: _true,
          locationProvider: _positionProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('27.7172'), findsOneWidget);
    expect(find.textContaining('85.324'), findsOneWidget);
    expect(find.text('Share SOS Message'), findsOneWidget);

    final message = buildSosMessage(
      name: 'Prakash Shrestha',
      phone: '+977 9812 345678',
      emergencyContactName: 'Maya Shrestha',
      emergencyContactPhone: '+977 9841 000000',
      latitude: 27.7172,
      longitude: 85.324,
      destination: 'Mustang',
    );
    expect(
      message,
      contains(
        'https://www.google.com/maps/search/?api=1&query=27.7172,85.324',
      ),
    );
    // Rendering never sends anything on its own.
    expect(find.text('Share SOS Message'), findsOneWidget);
  });

  testWidgets('TEST 6: denied location shows a friendly state, no crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SosScreen(
          permissionCheck: _false,
          locationProvider: _positionProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Location Settings'), findsOneWidget);
    expect(find.text('Share SOS Message'), findsNothing);
  });

  testWidgets('TEST 7: SOS stays reachable across Home, My Bookings, Profile '
      'and Offline', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(_sosAppBarAction(), findsOneWidget);

    // Home -> My Bookings
    await tester.tap(find.text('My Bookings'));
    await tester.pumpAndSettle();
    expect(find.byType(MyBookingsScreen), findsOneWidget);
    expect(_sosAppBarAction(), findsOneWidget);

    // My Bookings -> Home
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // Home -> Profile
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(_sosAppBarAction(), findsOneWidget);

    // The confirmation flow works on Profile too.
    await tester.tap(_sosAppBarAction());
    await tester.pumpAndSettle();
    expect(find.text('Send Emergency SOS?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Profile -> Home
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Home -> Offline
    await tester.tap(find.text('Offline'));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineAccessScreen), findsOneWidget);
    expect(_sosAppBarAction(), findsOneWidget);
  });

  testWidgets('TEST 8: existing navigation still works alongside SOS', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // Profile navigation via its AppBar icon still works.
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // My Bookings navigation still works.
    await tester.tap(find.text('My Bookings'));
    await tester.pumpAndSettle();
    expect(find.byType(MyBookingsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The SOS action still opens the confirmation on Home.
    await tester.tap(_sosAppBarAction());
    await tester.pumpAndSettle();
    expect(find.text('Send Emergency SOS?'), findsOneWidget);
  });
}
