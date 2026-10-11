import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart'; // Import for reaction
import 'package:provider/provider.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/mobx/engagement_reminder_store.dart';
import 'package:praticos/screens/menu_navigation/home_customer_list.dart';
import 'package:praticos/screens/menu_navigation/settings.dart';
import 'package:praticos/screens/dashboard/financial_tab.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/widgets/permission_widgets.dart';
import 'package:praticos/screens/agenda/agenda_screen.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/engagement_scheduler.dart';
import 'package:praticos/services/tracking_transparency_service.dart';

import 'home.dart';
import 'app_tabs.dart';
import 'tab_routes.dart';
import 'widgets/glass_tab_bar.dart';

class NavigationController extends StatefulWidget {
  const NavigationController({super.key});

  @override
  _NavigationControllerState createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController>
    with WidgetsBindingObserver {
  CupertinoTabController _tabController = CupertinoTabController();
  ReactionDisposer? _disposer;
  EngagementScheduler? _engagementScheduler;

  /// Tabs currently shown, in the fixed [AppTab] order.
  List<AppTab> _tabs = AppTab.values;

  Widget _buildPage(AppTab tab) {
    return switch (tab) {
      AppTab.home => Home(),
      AppTab.customers => HomeCustomerList(),
      AppTab.agenda => const AgendaScreen(),
      AppTab.financial => ProtectedRoute(
        permission: PermissionType.viewFinancialReports,
        accessDeniedMessage: context.l10n.financialAccessDenied,
        child: const FinancialTab(),
      ),
      AppTab.more => Settings(),
    };
  }

  BottomNavigationBarItem _buildTabItem(BuildContext context, AppTab tab) {
    return switch (tab) {
      AppTab.home => BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_home',
          child: const Icon(CupertinoIcons.house),
        ),
        activeIcon: const Icon(CupertinoIcons.house_fill),
        label: context.l10n.home,
      ),
      AppTab.customers => BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_customers',
          child: const Icon(CupertinoIcons.person_2),
        ),
        activeIcon: const Icon(CupertinoIcons.person_2_fill),
        label: context.l10n.customers,
      ),
      AppTab.agenda => BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_agenda',
          child: const Icon(CupertinoIcons.calendar),
        ),
        activeIcon: const Icon(CupertinoIcons.calendar_today),
        label: context.l10n.agenda,
      ),
      AppTab.financial => BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_financial',
          child: const Icon(CupertinoIcons.chart_pie),
        ),
        activeIcon: const Icon(CupertinoIcons.chart_pie_fill),
        label: context.l10n.financial,
      ),
      AppTab.more => BottomNavigationBarItem(
        icon: Semantics(
          identifier: 'tab_settings',
          child: const Icon(CupertinoIcons.ellipsis),
        ),
        label: context.l10n.more,
      ),
    };
  }

  /// Applies a new set of visible tabs, keeping the selected tab when it is
  /// still visible (otherwise falls back to Início).
  void _syncTabs(List<AppTab> tabs) {
    if (listEquals(tabs, _tabs)) return;
    final oldIndex = _tabController.index;
    final selected = oldIndex < _tabs.length ? _tabs[oldIndex] : AppTab.home;
    final newIndex = tabs.contains(selected) ? tabs.indexOf(selected) : 0;
    _tabs = tabs;

    final oldController = _tabController;
    _tabController = CupertinoTabController(initialIndex: newIndex)
      ..addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
      if (!mounted) return;
      Provider.of<BottomNavigationBarStore>(
        context,
        listen: false,
      ).setCurrentIndex(newIndex);
    });
  }

  void _onTabChanged() => _logTabScreen(_tabController.index);

  void _logTabScreen(int index) {
    final name = TabRoutes.nameForIndex(
      index,
      routes: [for (final tab in _tabs) tab.routeName],
    );
    if (name == null) return;
    try {
      FirebaseAnalytics.instance
          .logScreenView(screenName: name, screenClass: name)
          .catchError((_) {});
    } catch (_) {
      // Analytics unavailable (e.g. tests); ignore.
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _logTabScreen(0));
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrackingTransparencyService.instance.requestIfEligible();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigationStore = Provider.of<BottomNavigationBarStore>(context);

    // Dispose previous reaction if dependencies change
    _disposer?.call();

    // React to store changes to update the tab controller
    _disposer = reaction(
      (_) => navigationStore.currentIndex,
      (dynamic index) {
        if (index is int &&
            index < _tabs.length &&
            _tabController.index != index) {
          _tabController.index = index;
        }
      },
    );

    // Set up engagement scheduler with l10n strings
    final l10n = context.l10n;
    final store = Provider.of<EngagementReminderStore>(context, listen: false);
    _engagementScheduler = EngagementScheduler(
      store: store,
      strings: EngagementStrings(
        dailyTitle: l10n.dailyNotificationTitle,
        dailyBody: l10n.dailyNotificationBody,
        inactivity3dTitle: l10n.inactivity3dTitle,
        inactivity3dBody: l10n.inactivity3dBody,
        inactivity5dTitle: l10n.inactivity5dTitle,
        inactivity5dBody: l10n.inactivity5dBody,
        inactivity7dTitle: l10n.inactivity7dTitle,
        inactivity7dBody: l10n.inactivity7dBody,
        pendingOsTitle: l10n.pendingOsNotificationTitle,
        pendingOsBody: (count) => l10n.pendingOsNotificationBody(count),
      ),
    );
    _engagementScheduler!.onAppResumed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _engagementScheduler?.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposer?.call();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationStore = Provider.of<BottomNavigationBarStore>(context);
    final useScheduling = context.watch<SegmentConfigProvider>().useScheduling;

    return Observer(
      builder: (context) {
        _syncTabs(
          visibleAppTabs(
            useScheduling: useScheduling,
            canViewFinancialReports:
                AuthorizationService.instance.canViewFinancialReports,
          ),
        );
        final tabs = _tabs;

        return CupertinoTabScaffold(
          // A new tab set rebuilds the tab views, so a navigator never moves
          // to a different tab when one is hidden or shown.
          key: ValueKey(tabs.map((t) => t.name).join(',')),
          controller: _tabController,
          tabBar: GlassTabBar(
            // currentIndex is handled by the controller
            onTap: (index) {
              navigationStore.setCurrentIndex(index);
            },
            items: [for (final tab in tabs) _buildTabItem(context, tab)],
          ),
          tabBuilder: (BuildContext context, int index) {
            return CupertinoTabView(
              routes: appRoutes,
              builder: (BuildContext context) {
                return _buildPage(tabs[index]);
              },
            );
          },
        );
      },
    );
  }
}
