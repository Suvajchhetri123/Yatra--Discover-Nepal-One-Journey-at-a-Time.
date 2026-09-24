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
    (w) =>
        w is DropdownButtonFormField<String> && (w.decoration.hintText == hint),
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
/// Trip Type is always decided FIRST (before the boarding point): the screen
/// is opened with One Way selected, and tapping 'Round Trip' switches to a
/// round trip before any boarding point is chosen.
///
/// [outgoingLegs] is a list of (nextLocation, transportation) pairs.
/// Each pair selects the next destination for the leg, then selects the
/// transportation for that exact leg, then adds the leg.
///
/// [outboundStopDays] overrides the exploration/stay stepper for the matching
/// outbound stops (every arrival, including the final destination, defaults
/// to 0 days) before the return journey is started.
///
/// [returnTripLegs] (when [roundTrip] is true) lists the (destination,
/// transportation) pairs for each customized return leg, in order. The user
/// first taps the 'Custom Return' card, then builds the legs. When the list
/// is empty the automatic return route is used instead.
///
/// [returnStopDays] overrides the exploration/stay stepper for the matching
/// return-stop names after their leg is added (return stops default to 0
/// days). Use it to make return stops longer or to confirm a pass-through.
Future<void> _buildBoardingScreenRoute(
  WidgetTester tester, {
  required String destination,
  required String boarding,
  required List<(String, String)> outgoingLegs,
  bool roundTrip = false,
  List<(String, String)> returnTripLegs = const [],
  Map<String, int> outboundStopDays = const {},
  Map<String, int> returnStopDays = const {},
  DateTime? departureDate,
  DateTime? returnDate,
  bool tapContinue = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BoardingScreen(
        adultCount: 1,
        childCount: 0,
        touristType: 'Domestic Tourist',
        destination: destination,
        departureDate: departureDate ?? DateTime(2026, 9, 1),
        returnDate: returnDate ?? DateTime(2026, 9, 10),
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

  // Trip Type is the first planning choice.
  if (roundTrip) {
    await tester.tap(find.text('Round Trip'));
    await tester.pumpAndSettle();
  }

  // Boarding point
  await _pickDropdown(tester, 'Choose where you want to start', boarding);

  // Each outgoing leg: next destination, then transport for that leg.
  for (final (to, transport) in outgoingLegs) {
    await _pickDropdown(tester, 'Choose next location', to);
    await _pickDropdown(tester, 'Choose transportation', transport);
    await _tapButton(tester, 'Add Route Leg');
  }

  // Exploration days at outbound intermediate stops, before the return.
  for (final entry in outboundStopDays.entries) {
    await _setStepperDays(tester, stop: entry.key, targetDays: entry.value);
  }

  // Round trip: opt into Custom Return, then build each return leg with its
  // own destination and transportation.
  if (roundTrip) {
    if (returnTripLegs.isNotEmpty) {
      await tester.tap(find.text('Custom Return'));
      await tester.pumpAndSettle();

      for (final (to, transport) in returnTripLegs) {
        await _pickDropdown(tester, 'Choose next return destination', to);
        await _pickDropdown(tester, 'Choose transportation', transport);
        await _tapButton(tester, 'Add to Return Journey');
      }

      // The "Coming Back" stay steppers render once each return leg exists.
      for (final entry in returnStopDays.entries) {
        await _setStepperDays(
          tester,
          stop: entry.key,
          targetDays: entry.value,
          last: true,
        );
      }
    }
  }

  // Continue -> RecommendationScreen
  if (tapContinue) {
    await _tapButton(tester, 'Continue');
  }
}

/// Sets the exploration-day stepper for [stop] to [targetDays] by tapping
/// the +/- buttons. The stepper is located as the row containing the stop
/// name and the add-circle icon so it is not confused with dropdown labels.
/// The currently displayed day count is read from the row, so the number of
/// taps adapts to whatever state the screen already holds.
///
/// When the same location has both an outbound and a return stepper on
/// screen (for example Pokhara visited coming AND going), pass
/// [last] = true to target the return-journey stepper (which renders last).
Future<void> _setStepperDays(
  WidgetTester tester, {
  required String stop,
  required int targetDays,
  bool last = false,
}) async {
  // The exploration stepper is the Row that shows the stop name AND the
  // add-circle button. Matching the Row directly avoids picking up the
  // dropdown's selected-value label, which lives in its own row.
  final normalizedStop = stop.toLowerCase();
  final stepperRow = find.byWidgetPredicate(
    (w) =>
        w is Row &&
        w.children.any(
          (c) =>
              c is IconButton &&
              c.icon is Icon &&
              (c.icon as Icon).icon == Icons.add_circle_outline,
        ) &&
        w.children.any(
          (c) =>
              c is Expanded &&
              c.child is Column &&
              (c.child as Column).children.any(
                (t) => t is Text && t.data?.toLowerCase() == normalizedStop,
              ),
        ),
  );
  final target = last ? stepperRow.last : stepperRow.first;
  expect(target, findsOneWidget, reason: 'stepper row for $stop');

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  // Read the currently displayed day count: the numeric Text in the row
  // (the stop name and "N days of exploration" caption are not pure digits).
  final numericTexts = tester
      .widgetList<Text>(
        find.descendant(of: target, matching: find.byType(Text)),
      )
      .map((t) => t.data ?? '')
      .where((data) => RegExp(r'^\d+$').hasMatch(data))
      .toList();
  final currentDays = numericTexts.isEmpty ? 0 : int.parse(numericTexts.last);

  final steps = targetDays - currentDays;
  if (steps == 0) {
    return;
  }

  final minus = find.descendant(
    of: target,
    matching: find.byIcon(Icons.remove_circle_outline),
  );
  final plus = find.descendant(
    of: target,
    matching: find.byIcon(Icons.add_circle_outline),
  );

  for (var i = 0; i < steps.abs(); i++) {
    await tester.tap(steps < 0 ? minus : plus);
    await tester.pumpAndSettle();
  }
}

String _allText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');
}

/// Finds every exploration-day stepper row that shows the stop [stop].
/// A stop can legally appear twice (once under "Going", once under
/// "Coming Back"), so this returns a finder rather than a single row.
Finder _stopSteppers(String stop) {
  final normalizedStop = stop.toLowerCase();
  return find.byWidgetPredicate(
    (w) =>
        w is Row &&
        w.children.any(
          (c) =>
              c is IconButton &&
              c.icon is Icon &&
              (c.icon as Icon).icon == Icons.add_circle_outline,
        ) &&
        w.children.any(
          (c) =>
              c is Expanded &&
              c.child is Column &&
              (c.child as Column).children.any(
                (t) => t is Text && t.data?.toLowerCase() == normalizedStop,
              ),
        ),
  );
}

Future<void> _pumpBoardingScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BoardingScreen(
        adultCount: 1,
        childCount: 0,
        touristType: 'Domestic Tourist',
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

void main() {
  testWidgets('A: Kathmandu->Pokhara=Bus, Pokhara->Mustang=Jeep', (
    WidgetTester tester,
  ) async {
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

  testWidgets('B: Kathmandu->Pokhara=Flight, Pokhara->Jomsom=Jeep, '
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

  testWidgets('C: round trip with per-leg transports (outbound + return)', (
    WidgetTester tester,
  ) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      // Return legs are the reverse of the outgoing route:
      // Mustang->Pokhara, then Pokhara->Kathmandu.
      returnTripLegs: [('Pokhara', 'Jeep'), ('Kathmandu', 'Flight')],
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

  testWidgets('D: customized return route adds stops beyond the reversed '
      'outbound route', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      // Custom return: Mustang -> Kagbeni -> Jomsom -> Pokhara -> Kathmandu.
      // Kagbeni and Jomsom are not part of the outbound route at all.
      returnTripLegs: [
        ('Kagbeni', 'Jeep'),
        ('Jomsom', 'Private Vehicle'),
        ('Pokhara', 'Bus'),
        ('Kathmandu', 'Flight'),
      ],
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Mustang → Kagbeni'));
    expect(text, contains('Kagbeni → Jomsom'));
    expect(text, contains('Jomsom → Pokhara'));
    expect(text, contains('Pokhara → Kathmandu'));
  });

  testWidgets('E: Continue stays disabled until the custom return reaches the '
      'boarding point', (WidgetTester tester) async {
    await _pumpBoardingScreen(tester);

    // Trip Type is the first choice.
    await tester.tap(find.text('Round Trip'));
    await tester.pumpAndSettle();

    await _pickDropdown(tester, 'Choose where you want to start', 'Kathmandu');
    await _pickDropdown(tester, 'Choose next location', 'Pokhara');
    await _pickDropdown(tester, 'Choose transportation', 'Bus');
    await _tapButton(tester, 'Add Route Leg');
    await _pickDropdown(tester, 'Choose next location', 'Mustang');
    await _pickDropdown(tester, 'Choose transportation', 'Jeep');
    await _tapButton(tester, 'Add Route Leg');

    await tester.tap(find.text('Custom Return'));
    await tester.pumpAndSettle();

    // A single partial return leg (ends at Pokhara, not Kathmandu).
    await _pickDropdown(tester, 'Choose next return destination', 'Pokhara');
    await _pickDropdown(tester, 'Choose transportation', 'Jeep');
    await _tapButton(tester, 'Add to Return Journey');

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );

    // Not finished -> blocked, and the explanation is shown.
    expect(continueButton.onPressed, isNull);
    expect(
      _allText(tester),
      contains('Continue planning your return until you reach Kathmandu.'),
    );

    // Finish the route back to the boarding point -> Continue enabled.
    await _pickDropdown(tester, 'Choose next return destination', 'Kathmandu');
    await _pickDropdown(tester, 'Choose transportation', 'Flight');
    await _tapButton(tester, 'Add to Return Journey');

    final enabledButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );

    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('F: a customized return with stays is blocked when the calendar '
      'is too short', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      returnTripLegs: [
        ('Kagbeni', 'Jeep'),
        ('Pokhara', 'Bus'),
        ('Kathmandu', 'Flight'),
      ],
      // Kagbeni gets 3 exploration days instead of the default 0.
      returnStopDays: {'Kagbeni': 3},
      // 9 calendar days, but the route needs at least 11:
      // 2 travel + 3 Mustang stay + 3 return travel + 0 outbound-stop days
      // (all default 0) + 3 return-stop days (Kagbeni 3, Pokhara 0).
      returnDate: DateTime(2026, 9, 9),
    );

    final text = _allText(tester);
    expect(text, contains('provide 9 days'));
    expect(text, contains('needs at least 11 days'));

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNull);
  });

  testWidgets('G: zero exploration days on a return stop keeps Continue '
      'enabled', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      // A direct outbound leg leaves no intermediate outbound stops, so the
      // only "Pokhara" stepper on screen belongs to the return route.
      outgoingLegs: [('Mustang', 'Bus')],
      roundTrip: true,
      returnTripLegs: [
        ('Jomsom', 'Private Vehicle'),
        ('Pokhara', 'Bus'),
        ('Kathmandu', 'Flight'),
      ],
      // Jomsom and Pokhara (default 1 each) are both dropped to 0, so the
      // return stops cost no extra days. On a 9-day calendar the 7-day
      // minimum (1 travel + 3 Mustang stay + 3 return travel) fits, proving
      // "0" is a valid, accepted choice.
      returnStopDays: {'Jomsom': 0, 'Pokhara': 0},
      returnDate: DateTime(2026, 9, 9),
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, isNot(contains('needs at least')));

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('H: a direct outbound connection is offered because the database '
      'supports it', (WidgetTester tester) async {
    // Kathmandu -> Mustang is a real via-Jomsom route in the transportation
    // database, so the boarding screen offers it as a single direct leg
    // instead of forcing a multi-stop path.
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Mustang', 'Bus')],
    );

    final text = _allText(tester);
    expect(text, contains('Kathmandu → Mustang'));
    expect(text, contains('Bus'));
  });

  // ---------------------------------------------------------------------
  // NEW COVERAGE: trip type as the first planning choice + return UX.
  // ---------------------------------------------------------------------

  testWidgets('1: Trip Type is the first planning choice before boarding', (
    WidgetTester tester,
  ) async {
    await _pumpBoardingScreen(tester);

    expect(find.text('Trip Type'), findsOneWidget);
    expect(find.text('One Way'), findsOneWidget);
    expect(find.text('Round Trip'), findsOneWidget);

    // The boarding section can be reached as the next step.
    expect(_allText(tester), contains('Choose where you want to start'));
  });

  testWidgets('2: One Way shows no return-journey controls', (
    WidgetTester tester,
  ) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, isNot(contains('Return Journey')));
    expect(find.text('Automatic Return'), findsNothing);
    expect(find.text('Custom Return'), findsNothing);
  });

  testWidgets('3: Round Trip keeps the outgoing journey working and returns '
      'automatically', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      // No custom legs -> the automatic reversed return route is planned.
      tapContinue: true,
    );

    final text = _allText(tester);
    expect(text, contains('Kathmandu → Pokhara'));
    expect(text, contains('Pokhara → Mustang'));
    expect(text, contains('Mustang → Pokhara'));
    expect(text, contains('Pokhara → Kathmandu'));
  });

  testWidgets('4: a Round Trip still supports exploration days at outbound '
      'stops', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      // Pokhara is only an outbound stop here (automatic return), so its
      // stepper belongs to the outbound journey.
      outboundStopDays: {'Pokhara': 2},
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(find.text('2 days of exploration'), findsOneWidget);
    expect(text, isNot(contains('needs at least')));

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('5: Automatic Return shows a read-only reverse summary', (
    WidgetTester tester,
  ) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(find.text('Automatic Return'), findsOneWidget);
    expect(find.text('Custom Return'), findsOneWidget);
    expect(
      text,
      contains('Automatic return uses your outgoing route in reverse.'),
    );
    expect(text, isNot(contains('Custom Return Journey')));
    expect(text, isNot(contains('Choose next return destination')));

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('6: Custom Return shows context lines and the workable preview', (
    WidgetTester tester,
  ) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      returnTripLegs: [('Pokhara', 'Jeep')],
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Returning from: Mustang'));
    expect(text, contains('Returning to: Kathmandu'));
    expect(text, contains('Current location: Pokhara'));
    expect(text, contains('Your Return Journey'));
    expect(
      text,
      contains('Continue planning your return until you reach Kathmandu.'),
    );

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNull);
  });

  testWidgets('7: switching a Round Trip to One Way resets the return state '
      'but keeps the outbound journey', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      returnTripLegs: [('Pokhara', 'Jeep')],
      tapContinue: false,
    );

    // Bring the Trip Type cards back into view (the route builder may have
    // scrolled down), then switch to One Way.
    await tester.ensureVisible(find.text('One Way'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One Way'));
    await tester.pumpAndSettle();

    final text = _allText(tester);
    expect(text, isNot(contains('Your Return Journey')));
    expect(text, isNot(contains('Returning from:')));
    expect(text, contains('Kathmandu → Pokhara'));

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('8: switching a One Way to Round Trip keeps the outbound '
      'journey and offers an automatic return', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      tapContinue: false,
    );

    // Bring the Trip Type cards back into view, then switch to Round Trip.
    await tester.ensureVisible(find.text('Round Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Round Trip'));
    await tester.pumpAndSettle();

    final text = _allText(tester);
    expect(text, contains('Kathmandu → Pokhara'));
    expect(
      text,
      contains('Automatic return uses your outgoing route in reverse.'),
    );

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('9: outbound and return stays at the same location stay '
      'separate', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      returnTripLegs: [('Pokhara', 'Jeep'), ('Kathmandu', 'Flight')],
      // The outbound Pokhara stays at its own 1-day stepper while the return
      // Pokhara (default 0) is extended to 2 days.
      outboundStopDays: {'Pokhara': 1},
      returnStopDays: {'Pokhara': 2},
      tapContinue: false,
    );

    // The outbound Pokhara stepper keeps its own 1-day stay (it is the only
    // "1 day of exploration" on screen), the return Pokhara carries its own
    // 2-day stay, and the destination defaults to 0. The return preview
    // shows the return Pokhara leg carrying its own 2-day stay.
    expect(find.text('1 day of exploration'), findsOneWidget);
    expect(find.text('2 days of exploration'), findsOneWidget);
    expect(find.text('0 days of exploration'), findsOneWidget);
    expect(find.text('Jeep • Stay: 2 day(s)'), findsOneWidget);

    final text = _allText(tester);
    expect(text, isNot(contains('needs at least')));

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  // ---------------------------------------------------------------------
  // GENERIC EXPLORATION RULE: stops come from the route data, never from
  // hard-coded destination names. Three different route shapes below.
  // ---------------------------------------------------------------------

  testWidgets('A-generic: Going lists every outbound arrival, including the '
      'final destination', (WidgetTester tester) async {
    // A -> B -> C (Kathmandu -> Pokhara -> Mustang), one way.
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Going'));
    expect(text, isNot(contains('Coming Back')));

    // B is an adjustable outbound stop; C is the final destination and is
    // still listed as an adjustable arrival of its own.
    expect(_stopSteppers('Pokhara'), findsOneWidget);
    expect(_stopSteppers('Mustang'), findsOneWidget);
    expect(text, contains('Mustang'));
  });

  testWidgets('B-generic: a destination-only outbound with a custom return '
      'derives Coming Back from the return route', (WidgetTester tester) async {
    // Outbound: Kathmandu -> Chitwan (the destination is the ONLY arrival).
    // Custom return: Chitwan -> Pokhara -> Kathmandu.
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Chitwan',
      boarding: 'Kathmandu',
      outgoingLegs: [('Chitwan', 'Bus')],
      roundTrip: true,
      returnTripLegs: [('Pokhara', 'Bus'), ('Kathmandu', 'Flight')],
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Going'));
    expect(text, contains('Coming Back'));

    // Going = [Chitwan] (the destination itself is an adjustable arrival).
    expect(_stopSteppers('Chitwan'), findsOneWidget);

    // Pokhara only exists on the custom return route: exactly one Coming
    // Back stepper, derived entirely from the return segments.
    expect(_stopSteppers('Pokhara'), findsOneWidget);
  });

  testWidgets('C-generic: an automatic return lists its own arrivals and '
      'keeps them separate from the outbound visit', (
    WidgetTester tester,
  ) async {
    // Outbound: Kathmandu -> Pokhara -> Mustang. Automatic return reverses it
    // (Mustang -> Pokhara -> Kathmandu), so Pokhara is arrived at twice:
    // once Going, once Coming Back.
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      outboundStopDays: {'Pokhara': 2},
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Going'));
    expect(text, contains('Coming Back'));

    // Pokhara has one Going stepper and one Coming Back stepper.
    expect(_stopSteppers('Pokhara'), findsNWidgets(2));

    // The final destination is listed and stays adjustable like any other
    // outbound arrival.
    expect(_stopSteppers('Mustang'), findsOneWidget);

    // Going Pokhara = 2 days; the automatic-return Pokhara defaults to 0
    // and the destination also defaults to 0: separate stays never merge.
    expect(find.text('2 days of exploration'), findsOneWidget);
    expect(find.text('0 days of exploration'), findsNWidgets(2));
  });

  // ---------------------------------------------------------------------
  // VISIBILITY: the stay/exploration controls must appear dynamically from
  // the ACTUAL route, as soon as stops exist — never gated behind route
  // completion or return-route completion.
  // ---------------------------------------------------------------------

  testWidgets('Visibility TEST 1: one way A → B shows the B stay stepper', (
    WidgetTester tester,
  ) async {
    // One Way Kathmandu -> Chitwan (the ONE-WAY regression scenario).
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Chitwan',
      boarding: 'Kathmandu',
      outgoingLegs: [('Chitwan', 'Bus')],
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Going'));
    expect(text, isNot(contains('Coming Back')));
    expect(_stopSteppers('Chitwan'), findsOneWidget);
  });

  testWidgets('Visibility TEST 2: one way A → B → C shows B and C steppers', (
    WidgetTester tester,
  ) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      tapContinue: false,
    );

    expect(_stopSteppers('Pokhara'), findsOneWidget);
    expect(_stopSteppers('Mustang'), findsOneWidget);
    expect(_allText(tester), contains('Going'));
  });

  testWidgets('Visibility TEST 3: automatic round trip lists Going B, C and '
      'Coming Back B', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Going'));
    expect(text, contains('Coming Back'));

    // Pokhara is arrived at twice (Going + Coming Back): separate controls.
    expect(_stopSteppers('Pokhara'), findsNWidgets(2));
    // The destination is an outbound arrival; it is NOT repeated Coming Back.
    expect(_stopSteppers('Mustang'), findsOneWidget);
  });

  testWidgets('Visibility TEST 4: a partial custom return already shows the '
      'Coming Back stepper for the stop reached', (WidgetTester tester) async {
    // Outbound: Kathmandu -> Chitwan (A -> D). Custom return begins with one
    // leg, Chitwan -> Pokhara (D -> E), but never reaches Kathmandu.
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Chitwan',
      boarding: 'Kathmandu',
      outgoingLegs: [('Chitwan', 'Bus')],
      roundTrip: true,
      returnTripLegs: [('Pokhara', 'Bus')],
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Coming Back'));
    expect(_stopSteppers('Chitwan'), findsOneWidget);
    expect(_stopSteppers('Pokhara'), findsOneWidget);
  });

  testWidgets('Visibility TEST 5: return stay controls remain visible after '
      'the custom return reaches the boarding point', (
    WidgetTester tester,
  ) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Chitwan',
      boarding: 'Kathmandu',
      outgoingLegs: [('Chitwan', 'Bus')],
      roundTrip: true,
      returnTripLegs: [('Pokhara', 'Bus'), ('Kathmandu', 'Flight')],
      tapContinue: false,
    );

    final text = _allText(tester);
    expect(text, contains('Coming Back'));
    expect(_stopSteppers('Pokhara'), findsOneWidget);

    final continueButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('Visibility TEST 6: Going and Coming Back stays at the same '
      'location are separate controls', (WidgetTester tester) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      returnTripLegs: [('Pokhara', 'Jeep'), ('Kathmandu', 'Flight')],
      // Going Pokhara = 1 day, Coming Back Pokhara = 2 days: both shown.
      outboundStopDays: {'Pokhara': 1},
      returnStopDays: {'Pokhara': 2},
      tapContinue: false,
    );

    expect(_stopSteppers('Pokhara'), findsNWidgets(2));
    expect(find.text('1 day of exploration'), findsOneWidget);
    expect(find.text('2 days of exploration'), findsOneWidget);
  });

  testWidgets('Visibility TEST 7: changing + / - updates price and duration', (
    WidgetTester tester,
  ) async {
    await _buildBoardingScreenRoute(
      tester,
      destination: 'Mustang',
      boarding: 'Kathmandu',
      outgoingLegs: [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
      roundTrip: true,
      tapContinue: false,
    );

    String totalEstimate() {
      final row = find.ancestor(
        of: find.text('Estimated trip total'),
        matching: find.byType(Row),
      );
      return tester
          .widget<Text>(
            find.descendant(of: row, matching: find.byType(Text)).last,
          )
          .data!;
    }

    final before = totalEstimate();
    expect(_allText(tester), isNot(contains('needs at least')));

    // Raising the destination stay from 0 to 4 pushes the minimum from 7 to
    // 11 (4 travel + 3 destination visit + 4 exploration), beyond the
    // 10-day calendar.
    await _setStepperDays(tester, stop: 'Mustang', targetDays: 4);

    expect(totalEstimate(), isNot(before));
    expect(_allText(tester), contains('needs at least 11 days'));
  });
}
