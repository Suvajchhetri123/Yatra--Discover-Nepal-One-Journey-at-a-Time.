import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/screens/boarding/boarding_screen.dart';

Future<void> _pumpBoarding(
  WidgetTester tester, {
  required String destination,
  String? selectedTransport,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BoardingScreen(
        destination: destination,
        selectedTransport: selectedTransport,
        departureDate: DateTime(2026, 9, 1),
        returnDate: DateTime(2026, 9, 10),
        season: 'Autumn',
        suitability: 'Good',
        currency: 'USD',
        budget: 5000,
        ages: [30],
        travelType: 'Couples',
        groupSize: 2,
        seasonMessage: 'msg',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _boardingDropdown() => find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          (w.decoration.hintText == 'Choose where you want to start'),
    );

Finder _continueButton() =>
    find.widgetWithText(ElevatedButton, 'Continue');

void main() {
  testWidgets(
      'Kathmandu + transport "Kathmandu" is local exploration: '
      'no intercity boarding route is shown', (tester) async {
    await _pumpBoarding(
      tester,
      destination: 'Kathmandu',
      selectedTransport: 'Kathmandu',
    );

    // Local-exploration state is shown.
    expect(find.text('Kathmandu Local Exploration'), findsOneWidget);

    // Intercity boarding selector and its origin options must not appear.
    // These are boarding points for routes TO Kathmandu and are meaningless
    // when the user is already in Kathmandu.
    expect(_boardingDropdown(), findsNothing);
    expect(find.text('Choose where you want to start'), findsNothing);
    expect(find.text('Boarding Point'), findsNothing);
    for (final origin in ['Chitwan', 'Lukla', 'Rasuwa', 'Tansen']) {
      expect(find.text(origin), findsNothing,
          reason: '$origin must not appear in local-exploration mode');
    }

    // Continue is immediately available so the user can move toward the
    // recommendation without building an intercity route.
    expect(_continueButton(), findsOneWidget);
  });

  testWidgets(
      'Kathmandu + normal transport option still builds an intercity route',
      (tester) async {
    await _pumpBoarding(
      tester,
      destination: 'Kathmandu',
      selectedTransport: 'Bus',
    );

    expect(_boardingDropdown(), findsOneWidget);
    expect(find.text('Kathmandu Local Exploration'), findsNothing);
    expect(find.text('Choose where you want to start'), findsOneWidget);
  });

  testWidgets(
      'Other destinations are NOT treated as local exploration',
      (tester) async {
    await _pumpBoarding(
      tester,
      destination: 'Pokhara',
      selectedTransport: 'Kathmandu',
    );

    expect(_boardingDropdown(), findsOneWidget);
    expect(find.text('Kathmandu Local Exploration'), findsNothing);
  });
}
