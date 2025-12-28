import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, Colors; // Keep for fallback/Store
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart'; // Import for reaction
import 'package:provider/provider.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/menu_navigation/settings.dart';
import 'package:praticos/routes.dart';

import 'home.dart';

class NavigationController extends StatefulWidget {
  NavigationController({Key? key}) : super(key: key);

  @override
  _NavigationControllerState createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  final CupertinoTabController _tabController = CupertinoTabController();
  final _pageOptions = [Home(), HomeCustomerList(), Settings()];
  ReactionDisposer? _disposer;

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

    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        // currentIndex is handled by the controller
        onTap: (index) {
          navigationStore.setCurrentIndex(index);
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            activeIcon: Icon(CupertinoIcons.person_2_fill),
            label: 'Clientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.ellipsis),
            label: 'Mais',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          routes: appRoutes, 
          builder: (BuildContext context) {
            return _pageOptions[index];
          },
        );
      },
    );
  }
}