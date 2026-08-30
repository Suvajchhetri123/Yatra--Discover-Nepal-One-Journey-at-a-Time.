import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/data/transportation_data.dart';
import 'package:yatra/screens/boarding/boarding_screen.dart';

List<String> _names(List<RouteTransport> transports) =>
    transports.map((rt) => rt.option.name).toList();

/// Finds the [RouteTransport] for [mode] on the [from] -> [to] leg.
RouteTransport _route(String from, String to, String mode) {
  return transportOptionsForRoute(
    from,
    to,
  ).firstWhere((rt) => rt.option.name == mode);
}

void main() {
  group('route-aware transportation lookup', () {
    test('Everest trekking legs show only Trek', () {
      expect(_names(transportOptionsForRoute('Lukla', 'Namche Bazaar')), [
        'Trek',
      ]);
      expect(_names(transportOptionsForRoute('Namche Bazaar', 'Everest')), [
        'Trek',
      ]);
    });

    test('Kathmandu -> Lukla offers Flight directly plus realistic '
        'transfer options', () {
      final options = transportOptionsForRoute('Kathmandu', 'Lukla');
      expect(_names(options), [
        'Flight',
        'Bus',
        'Private Vehicle',
        'Jeep',
        'Motorbike',
      ]);

      // Flight covers the leg directly. The road modes only cover part of
      // the journey (no road reaches Lukla), so they are labelled as
      // requiring a transfer instead of being implied as direct.
      expect(_route('Kathmandu', 'Lukla', 'Flight').requiresTransfer, isFalse);
      for (final mode in ['Bus', 'Private Vehicle', 'Jeep', 'Motorbike']) {
        final rt = _route('Kathmandu', 'Lukla', mode);
        expect(rt.requiresTransfer, isTrue, reason: '$mode needs a transfer');
        expect(rt.transferNote, isNotNull);
      }
    });

    test('the return leg Lukla -> Kathmandu keeps the same choices', () {
      final options = _names(transportOptionsForRoute('Lukla', 'Kathmandu'));
      expect(options, containsAll(['Flight', 'Bus', 'Private Vehicle']));
      expect(_route('Lukla', 'Kathmandu', 'Bus').requiresTransfer, isTrue);
    });

    test('Annapurna village-to-village trekking legs show Trek', () {
      expect(_names(transportOptionsForRoute('Ghandruk', 'Poon Hill')), [
        'Trek',
      ]);
      expect(_names(transportOptionsForRoute('Poon Hill', 'Annapurna')), [
        'Trek',
      ]);
      expect(_names(transportOptionsForRoute('Ghandruk', 'Annapurna')), [
        'Trek',
      ]);
    });

    test('road-to-trailhead travel is offered as labelled transfer modes '
        'on Poon Hill and Annapurna Base Camp legs', () {
      for (final (from, to) in [
        ('Pokhara', 'Poon Hill'),
        ('Pokhara', 'Annapurna'),
      ]) {
        final names = _names(transportOptionsForRoute(from, to));
        expect(names, contains('Trek'));
        expect(names, contains('Jeep'));
        expect(names, contains('Private Vehicle'));
        expect(names, contains('Bus'));
        expect(_route(from, to, 'Trek').requiresTransfer, isFalse);
        for (final mode in ['Jeep', 'Private Vehicle', 'Bus']) {
          expect(
            _route(from, to, mode).requiresTransfer,
            isTrue,
            reason: '$mode on $from -> $to only reaches the trailhead',
          );
        }
      }
    });

    test('Kathmandu -> Pokhara shows road and air options, no Trek', () {
      final options = _names(transportOptionsForRoute('Kathmandu', 'Pokhara'));
      expect(options, contains('Bus'));
      expect(options, contains('Flight'));
      expect(options, contains('Private Vehicle'));
      expect(options, contains('Jeep'));
      expect(options, contains('Motorbike'));
      expect(options, isNot(contains('Trek')));
    });

    test('Pokhara -> Ghandruk shows road options, not Trek', () {
      final options = _names(transportOptionsForRoute('Pokhara', 'Ghandruk'));
      expect(options, contains('Jeep'));
      expect(options, contains('Bus'));
      expect(options, contains('Motorbike'));
      expect(options, isNot(contains('Trek')));
    });

    test('non-trekking routes do not incorrectly show Trek', () {
      final chitwan = _names(transportOptionsForRoute('Kathmandu', 'Chitwan'));
      expect(chitwan, isNot(contains('Trek')));
      final mustang = _names(transportOptionsForRoute('Pokhara', 'Mustang'));
      expect(mustang, isNot(contains('Trek')));
    });

    test('Mustang valley and Upper-Mustang legs are road-only '
        'without Motorbike', () {
      for (final (from, to) in [
        ('Jomsom', 'Kagbeni'),
        ('Jomsom', 'Marpha'),
        ('Kagbeni', 'Muktinath'),
        ('Kagbeni', 'Mustang'),
        ('Jomsom', 'Mustang'),
      ]) {
        final names = _names(transportOptionsForRoute(from, to));
        expect(names, contains('Jeep'));
        expect(names, isNot(contains('Motorbike')));
        expect(names, isNot(contains('Flight')));
        expect(names, isNot(contains('Trek')));
      }
    });

    test('Jomsom gateway routes include Motorbike plus road and air', () {
      final jomsom = _names(transportOptionsForRoute('Kathmandu', 'Jomsom'));
      expect(
        jomsom,
        containsAll(['Flight', 'Bus', 'Jeep', 'Private Vehicle', 'Motorbike']),
      );
    });

    test('route pairing is symmetric (returns use the same suitability)', () {
      expect(_names(transportOptionsForRoute('Namche Bazaar', 'Everest')), [
        'Trek',
      ]);
      expect(_names(transportOptionsForRoute('Everest', 'Namche Bazaar')), [
        'Trek',
      ]);
      expect(
        _names(transportOptionsForRoute('Mustang', 'Pokhara')),
        contains('Jeep'),
      );
      // Flying Mustang -> Pokhara goes via Jomsom, so it is a transfer too.
      expect(_route('Mustang', 'Pokhara', 'Flight').requiresTransfer, isTrue);
      expect(
        _names(transportOptionsForRoute('Jomsom', 'Pokhara')),
        contains('Flight'),
      );
    });

    test('Trek is a first-class recognized mode', () {
      expect(trekOption.name, 'Trek');
    });
  });

  // ---- Widget-level: option visibility driven by the real route ----

  Future<void> pumpBoarding(
    WidgetTester tester, {
    String destination = 'Everest',
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
  }

  Future<void> pick(WidgetTester tester, String hint, String value) async {
    final dropdown = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
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

  Future<void> tapButton(WidgetTester tester, String label) async {
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

  Future<List<String>> dropdownOptions(
    WidgetTester tester,
    String hint, {
    List<String> candidates = const [
      'Bus',
      'Flight',
      'Private Vehicle',
      'Jeep',
      'Motorbike',
      'Trek',
      'Bicycle',
    ],
  }) async {
    final dropdown = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          (w.decoration.hintText == hint),
    );
    expect(dropdown, findsOneWidget, reason: 'dropdown with hint "$hint"');
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Only the currently-open menu's items render as visible text.
    final present = <String>[
      for (final name in candidates)
        if (tester.any(find.text(name))) name,
    ];

    // Dismiss the open menu.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    return present;
  }

  testWidgets('Kathmandu -> Lukla offers the realistic set of transportation', (
    tester,
  ) async {
    await pumpBoarding(tester, destination: 'Everest');
    await pick(tester, 'Choose where you want to start', 'Kathmandu');
    await pick(tester, 'Choose next location', 'Lukla');

    final options = await dropdownOptions(tester, 'Choose transportation');
    expect(
      options,
      containsAll(['Flight', 'Bus', 'Private Vehicle', 'Jeep', 'Motorbike']),
    );
    expect(options, isNot(contains('Trek')));
  });

  testWidgets('transfer journeys are labelled so road options to Lukla are '
      'not implied as direct', (tester) async {
    await pumpBoarding(tester, destination: 'Everest');
    await pick(tester, 'Choose where you want to start', 'Kathmandu');
    await pick(tester, 'Choose next location', 'Lukla');

    final transportDropdown = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          (w.decoration.hintText == 'Choose transportation'),
    );
    await tester.ensureVisible(transportDropdown);
    await tester.pumpAndSettle();
    await tester.tap(transportDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify that the four road options are present.
    for (final mode in ['Bus', 'Private Vehicle', 'Jeep', 'Motorbike']) {
      expect(
        find.text(mode),
        findsOneWidget,
        reason: '$mode should be available as a transfer option',
      );
    }

    // The transfer explanation is part of each RouteTransport record.
    final options = transportOptionsForRoute('Kathmandu', 'Lukla');

    final transferOptions = options.where((rt) => rt.requiresTransfer);
    expect(
      transferOptions.length,
      4,
      reason: 'Four road options should be required a transfer',
    );

    for (final rt in transferOptions) {
      expect(rt.transferNote, isNotNull);
      expect(
        rt.transferNote,
        'No road reaches Lukla: drive to Jiri/Salleri, then trek the rest.',
      );
    }

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });

  testWidgets('Everest second leg (Lukla -> Namche Bazaar) is Trek-only', (
    tester,
  ) async {
    await pumpBoarding(tester, destination: 'Everest');
    await pick(tester, 'Choose where you want to start', 'Kathmandu');
    await pick(tester, 'Choose next location', 'Lukla');
    await pick(tester, 'Choose transportation', 'Flight');
    await tapButton(tester, 'Add Route Leg');

    await pick(tester, 'Choose next location', 'Namche Bazaar');
    expect(await dropdownOptions(tester, 'Choose transportation'), ['Trek']);
  });

  testWidgets('Kathmandu -> Pokhara offers road+air, not Trek', (tester) async {
    await pumpBoarding(tester, destination: 'Mustang');
    await pick(tester, 'Choose where you want to start', 'Kathmandu');
    await pick(tester, 'Choose next location', 'Pokhara');

    final options = await dropdownOptions(tester, 'Choose transportation');
    expect(options, contains('Bus'));
    expect(options, contains('Flight'));
    expect(options, contains('Private Vehicle'));
    expect(options, contains('Jeep'));
    expect(options, contains('Motorbike'));
    expect(options, isNot(contains('Trek')));
  });
}
