import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/menu_navigation/tab_routes.dart';

void main() {
  test('maps tab indexes to analytics route names', () {
    expect(TabRoutes.nameForIndex(0), '/home');
    expect(TabRoutes.nameForIndex(1), '/customers');
    expect(TabRoutes.nameForIndex(2), '/agenda');
    expect(TabRoutes.nameForIndex(3), '/financial');
    expect(TabRoutes.nameForIndex(4), '/more');
  });

  test('returns null for out-of-range indexes', () {
    expect(TabRoutes.nameForIndex(-1), isNull);
    expect(TabRoutes.nameForIndex(5), isNull);
  });

  test('route names are unique', () {
    expect(TabRoutes.all.toSet().length, TabRoutes.all.length);
  });
}
