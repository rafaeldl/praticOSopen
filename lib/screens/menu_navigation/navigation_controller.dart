import 'package:flutter/cupertino.dart';
import 'package:mobx/mobx.dart'; // Import for reaction
import 'package:provider/provider.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/menu_navigation/settings.dart';
import 'package:praticos/screens/dashboard/financial_dashboard_simple.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/extensions/context_extensions.dart';

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
      FinancialDashboardSimple(),
      Settings(),
    ];
  }

  /// Build tab items - Financial tab is always included
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

    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        // currentIndex is handled by the controller
        onTap: (index) {
          navigationStore.setCurrentIndex(index);
        },
        items: tabItems,
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          routes: appRoutes,
          builder: (BuildContext context) {
            return pageOptions[index];
          },
        );
      },
    );
  }
}