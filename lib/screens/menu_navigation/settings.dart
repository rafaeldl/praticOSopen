import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:praticos/global.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final UserStore _userStore = UserStore();

  @override
  Widget build(BuildContext context) {
    _userStore.findCurrentUser();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Ajustes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header do perfil
            _buildProfileHeader(),
            SizedBox(height: 16),
            // Seções de menu
            _buildMenuSection(
              'Cadastros',
              [
                _MenuItemData(
                  icon: Icons.people_rounded,
                  title: 'Clientes',
                  subtitle: 'Gerenciar clientes cadastrados',
                  onTap: () => Navigator.pushNamed(context, '/customer_list'),
                ),
                _MenuItemData(
                  icon: Icons.directions_car_rounded,
                  title: 'Veículos',
                  subtitle: 'Gerenciar veículos cadastrados',
                  onTap: () => Navigator.pushNamed(context, '/device_list'),
                ),
                _MenuItemData(
                  icon: Icons.build_rounded,
                  title: 'Serviços',
                  subtitle: 'Gerenciar serviços oferecidos',
                  onTap: () => Navigator.pushNamed(context, '/service_list'),
                ),
                _MenuItemData(
                  icon: Icons.inventory_2_rounded,
                  title: 'Produtos',
                  subtitle: 'Gerenciar estoque de produtos',
                  onTap: () => Navigator.pushNamed(context, '/product_list'),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildMenuSection(
              'Conta',
              [
                _MenuItemData(
                  icon: Icons.logout_rounded,
                  title: 'Sair',
                  subtitle: 'Encerrar sessão',
                  onTap: () async => AuthStore().signOutGoogle(),
                  isDestructive: true,
                ),
              ],
            ),
            SizedBox(height: 24),
            _buildVersionInfo(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      color: AppTheme.surfaceColor,
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.backgroundColor,
              backgroundImage: Global.currentUser?.photoURL != null
                  ? NetworkImage(Global.currentUser!.photoURL!)
                  : null,
              child: Global.currentUser?.photoURL == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 50,
                      color: AppTheme.textTertiary,
                    )
                  : null,
            ),
          ),
          SizedBox(height: 16),
          Text(
            Global.currentUser?.displayName ?? 'Usuário',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            Global.currentUser?.email ?? '',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<_MenuItemData> items) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                _buildMenuItem(item),
                if (index < items.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: AppTheme.borderLight,
                  ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMenuItem(_MenuItemData item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.isDestructive
                    ? AppTheme.errorLight
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: item.isDestructive
                    ? AppTheme.errorColor
                    : AppTheme.primaryColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: item.isDestructive
                          ? AppTheme.errorColor
                          : AppTheme.textPrimary,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Column(
      children: [
        Icon(
          Icons.apps_rounded,
          size: 32,
          color: AppTheme.textTertiary,
        ),
        SizedBox(height: 8),
        Text(
          'PraticOS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Versão ${Global.version}',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  _MenuItemData({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
}
