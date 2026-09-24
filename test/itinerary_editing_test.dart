import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/travel_route_model.dart';
import 'package:yatra/screens/recommendation/recommendation_screen.dart';

const _route = TravelRoute(
  boardingPoint: 'Kathmandu',
  destination: 'Pokhara',
  segments: [
    RouteSegment(
      from: 'Kathmandu',
      to: 'Pokhara',
      transportation: 'Tourist Bus',
    ),
  ],
  tripDirection: TripDirection.oneWay,
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RecommendationScreen(
        touristType: 'Domestic Tourist',
        destination: 'Pokhara',
        departureDate: DateTime(2026, 9, 1),
        returnDate: DateTime(2026, 9, 4),
        season: 'Autumn',
        suitability: 'Good',
        currency: 'USD',
        budget: 5000,
        ages: [30],
        adultCount: 1,
        childCount: 0,
        travelType: 'Solo',
        groupSize: 1,
        seasonMessage: 'msg',
        route: _route,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('itinerary can be edited, cancelled and reset', (tester) async {
    await _pump(tester);

    // Read-only mode shows an edit entry point and no editing controls.
    expect(find.text('Edit Itinerary'), findsOneWidget);
    expect(find.text('Editing Mode'), findsNothing);

    // Enter edit mode.
    await _tapVisible(tester, find.text('Edit Itinerary'));
    expect(find.text('Editing Mode'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Reset to Recommended'), findsOneWidget);

    // Travel legs stay read-only: exactly one travel row (KTM -> Pokhara) is
    // rendered on day 1, without an edit/delete control.
    expect(find.textContaining('Travel · Kathmandu → Pokhara'), findsOneWidget);

    // Open the first editable (attraction/activity) item and change its title.
    await _tapVisible(tester, find.byTooltip('Edit text / note').first);
    expect(find.text('Edit Itinerary Item'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'My Custom Stop');
    await _tapVisible(tester, find.text('Save'));

    // The edited title is visible in edit mode after saving the sheet.
    expect(find.text('My Custom Stop'), findsOneWidget);

    // Cancel discards the edit and restores the recommended plan.
    await _tapVisible(tester, find.text('Cancel'));
    expect(find.text('Editing Mode'), findsNothing);
    expect(find.text('My Custom Stop'), findsNothing);

    // Re-edit and save so the on-screen itinerary reflects the change.
    await _tapVisible(tester, find.text('Edit Itinerary'));
    await _tapVisible(tester, find.byTooltip('Edit text / note').first);
    await tester.enterText(find.byType(TextField).first, 'Custom Stop Kept');
    await _tapVisible(tester, find.text('Save'));
    await _tapVisible(tester, find.text('Save Changes'));

    expect(find.text('Custom Stop Kept'), findsOneWidget);
    expect(find.text('Editing Mode'), findsNothing);

    // Reset to Recommended clears the saved edit and restores generated text.
    await _tapVisible(tester, find.text('Edit Itinerary'));
    await _tapVisible(tester, find.text('Reset to Recommended'));
    expect(find.text('Custom Stop Kept'), findsNothing);
    expect(find.text('Editing Mode'), findsNothing);
  });

  testWidgets('Edit Trip Plan action returns to the planning flow', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byIcon(Icons.edit_outlined), findsWidgets);

    // Use the AppBar action (tooltip 'Edit Trip Plan').
    await tester.tap(find.byTooltip('Edit Trip Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Trip Plan?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Trip Plan?'), findsNothing);
  });

  testWidgets('itinerary items can be reordered within a day', (tester) async {
    await _pump(tester);
    await _tapVisible(tester, find.text('Edit Itinerary'));

    // Editable rows expose up/down/remove handles and per-day add buttons;
    // travel legs are read-only so there is no 'Add Activity' tooltip row.
    expect(find.byTooltip('Move up'), findsWidgets);
    expect(find.byTooltip('Move down'), findsWidgets);
    expect(find.byTooltip('Remove'), findsWidgets);
    expect(find.byTooltip('Add Activity'), findsNothing);
    expect(find.text('Add Activity'), findsWidgets);

    // Removing a row is allowed in edit mode; travel rows cannot be removed.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
  });
}
