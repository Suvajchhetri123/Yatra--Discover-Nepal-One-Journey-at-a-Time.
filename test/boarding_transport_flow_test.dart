import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/screens/boarding/boarding_screen.dart';

Future<void> _pumpBoarding(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BoardingScreen(
        destination: 'Mustang',
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

Future<void> _pickDropdown(
  WidgetTester tester,
  String hint,
  String value,
) async {
  final dropdown = find.byWidgetPredicate(
    (w) => w is DropdownButtonFormField<String> &&
        (w.decoration.hintText == hint),
  );
  expect(dropdown, findsOneWidget, reason: 'dropdown with hint "$hint"');
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown, warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
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

Finder _transportLabel(String text) => find.text(text);
Finder _addRouteLegButton() =>
    find.widgetWithText(OutlinedButton, 'Add Route Leg');
Finder _addReturnLegButton() =>
    find.widgetWithText(OutlinedButton, 'Add Return Leg');

String _allText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');
}

void main() {
  testWidgets(
      'Boarding points first settle: '
      'no transportation selector when the screen opens', (tester) async {
    await _pumpBoarding(tester);

    // Overview destination is Mustang, but no transport should show.
    expect(find.text('Transportation'), findsNothing);
    expect(_addRouteLegButton(), findsNothing);
    expect(_addReturnLegButton(), findsNothing);
  });

  testWidgets(
      'selecting the next destination reveals exactly that leg\'s '
      'transportation and the label contains A → B', (tester) async {
    await _pumpBoarding(tester);
    await _pickDropdown(tester, 'Choose where you want to start', 'Kathmandu');

    // After boarding only, transport must stay hidden.
    expect(find.text('Transportation'), findsNothing);
    expect(_addRouteLegButton(), findsNothing);

    // Select the next destination: this creates pending A -> B.
    await _pickDropdown(tester, 'Choose next location', 'Pokhara');

    expect(find.text('Transportation'), findsOneWidget);
    expect(_transportLabel('Transportation: Kathmandu → Pokhara'),
        findsOneWidget);
    // Add Route Leg must be disabled (hidden) until transport selected.
    expect(_addRouteLegButton(), findsNothing);
  });

  testWidgets('Add Route Leg is disabled until transportation is selected',
      (tester) async {
    await _pumpBoarding(tester);
    await _pickDropdown(tester, 'Choose where you want to start', 'Kathmandu');
    await _pickDropdown(tester, 'Choose next location', 'Pokhara');

    expect(_addRouteLegButton(), findsNothing);

    await _pickDropdown(tester, 'Choose transportation', 'Bus');
    expect(_addRouteLegButton(), findsOneWidget);
  });

  testWidgets(
      'after adding A → B the transportation selector disappears, '
      'then B → C reveals a NEW selector for B → C', (tester) async {
    await _pumpBoarding(tester);
    await _pickDropdown(tester, 'Choose where you want to start', 'Kathmandu');
    await _pickDropdown(tester, 'Choose next location', 'Pokhara');
    await _pickDropdown(tester, 'Choose transportation', 'Bus');

    await _tapButton(tester, 'Add Route Leg');

    // The A -> B selector must be gone after the leg is added.
    expect(find.text('Transportation'), findsNothing);
    expect(_transportLabel('Transportation: Kathmandu → Pokhara'),
        findsNothing);
    expect(_addRouteLegButton(), findsNothing);

    // Select B -> C.
    await _pickDropdown(tester, 'Choose next location', 'Jomsom');
    expect(find.text('Transportation'), findsOneWidget);
    expect(_transportLabel('Transportation: Pokhara → Jomsom'),
        findsOneWidget);
    expect(_transportLabel('Transportation: Kathmandu → Pokhara'),
        findsNothing);
  });

  testWidgets(
      'multiple intermediate destinations: each leg keeps its own '
      'transportation through to the recommendation', (tester) async {
    await _pumpBoarding(tester);
    await _pickDropdown(tester, 'Choose where you want to start', 'Kathmandu');

    // A -> B = Bus
    await _pickDropdown(tester, 'Choose next location', 'Pokhara');
    await _pickDropdown(tester, 'Choose transportation', 'Bus');
    await _tapButton(tester, 'Add Route Leg');

    // B -> C = Flight
    await _pickDropdown(tester, 'Choose next location', 'Jomsom');
    await _pickDropdown(tester, 'Choose transportation', 'Flight');
    await _tapButton(tester, 'Add Route Leg');

    // C -> D = Jeep
    await _pickDropdown(tester, 'Choose next location', 'Mustang');
    await _pickDropdown(tester, 'Choose transportation', 'Jeep');
    await _tapButton(tester, 'Add Route Leg');

    await _tapButton(tester, 'Continue');
    final text = _allText(tester);

    // A -> B keeps its original transport.
    expect(text, contains('Kathmandu → Pokhara\nBus'));
    expect(text, contains('Pokhara → Jomsom\nFlight'));
    expect(text, contains('Jomsom → Mustang\nJeep'));
  });

  testWidgets('return legs work the same way with their own transportation',
      (tester) async {
    await _pumpBoarding(tester);
    await _pickDropdown(tester, 'Choose where you want to start', 'Kathmandu');

    // Outbound
    await _pickDropdown(tester, 'Choose next location', 'Pokhara');
    await _pickDropdown(tester, 'Choose transportation', 'Bus');
    await _tapButton(tester, 'Add Route Leg');
    await _pickDropdown(tester, 'Choose next location', 'Mustang');
    await _pickDropdown(tester, 'Choose transportation', 'Jeep');
    await _tapButton(tester, 'Add Route Leg');

    // Round trip -> return journey
    await tester.tap(find.widgetWithText(ChoiceChip, 'Round Trip'));
    await tester.pumpAndSettle();

    // Return Mustang -> Pokhara = Private Vehicle (road-only route)
    expect(_transportLabel('Transportation: Mustang → Pokhara'),
        findsOneWidget);
    expect(_addReturnLegButton(), findsNothing);
    await _pickDropdown(tester, 'Choose transportation', 'Private Vehicle');
    await _tapButton(tester, 'Add Return Leg');

    // Return Pokhara -> Kathmandu = Flight (road + air route)
    expect(_transportLabel('Transportation: Pokhara → Kathmandu'),
        findsOneWidget);
    await _pickDropdown(tester, 'Choose transportation', 'Flight');
    await _tapButton(tester, 'Add Return Leg');

    await _tapButton(tester, 'Continue');
    final text = _allText(tester);

    // Every return segment retains its own transportation. Return legs
    // render as title (from -> to) and subtitle (transportation) texts.
    expect(text, contains('Mustang → Pokhara'));
    expect(text, contains('Pokhara → Kathmandu'));
    expect(text, contains('Private Vehicle'));
    expect(text, contains('Flight'));
  });
}
