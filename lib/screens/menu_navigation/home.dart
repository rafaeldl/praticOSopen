import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/mobx/notification_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/mobx/whatsapp_link_store.dart';
import 'package:praticos/mobx/whatsapp_setup_banner_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/menu_navigation/home_content.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';
import 'package:praticos/screens/menu_navigation/settings.dart';
import 'package:praticos/screens/menu_navigation/widgets/link_whatsapp_sheet.dart';
import 'package:praticos/screens/order/assistant/ai_intro.dart';
import 'package:praticos/screens/widgets/courtesy_banner.dart';
import 'package:praticos/screens/widgets/whatsapp_setup_banner.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../global.dart';

/// Bumped when an order may have changed outside Início (the "+" beside the
/// tabs creates one), so the list reloads.
final ValueNotifier<int> ordersChanged = ValueNotifier(0);

/// Início tab: wires [HomeContent] to the order store.
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthorizationService _authService = AuthorizationService.instance;
  late OrderStore orderStore;
  /// Technicians start on "Minhas" (prototype "Início · técnico").
  late HomeView _view =
      _authService.isTechnician ? HomeView.mine : HomeView.open;
  bool? _companyHasOrders;
  final WhatsAppLinkStore _whatsappStore = WhatsAppLinkStore();
  final WhatsAppSetupBannerStore _bannerStore = WhatsAppSetupBannerStore();
  bool _whatsappStatusLoaded = false;
  bool _aiIntroChecked = false;
  bool _aiIntroRunning = false;

  @override
  void initState() {
    super.initState();
    ordersChanged.addListener(_loadOrders);
  }

  @override
  void dispose() {
    ordersChanged.removeListener(_loadOrders);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    orderStore = Provider.of<OrderStore>(context);

    if (Global.companyAggr?.id == null) {
      Future.delayed(const Duration(milliseconds: 1000), _loadOrders);
    } else {
      _loadOrders();
    }

    // Load WhatsApp status once for navbar button and banner
    if (kWhatsAppBotEnabled && !_whatsappStatusLoaded) {
      _whatsappStatusLoaded = true;
      _whatsappStore.loadStatus().then((_) {
        _bannerStore.updateLinkStatus(_whatsappStore.isLinked);
        _bannerStore.checkVisibility();
      });
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    await orderStore.loadOrdersInfinite(_view.queryField);
    await _checkCompanyHasOrders();
    _showAiIntroOnce();
  }

  /// After a load, so the sheet opens over a settled Início. Only for who has
  /// the "+": the sheet leads to a new order.
  Future<void> _showAiIntroOnce() async {
    if (_aiIntroChecked || _aiIntroRunning || !mounted) return;
    if (Global.companyAggr?.id == null) return;
    if (!_authService.canCreateOrder) {
      _aiIntroChecked = true;
      return;
    }
    _aiIntroRunning = true;
    final done = await showAiIntroOnce(context, isSettled: _isSettledOnHome);
    _aiIntroRunning = false;
    _aiIntroChecked = done;
  }

  /// Início is what the user sees: its tab, with nothing pushed over the app.
  bool _isSettledOnHome() {
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;
    if (Navigator.of(context, rootNavigator: true).canPop()) return false;
    return Provider.of<BottomNavigationBarStore>(
          context,
          listen: false,
        ).currentIndex ==
        0;
  }

  /// Tells "no open orders" apart from "company never created an order".
  Future<void> _checkCompanyHasOrders() async {
    if (!mounted) return;
    if (orderStore.orders.isNotEmpty) {
      if (_companyHasOrders != true) setState(() => _companyHasOrders = true);
      return;
    }
    if (orderStore.ordersLoadFailed || orderStore.customerFilter != null) {
      return;
    }
    if (_view == HomeView.all) {
      setState(() => _companyHasOrders = false);
      return;
    }
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return;
    try {
      final snapshot = await orderStore.repository
          .getOrdersWithPagination(companyId, limit: 1);
      if (mounted) setState(() => _companyHasOrders = snapshot.docs.isNotEmpty);
    } catch (_) {
      // Unknown: keep showing the regular empty state.
    }
  }

  void _changeView(HomeView view) {
    if (view == _view) return;
    HapticFeedback.selectionClick();
    setState(() => _view = view);
    _loadOrders();
  }

  void _openOrder(Order order) {
    Navigator.of(context, rootNavigator: true)
        .pushNamed('/order', arguments: {
          'order': order,
          'previousTitle': context.l10n.home,
        })
        .then((_) => _loadOrders());
  }

  void _openProfile() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        title: context.l10n.myCompany,
        builder: (_) => const Settings(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final notificationStore = Provider.of<NotificationStore>(context);
    FirebaseCrashlytics.instance.log("Abrindo home (Cupertino)");

    return Observer(
      builder: (_) => HomeContent(
        orders: orderStore.orders.whereType<Order>().toList(),
        view: _view,
        onViewChanged: _changeView,
        title: config.serviceOrderPlural,
        isLoading: orderStore.isLoading,
        hasMore: orderStore.hasMoreOrders,
        loadFailed: orderStore.ordersLoadFailed,
        hasAnyOrders: _companyHasOrders,
        showPrices: _authService.hasPermission(PermissionType.viewPrices),
        showDevice: config.showDeviceInOrderList,
        deviceLabel: config.showDeviceInOrderList ? config.device : null,
        technician: _authService.isTechnician,
        currentUserId: Global.currentUser?.uid,
        unreadCount: notificationStore.unreadCount?.value ?? 0,
        statusLabel: (status) => config.getStatus(status ?? ''),
        customerFilterName: orderStore.customerFilter?.name,
        onClearCustomerFilter: () {
          HapticFeedback.lightImpact();
          orderStore.setCustomerFilter(null);
          _loadOrders();
        },
        onOpenOrder: _openOrder,
        onOpenProfile: _openProfile,
        companyName: Global.companyAggr?.name,
        onRetry: _loadOrders,
        onLoadMore: () =>
            orderStore.loadMoreOrdersInfinite(_view.queryField),
        onOpenNotifications: () => Navigator.of(context, rootNavigator: true)
            .pushNamed('/notifications'),
        leading: _buildWhatsAppNavButton(context),
        banner: _buildCourtesyBanner() ?? _buildWhatsAppBanner(),
      ),
    );
  }

  /// WhatsApp bot shortcut in the navigation bar. Hidden while the bot is off —
  /// the MCP connector covers this role. See [kWhatsAppBotEnabled].
  Widget? _buildWhatsAppNavButton(BuildContext context) {
    if (!kWhatsAppBotEnabled) return null;
    return Observer(
      builder: (_) {
        final isLinked = _whatsappStore.isLinked;
        return Semantics(
          identifier: 'whatsapp_button',
          button: true,
          label: 'WhatsApp',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FaIcon(
                  FontAwesomeIcons.whatsapp,
                  size: 24,
                  color: isLinked
                      ? const Color(0xFF25D366)
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                if (!isLinked)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (isLinked) {
                final uri = Uri.parse('https://wa.me/${_whatsappStore.botNumber}');
                launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                LinkWhatsAppSheet.show(context, _whatsappStore).then((_) {
                  _whatsappStore.loadStatus().then((_) {
                    _bannerStore.updateLinkStatus(_whatsappStore.isLinked);
                  });
                });
              }
            },
          ),
        );
      },
    );
  }

  /// End of the Pro courtesy, for whoever can buy (see [CourtesyBanner]).
  Widget? _buildCourtesyBanner() {
    final subscription = context.read<SubscriptionStore>().subscription;
    if (!CourtesyBanner.applies(subscription, DateTime.now())) return null;
    final companyId = Global.companyAggr?.id;
    return CourtesyBanner(
      key: ValueKey('courtesy_$companyId'),
      subscription: subscription!,
      companyId: companyId,
    );
  }

  Widget? _buildWhatsAppBanner() {
    if (!kWhatsAppBotEnabled) return null;
    return Observer(
      builder: (_) {
        if (!_bannerStore.isVisible) return const SizedBox.shrink();
        return WhatsAppSetupBanner(
          onConnect: () {
            LinkWhatsAppSheet.show(context, _whatsappStore).then((_) {
              _whatsappStore.loadStatus().then((_) {
                _bannerStore.updateLinkStatus(_whatsappStore.isLinked);
              });
            });
          },
          onDismiss: () {
            _bannerStore.dismiss();
          },
        );
      },
    );
  }
}
