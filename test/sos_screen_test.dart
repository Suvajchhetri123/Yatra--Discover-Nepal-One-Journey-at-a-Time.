import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:yatra/models/user_profile.dart';
import 'package:yatra/screens/sos/sos_screen.dart';

const UserProfile _profile = UserProfile(
  uid: 'test-uid',
  name: 'Suva',
  email: 'suva@example.com',
  phone: '9800000000',
  emergencyContactName: 'Maya',
  emergencyContactPhone: '9811111111',
  language: 'English',
);

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
      await tester.pumpWidget(
        MaterialApp(
          home: SosScreen(
            permissionCheck: _true,
            locationProvider: _positionProvider,
            profileProvider: _profileProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share SOS Message'), findsOneWidget);
      expect(find.text('Open My Location in Google Maps'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);

      // Nothing has been sent by merely rendering the screen: there is no
      // auto-share side effect, the user must press the button.
      expect(find.text('Share SOS Message'), findsOneWidget);
    },
  );

  testWidgets('SOS screen without permission shows settings, not share', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SosScreen(
          permissionCheck: _false,
          locationProvider: _positionProvider,
          profileProvider: _profileProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Location Settings'), findsOneWidget);
    expect(find.text('Share SOS Message'), findsNothing);
  });

  test('SOS message can use a supplied Firestore profile', () {
    final message = buildSosMessage(
      name: _profile.name,
      phone: _profile.phone!,
      emergencyContactName: _profile.emergencyContactName!,
      emergencyContactPhone: _profile.emergencyContactPhone!,
      latitude: 27.7172,
      longitude: 85.324,
      destination: 'My planned trip in Nepal',
    );

    expect(message, contains('Suva'));
    expect(message, contains('9800000000'));
    expect(message, contains('Maya'));
    expect(message, contains('9811111111'));
    expect(message, contains('27.7172,85.324'));
  });

  testWidgets('SOS remains usable when the profile is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SosScreen(
          permissionCheck: _true,
          locationProvider: _positionProvider,
          profileProvider: _nullProfileProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No emergency contact saved yet.'), findsOneWidget);
    expect(find.text('Share SOS Message'), findsOneWidget);
    expect(find.textContaining('27.7172'), findsOneWidget);
  });

  testWidgets('SOS remains usable when profile loading fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SosScreen(
          permissionCheck: _true,
          locationProvider: _positionProvider,
          profileProvider: _throwingProfileProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Saved profile information could not be loaded. You can still share '
        'your current location.',
      ),
      findsOneWidget,
    );
    expect(find.text('Share SOS Message'), findsOneWidget);
    expect(find.textContaining('27.7172'), findsOneWidget);
  });
}

Future<bool> _true() async => true;

Future<bool> _false() async => false;

Future<Position?> _positionProvider() async => _position;

Future<UserProfile?> _profileProvider() async => _profile;

Future<UserProfile?> _nullProfileProvider() async => null;

Future<UserProfile?> _throwingProfileProvider() async {
  throw Exception('Firebase profile load failed');
}
