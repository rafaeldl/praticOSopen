import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode; 
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/mobx/theme_store.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/widgets/cached_image.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final UserStore _userStore = UserStore();
  final AuthStore _authStore = AuthStore();

  @override
  Widget build(BuildContext context) {
    _userStore.findCurrentUser();
    final themeStore = Provider.of<ThemeStore>(context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Ajustes'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // Profile Section
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leadingSize: 60,
                    leading: ClipOval(
                      child: Global.currentUser?.photoURL != null
                          ? CachedImage(
                              imageUrl: Global.currentUser!.photoURL!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: CupertinoColors.systemGrey5,
                              child: const Icon(CupertinoIcons.person_solid, color: CupertinoColors.systemGrey),
                            ),
                    ),
                    title: Text(
                      Global.currentUser?.displayName ?? 'Usuário',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Global.currentUser?.email ?? ''),
                        if (_authStore.companyAggr?.name != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _authStore.companyAggr!.name!,
                              style: const TextStyle(
                                color: CupertinoColors.activeBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Company Switcher (if applicable)
              Observer(builder: (_) {
                if (_userStore.user?.value != null &&
                    _userStore.user!.value!.companies != null &&
                    _userStore.user!.value!.companies!.length > 1) {
                  return CupertinoListSection.insetGrouped(
                    header: const Text('ORGANIZAÇÃO'),
                    children: [
                      CupertinoListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemPurple,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(CupertinoIcons.building_2_fill, color: CupertinoColors.white, size: 20),
                        ),
                        title: const Text('Trocar Empresa'),
                        subtitle: const Text('Alternar entre organizações'),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => _showCompanySelectionModal(context),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),

              // Admin/Management Section
              Observer(builder: (context) {
                final isAdmin = _isAdmin();
                return CupertinoListSection.insetGrouped(
                  header: const Text('GERENCIAMENTO'),
                  children: [
                    if (isAdmin) ...[
                      _buildSettingsTile(
                        icon: CupertinoIcons.briefcase_fill,
                        color: CupertinoColors.systemOrange,
                        title: 'Dados da Empresa',
                        onTap: () => Navigator.pushNamed(context, '/company_form'),
                      ),
                      _buildSettingsTile(
                        icon: CupertinoIcons.person_3_fill,
                        color: CupertinoColors.systemBlue,
                        title: 'Colaboradores',
                        onTap: () => Navigator.pushNamed(context, '/collaborator_list'),
                      ),
                    ],
                    _buildSettingsTile(
                      icon: CupertinoIcons.car_detailed,
                      color: CupertinoColors.systemGreen,
                      title: 'Veículos',
                      onTap: () => Navigator.pushNamed(context, '/device_list'),
                    ),
                    _buildSettingsTile(
                      icon: CupertinoIcons.wrench_fill,
                      color: CupertinoColors.systemIndigo,
                      title: 'Serviços',
                      onTap: () => Navigator.pushNamed(context, '/service_list'),
                    ),
                    _buildSettingsTile(
                      icon: CupertinoIcons.cube_box_fill,
                      color: CupertinoColors.systemPink,
                      title: 'Produtos',
                      onTap: () => Navigator.pushNamed(context, '/product_list'),
                    ),
                  ],
                );
              }),

              // Interface Section
              CupertinoListSection.insetGrouped(
                header: const Text('INTERFACE'),
                children: [
                  CupertinoListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(CupertinoIcons.moon_fill, color: CupertinoColors.white, size: 20),
                    ),
                    title: const Text('Modo Noturno'),
                    additionalInfo: Text(_getThemeModeText(themeStore.themeMode)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _showThemeSelectionDialog(context, themeStore),
                  ),
                ],
              ),

              // Account Section
              CupertinoListSection.insetGrouped(
                header: const Text('CONTA'),
                children: [
                  CupertinoListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(CupertinoIcons.arrow_right_square_fill, color: CupertinoColors.white, size: 20),
                    ),
                    title: const Text('Sair', style: TextStyle(color: CupertinoColors.systemRed)),
                    onTap: () => _showLogoutConfirmation(context),
                  ),
                ],
              ),

              // Version
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'PraticOS ${Global.version}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return CupertinoListTile(
      leading: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: CupertinoColors.white, size: 20),
      ),
      title: Text(title),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
  
  bool _isAdmin() {
    if (_userStore.user?.value == null || Global.companyAggr == null) return false;
    final currentCompanyId = Global.companyAggr!.id;
    final companyRole = _userStore.user!.value!.companies?.firstWhere(
      (c) => c.company?.id == currentCompanyId,
      orElse: () => CompanyRoleAggr(),
    );
    return companyRole?.role == RolesType.admin || companyRole?.role == RolesType.manager;
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return 'Automático';
      case ThemeMode.light: return 'Claro';
      case ThemeMode.dark: return 'Escuro';
    }
  }

  void _showThemeSelectionDialog(BuildContext context, ThemeStore themeStore) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Escolher tema'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Automático (Sistema)'),
            onPressed: () { themeStore.setThemeMode(ThemeMode.system); Navigator.pop(context); },
          ),
          CupertinoActionSheetAction(
            child: const Text('Claro'),
            onPressed: () { themeStore.setThemeMode(ThemeMode.light); Navigator.pop(context); },
          ),
          CupertinoActionSheetAction(
            child: const Text('Escuro'),
            onPressed: () { themeStore.setThemeMode(ThemeMode.dark); Navigator.pop(context); },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await _authStore.signOutGoogle();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _showCompanySelectionModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar Empresa'),
        actions: _userStore.user?.value?.companies?.map((companyRole) {
          return CupertinoActionSheetAction(
            child: Text(companyRole.company?.name ?? 'Empresa sem nome'),
            onPressed: () async {
              if (companyRole.company?.id != null) {
                Navigator.pop(context);
                await _authStore.switchCompany(companyRole.company!.id!);
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
          );
        }).toList() ?? [],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}