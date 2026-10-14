import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/menu_navigation/app_tabs.dart';
import 'package:praticos/screens/menu_navigation/tab_routes.dart';

void main() {
  group('visibleAppTabs', () {
    test('shows Início, Agenda and Financeiro in the fixed order', () {
      expect(
        visibleAppTabs(useScheduling: true, canViewFinancialReports: true),
        [AppTab.home, AppTab.agenda, AppTab.financial],
      );
    });

    test('hides Agenda when the company does not use scheduling', () {
      expect(
        visibleAppTabs(useScheduling: false, canViewFinancialReports: true),
        [AppTab.home, AppTab.financial],
      );
    });

    test('hides Financeiro without viewFinancialReports', () {
      expect(
        visibleAppTabs(useScheduling: true, canViewFinancialReports: false),
        [AppTab.home, AppTab.agenda],
      );
    });

    test('hides both and keeps Início alone', () {
      expect(
        visibleAppTabs(useScheduling: false, canViewFinancialReports: false),
        [AppTab.home],
      );
    });

    test('hides Financeiro when the company does not use values and billing',
        () {
      expect(
        visibleAppTabs(
          useScheduling: true,
          canViewFinancialReports: true,
          useFinancial: false,
        ),
        [AppTab.home, AppTab.agenda],
      );
    });

    test('every combination keeps the relative order of AppTab', () {
      for (final scheduling in [true, false]) {
        for (final financial in [true, false]) {
          for (final useFinancial in [true, false]) {
            final tabs = visibleAppTabs(
              useScheduling: scheduling,
              canViewFinancialReports: financial,
              useFinancial: useFinancial,
            );
            final indexes = tabs.map((t) => t.index).toList();
            expect(indexes, [...indexes]..sort());
            expect(tabs.first, AppTab.home);
          }
        }
      }
    });
  });

  group('analytics names with visible tabs', () {
    test('index follows the visible tabs', () {
      final routes = [
        for (final tab in visibleAppTabs(
          useScheduling: false,
          canViewFinancialReports: true,
        ))
          tab.routeName,
      ];
      expect(TabRoutes.nameForIndex(0, routes: routes), TabRoutes.home);
      expect(TabRoutes.nameForIndex(1, routes: routes), TabRoutes.financial);
      expect(TabRoutes.nameForIndex(2, routes: routes), isNull);
    });

    test('route names match TabRoutes.all for the full tab list', () {
      expect(AppTab.values.map((t) => t.routeName).toList(), TabRoutes.all);
    });
  });
}
