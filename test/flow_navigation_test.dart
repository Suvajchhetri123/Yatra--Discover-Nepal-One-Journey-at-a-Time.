import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/screens/boarding/boarding_screen.dart';
import 'package:yatra/screens/destination/destination_screen.dart';
import 'package:yatra/screens/season_analysis/season_analysis_screen.dart';
import 'package:yatra/theme/app_theme.dart';

void main() {
  testWidgets(
      'flow order: Destination -> Trip Overview -> Boarding (route builder)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DestinationScreen(
          currency: 'NPR',
          budget: 1000,
          ages: const [30],
          travelType: 'Solo',
          groupSize: 1,
          departureDate: DateTime(2026, 10, 5),
          returnDate: DateTime(2026, 10, 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kathmandu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    // Step 1: Trip Overview comes after choosing a destination.
    expect(find.byType(SeasonAnalysisScreen), findsOneWidget);

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Continue to Route Builder'),
    );
    await tester.pumpAndSettle();

    // Step 2: Route builder (boarding points/stops/transport) follows.
    expect(find.byType(BoardingScreen), findsOneWidget);
  });
}