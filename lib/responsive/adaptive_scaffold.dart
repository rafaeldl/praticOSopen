import 'package:flutter/cupertino.dart';
import 'package:praticos/responsive/breakpoints.dart';
import 'package:praticos/responsive/desktop_sidebar.dart';

/// Adaptive scaffold that switches between mobile tab bar and desktop sidebar.
///
/// - **Mobile** (< 768px): Renders [CupertinoTabScaffold] with [CupertinoTabBar]
///   exactly as the app has always worked.
/// - **Desktop** (>= 768px): Renders a [Row] with [DesktopSidebar] and content area.
///   Each tab has its own [Navigator] to preserve per-tab navigation stacks.
class AdaptiveScaffold extends StatelessWidget {
  final CupertinoTabController tabController;
  final List<SidebarDestination> destinations;
  final List<BottomNavigationBarItem> tabItems;
  final List<Widget> pages;
  final Map<String, WidgetBuilder> routes;
  final ValueChanged<int> onTabChanged;

  const AdaptiveScaffold({
    super.key,
    required this.tabController,
    required this.destinations,
    required this.tabItems,
    required this.pages,
    required this.routes,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final screenSize = Breakpoints.getScreenSize(width);

    if (screenSize == ScreenSize.mobile) {
      return _buildMobileLayout();
    }
    return _buildDesktopLayout();
  }

  /// Mobile: Standard CupertinoTabScaffold with bottom tab bar.
  Widget _buildMobileLayout() {
    return CupertinoTabScaffold(
      controller: tabController,
      tabBar: CupertinoTabBar(
        onTap: onTabChanged,
        items: tabItems,
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          routes: routes,
          builder: (BuildContext context) {
            return pages[index];
          },
        );
      },
    );
  }

  /// Desktop: Sidebar + content area with per-tab navigators.
  Widget _buildDesktopLayout() {
    return _DesktopLayoutBody(
      tabController: tabController,
      destinations: destinations,
      pages: pages,
      routes: routes,
      onTabChanged: onTabChanged,
    );
  }
}

/// Stateful widget for desktop layout that listens to tab controller changes.
class _DesktopLayoutBody extends StatefulWidget {
  final CupertinoTabController tabController;
  final List<SidebarDestination> destinations;
  final List<Widget> pages;
  final Map<String, WidgetBuilder> routes;
  final ValueChanged<int> onTabChanged;

  const _DesktopLayoutBody({
    required this.tabController,
    required this.destinations,
    required this.pages,
    required this.routes,
    required this.onTabChanged,
  });

  @override
  State<_DesktopLayoutBody> createState() => _DesktopLayoutBodyState();
}

class _DesktopLayoutBodyState extends State<_DesktopLayoutBody> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.tabController.index;
    widget.tabController.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant _DesktopLayoutBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabController != oldWidget.tabController) {
      oldWidget.tabController.removeListener(_onTabChanged);
      widget.tabController.addListener(_onTabChanged);
      _currentIndex = widget.tabController.index;
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_currentIndex != widget.tabController.index) {
      setState(() {
        _currentIndex = widget.tabController.index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DesktopSidebar(
          destinations: widget.destinations,
          currentIndex: _currentIndex,
          onDestinationSelected: (index) {
            widget.tabController.index = index;
            widget.onTabChanged(index);
          },
        ),
        Expanded(
          child: IndexedStack(
            index: _currentIndex,
            children: List.generate(widget.pages.length, (index) {
              return Navigator(
                key: ValueKey('tab_navigator_$index'),
                onGenerateRoute: (settings) {
                  // Check named routes first
                  final routeBuilder = widget.routes[settings.name];
                  if (routeBuilder != null) {
                    return CupertinoPageRoute(
                      builder: routeBuilder,
                      settings: settings,
                    );
                  }
                  // Default: show the tab's root page
                  return CupertinoPageRoute(
                    builder: (_) => widget.pages[index],
                    settings: settings,
                  );
                },
              );
            }),
          ),
        ),
      ],
    );
  }
}
