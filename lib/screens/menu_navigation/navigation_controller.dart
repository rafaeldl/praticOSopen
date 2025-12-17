import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/menu_navigation/settings.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'home.dart';

class NavigationController extends StatefulWidget {
  NavigationController();

  @override
  _NavigationControllerState createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  final _pageOptions = [Home(), HomeCustomerList(), Settings()];

  @override
  Widget build(BuildContext context) {
    final navegationStore = Provider.of<BottomNavigationBarStore>(context);

    return Observer(builder: (_) {
      return Scaffold(
        body: _pageOptions[navegationStore.currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.home_rounded,
                    iconOutlined: Icons.home_outlined,
                    label: 'Início',
                    currentIndex: navegationStore.currentIndex,
                    onTap: () => navegationStore.setCurrentIndex(0),
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.people_rounded,
                    iconOutlined: Icons.people_outline_rounded,
                    label: 'Clientes',
                    currentIndex: navegationStore.currentIndex,
                    onTap: () => navegationStore.setCurrentIndex(1),
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.menu_rounded,
                    iconOutlined: Icons.menu_rounded,
                    label: 'Mais',
                    currentIndex: navegationStore.currentIndex,
                    onTap: () => navegationStore.setCurrentIndex(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData iconOutlined,
    required String label,
    required int currentIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? icon : iconOutlined,
              size: 24,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
            ),
            if (isSelected) ...[
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
