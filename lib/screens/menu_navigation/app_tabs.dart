import 'tab_routes.dart';

/// Main tabs of the app, in their fixed order (design system: "Abas").
///
/// Only the places people go every day are tabs: Início (which leads to
/// everything that belongs to an order, customers included), Agenda and
/// Financeiro. Customers, catalog, team and settings open from the profile
/// button on Início. Tabs a user does not use are hidden; the remaining ones
/// keep the same relative order.
enum AppTab {
  home,
  agenda,
  financial;

  /// Analytics route name of this tab (see [TabRoutes]).
  String get routeName => switch (this) {
    AppTab.home => TabRoutes.home,
    AppTab.agenda => TabRoutes.agenda,
    AppTab.financial => TabRoutes.financial,
  };
}

/// Returns the tabs the current user sees, always in [AppTab] order.
///
/// - Agenda is hidden when the company does not use scheduling
///   (`Company.useScheduling`).
/// - Financeiro is shown only with the `viewFinancialReports` permission and
///   when the company uses values and billing (`Company.useFinancial`).
List<AppTab> visibleAppTabs({
  required bool useScheduling,
  required bool canViewFinancialReports,
  bool useFinancial = true,
}) {
  return AppTab.values
      .where(
        (tab) => switch (tab) {
          AppTab.agenda => useScheduling,
          AppTab.financial => useFinancial && canViewFinancialReports,
          _ => true,
        },
      )
      .toList(growable: false);
}
