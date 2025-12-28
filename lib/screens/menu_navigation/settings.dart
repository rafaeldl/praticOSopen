import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme, Material, MaterialType, Icons, CircleAvatar, Divider, DebugShowCheckedModeBanner, InkWell, ThemeMode; 
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/mobx/theme_store.dart';
import 'package:praticos/models/user_role.dart';

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
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            const CupertinoSliverNavigationBar(
              largeTitle: Text('Ajustes'),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  
                  // Company Switcher (if applicable)
                  Observer(builder: (_) {
                    if (_userStore.user?.value != null &&
                        _userStore.user!.value!.companies != null &&
                        _userStore.user!.value!.companies!.length > 1) {
                      return _buildSection(
                        header: 'ORGANIZAÇÃO',
                        children: [
                          _buildListTile(
                            icon: CupertinoIcons.building_2_fill,
                            title: 'Trocar Empresa',
                            subtitle: 'Alternar entre organizações',
                            iconColor: CupertinoColors.systemPurple,
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
                    return _buildSection(
                      header: 'GERENCIAMENTO',
                      children: [
                        if (isAdmin) ...[
                          _buildListTile(
                            icon: CupertinoIcons.briefcase_fill,
                            title: 'Dados da Empresa',
                            iconColor: CupertinoColors.systemOrange,
                            onTap: () => Navigator.pushNamed(context, '/company_form'),
                          ),
                          _buildListTile(
                            icon: CupertinoIcons.person_3_fill,
                            title: 'Colaboradores',
                            iconColor: CupertinoColors.systemBlue,
                            onTap: () => Navigator.pushNamed(context, '/collaborator_list'),
                          ),
                        ],
                        _buildListTile(
                          icon: CupertinoIcons.car_detailed,
                          title: 'Veículos',
                          iconColor: CupertinoColors.systemGreen,
                          onTap: () => Navigator.pushNamed(context, '/device_list'),
                        ),
                        _buildListTile(
                          icon: CupertinoIcons.wrench_fill,
                          title: 'Serviços',
                          iconColor: CupertinoColors.systemIndigo,
                          onTap: () => Navigator.pushNamed(context, '/service_list'),
                        ),
                        _buildListTile(
                          icon: CupertinoIcons.cube_box_fill,
                          title: 'Produtos',
                          iconColor: CupertinoColors.systemPink,
                          onTap: () => Navigator.pushNamed(context, '/product_list'),
                        ),
                      ],
                    );
                  }),

                  // Interface Section
                  _buildSection(
                    header: 'INTERFACE',
                    children: [
                      _buildListTile(
                        icon: CupertinoIcons.moon_fill,
                        title: 'Modo Noturno',
                        subtitle: _getThemeModeText(themeStore.themeMode),
                        iconColor: CupertinoColors.systemGrey,
                        onTap: () => _showThemeSelectionDialog(context, themeStore),
                      ),
                    ],
                  ),

                  // Account Section
                  _buildSection(
                    header: 'CONTA',
                    children: [
                      _buildListTile(
                        icon: CupertinoIcons.arrow_right_square_fill,
                        title: 'Sair',
                        iconColor: CupertinoColors.systemRed,
                        onTap: () => _showLogoutConfirmation(context),
                        isDestructive: true,
                      ),
                    ],
                  ),

                  // Version
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Text(
                          'PraticOS ${Global.version}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom Padding
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.systemGrey5,
            ),
            child: ClipOval(
              child: Global.currentUser?.photoURL != null
                  ? Image.network(Global.currentUser!.photoURL!, fit: BoxFit.cover)
                  : const Icon(CupertinoIcons.person_solid, size: 40, color: CupertinoColors.systemGrey),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            Global.currentUser?.displayName ?? 'Usuário',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.label,
            ),
          ),
          Text(
            Global.currentUser?.email ?? '',
            style: const TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 8),
          Observer(builder: (_) {
            return _authStore.companyAggr?.name != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _authStore.companyAggr!.name!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildSection({required String header, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 16, 8),
          child: Text(
            header,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: children.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              return Column(
                children: [
                  child,
                  if (index < children.length - 1)
                    const Divider(
                      height: 1,
                      indent: 52, // Icon width + padding
                      color: CupertinoColors.separator,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: CupertinoColors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      color: isDestructive ? CupertinoColors.systemRed : CupertinoColors.label,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey3),
          ],
        ),
      ),
    );
  }

  // ... (Other helper methods adapted to Cupertino) ...
  
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
    // Adapted to ActionSheet for simplicity in iOS
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