import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/screens/profile/profile_screen.dart';

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

    // Without a Firestore role there is no admin entry for this account.
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Admin (Demo)'), findsNothing);

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
    // Without a Firestore backend the edit is kept in memory by the screen.
    expect(find.text('Maya Shrestha'), findsOneWidget);
  });

  testWidgets('language selector switches to Nepali and rebuilds labels', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await _scrollTo(tester, find.text('नेपाली'));
    await tester.tap(find.text('नेपाली'));
    await tester.pumpAndSettle();

    // AppBar title now uses the Nepali translation of 'Profile', proving the
    // selection took effect and the screen rebuilt from the new language.
    expect(find.text('प्रोफाइल'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
  });
}
