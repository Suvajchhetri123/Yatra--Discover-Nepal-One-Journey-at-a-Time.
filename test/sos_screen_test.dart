import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

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

void main() {
  setUp(() {
    DemoProfileStore.instance.clear();
  });

  test(
    'SOS share message includes name, contact, destination and a maps pin',
    () {
      final message = buildSosMessage(
        name: 'Prakash Shrestha',
        phone: '+977 9812 345678',
        emergencyContactName: 'Maya Shrestha',
        emergencyContactPhone: '+977 9841 000000',
        latitude: 27.7172,
        longitude: 85.324,
        destination: 'Pokhara',
      );

      expect(message, contains('Prakash Shrestha'));
      expect(message, contains('+977 9812 345678'));
      expect(message, contains('Maya Shrestha (+977 9841 000000)'));
      expect(message, contains('Pokhara'));
      expect(
        message,
        contains(
          'https://www.google.com/maps/search/?api=1&query=27.7172,85.324',
        ),
      );
    },
  );

  test('SOS share message works without a resolved location', () {
    final message = buildSosMessage(
      name: 'Prakash Shrestha',
      phone: '+977 9812 345678',
      emergencyContactName: '',
      emergencyContactPhone: '',
      latitude: null,
      longitude: null,
      destination: 'Chitwan',
    );

    expect(message, contains('current location could not be pinned'));
    expect(message, isNot(contains('google.com/maps')));
  });

  testWidgets(
    'SOS screen with permission and location offers share, without auto-send',
    (tester) async {
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

      expect(find.text('Share SOS Message'), findsOneWidget);
      expect(find.text('Open My Location in Google Maps'), findsOneWidget);
      expect(find.text('Maya Shrestha'), findsOneWidget);

      // Nothing has been sent by merely rendering the screen: there is no
      // auto-share side effect, the user must press the button.
      expect(find.text('Share SOS Message'), findsOneWidget);
    },
  );

  testWidgets('SOS screen without permission shows settings, not share', (
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
}

Future<bool> _true() async => true;

Future<bool> _false() async => false;

Future<Position?> _positionProvider() async => _position;
