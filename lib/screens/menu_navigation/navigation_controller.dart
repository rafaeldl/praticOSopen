import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, Colors; // Keep for fallback/Store
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/menu_navigation/settings.dart';
import 'package:praticos/routes.dart';

import 'home.dart';

class NavigationController extends StatelessWidget {
  NavigationController({Key? key}) : super(key: key);

  final _pageOptions = [Home(), HomeCustomerList(), Settings()];

  @override
  Widget build(BuildContext context) {
    final navigationStore = Provider.of<BottomNavigationBarStore>(context);

    return Observer(
      builder: (_) {
        return CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            currentIndex: navigationStore.currentIndex,
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
              routes: appRoutes, // Inject routes here
              builder: (BuildContext context) {
                return _pageOptions[index];
              },
            );
          },
        );
      },
    );
  }
}