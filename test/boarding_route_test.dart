import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/screens/boarding/boarding_screen.dart';

Future<void> _pickDropdown(
  WidgetTester tester,
  String hint,
  String value, {
  bool last = true,
}) async {
  final dropdown = find.byWidgetPredicate(
    (w) => w is DropdownButtonFormField<String> &&
        (w.decoration.hintText == hint),
  );
  expect(dropdown, findsOneWidget, reason: 'dropdown with hint "$hint"');
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown, warnIfMissed: false);
  await tester.pumpAndSettle();

  final target = last ? find.text(value).last : find.text(value).first;
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final btn = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (w) => w is OutlinedButton || w is ElevatedButton,
    ),
  );
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

/// Builds a route through [BoardingScreen].
///
/// [outgoingLegs] is a list of (nextLocation, transportation) pairs.
/// Each pair selects the next destination for the leg, then selects the
/// transportation for that exact leg, then adds the leg.
///
/// [returnTripTransports] (when [roundTrip] is true) lists the
/// transportation to use for each automatic return leg, in order.
Future<void> _buildBoardingScreenRoute(
  WidgetTester tester, {
  required String destination,
  required String boarding,
  required List<(String, String)> outgoingLegs,
  bool roundTrip = false,
  List<String> returnTripTransports = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BoardingScreen(
        destination: destination,
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

  // Boarding point
  await _pickDropdown(tester, 'Choose where you want to start', boarding);

  // Each outgoing leg: next destination, then transport for that leg.
  for (final (to, transport) in outgoingLegs) {
    await _pickDropdown(tester, 'Choose next location', to);
    await _pickDropdown(tester, 'Choose transportation', transport);
    await _tapButton(tester, 'Add Route Leg');
  }

  // Round trip: select Round Trip, then a transport per return leg.
  if (roundTrip) {
    await tester.tap(find.widgetWithText(ChoiceChip, 'Round Trip'));
    await tester.pumpAndSettle();

    for (final transport in returnTripTransports) {
      await _pickDropdown(tester, 'Choose transportation', transport);
      await _tapButton(tester, 'Add Return Leg');
    }
  }

  // Continue -> RecommendationScreen
  await _tapButton(tester, 'Continue');
}

String _allText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');
}

void main() {
  testWidgets('A: Kathmandu->Pokhara=Bus, Pokhara->Mustang=Jeep',
      (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
    );

    final text = _allText(tester);
    expect(text, contains('Kathmandu → Pokhara'));
    expect(text, contains('Pokhara → Mustang'));
    expect(text, contains('Bus'));
    expect(text, contains('Jeep'));
  });

  testWidgets(
      'B: Kathmandu->Pokhara=Flight, Pokhara->Jomsom=Jeep, '
      'Jomsom->Mustang=Private Vehicle', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [
        ('Pokhara', 'Flight'),
        ('Jomsom', 'Jeep'),
        ('Mustang', 'Private Vehicle'),
      ],
    );

    final text = _allText(tester);
    expect(text, contains('Kathmandu → Pokhara'));
    expect(text, contains('Pokhara → Jomsom'));
    expect(text, contains('Jomsom → Mustang'));
    expect(text, contains('Flight'));
    expect(text, contains('Jeep'));
    expect(text, contains('Private Vehicle'));
  });

  testWidgets(
      'C: round trip with per-leg transports (outbound + return)',
      (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      // Return legs are the reverse of the outgoing route:
      // Mustang->Pokhara, then Pokhara->Kathmandu.
      returnTripTransports: ['Jeep', 'Flight'],
    );

    final text = _allText(tester);
    expect(text, contains('Kathmandu → Pokhara'));
    expect(text, contains('Pokhara → Mustang'));
    expect(text, contains('Mustang → Pokhara'));
    expect(text, contains('Pokhara → Kathmandu'));
    expect(text, contains('Bus'));
    expect(text, contains('Jeep'));
    expect(text, contains('Flight'));
  });
}
