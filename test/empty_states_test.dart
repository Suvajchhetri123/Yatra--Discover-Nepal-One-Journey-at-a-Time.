import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/screens/admin/admin_booking_list_screen.dart';
import 'package:yatra/screens/booking/my_bookings_screen.dart';
import 'package:yatra/services/demo_booking_store.dart';

void main() {
  setUp(() {
    DemoBookingStore.instance.clear();
  });

  testWidgets(
    'My Bookings shows a friendly empty state with a Plan a Trip CTA',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MyBookingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No bookings yet'), findsOneWidget);
      expect(
        find.text('Your booked itineraries will appear here.'),
        findsOneWidget,
      );
      expect(find.text('Plan a Trip'), findsOneWidget);
    },
  );

  testWidgets('admin booking list shows an empty state when nothing matches', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminBookingListScreen(initialStatus: null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No bookings'), findsOneWidget);
    expect(find.text('No bookings match this status filter.'), findsOneWidget);
  });
}
