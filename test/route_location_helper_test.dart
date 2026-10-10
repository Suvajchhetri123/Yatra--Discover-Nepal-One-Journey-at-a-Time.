import 'package:flutter_test/flutter_test.dart';
import 'package:yatra/services/route_location_helper.dart';

void main() {
  const known = <String>['Kathmandu', 'Birtamod', 'Ilam', 'Jomsom'];

  test('canonicalize reuses established location spelling', () {
    expect(
      RouteLocationHelper.canonicalize('  kathmandu  ', known),
      'Kathmandu',
    );

    expect(RouteLocationHelper.canonicalize('BIRTAMOD', known), 'Birtamod');
  });

  test('suggestions prefer prefix matches', () {
    expect(RouteLocationHelper.suggestions('bir', known), ['Birtamod']);
  });

  test('nearDuplicate catches Biratmod versus Birtamod', () {
    expect(RouteLocationHelper.nearDuplicate('Biratmod', known), 'Birtamod');
  });

  test('genuinely different intermediate location remains allowed', () {
    expect(RouteLocationHelper.nearDuplicate('Dhulikhel', known), isNull);

    expect(RouteLocationHelper.canonicalize('Dhulikhel', known), 'Dhulikhel');
  });
}
