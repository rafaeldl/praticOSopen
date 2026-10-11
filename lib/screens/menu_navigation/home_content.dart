import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/order_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';

/// Visual layer of the Início tab. It receives plain data and callbacks (no
/// store, no Firebase), so every state can be tested in isolation. `Home`
/// wires it to the order store.
///
/// Zones: top bar (bell, "…"), large title, next-step block, "Em aberto |
/// Todas" toggle, search, grouped list and the floating "Nova OS" button.
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
    required this.useContracts,
    required this.unreadCount,
    required this.statusLabel,
    required this.onOpenOrder,
    required this.onNewOrder,
    required this.onRetry,
    required this.onLoadMore,
    required this.onOpenNotifications,
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
  final bool useContracts;
  final int unreadCount;

  /// Status label by segment (falls back to the l10n default).
  final String Function(String? status) statusLabel;
  final ValueChanged<Order> onOpenOrder;
  final VoidCallback onNewOrder;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final VoidCallback onOpenNotifications;

  /// Whether the company has any order at all. `null` = not known yet, which
  /// is treated as "yes" so the first-time screen never flashes.
  final bool? hasAnyOrders;
  final String? customerFilterName;
  final VoidCallback? onClearCustomerFilter;
  final Widget? leading;
  final Widget? banner;

  /// Clock, for tests.
  final DateTime Function()? now;

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Map<HomeGroup, GlobalKey> _groupKeys = {
    for (final g in HomeGroup.values) g: GlobalKey(),
  };
  String _query = '';

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 200 &&
        widget.hasMore &&
        !widget.isLoading) {
      widget.onLoadMore();
    }
  }

  bool get _isFirstTime =>
      widget.hasAnyOrders == false &&
      widget.orders.isEmpty &&
      !widget.isLoading &&
      !widget.loadFailed &&
      widget.customerFilterName == null &&
      widget.view.isSegmented;

  List<Order> get _visibleOrders {
    if (_query.isEmpty) return widget.orders;
    return widget.orders.where((order) {
      final number = order.number?.toString().toLowerCase() ?? '';
      final customer = order.customer?.name?.toLowerCase() ?? '';
      final device = order.device?.name?.toLowerCase() ?? '';
      final serial = order.device?.serial?.toLowerCase() ?? '';
      return number.contains(_query) ||
          customer.contains(_query) ||
          device.contains(_query) ||
          serial.contains(_query);
    }).toList();
  }

  void _scrollToGroup(HomeGroup group) {
    final context = _groupKeys[group]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  String _groupTitle(HomeGroup group) {
    final l10n = context.l10n;
    return switch (group) {
      HomeGroup.late => l10n.sectionLate,
      HomeGroup.dueToday => l10n.sectionDueToday,
      HomeGroup.inProgress => l10n.sectionInProgress,
      HomeGroup.waitingApproval => l10n.sectionWaitingApproval,
      HomeGroup.approved => l10n.sectionApproved,
    };
  }

  Future<void> _showMoreMenu() {
    final l10n = context.l10n;
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              widget.onViewChanged(HomeView.canceled);
            },
            child: Text(l10n.moreShowCanceled),
          ),
          if (widget.useContracts)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context, rootNavigator: true)
                    .pushNamed('/contract_list');
              },
              child: Text(l10n.contracts),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstTime = _isFirstTime;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final buttonBottom = bottomInset + AppSpacing.md;
    final listBottomPadding =
        buttonBottom + AppSizes.primaryButtonHeight + AppSpacing.xl;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              _buildNavigationBar(context),
              ..._buildBody(context, firstTime, listBottomPadding),
            ],
          ),
          if (!firstTime)
            Positioned(
              left: AppSpacing.blockMargin,
              right: AppSpacing.blockMargin,
              bottom: buttonBottom,
              child: Semantics(
                identifier: 'add_order_button',
                child: PrimaryButton(
                  label: context.l10n.homeNewOrder,
                  icon: CupertinoIcons.add,
                  floating: true,
                  onPressed: widget.onNewOrder,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    final l10n = context.l10n;
    final count = widget.unreadCount;
    return CupertinoSliverNavigationBar(
      automaticallyImplyLeading: false,
      leading: widget.leading,
      largeTitle: Semantics(
        identifier: 'home_title',
        child: Text(widget.title),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            identifier: 'notifications_button',
            button: true,
            label: count > 0
                ? l10n.notificationsA11y(count)
                : l10n.notifications,
            excludeSemantics: true,
            child: _GlassIconButton(
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
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            identifier: 'home_more_button',
            button: true,
            label: l10n.homeMoreMenu,
            excludeSemantics: true,
            child: _GlassIconButton(
              onPressed: _showMoreMenu,
              child: Icon(
                CupertinoIcons.ellipsis,
                color: AppColors.text.resolveFrom(context),
              ),
            ),
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
    final visible = _visibleOrders;
    final searching = _query.isNotEmpty;

    // Subtitle: only when every open order is loaded (a count of a partial
    // page would be wrong).
    if (widget.view == HomeView.open &&
        !widget.hasMore &&
        !widget.isLoading &&
        widget.orders.isNotEmpty &&
        widget.customerFilterName == null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              0,
              AppSpacing.pageMargin,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.homeOpenCount(widget.orders.length),
              style: AppTypography.callout.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.banner != null) {
      slivers.add(SliverToBoxAdapter(child: widget.banner));
    }

    if (widget.customerFilterName != null) {
      slivers.add(SliverToBoxAdapter(child: _buildCustomerFilter(context)));
    }

    // Next step (open view only; not while searching).
    if (widget.view == HomeView.open && !searching) {
      final step = HomeRules.nextStep(widget.orders, _now);
      if (step != null) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildNextStep(context, step),
            ),
          ),
        );
      }
    }

    slivers.add(SliverToBoxAdapter(child: _buildViewSwitcher(context)));

    if (widget.orders.isNotEmpty || searching) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.blockMargin,
              AppSpacing.sm,
              AppSpacing.blockMargin,
              0,
            ),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: '${l10n.search} ${widget.title}',
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
        ),
      );
    }

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
        const SliverFillRemaining(
          hasScrollBody: false,
          child: LoadingState(),
        ),
      );
      return slivers;
    }
    if (widget.orders.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: widget.view == HomeView.open
              ? EmptyState(
                  title: l10n.noOpenOrders,
                  actionLabel: l10n.seeAllOrders,
                  onAction: () => widget.onViewChanged(HomeView.all),
                )
              : EmptyState(title: l10n.noOrdersInView),
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

    final items = _buildListItems(context, visible);
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

  List<Widget> _buildFirstTime(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      l10n.howItWorksStep1,
      l10n.howItWorksStep2,
      l10n.howItWorksStep3,
    ];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: NextStepBlock(
            text: l10n.firstOrderTitle,
            button: Semantics(
              identifier: 'add_order_button',
              child: PrimaryButton(
                label: l10n.homeNewOrder,
                onPressed: widget.onNewOrder,
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: SectionLabel(l10n.howItWorks)),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary.resolveFrom(context),
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[index],
                    style: AppTypography.body.copyWith(
                      color: AppColors.text.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          childCount: steps.length,
        ),
      ),
    ];
  }

  Widget _buildNextStep(BuildContext context, NextStep step) {
    final l10n = context.l10n;
    final late = step.kind == NextStepKind.late;
    return NextStepBlock(
      warning: late,
      label: late ? l10n.nextStepLabelToday : null,
      text: switch (step.kind) {
        NextStepKind.late => l10n.nextStepLate(step.count),
        NextStepKind.dueToday => l10n.nextStepDueToday(step.count),
        NextStepKind.quotesWaiting => l10n.nextStepQuotesWaiting(step.count),
      },
      linkLabel: late ? l10n.seeLate : l10n.seeThem,
      onLink: () => _scrollToGroup(step.target),
    );
  }

  Widget _buildViewSwitcher(BuildContext context) {
    final l10n = context.l10n;
    if (widget.view.isSegmented) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.blockMargin,
          AppSpacing.sm,
          AppSpacing.blockMargin,
          0,
        ),
        child: CupertinoSlidingSegmentedControl<HomeView>(
          groupValue: widget.view,
          children: {
            HomeView.open: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(l10n.filterOpen),
            ),
            HomeView.all: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(l10n.filterAll),
            ),
          },
          onValueChanged: (value) {
            if (value != null && value != widget.view) {
              widget.onViewChanged(value);
            }
          },
        ),
      );
    }
    final title = l10n.viewCanceledTitle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.bodyStrong.copyWith(
                  color: AppColors.text.resolveFrom(context),
                ),
              ),
            ),
          ),
          TextLink(
            label: l10n.backToOpenOrders,
            onPressed: () => widget.onViewChanged(HomeView.open),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerFilter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  List<Widget> _buildListItems(BuildContext context, List<Order> visible) {
    final items = <Widget>[];
    final now = _now;

    if (widget.view == HomeView.open) {
      final groups = HomeRules.groupOpen(visible, now);
      for (final entry in groups.entries) {
        items.add(
          KeyedSubtree(
            key: _groupKeys[entry.key],
            child: SectionLabel(_groupTitle(entry.key)),
          ),
        );
        for (final order in entry.value) {
          items.add(_buildRow(context, order, now));
        }
      }
      return items;
    }

    final format = FormatService();
    for (final entry in HomeRules.groupByMonth(visible)) {
      if (entry.key != null) {
        items.add(SectionLabel(format.formatMonthYearTitle(entry.key)));
      }
      for (final order in entry.value) {
        items.add(_buildRow(context, order, now));
      }
    }
    return items;
  }

  Widget _buildRow(BuildContext context, Order order, DateTime now) {
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

    String? device;
    if (widget.showDevice) {
      final devices = order.effectiveDevices;
      if (devices.isNotEmpty) {
        final first = devices.first;
        final parts = [
          if ((first.name ?? '').isNotEmpty) first.name!,
          if ((first.serial ?? '').isNotEmpty) first.serial!,
        ];
        if (parts.isNotEmpty) {
          device = parts.join(' • ');
          if (devices.length > 1) device = '$device +${devices.length - 1}';
        }
      }
    }
    final number = order.number?.toString();
    final detail = number == null
        ? device
        : (device == null
              ? l10n.orderRowNumber(number)
              : l10n.orderRowNumberDevice(number, device));

    final customer = order.customer?.name ?? '';
    return Semantics(
      identifier: 'order_card_${order.id ?? order.number ?? ''}',
      button: true,
      child: OrderListRow(
        customerName: customer,
        valueText: widget.showPrices
            ? format.formatCurrency(order.total ?? 0)
            : null,
        statusText: statusText,
        dotColor: overdue
            ? OrderStatusStyle.overdueColor
            : OrderStatusStyle.dotColor(order.status),
        overdue: overdue,
        paidText: widget.showPrices && order.payment == 'paid'
            ? l10n.paid
            : null,
        detailText: detail,
        thumbnailUrl: order.coverPhotoUrl,
        progress: _executionPercentage(order),
        onTap: () => widget.onOpenOrder(order),
      ),
    );
  }

  /// Reads executionPercentage from order.customData (segments that track it).
  double? _executionPercentage(Order order) {
    final value = order.customData?['executionPercentage'];
    if (value == null) return null;
    if (value is num) return value.toDouble().clamp(0, 100);
    if (value is String) return double.tryParse(value)?.clamp(0, 100);
    return null;
  }
}

/// Round 44pt button on glass, for the top bar (design system rule 11).
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppGlass(
      borderRadius: BorderRadius.circular(AppSizes.minTouchTarget / 2),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
