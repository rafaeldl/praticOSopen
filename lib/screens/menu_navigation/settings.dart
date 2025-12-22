import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:flutter/material.dart';
import 'package:praticos/global.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/theme_store.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final UserStore _userStore = UserStore();

  @override
  Widget build(BuildContext context) {
    _userStore.findCurrentUser();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeStore = Provider.of<ThemeStore>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text(
          'Ajustes',
          style: theme.appBarTheme.titleTextStyle,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header do perfil
            _buildProfileHeader(theme, colorScheme),
            SizedBox(height: 16),
            // Seções de menu
            _buildMenuSection(
              theme,
              colorScheme,
              'Cadastros',
              [
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
              theme,
              colorScheme,
              'Interface',
              [
                _MenuItemData(
                  icon: Icons.dark_mode_rounded,
                  title: 'Modo Noturno',
                  subtitle: _getThemeModeText(themeStore.themeMode),
                  onTap: () => _showThemeSelectionDialog(context, themeStore),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildMenuSection(
              theme,
              colorScheme,
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
            _buildVersionInfo(theme),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      color: theme.cardColor,
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.primaryColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: theme.scaffoldBackgroundColor,
              backgroundImage: Global.currentUser?.photoURL != null
                  ? NetworkImage(Global.currentUser!.photoURL!)
                  : null,
              child: Global.currentUser?.photoURL == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 50,
                      color: theme.disabledColor,
                    )
                  : null,
            ),
          ),
          SizedBox(height: 16),
          Text(
            Global.currentUser?.displayName ?? 'Usuário',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            Global.currentUser?.email ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(ThemeData theme, ColorScheme colorScheme, String title, List<_MenuItemData> items) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
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
                color: theme.disabledColor,
                letterSpacing: 1,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                _buildMenuItem(theme, colorScheme, item),
                if (index < items.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.dividerColor,
                  ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMenuItem(ThemeData theme, ColorScheme colorScheme, _MenuItemData item) {
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
                    ? colorScheme.errorContainer
                    : theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: item.isDestructive
                    ? colorScheme.error
                    : theme.primaryColor,
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
                          ? colorScheme.error
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.disabledColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.apps_rounded,
          size: 32,
          color: theme.disabledColor,
        ),
        SizedBox(height: 8),
        Text(
          'PraticOS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Versão ${Global.version}',
          style: TextStyle(
            fontSize: 13,
            color: theme.disabledColor,
          ),
        ),
      ],
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Automático (Sistema)';
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Escuro';
    }
  }

  void _showThemeSelectionDialog(BuildContext context, ThemeStore themeStore) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Escolher tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text('Automático (Sistema)'),
                value: ThemeMode.system,
                groupValue: themeStore.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    themeStore.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text('Claro'),
                value: ThemeMode.light,
                groupValue: themeStore.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    themeStore.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text('Escuro'),
                value: ThemeMode.dark,
                groupValue: themeStore.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    themeStore.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
