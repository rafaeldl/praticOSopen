import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/menu_navigation/app_tabs.dart';
import 'package:praticos/screens/menu_navigation/tab_routes.dart';

void main() {
  group('visibleAppTabs', () {
    test('shows Início, Clientes, Agenda and Financeiro in the fixed order', () {
      expect(
        visibleAppTabs(useScheduling: true, canViewFinancialReports: true),
        [AppTab.home, AppTab.customers, AppTab.agenda, AppTab.financial],
      );
    });

    test('hides Agenda when the company does not use scheduling', () {
      expect(
        visibleAppTabs(useScheduling: false, canViewFinancialReports: true),
        [AppTab.home, AppTab.customers, AppTab.financial],
      );
    });

    test('hides Financeiro without viewFinancialReports', () {
      expect(
        visibleAppTabs(useScheduling: true, canViewFinancialReports: false),
        [AppTab.home, AppTab.customers, AppTab.agenda],
      );
    });

    test('hides both and keeps Início and Clientes', () {
      expect(
        visibleAppTabs(useScheduling: false, canViewFinancialReports: false),
        [AppTab.home, AppTab.customers],
      );
    });

    test('Clientes shows for every role and company setting', () {
      for (final scheduling in [true, false]) {
        for (final financial in [true, false]) {
          expect(
            visibleAppTabs(
              useScheduling: scheduling,
              canViewFinancialReports: financial,
            ),
            contains(AppTab.customers),
          );
        }
      }
    });

    test(
      'hides Financeiro when the company does not use values and billing',
      () {
        expect(
          visibleAppTabs(
            useScheduling: true,
            canViewFinancialReports: true,
            useFinancial: false,
          ),
          [AppTab.home, AppTab.customers, AppTab.agenda],
        );
      },
    );

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
            expect(tabs[1], AppTab.customers);
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
      expect(TabRoutes.nameForIndex(1, routes: routes), TabRoutes.customers);
      expect(TabRoutes.nameForIndex(2, routes: routes), TabRoutes.financial);
      expect(TabRoutes.nameForIndex(3, routes: routes), isNull);
    });

    test('route names match TabRoutes.all for the full tab list', () {
      expect(AppTab.values.map((t) => t.routeName).toList(), TabRoutes.all);
    });
  });
}
