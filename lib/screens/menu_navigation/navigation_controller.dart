import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/menu_navigation/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'home.dart';

class NavigationController extends StatefulWidget {
  NavigationController();

  @override
  _NavigationControllerState createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  // GlobalKey globalKey = GlobalKey(debugLabel: 'btm_app_bar');

  final _pageOptions = [Home(), HomeCustomerList(), Settings()];

  @override
  Widget build(BuildContext context) {
    final navegationStore = Provider.of<BottomNavigationBarStore>(context);

    return Observer(builder: (_) {
      return Scaffold(
        body: _pageOptions[navegationStore.currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navegationStore.currentIndex,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
            BottomNavigationBarItem(
                icon: Icon(Icons.people), label: 'Clientes'),
            BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Mais'),
          ],
          onTap: (index) {
            navegationStore.setCurrentIndex(index);
          },
        ),
      );
    });
  }
}
