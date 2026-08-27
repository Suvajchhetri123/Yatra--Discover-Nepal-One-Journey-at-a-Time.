import 'package:flutter_test/flutter_test.dart';
import 'package:yatra/main.dart';

void main() {
  testWidgets('Yatra app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const YatraApp());

    expect(find.text('YATRA'), findsOneWidget);
    expect(
      find.text('Explore Nepal. Plan Your Journey.'),
      findsOneWidget,
    );
  });
}