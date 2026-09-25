import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/packages_data.dart';
import 'package:yatra/models/journey_stop_plan.dart';
import 'package:yatra/models/package_model.dart';
import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/screens/boarding/boarding_screen.dart';
import 'package:yatra/services/trip_cost_estimator.dart';

final DateTime _departure = DateTime(2026, 9, 1);
final DateTime _returnDate = DateTime(2026, 9, 30);

/// Mirrors the boarding screen's `_routeEstimate` for a one-way
/// Kathmandu -> Pokhara -> Mustang route using the SAME input the screen uses.
TripCostEstimate _estimate({
  List<RouteSegment>? segments,
  TripDirection direction = TripDirection.oneWay,
  List<JourneyStopPlan> stopPlans = const [],
  List<RouteSegment>? returnSegments,
}) {
  return TripCostEstimator.estimate(
    touristType: 'Domestic Tourist',
    destination: 'Mustang',
    durationDays: _returnDate.difference(_departure).inDays + 1,
    adultCount: 1,
    childCount: 0,
    childAges: const [],
    route: TravelRoute(
      boardingPoint: 'Kathmandu',
      destination: 'Mustang',
      segments: segments ?? const [],
      tripDirection: direction,
      stopPlans: stopPlans,
      returnSegments: returnSegments,
    ),
  );
}

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

String _allText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');
}

String _totalText(WidgetTester tester) {
  final row = find.ancestor(
    of: find.text('Estimated trip total'),
    matching: find.byType(Row),
  );
  return tester
      .widget<Text>(find.descendant(of: row, matching: find.byType(Text)).last)
      .data!;
}

bool _continueEnabled(WidgetTester tester) {
  final button = tester.widget<ElevatedButton>(
    find.ancestor(
      of: find.text('Continue'),
      matching: find.byType(ElevatedButton),
    ),
  );
  return button.onPressed != null;
}

