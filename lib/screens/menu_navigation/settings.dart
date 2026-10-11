import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/more/account_screen.dart';
import 'package:praticos/screens/menu_navigation/more/advanced_screen.dart';
import 'package:praticos/screens/menu_navigation/more/more_view.dart';
import 'package:praticos/screens/menu_navigation/more/my_company_screen.dart';
import 'package:praticos/screens/menu_navigation/more/plan_screen.dart';
import 'package:praticos/screens/menu_navigation/more/reminders_screen.dart';
import 'package:praticos/services/authorization_service.dart';

/// The "Mais" tab. Builds [MoreView] with the rows the current role can see
/// and opens the destination of each row.
class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final UserStore _userStore = UserStore();
  final AuthorizationService _authService = AuthorizationService.instance;

  @override
  Widget build(BuildContext context) {
    _userStore.findCurrentUser();
    // Set the UserStore instance for AuthorizationService to use
    AuthorizationService.setUserStore(_userStore);
    final config = context.watch<SegmentConfigProvider>();
    final authStore = context.watch<AuthStore>();
    final subscription =
        context.watch<SubscriptionStore>().subscription ?? Subscription();

    return Observer(builder: (_) {
      final canViewServices =
          _authService.hasPermission(PermissionType.viewServices);
      final canViewProducts =
          _authService.hasPermission(PermissionType.viewProducts);
      final visibility = MoreVisibility(
        company: _authService.hasPermission(PermissionType.manageCompany),
        team: _authService.hasPermission(PermissionType.manageUsers),
        catalog: canViewServices || canViewProducts,
        checklists: _authService.hasPermission(PermissionType.manageForms),
        ratings: _authService.hasPermission(PermissionType.manageCompany),
        advanced: AdvancedScreen.hasEntries(
          showIntegrations: _showIntegrations,
          showDevices: _showDevices(config),
        ),
      );
      final userName =
          _userStore.user?.value?.name ?? Global.currentUser?.displayName;
      final l10n = context.l10n;
      return MoreView(
        visibility: visibility,
        planName: subscription.effectivePlan(DateTime.now()).displayName,
        accountName: userName,
        companyName: authStore.companyAggr?.name,
        catalogSubtitle:
            l10n.moreCatalogSubtitle(l10n.products.toLowerCase()),
        version: Global.version,
        onOpen: (destination) => _open(context, destination, config),
      );
    });
  }

  bool get _showIntegrations =>
      _authService.hasPermission(PermissionType.manageUsers);

  bool _showDevices(SegmentConfigProvider config) =>
      config.useDeviceManagement &&
      _authService.hasPermission(PermissionType.viewDevices);

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, CupertinoPageRoute<void>(builder: (_) => screen));
  }

  void _open(
    BuildContext context,
    MoreDestination destination,
    SegmentConfigProvider config,
  ) {
    switch (destination) {
      case MoreDestination.account:
        _push(context, const AccountScreen());
      case MoreDestination.company:
        _push(
          context,
          MyCompanySettings(
            companyId: Global.companyAggr?.id,
            onOpenCompanyData: () =>
                Navigator.pushNamed(context, '/company_form'),
          ),
        );
      case MoreDestination.team:
        Navigator.pushNamed(context, '/collaborator_list');
      case MoreDestination.plan:
        _push(context, const PlanScreen());
      case MoreDestination.catalog:
        _openCatalog(context);
      case MoreDestination.checklists:
        Navigator.pushNamed(context, '/form_template_list');
      case MoreDestination.ratings:
        Navigator.pushNamed(context, '/ratings');
      case MoreDestination.reminders:
        _push(context, const RemindersScreen());
      case MoreDestination.advanced:
        _push(
          context,
          AdvancedScreen(
            devicesLabel: config.devicePlural,
            showIntegrations: _showIntegrations,
            showDevices: _showDevices(config),
            onOpenIntegrations: () =>
                Navigator.pushNamed(context, '/integrations'),
            onOpenDevices: () => Navigator.pushNamed(context, '/device_list'),
          ),
        );
    }
  }

  /// Catalog entry point: the unified "Serviços | Produtos" screen, opened
  /// on the kind the role can see.
  void _openCatalog(BuildContext context) {
    final canServices = _authService.hasPermission(PermissionType.viewServices);
    Navigator.pushNamed(
        context, canServices ? '/service_list' : '/product_list');
  }
}
