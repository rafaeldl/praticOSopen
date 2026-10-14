import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/menu_navigation/tab_routes.dart';

void main() {
  test('maps tab indexes to analytics route names', () {
    expect(TabRoutes.nameForIndex(0), '/home');
    expect(TabRoutes.nameForIndex(1), '/agenda');
    expect(TabRoutes.nameForIndex(2), '/financial');
  });

  test('returns null for out-of-range indexes', () {
    expect(TabRoutes.nameForIndex(-1), isNull);
    expect(TabRoutes.nameForIndex(3), isNull);
  });

  test('route names are unique', () {
    expect(TabRoutes.all.toSet().length, TabRoutes.all.length);
  });
}
