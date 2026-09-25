import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/screens/profile/profile_screen.dart';
import 'package:yatra/services/demo_profile_store.dart';

Future<void> _pumpProfile(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
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

void main() {
  setUp(() {
    DemoProfileStore.instance.clear();
  });

  testWidgets('profile shows personal info, emergency contact and language', (
    tester,
  ) async {
    await _pumpProfile(tester);

    expect(find.text('Personal Info'), findsOneWidget);
    expect(find.text('Travel Preferences'), findsOneWidget);

    await _scrollTo(tester, find.text('Emergency Contact'));
    expect(find.text('Emergency Contact'), findsOneWidget);

    await _scrollTo(tester, find.text('Language'));
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('नेपाली'), findsOneWidget);

    await _scrollTo(tester, find.text('My Bookings'));
    expect(find.text('My Bookings'), findsOneWidget);
    expect(find.text('Offline Access'), findsOneWidget);
    expect(find.text('Admin (Demo)'), findsOneWidget);

    await _scrollTo(tester, find.text('Log Out'));
    expect(find.text('Log Out'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('cancelling the logout confirmation stays on the profile', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await _scrollTo(tester, find.text('Log Out'));
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('Are you sure you want to log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('emergency contact can be edited from the profile', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await _scrollTo(
      tester,
      find.text('No emergency contact saved. Add one so SOS can include it.'),
    );
    expect(
      find.text('No emergency contact saved. Add one so SOS can include it.'),
      findsOneWidget,
    );

    await _scrollTo(tester, find.text('Edit Emergency Contact'));
    await tester.tap(find.text('Edit Emergency Contact'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Maya Shrestha');
    await tester.enterText(find.byType(TextField).at(1), '+977 9841 000000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Maya Shrestha'), findsOneWidget);
    expect(find.text('+977 9841 000000'), findsOneWidget);
    expect(DemoProfileStore.instance.emergencyContactName, 'Maya Shrestha');
  });

  testWidgets('language selector switches to Nepali and rebuilds labels', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await _scrollTo(tester, find.text('नेपाली'));
    await tester.tap(find.text('नेपाली'));
    await tester.pumpAndSettle();

    expect(DemoProfileStore.instance.language, 'नेपाली');
    // AppBar title now uses the Nepali translation of 'Profile'.
    expect(find.text('प्रोफाइल'), findsOneWidget);
  });
}