/// Pumps [BoardingScreen] in NPR and builds the matching route.
Future<void> _pumpBoarding(
  WidgetTester tester, {
  required double budget,
  bool roundTrip = false,
  List<(String, String)> legs = const [('Pokhara', 'Bus'), ('Mustang', 'Jeep')],
  TourPackage? package,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BoardingScreen(
        adultCount: 1,
        childCount: 0,
        touristType: 'Domestic Tourist',
        destination: 'Mustang',
        departureDate: _departure,
        returnDate: _returnDate,
        season: 'Autumn',
        suitability: 'Good',
        currency: 'NPR',
        budget: budget,
        ages: [30],
        travelType: 'Couples',
        groupSize: 2,
        seasonMessage: 'msg',
        package: package,
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (roundTrip) {
    await tester.tap(find.text('Round Trip'));
    await tester.pumpAndSettle();
  }

  await _pickDropdown(tester, 'Choose where you want to start', 'Kathmandu');

  for (final (to, transport) in legs) {
    await _pickDropdown(tester, 'Choose next location', to);
    await _pickDropdown(tester, 'Choose transportation', transport);
    await _tapButton(tester, 'Add Route Leg');
  }
}

void main() {
  testWidgets('TEST 3: manual low budget is blocked with the warning card', (
    tester,
  ) async {
    final min = _estimate(
      segments: const [
        RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
        RouteSegment(from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
      ],
    ).minimum;

    await _pumpBoarding(tester, budget: min - 1000);

    final text = _allText(tester);
    expect(text, contains('Route Cost Summary'));
    expect(text, contains('Your budget'));
    expect(text, contains('Estimated trip total'));
    expect(text, contains('Your budget is not enough for this trip.'));
    expect(text, contains('Estimated minimum:'));
    expect(text, contains('Additional amount needed:'));
    expect(text, contains('Increase your budget or adjust your trip.'));

    expect(_continueEnabled(tester), isFalse);
  });

  testWidgets('TEST 4: a sufficient manual budget continues', (tester) async {
    final total = _estimate(
      segments: const [
        RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
        RouteSegment(from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
      ],
    ).total;

    await _pumpBoarding(tester, budget: total);

    expect(_continueEnabled(tester), isTrue);
    expect(_allText(tester), contains('Budget Sufficient'));
    expect(
      _allText(tester),
      isNot(contains('Your budget is not enough for this trip.')),
    );
  });

  testWidgets('TEST 5: exploration days flip the verdict to blocked', (
    tester,
  ) async {
    final segments = const [
      RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
      RouteSegment(from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
    ];
    final minBase = _estimate(segments: segments).minimum;
    final minWithStay = _estimate(
      segments: segments,
      stopPlans: const [
        JourneyStopPlan(location: 'Mustang', explorationDays: 5),
      ],
    ).minimum;

    await _pumpBoarding(tester, budget: (minBase + minWithStay) / 2);

    expect(_continueEnabled(tester), isTrue);
    expect(
      _allText(tester),
      isNot(contains('Your budget is not enough for this trip.')),
    );

    await _setStepperDays(tester, stop: 'Mustang', targetDays: 5);

    expect(_continueEnabled(tester), isFalse);
    expect(
      _allText(tester),
      contains('Your budget is not enough for this trip.'),
    );
  });

  testWidgets('TEST 6: changing a return transport recalculates the gate', (
    tester,
  ) async {
    final outbound = const [
      RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
      RouteSegment(from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
    ];
    final customReturn = const [
      RouteSegment(from: 'Mustang', to: 'Pokhara', transportation: 'Jeep'),
      RouteSegment(from: 'Pokhara', to: 'Kathmandu', transportation: 'Flight'),
    ];
    final minAuto = _estimate(
      segments: outbound,
      direction: TripDirection.roundTrip,
    ).minimum;
    final minCustom = _estimate(
      segments: outbound,
      direction: TripDirection.roundTrip,
      returnSegments: customReturn,
    ).minimum;

    await _pumpBoarding(
      tester,
      budget: (minAuto + minCustom) / 2,
      roundTrip: true,
    );

    // Automatic (reversed-bus/jeep) return fits the midpoint budget.
    expect(_continueEnabled(tester), isTrue);
    final autoTotal = _totalText(tester);

    await tester.tap(find.text('Custom Return'));
    await tester.pumpAndSettle();

    // First custom return leg: Mustang -> Pokhara by Jeep. The estimate
    // recalculates live as the return route changes.
    await _pickDropdown(tester, 'Choose next return destination', 'Pokhara');
    await _pickDropdown(tester, 'Choose transportation', 'Jeep');
    await _tapButton(tester, 'Add to Return Journey');
    expect(_totalText(tester), isNot(autoTotal));

    // Expensive Flight return leg pushes the minimum above the budget.
    await _pickDropdown(tester, 'Choose next return destination', 'Kathmandu');
    await _pickDropdown(tester, 'Choose transportation', 'Flight');
    await _tapButton(tester, 'Add to Return Journey');

    expect(_continueEnabled(tester), isFalse);
    expect(
      _allText(tester),
      contains('Your budget is not enough for this trip.'),
    );
  });

  testWidgets('TEST 7: a custom return changes the estimate', (tester) async {
    final outbound = const [
      RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
      RouteSegment(from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
    ];
    final customReturn = const [
      RouteSegment(from: 'Mustang', to: 'Pokhara', transportation: 'Jeep'),
      RouteSegment(from: 'Pokhara', to: 'Kathmandu', transportation: 'Flight'),
    ];
    // Comfortably above the custom-return minimum so only the estimate
    // change is under test, never the gate.
    final budget =
        _estimate(
          segments: outbound,
          direction: TripDirection.roundTrip,
          returnSegments: customReturn,
        ).minimum +
        5000;

    await _pumpBoarding(tester, budget: budget, roundTrip: true);
    final autoTotal = _totalText(tester);

    await tester.tap(find.text('Custom Return'));
    await tester.pumpAndSettle();
    await _pickDropdown(tester, 'Choose next return destination', 'Pokhara');
    await _pickDropdown(tester, 'Choose transportation', 'Jeep');
    await _tapButton(tester, 'Add to Return Journey');
    await _pickDropdown(tester, 'Choose next return destination', 'Kathmandu');
    await _pickDropdown(tester, 'Choose transportation', 'Flight');
    await _tapButton(tester, 'Add to Return Journey');

    final text = _allText(tester);
    expect(_totalText(tester), isNot(autoTotal));
    expect(text, contains('Mustang → Pokhara (Jeep)'));
    expect(text, contains('Pokhara → Kathmandu (Flight)'));
    expect(_continueEnabled(tester), isTrue);
  });

  testWidgets('TEST 8: package trips keep working with the budget gate', (
    tester,
  ) async {
    final min = _estimate(
      segments: const [
        RouteSegment(from: 'Kathmandu', to: 'Mustang', transportation: 'Bus'),
      ],
    ).minimum;

    await _pumpBoarding(
      tester,
      budget: min + 1000,
      legs: const [('Mustang', 'Bus')],
      package: tourPackages.first,
    );

    expect(_continueEnabled(tester), isTrue);
    expect(
      _allText(tester),
      isNot(contains('Your budget is not enough for this trip.')),
    );
  });

  testWidgets('TEST 9: a very high budget stays allowed and never inflates', (
    tester,
  ) async {
    final est = _estimate(
      segments: const [
        RouteSegment(from: 'Kathmandu', to: 'Pokhara', transportation: 'Bus'),
        RouteSegment(from: 'Pokhara', to: 'Mustang', transportation: 'Jeep'),
      ],
    );

    await _pumpBoarding(tester, budget: est.total * 3);

    expect(_continueEnabled(tester), isTrue);
    expect(_allText(tester), contains('Budget More Than Enough'));
    expect(_allText(tester), contains('exceeds the estimated'));
    // The estimated trip cost keeps its TRUE value; the extra budget only
    // changes the verdict, never the trip total.
    expect(_totalText(tester), TripCostEstimator.formatNprAmount(est.total));
  });
}

/// Taps the +/- stepper for [stop] until it reads [targetDays].
Future<void> _setStepperDays(
  WidgetTester tester, {
  required String stop,
  required int targetDays,
}) async {
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
  final target = stepperRow.first;
  expect(target, findsOneWidget, reason: 'stepper row for $stop');

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  final numericTexts = tester
      .widgetList<Text>(
        find.descendant(of: target, matching: find.byType(Text)),
      )
      .map((t) => t.data ?? '')
      .where((data) => RegExp(r'^\d+$').hasMatch(data))
      .toList();
  final currentDays = numericTexts.isEmpty ? 0 : int.parse(numericTexts.last);

  final steps = targetDays - currentDays;
  if (steps == 0) return;

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
