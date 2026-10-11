import 'tab_routes.dart';

/// Main tabs of the app, in their fixed order (design system: "Abas").
///
/// The order never changes by role or company: tabs a user does not use are
/// hidden, and the remaining ones keep the same relative order.
enum AppTab {
  home,
  customers,
  agenda,
  financial,
  more;

  /// Analytics route name of this tab (see [TabRoutes]).
  String get routeName => switch (this) {
    AppTab.home => TabRoutes.home,
    AppTab.customers => TabRoutes.customers,
    AppTab.agenda => TabRoutes.agenda,
    AppTab.financial => TabRoutes.financial,
    AppTab.more => TabRoutes.more,
  };
}

/// Returns the tabs the current user sees, always in [AppTab] order.
///
/// - Agenda is hidden when the company does not use scheduling
///   (`Company.useScheduling`).
/// - Financeiro is shown only with the `viewFinancialReports` permission.
List<AppTab> visibleAppTabs({
  required bool useScheduling,
  required bool canViewFinancialReports,
}) {
  return AppTab.values
      .where(
        (tab) => switch (tab) {
          AppTab.agenda => useScheduling,
          AppTab.financial => canViewFinancialReports,
          _ => true,
        },
      )
      .toList(growable: false);
}
