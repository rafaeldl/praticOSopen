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
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/onboarding/company_info_screen.dart';
import 'package:praticos/repositories/company_repository.dart';

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
                      CupertinoSliverNavigationBar(
                        largeTitle: Text(context.l10n.settings),
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
                    // Prefer photo from Firestore user, fallback to Firebase Auth
                    final userPhoto = user?.photo ?? Global.currentUser?.photoURL;

                    return CupertinoListTile(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leadingSize: 60,
                      leading: ClipOval(
                        child: userPhoto != null
                            ? CachedImage(
                                imageUrl: userPhoto,
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
                                    _authService.getRoleLabelLocalized(context.l10n),
                                    style: TextStyle(
                                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : null,
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => Navigator.pushNamed(context, '/user_profile_edit'),
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
                    header: Text(context.l10n.organization.toUpperCase()),
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
                        title: Text(context.l10n.switchCompany),
                        subtitle: Text(context.l10n.switchBetweenOrganizations),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => _showCompanySelectionModal(context, config),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),

              // Admin/Management Section - RBAC based
              Observer(builder: (ctx) {
                final canManageCompany = _authService.hasPermission(PermissionType.manageCompany);
                final canManageUsers = _authService.hasPermission(PermissionType.manageUsers);
                final canManageForms = _authService.hasPermission(PermissionType.manageForms);
                final canViewDevices = _authService.hasPermission(PermissionType.viewDevices);
                final canViewServices = _authService.hasPermission(PermissionType.viewServices);
                final canViewProducts = _authService.hasPermission(PermissionType.viewProducts);

                return CupertinoListSection.insetGrouped(
                  header: Text(context.l10n.management.toUpperCase()),
                  children: [
                    // Dados da Empresa - apenas Admin
                    if (canManageCompany)
                      _buildSettingsTile(
                        icon: CupertinoIcons.briefcase_fill,
                        color: CupertinoColors.systemOrange,
                        title: context.l10n.companyData,
                        onTap: () => Navigator.pushNamed(context, '/company_form'),
                      ),

                    // Colaboradores - apenas Admin
                    if (canManageUsers)
                      _buildSettingsTile(
                        icon: CupertinoIcons.person_3_fill,
                        color: CupertinoColors.systemBlue,
                        title: context.l10n.collaborators,
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
                        title: context.l10n.services,
                        onTap: () => Navigator.pushNamed(context, '/service_list'),
                      ),

                    // Produtos - Admin/Supervisor podem gerenciar
                    if (canViewProducts)
                      _buildSettingsTile(
                        icon: CupertinoIcons.cube_box_fill,
                        color: CupertinoColors.systemPink,
                        title: context.l10n.products,
                        onTap: () => Navigator.pushNamed(context, '/product_list'),
                      ),

                    // Formulários - Admin/Supervisor podem gerenciar
                    if (canManageForms)
                      _buildSettingsTile(
                        icon: CupertinoIcons.doc_text_fill,
                        color: CupertinoColors.systemTeal,
                        title: context.l10n.procedures,
                        onTap: () => Navigator.pushNamed(context, '/form_template_list'),
                      ),
                  ],
                );
              }),

              // Interface Section
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.interface_.toUpperCase()),
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
                    title: Text(context.l10n.nightMode),
                    additionalInfo: Text(_getThemeModeText(context, themeStore.themeMode)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _showThemeSelectionDialog(context, themeStore, config),
                  ),
                  // Reabrir Onboarding - para reconfigurar empresa e capturar screenshots
                  Observer(builder: (_) {
                    if (_authService.hasPermission(PermissionType.manageCompany)) {
                      return Semantics(
                        identifier: 'reopen_onboarding_button',
                        button: true,
                        label: context.l10n.reopenOnboarding,
                        child: CupertinoListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemPurple,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(CupertinoIcons.refresh_bold, color: CupertinoColors.white, size: 20),
                          ),
                          title: Text(context.l10n.reopenOnboarding),
                          subtitle: Text(context.l10n.reconfigureCompanySetup),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => _reopenOnboarding(context),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),

              // Account Section
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.account.toUpperCase()),
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
                    title: Text(context.l10n.logout, style: const TextStyle(color: CupertinoColors.systemRed)),
                    onTap: () => _showLogoutConfirmation(context, config),
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

  String _getThemeModeText(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return context.l10n.automatic;
      case ThemeMode.light: return context.l10n.light;
      case ThemeMode.dark: return context.l10n.dark;
    }
  }

  void _showThemeSelectionDialog(BuildContext context, ThemeStore themeStore, SegmentConfigProvider config) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoActionSheet(
        title: Text(context.l10n.chooseTheme),
        actions: [
          CupertinoActionSheetAction(
            child: Text(context.l10n.automaticSystem),
            onPressed: () { themeStore.setThemeMode(ThemeMode.system); Navigator.pop(dialogContext); },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.light),
            onPressed: () { themeStore.setThemeMode(ThemeMode.light); Navigator.pop(dialogContext); },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.dark),
            onPressed: () { themeStore.setThemeMode(ThemeMode.dark); Navigator.pop(dialogContext); },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, SegmentConfigProvider config) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.logout),
        content: Text(context.l10n.logoutConfirm),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _authStore.signOutGoogle();
            },
            child: Text(context.l10n.logout),
          ),
        ],
      ),
    );
  }

  void _showCompanySelectionModal(BuildContext context, SegmentConfigProvider config) {
    showCupertinoModalPopup(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: Text(context.l10n.selectCompany),
        actions: _userStore.user?.value?.companies?.map((companyRole) {
          return CupertinoActionSheetAction(
            child: Text(companyRole.company?.name ?? context.l10n.companyNoName),
            onPressed: () async {
              if (companyRole.company?.id != null) {
                Navigator.pop(dialogContext);
                await _authStore.switchCompany(companyRole.company!.id!);
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
          );
        }).toList() ?? [],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  /// Reopen onboarding to reconfigure company setup
  Future<void> _reopenOnboarding(BuildContext context) async {
    final companyAggr = _authStore.companyAggr;

    if (companyAggr?.id == null) {
      return;
    }

    try {
      // Fetch full company data
      final companyRepo = CompanyRepository();
      final company = await companyRepo.getSingle(companyAggr!.id);

      // Navigate directly to company info screen (skip welcome screen)
      if (context.mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => CompanyInfoScreen(
              authStore: _authStore,
              companyId: company?.id,
              initialName: company?.name,
              initialAddress: company?.address,
              initialPhone: company?.phone,
              initialEmail: company?.email,
              initialSite: company?.site,
              initialLogoUrl: company?.logo,
            ),
          ),
        );
      }
    } catch (e) {
      // Show error
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.error),
            content: Text('${context.l10n.couldNotLoadCompanyData}\n\n$e'),
            actions: [
              CupertinoDialogAction(
                child: Text(context.l10n.ok),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }
}