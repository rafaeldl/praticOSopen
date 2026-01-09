import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode, Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/mobx/theme_store.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final UserStore _userStore = UserStore();
  final AuthStore _authStore = AuthStore();
  final AuthorizationService _authService = AuthorizationService.instance;

  @override
  Widget build(BuildContext context) {
    _userStore.findCurrentUser();
    // Set the UserStore instance for AuthorizationService to use
    AuthorizationService.setUserStore(_userStore);
    final themeStore = Provider.of<ThemeStore>(context);
    final config = context.watch<SegmentConfigProvider>();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
                      const CupertinoSliverNavigationBar(
                        largeTitle: Text('Ajustes'),
                      ),
                      SliverSafeArea(
                        top: false,
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Profile Section
                            CupertinoListSection.insetGrouped(                children: [
                  Observer(builder: (_) {
                    final user = _userStore.user?.value;
                    final userName = user?.name ?? Global.currentUser?.displayName ?? 'Usuário';

                    return CupertinoListTile(
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
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                      ),
                      subtitle: _authStore.companyAggr?.name != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _authStore.companyAggr!.name!,
                                  style: const TextStyle(
                                    color: CupertinoColors.activeBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    _authService.currentRoleLabel,
                                    style: TextStyle(
                                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    );
                  }),
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
                        onTap: () => _showCompanySelectionModal(context, config),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),

              // Admin/Management Section - RBAC based
              Observer(builder: (context) {
                final canManageCompany = _authService.hasPermission(PermissionType.manageCompany);
                final canManageUsers = _authService.hasPermission(PermissionType.manageUsers);
                final canManageForms = _authService.hasPermission(PermissionType.manageForms);
                final canViewDevices = _authService.hasPermission(PermissionType.viewDevices);
                final canViewServices = _authService.hasPermission(PermissionType.viewServices);
                final canViewProducts = _authService.hasPermission(PermissionType.viewProducts);

                return CupertinoListSection.insetGrouped(
                  header: const Text('GERENCIAMENTO'),
                  children: [
                    // Dados da Empresa - apenas Admin
                    if (canManageCompany)
                      _buildSettingsTile(
                        icon: CupertinoIcons.briefcase_fill,
                        color: CupertinoColors.systemOrange,
                        title: 'Dados da Empresa',
                        onTap: () => Navigator.pushNamed(context, '/company_form'),
                      ),

                    // Colaboradores - apenas Admin
                    if (canManageUsers)
                      _buildSettingsTile(
                        icon: CupertinoIcons.person_3_fill,
                        color: CupertinoColors.systemBlue,
                        title: 'Colaboradores',
                        onTap: () => Navigator.pushNamed(context, '/collaborator_list'),
                      ),

                    // Dispositivos - Admin/Supervisor podem gerenciar, outros podem visualizar
                    if (canViewDevices)
                      _buildSettingsTile(
                        icon: config.deviceIcon,
                        color: CupertinoColors.systemGreen,
                        title: config.devicePlural,
                        onTap: () => Navigator.pushNamed(context, '/device_list'),
                      ),

                    // Serviços - Admin/Supervisor podem gerenciar
                    if (canViewServices)
                      _buildSettingsTile(
                        icon: CupertinoIcons.wrench_fill,
                        color: CupertinoColors.systemIndigo,
                        title: 'Serviços',
                        onTap: () => Navigator.pushNamed(context, '/service_list'),
                      ),

                    // Produtos - Admin/Supervisor podem gerenciar
                    if (canViewProducts)
                      _buildSettingsTile(
                        icon: CupertinoIcons.cube_box_fill,
                        color: CupertinoColors.systemPink,
                        title: 'Produtos',
                        onTap: () => Navigator.pushNamed(context, '/product_list'),
                      ),

                    // Formulários - Admin/Supervisor podem gerenciar
                    if (canManageForms)
                      _buildSettingsTile(
                        icon: CupertinoIcons.doc_text_fill,
                        color: CupertinoColors.systemTeal,
                        title: 'Procedimentos',
                        onTap: () => Navigator.pushNamed(context, '/form_template_list'),
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
                    onTap: () => _showThemeSelectionDialog(context, themeStore, config),
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
                    onTap: () => _showLogoutConfirmation(context, config),
                  ),
                  CupertinoListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(CupertinoIcons.trash_fill, color: CupertinoColors.white, size: 20),
                    ),
                    title: const Text('Excluir Conta', style: TextStyle(color: CupertinoColors.systemRed)),
                    subtitle: const Text('Remover permanentemente todos os dados'),
                    onTap: () => _showDeleteAccountConfirmation(context, config),
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
              
          ),
              
        ],
              
      ),
              
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

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return 'Automático';
      case ThemeMode.light: return 'Claro';
      case ThemeMode.dark: return 'Escuro';
    }
  }

  void _showThemeSelectionDialog(BuildContext context, ThemeStore themeStore, SegmentConfigProvider config) {
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
          child: Text(config.label(LabelKeys.cancel)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, SegmentConfigProvider config) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          CupertinoDialogAction(
            child: Text(config.label(LabelKeys.cancel)),
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

  void _showCompanySelectionModal(BuildContext context, SegmentConfigProvider config) {
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
          child: Text(config.label(LabelKeys.cancel)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context, SegmentConfigProvider config) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Excluir Conta'),
        content: const Text(
          'Esta ação é permanente e não pode ser desfeita.\n\n'
          'Todos os seus dados, incluindo ordens de serviço, clientes e configurações '
          'serão removidos permanentemente.\n\n'
          'Tem certeza que deseja continuar?',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(config.label(LabelKeys.cancel)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              _showDeleteAccountFinalConfirmation(context);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountFinalConfirmation(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Confirmação Final'),
        content: const Text(
          'Esta é sua última chance de cancelar.\n\n'
          'Confirma a exclusão permanente da sua conta?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showCupertinoDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CupertinoActivityIndicator(radius: 20),
                ),
              );

              try {
                await _authStore.deleteAccount();
                // The auth state change will automatically redirect to login
              } catch (e) {
                Navigator.pop(context); // Close loading
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const Text('Erro'),
                    content: Text(
                      'Não foi possível excluir sua conta. '
                      'Por favor, tente novamente ou entre em contato com o suporte.\n\n'
                      'Erro: ${e.toString()}',
                    ),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Excluir Permanentemente'),
          ),
        ],
      ),
    );
  }
}