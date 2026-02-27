import 'package:flutter/cupertino.dart';
import 'package:mobx/mobx.dart'; // Import for reaction
import 'package:provider/provider.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/menu_navigation/settings.dart';
import 'package:praticos/screens/dashboard/financial_dashboard_simple.dart';
import 'package:praticos/screens/agenda/agenda_screen.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/responsive/adaptive_scaffold.dart';
import 'package:praticos/responsive/desktop_sidebar.dart';

import 'home.dart';

class NavigationController extends StatefulWidget {
  const NavigationController({super.key});

  @override
  _NavigationControllerState createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  final CupertinoTabController _tabController = CupertinoTabController();
  ReactionDisposer? _disposer;

  /// Build page options - Financial tab is always included
  /// Permission check is handled inside FinancialDashboardSimple
  List<Widget> _buildPageOptions() {
    return <Widget>[
      Home(),
      HomeCustomerList(),
      const AgendaScreen(),
      FinancialDashboardSimple(),
      Settings(),
    ];
  }

  /// Build tab items for mobile bottom bar
  List<BottomNavigationBarItem> _buildTabItems(BuildContext context) {
    return <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_home',
          child: const Icon(CupertinoIcons.house),
        ),
        activeIcon: const Icon(CupertinoIcons.house_fill),
        label: context.l10n.home,
      ),
      BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_customers',
          child: const Icon(CupertinoIcons.person_2),
        ),
        activeIcon: const Icon(CupertinoIcons.person_2_fill),
        label: context.l10n.customers,
      ),
      BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_agenda',
          child: const Icon(CupertinoIcons.calendar),
        ),
        activeIcon: const Icon(CupertinoIcons.calendar_today),
        label: context.l10n.agenda,
      ),
      BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_financial',
          child: const Icon(CupertinoIcons.chart_pie),
        ),
        activeIcon: const Icon(CupertinoIcons.chart_pie_fill),
        label: context.l10n.financial,
      ),
      BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_settings',
          child: const Icon(CupertinoIcons.ellipsis),
        ),
        label: context.l10n.more,
      ),
    ];
  }

  /// Build sidebar destinations for desktop layout
  List<SidebarDestination> _buildSidebarDestinations(BuildContext context) {
    return [
      SidebarDestination(
        icon: CupertinoIcons.house,
        activeIcon: CupertinoIcons.house_fill,
        label: context.l10n.home,
      ),
      SidebarDestination(
        icon: CupertinoIcons.person_2,
        activeIcon: CupertinoIcons.person_2_fill,
        label: context.l10n.customers,
      ),
      SidebarDestination(
        icon: CupertinoIcons.calendar,
        activeIcon: CupertinoIcons.calendar_today,
        label: context.l10n.agenda,
      ),
      SidebarDestination(
        icon: CupertinoIcons.chart_pie,
        activeIcon: CupertinoIcons.chart_pie_fill,
        label: context.l10n.financial,
      ),
      SidebarDestination(
        icon: CupertinoIcons.ellipsis,
        activeIcon: CupertinoIcons.ellipsis,
        label: context.l10n.more,
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigationStore = Provider.of<BottomNavigationBarStore>(context);

    // Dispose previous reaction if dependencies change
    _disposer?.call();

    // React to store changes to update the tab controller
    _disposer = reaction(
      (_) => navigationStore.currentIndex,
      (dynamic index) {
        if (_tabController.index != index) {
          _tabController.index = index;
        }
      },
    );
  }

  @override
  void dispose() {
    _disposer?.call();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationStore = Provider.of<BottomNavigationBarStore>(context);
    final pageOptions = _buildPageOptions();
    final tabItems = _buildTabItems(context);
    final sidebarDestinations = _buildSidebarDestinations(context);

    return AdaptiveScaffold(
      tabController: _tabController,
      destinations: sidebarDestinations,
      tabItems: tabItems,
      pages: pageOptions,
      routes: appRoutes,
      onTabChanged: (index) {
        navigationStore.setCurrentIndex(index);
      },
    );
  }
}
