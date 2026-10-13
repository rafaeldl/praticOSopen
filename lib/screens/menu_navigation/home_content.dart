import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/order_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Visual layer of the Início tab. It receives plain data and callbacks (no
/// store, no Firebase), so every state can be tested in isolation. `Home`
/// wires it to the order store.
///
/// Zones: top bar (bell, profile), large title with a one-line summary,
/// filter buttons ("Em aberto | Concluídas | Todas"), and the list in the
/// style of Mail. Search is hidden until the list is pulled down. "Nova OS"
/// is the blue "+" beside the tabs ([NewOrderTabButton]), not on this screen.
class HomeContent extends StatefulWidget {
  const HomeContent({
    super.key,
    required this.orders,
    required this.view,
    required this.onViewChanged,
    required this.title,
    required this.isLoading,
    required this.hasMore,
    required this.loadFailed,
    required this.showPrices,
    required this.showDevice,
    required this.unreadCount,
    required this.statusLabel,
    required this.onOpenOrder,
    required this.onRetry,
    required this.onLoadMore,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    this.companyName,
    this.deviceLabel,
    this.technician = false,
    this.currentUserId,
    this.hasAnyOrders,
    this.customerFilterName,
    this.onClearCustomerFilter,
    this.leading,
    this.banner,
    this.now,
  });

  final List<Order> orders;
  final HomeView view;
  final ValueChanged<HomeView> onViewChanged;

  /// Large title (segment label, e.g. "Ordens de serviço").
  final String title;
  final bool isLoading;
  final bool hasMore;
  final bool loadFailed;
  final bool showPrices;
  final bool showDevice;
  final int unreadCount;

  /// Company on the profile button ("OZ" for "Oficina do Zé").
  final String? companyName;

  /// Segment name of the device ("veículo"), for the first-time steps and
  /// the search hint. Null when the segment does not track devices.
  final String? deviceLabel;

  /// Technician layout (prototype "Início · técnico"): "Minhas | Todas" and
  /// the "Agora" block with today's next visit.
  final bool technician;

  /// Signed-in user, to pick the technician's orders ("Minhas").
  final String? currentUserId;

  /// Status label by segment (falls back to the l10n default).
  final String Function(String? status) statusLabel;
  final ValueChanged<Order> onOpenOrder;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final VoidCallback onOpenNotifications;

  /// Profile button: customers, catalog, team and settings (the former
  /// "Mais" tab).
  final VoidCallback onOpenProfile;

  /// Whether the company has any order at all. `null` = not known yet, which
  /// is treated as "yes" so the first-time screen never flashes.
  final bool? hasAnyOrders;
  final String? customerFilterName;
  final VoidCallback? onClearCustomerFilter;
  final Widget? leading;
  final Widget? banner;

  /// Clock, for tests.
  final DateTime Function()? now;

  /// How far the list must be pulled down to show the search field.
  static const double pullToSearch = 48;

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey _searchKey = GlobalKey();
  String _query = '';

  /// Search shows up when the list is pulled down (like Mail and Notes) and
  /// stays until the list is scrolled away with an empty field.
  bool _searchVisible = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view && _query.isEmpty) {
      _searchVisible = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.extentAfter < 200 && widget.hasMore && !widget.isLoading) {
      widget.onLoadMore();
    }
    if (!_searchVisible && position.pixels < -HomeContent.pullToSearch) {
      setState(() => _searchVisible = true);
    } else if (_searchVisible &&
        _query.isEmpty &&
        !_searchFocus.hasFocus &&
        position.pixels > 300) {
      // Hide it without moving the rows under the finger.
      final height = _searchKey.currentContext?.size?.height ?? 0;
      setState(() => _searchVisible = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset - height);
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() => _query = '');
  }

  bool get _isFirstTime =>
      widget.hasAnyOrders == false &&
      widget.orders.isEmpty &&
      !widget.isLoading &&
      !widget.loadFailed &&
      widget.customerFilterName == null &&
      widget.view != HomeView.done;

  /// Orders of the current view before search ("Minhas" keeps only the ones
  /// assigned to the user).
  List<Order> get _baseOrders => widget.view == HomeView.mine
      ? HomeRules.assignedTo(widget.orders, widget.currentUserId)
      : widget.orders;

  /// Technician's next visit today, shown in the "Agora" block.
  Order? get _nextVisit => widget.view == HomeView.mine && _query.isEmpty
      ? HomeRules.nextVisit(_baseOrders, _now)
      : null;

  List<Order> get _visibleOrders {
    if (_query.isEmpty) return _baseOrders;
    return _baseOrders.where((order) {
      final number = order.number?.toString().toLowerCase() ?? '';
      final customer = order.customer?.name?.toLowerCase() ?? '';
      final devices = order.effectiveDevices;
      return number.contains(_query) ||
          customer.contains(_query) ||
          devices.any(
            (d) =>
                (d.name?.toLowerCase() ?? '').contains(_query) ||
                (d.serial?.toLowerCase() ?? '').contains(_query),
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final firstTime = _isFirstTime;
    final listBottomPadding =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        controller: _scroll,
        // Bouncing everywhere: pulling past the top is what shows search.
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          _buildNavigationBar(context),
          ..._buildBody(context, firstTime, listBottomPadding),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    final l10n = context.l10n;
    final count = widget.unreadCount;
    return CupertinoSliverNavigationBar(
      backgroundColor: AppNavBar.barBackground(context),
      alwaysShowMiddle: false,
      automaticallyImplyLeading: false,
      leading: widget.leading,
      largeTitle: Semantics(
        identifier: 'home_title',
        child: Text(widget.title),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassBarButton(
            identifier: 'notifications_button',
            label: count > 0
                ? l10n.notificationsA11y(count)
                : l10n.notifications,
            onPressed: widget.onOpenNotifications,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  CupertinoIcons.bell,
                  color: AppColors.text.resolveFrom(context),
                ),
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.resolveFrom(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onAccent.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ProfileButton(
            name: widget.companyName,
            label: l10n.profileButtonA11y(widget.companyName ?? l10n.more),
            onPressed: widget.onOpenProfile,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    bool firstTime,
    double bottomPadding,
  ) {
    final l10n = context.l10n;
    if (firstTime) return _buildFirstTime(context);

    final slivers = <Widget>[];
    final base = _baseOrders;
    final visible = _visibleOrders;

    // Subtitle: open views load every open order, so the count is exact.
    if (widget.view.isOpenList &&
        !widget.hasMore &&
        !widget.isLoading &&
        base.isNotEmpty &&
        widget.customerFilterName == null) {
      final String text;
      if (widget.view == HomeView.mine) {
        final today = HomeRules.scheduledToday(base, _now).length;
        text = today > 0
            ? l10n.homeWithYouToday(today)
            : l10n.homeWithYou(base.length);
      } else {
        final late = HomeRules.lateCount(base, _now);
        text = late > 0
            ? '${l10n.homeOpenCount(base.length)} · ${l10n.homeLateCount(late)}'
            : l10n.homeOpenCount(base.length);
      }
      slivers.add(_buildSubtitle(context, text));
    }

    if (_searchVisible) {
      slivers.add(SliverToBoxAdapter(child: _buildSearch(context)));
    }

    if (widget.banner != null) {
      slivers.add(SliverToBoxAdapter(child: widget.banner));
    }

    if (widget.customerFilterName != null) {
      slivers.add(SliverToBoxAdapter(child: _buildCustomerFilter(context)));
    }

    final visit = _nextVisit;
    if (visit != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _buildNextVisit(context, visit),
          ),
        ),
      );
    }

    slivers.add(SliverToBoxAdapter(child: _buildFilters(context)));

    // States.
    if (widget.loadFailed && widget.orders.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: l10n.loadOrdersError,
            onRetry: widget.onRetry,
          ),
        ),
      );
      return slivers;
    }
    if (widget.isLoading && widget.orders.isEmpty) {
      slivers.add(
        const SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      );
      return slivers;
    }
    if (base.isEmpty) {
      final mainView =
          widget.view == HomeView.mine || widget.view == HomeView.open;
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: widget.view == HomeView.mine
                ? l10n.noOrdersWithYou
                : widget.view == HomeView.open
                ? l10n.noOpenOrders
                : l10n.noOrdersInView,
            actionLabel: mainView ? l10n.seeAllOrders : null,
            onAction: mainView
                ? () => widget.onViewChanged(HomeView.all)
                : null,
          ),
        ),
      );
      return slivers;
    }
    if (visible.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: l10n.searchNotFoundLoaded,
            actionLabel: widget.hasMore ? l10n.searchOlder : null,
            onAction: widget.hasMore ? widget.onLoadMore : null,
          ),
        ),
      );
      return slivers;
    }

    final items = _buildListItems(context, visible, visit);
    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => items[index],
          childCount: items.length,
        ),
      ),
    );
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CupertinoActivityIndicator()),
                )
              : null,
        ),
      ),
    );
    return slivers;
  }

  Widget _buildSubtitle(BuildContext context, String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          0,
          AppSpacing.pageMargin,
          AppSpacing.xs,
        ),
        child: Text(
          text,
          style: AppTypography.callout.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    final l10n = context.l10n;
    final device = widget.deviceLabel;
    return Padding(
      key: _searchKey,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.sm,
        AppSpacing.pageMargin,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              identifier: 'home_search_field',
              child: CupertinoSearchTextField(
                controller: _searchController,
                focusNode: _searchFocus,
                placeholder: device == null
                    ? l10n.homeSearchHint
                    : l10n.homeSearchHintDevice(device.toLowerCase()),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
          ),
          if (_query.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            TextLink(label: l10n.cancel, onPressed: _clearSearch),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFirstTime(BuildContext context) {
    final l10n = context.l10n;
    final device = widget.deviceLabel;
    final steps = [
      (
        l10n.howItWorksStep1,
        device == null
            ? l10n.howItWorksStep1Detail
            : l10n.howItWorksStep1DetailDevice(device.toLowerCase()),
      ),
      (l10n.howItWorksStep2, l10n.howItWorksStep2Detail),
      (l10n.howItWorksStep3, l10n.howItWorksStep3Detail),
    ];
    return [
      _buildSubtitle(context, l10n.homeNoOrdersYet),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          // Points at the blue "+" beside the tabs, the screen's one button.
          child: NextStepBlock(
            label: l10n.firstOrderLabel,
            text: l10n.firstOrderTapPlus,
          ),
        ),
      ),
      SliverToBoxAdapter(child: SectionLabel(l10n.howItWorks)),
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final (title, detail) = steps[index ~/ 2];
          if (index.isOdd) {
            return const _RowDivider(inset: AppSpacing.pageMargin);
          }
          return AppListRow(
            title: title,
            titleStyle: AppTypography.bodyStrong,
            subtitle: detail,
          );
        }, childCount: steps.length * 2 - 1),
      ),
    ];
  }

  /// Technician's "Agora" block: today's next visit and a button to open it.
  Widget _buildNextVisit(BuildContext context, Order order) {
    final l10n = context.l10n;
    final customer = (order.customer?.name ?? '').trim().split(' ').first;
    final time = FormatService().formatTime(order.scheduledDate);
    final device = widget.deviceLabel == null
        ? null
        : order.effectiveDevices.firstOrNull?.name;
    return NextStepBlock(
      label: l10n.nextVisitLabel,
      text: (device ?? '').isEmpty
          ? l10n.nextVisit(customer, time)
          : l10n.nextVisitDevice(customer, device!, time),
      button: Semantics(
        identifier: 'next_visit_button',
        child: PrimaryButton(
          label: l10n.openOrderNumber(order.number?.toString() ?? ''),
          onPressed: () => widget.onOpenOrder(order),
        ),
      ),
    );
  }

  /// Filter buttons, like the categories in Mail. They wrap to a second
  /// line with large text instead of shrinking.
  Widget _buildFilters(BuildContext context) {
    final l10n = context.l10n;
    final filters = widget.technician
        ? [(HomeView.mine, l10n.filterMine), (HomeView.all, l10n.filterAll)]
        : [
            (HomeView.open, l10n.filterOpen),
            (HomeView.done, l10n.filterDone),
            (HomeView.all, l10n.filterAll),
          ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.md,
        AppSpacing.pageMargin,
        AppSpacing.xs,
      ),
      child: Semantics(
        container: true,
        identifier: 'home_filters',
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (view, label) in filters)
              _FilterButton(
                label: label,
                selected: widget.view == view,
                onPressed: () {
                  if (view != widget.view) widget.onViewChanged(view);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerFilter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.sm,
        AppSpacing.pageMargin,
        0,
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.person_fill,
            size: 16,
            color: AppColors.textSecondary.resolveFrom(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              widget.customerFilterName!,
              style: AppTypography.callout.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
          ),
          if (widget.onClearCustomerFilter != null)
            TextLink(
              label: context.l10n.cancel,
              onPressed: widget.onClearCustomerFilter,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildListItems(
    BuildContext context,
    List<Order> visible,
    Order? visit,
  ) {
    final items = <Widget>[];
    final now = _now;
    final format = FormatService();

    switch (widget.view) {
      case HomeView.mine:
        // Today's visits by time (the time where the value goes), then the
        // rest. The "Agora" visit is already in the block above.
        final today = HomeRules.scheduledToday(visible, now);
        final rows = <(Order, String?)>[
          for (final o in today)
            if (o != visit) (o, format.formatTime(o.scheduledDate)),
          for (final o in HomeRules.sortOpen(
            visible.where((o) => !today.contains(o)).toList(),
            now,
          ))
            (o, null),
        ];
        for (var i = 0; i < rows.length; i++) {
          if (i > 0) items.add(const _RowDivider());
          items.add(_buildRow(context, rows[i].$1, now, trailing: rows[i].$2));
        }
      case HomeView.open:
        _addRows(context, items, HomeRules.sortOpen(visible, now), now);
      case HomeView.done:
        _addRows(context, items, visible, now);
      case HomeView.all:
        for (final entry in HomeRules.groupByMonth(visible)) {
          if (entry.key != null) {
            items.add(SectionLabel(format.formatMonthYearTitle(entry.key)));
          }
          _addRows(context, items, entry.value, now);
        }
    }
    return items;
  }

  /// Rows with an inset hairline between them.
  void _addRows(
    BuildContext context,
    List<Widget> items,
    List<Order> orders,
    DateTime now,
  ) {
    for (var i = 0; i < orders.length; i++) {
      if (i > 0) items.add(const _RowDivider());
      items.add(_buildRow(context, orders[i], now));
    }
  }

  /// [trailing] replaces the value on the right (e.g. the visit time).
  Widget _buildRow(
    BuildContext context,
    Order order,
    DateTime now, {
    String? trailing,
  }) {
    final l10n = context.l10n;
    final format = FormatService();
    final overdue = HomeRules.isOverdue(order, now);

    final String statusText;
    if (overdue) {
      statusText = l10n.orderLateDays(HomeRules.overdueDays(order, now));
    } else {
      final label = widget.statusLabel(order.status);
      final showDue = order.dueDate != null && !HomeRules.isFinished(order);
      statusText = showDue
          ? l10n.orderStatusDue(label, format.formatDayMonth(order.dueDate))
          : label;
    }

    // Money on the list only once the work is done: what is left to receive.
    String? remaining;
    if (widget.showPrices &&
        order.status == 'done' &&
        (order.total ?? 0) > 0 &&
        order.remainingBalance > 0.009) {
      // Non-breaking spaces: "falta receber R$ 180" wraps as one piece.
      remaining = l10n
          .remainingToReceive(format.formatCurrency(order.remainingBalance))
          .replaceAll(' ', '\u00A0');
    }

    return Semantics(
      identifier: 'order_card_${order.id ?? order.number ?? ''}',
      button: true,
      child: OrderListRow(
        customerName: order.customer?.name ?? '',
        valueText:
            trailing ??
            (widget.showPrices
                ? format.formatCurrency(order.total ?? 0)
                : null),
        detailText: _detail(order),
        statusText: statusText,
        statusExtra: remaining,
        overdue: overdue,
        onTap: () => widget.onOpenOrder(order),
      ),
    );
  }

  /// Second line: what is being done ("Fiat Uno · troca de embreagem").
  String? _detail(Order order) {
    final parts = <String>[];
    if (widget.showDevice) {
      final devices = order.effectiveDevices;
      final name = devices.firstOrNull?.name;
      if ((name ?? '').isNotEmpty) {
        parts.add(devices.length > 1 ? '$name +${devices.length - 1}' : name!);
      }
    }
    final services = [
      for (final s in order.services ?? const <OrderService>[])
        if ((s.service?.name ?? s.description ?? '').trim().isNotEmpty)
          (s.service?.name ?? s.description)!.trim(),
    ];
    if (services.isNotEmpty) parts.add(services.join(', '));
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// One filter button: filled accent when selected, grey otherwise.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? AppColors.accent.resolveFrom(context)
        : AppColors.secondaryFill.resolveFrom(context);
    final foreground = selected
        ? AppColors.onAccent.resolveFrom(context)
        : AppColors.onSecondaryFill.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
          ),
          // widthFactor 1: the button hugs its label instead of filling the
          // row, so the three filters sit side by side.
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: AppTypography.callout.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Company initials in a soft accent circle, top right: opens customers,
/// catalog, team and settings.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.name,
    required this.label,
    required this.onPressed,
  });

  final String? name;
  final String label;
  final VoidCallback onPressed;

  static const _connectors = {'da', 'de', 'do', 'das', 'dos', 'e', '&', 'y'};

  /// "Oficina do Zé" → "OZ": first letters of the first and last words.
  static String initials(String? name) {
    // Skip connectors ("do", "da", "e") so "Oficina do Zé" gives "OZ".
    final words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_connectors.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final text = initials(name);
    return Semantics(
      identifier: 'home_profile_button',
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentSoft.resolveFrom(context),
            shape: BoxShape.circle,
          ),
          child: text.isEmpty
              ? Icon(
                  CupertinoIcons.person_fill,
                  size: 22,
                  color: AppColors.onAccentSoft.resolveFrom(context),
                )
              // Initials in a fixed circle: shrink to fit with large text
              // rather than spill out (the label is spoken in full).
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onAccentSoft.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider({this.inset = OrderListRow.leadingInset});

  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: inset),
      child: Container(
        height: 0.5,
        color: AppColors.separator.resolveFrom(context),
      ),
    );
  }
}
