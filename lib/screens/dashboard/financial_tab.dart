import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_tab_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/widgets/permission_widgets.dart';
import 'package:praticos/screens/dashboard/financial_list_screen.dart';
import 'package:praticos/screens/dashboard/financial_report_screen.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/nfse/nfse_list_screen.dart';
import 'package:praticos/screens/payments/receive_customer_screen.dart';
import 'package:praticos/screens/payments/send_charge_flow.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/period_stepper.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/financial_summary.dart';

/// Financeiro tab.
///
/// Recebido and Vendido follow the chosen month; Hoje (A receber, Em
/// andamento) and Próxima cobrança do not. Each value opens the list that adds
/// up to it; charts, rankings and other periods live in
/// [FinancialReportScreen], reached from the "…" menu.
///
/// The `on*` callbacks default to the real navigation and exist so tests can
/// observe what the tab asks for. Permission (`viewFinancialReports`) is
/// enforced by the caller (see `NavigationController`).
class FinancialTab extends StatefulWidget {
  const FinancialTab({
    super.key,
    this.store,
    this.onOpenOrder,
    this.onOpenOrderScreen,
    this.onSendCharge,
    this.onOpenReport,
    this.sendChargeFlow,
    this.onReceiveFromCustomer,
    this.onChargeCustomer,
    this.nfse,
  });

  final FinancialTabStore? store;

  /// Notas of the month's row (tests); defaults to a new [NfseController]
  /// that stays off unless the company has `nfseEnabled`.
  final NfseController? nfse;

  /// Opens the Receber of one order.
  final void Function(BuildContext context, Order order)? onOpenOrder;

  /// Opens the order itself (Em andamento, Vendido). Defaults to `/order`.
  final void Function(BuildContext context, Order order)? onOpenOrderScreen;

  /// "Receber de João": one payment over the customer's open orders.
  /// Defaults to pushing [ReceiveCustomerScreen] (test seam).
  final Future<bool> Function(BuildContext context, Debtor debtor)?
  onReceiveFromCustomer;

  /// "Mandar cobrança" for a customer with several orders. Defaults to
  /// [ReceiveCustomerScreen] with the charge sheet open (test seam).
  final Future<bool> Function(BuildContext context, Debtor debtor)?
  onChargeCustomer;

  /// Sends the payment link of an order to its customer. Overrides
  /// [sendChargeFlow] entirely (test seam).
  final void Function(BuildContext context, Order order)? onSendCharge;

  /// "Mandar cobrança" flow: with Asaas connected it generates the charge
  /// first, then shares the link; otherwise it shares the order link.
  /// Defaults to [SendChargeFlow] with the real dependencies.
  final SendChargeFlow? sendChargeFlow;

  /// Opens the report screen; [customPeriod] asks for the period picker.
  final void Function(BuildContext context, {required bool customPeriod})?
  onOpenReport;

  @override
  State<FinancialTab> createState() => _FinancialTabState();
}

class _FinancialTabState extends State<FinancialTab> {
  late final FinancialTabStore _store = widget.store ?? FinancialTabStore();

  /// True while "Mandar cobrança" runs (reads Asaas state, charge screen,
  /// share sheet): a second tap is ignored so no duplicate charge is made.
  bool _sendingCharge = false;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  // ── Navigation ──────────────────────────────────────────────────

  Future<void> _openOrder(Order order) async {
    final open = widget.onOpenOrder;
    if (open != null) {
      open(context, order);
    } else {
      // "Receber" of the order, as in the prototype (app-financeiro →
      // app-receber); the order itself is one tap away from there.
      await Navigator.of(context).pushNamed(
        '/payment_management',
        arguments: {'orderStore': OrderStore()..setOrder(order)},
      );
    }
    // The order may have been paid there.
    if (mounted) _store.refresh();
  }

  Future<void> _openOrderScreen(Order order) async {
    final open = widget.onOpenOrderScreen;
    if (open != null) {
      open(context, order);
    } else {
      await Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamed('/order', arguments: {'order': order});
    }
    if (mounted) _store.refresh();
  }

  Future<void> _sendCharge(Order order) async {
    final send = widget.onSendCharge;
    if (send != null) {
      send(context, order);
      return;
    }
    if (_sendingCharge) return;
    setState(() => _sendingCharge = true);
    try {
      final action = await (widget.sendChargeFlow ?? SendChargeFlow()).send(
        context,
        order,
      );
      // A charge may have been created: reload what is owed.
      if (mounted && action != SendChargeAction.shareOrderLink) {
        _store.refresh();
      }
    } finally {
      if (mounted) setState(() => _sendingCharge = false);
    }
  }

  Future<void> _openReport({bool customPeriod = false}) async {
    final open = widget.onOpenReport;
    if (open != null) {
      open(context, customPeriod: customPeriod);
      return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        settings: const RouteSettings(name: '/financial_report'),
        builder: (_) => ProtectedRoute(
          permission: PermissionType.viewFinancialReports,
          accessDeniedMessage: context.l10n.financialAccessDenied,
          child: FinancialReportScreen(
            openCustomPeriod: customPeriod,
            initialMonthOffset: _store.monthOffset,
          ),
        ),
      ),
    );
  }

  /// One open order: its Receber. Several (same customer): "Receber de
  /// João", one payment split oldest first. Orders without a customer are
  /// not one payer, so they keep the "Qual OS?" picker. Goes by every open
  /// order of the customer, not only the completed ones in A receber.
  Future<void> _openDebtor(Debtor debtor) async {
    final orders = debtor.openOrders;
    if (orders.length == 1) {
      _openOrder(orders.first);
      return;
    }
    if (debtor.customerId != null) {
      final receive = widget.onReceiveFromCustomer;
      final received = receive != null
          ? await receive(context, debtor)
          : await ReceiveCustomerScreen.open(
              context,
              orders: orders,
              checkedOrderIds: {for (final o in debtor.orders) o.id!},
              customer: debtor.oldestOrder.customer,
              customerName: debtor.name,
            );
      if (received && mounted) _store.refresh();
      return;
    }
    final order = await _pickOrder(debtor, orders);
    if (order != null && mounted) _openOrder(order);
  }

  Future<Order?> _pickOrder(Debtor debtor, List<Order> orders) {
    final l10n = context.l10n;
    final format = FormatService();
    return pickOne<Order>(
      context,
      title: l10n.financialWhichOrder,
      subtitle: l10n.financialPickOrderTitle(
        debtor.name ?? l10n.customerWithoutName,
      ),
      options: [
        for (final order in orders)
          PickerItem<Order>(
            value: order,
            title: l10n.financialOrderOption(
              order.number ?? 0,
              format.formatCurrency(FinancialSummary.openAmount(order)),
              format.formatDayMonthOrDate(order.createdAt),
            ),
          ),
      ],
    );
  }

  /// "Mandar cobrança" of a customer with several orders: one charge, from
  /// the same screen that receives, with the completed orders checked.
  /// False when Asaas can't charge them, so the caller picks one order.
  Future<bool> _chargeCustomer(Debtor debtor) async {
    final charge = widget.onChargeCustomer;
    if (charge != null) {
      if (await charge(context, debtor) && mounted) _store.refresh();
      return true;
    }
    final customer = debtor.oldestOrder.customer;
    bool available;
    try {
      available = await ReceiveCustomerScreen.chargeAvailable(customer?.id);
    } catch (_) {
      available = false;
    }
    if (!available || !mounted) return false;
    final done = await ReceiveCustomerScreen.open(
      context,
      orders: debtor.openOrders,
      checkedOrderIds: {for (final o in debtor.orders) o.id!},
      customer: customer,
      customerName: debtor.name,
      startCharge: true,
    );
    if (done && mounted) _store.refresh();
    return true;
  }

  /// Próxima cobrança: "Mandar cobrança" or "Agora não", which only pauses
  /// the suggestion. With Asaas, several orders of a customer go in one
  /// charge; otherwise it asks which order, as only one link can be shared.
  Future<void> _showNextCharge(Debtor debtor) async {
    if (_sendingCharge) return;
    final l10n = context.l10n;
    final format = FormatService();
    final choice = await showCupertinoModalPopup<_NextChargeChoice>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        message: Text(
          l10n.financialNextChargeMessage(
            debtor.name ?? l10n.customerWithoutName,
            format.formatCurrency(debtor.amount),
            format.formatDayMonthOrDate(debtor.since),
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            key: const Key('financialSendCharge'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(sheet, _NextChargeChoice.send),
            child: Text(l10n.financialSendCharge),
          ),
          CupertinoActionSheetAction(
            key: const Key('financialNotNow'),
            onPressed: () => Navigator.pop(sheet, _NextChargeChoice.snooze),
            child: Text(l10n.notNow),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == _NextChargeChoice.snooze) {
      await _store.snoozeNextCharge(debtor);
    } else if (choice == _NextChargeChoice.send) {
      if (!debtor.hasSingleOrder &&
          debtor.customerId != null &&
          await _chargeCustomer(debtor)) {
        return;
      }
      if (!mounted) return;
      final order = debtor.hasSingleOrder
          ? debtor.oldestOrder
          : await _pickOrder(debtor, debtor.orders);
      if (order != null && mounted) await _sendCharge(order);
    }
  }

  void _openList({
    required String title,
    required String Function(FinancialSummary summary) subtitle,
    required List<Widget> Function(FinancialSummary summary) rows,
    required String emptyMessage,
  }) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => FinancialListScreen(
          store: _store,
          title: title,
          subtitle: subtitle,
          rows: rows,
          emptyMessage: emptyMessage,
        ),
      ),
    );
  }

  void _openReceivable() {
    final l10n = context.l10n;
    final format = FormatService();
    _openList(
      title: l10n.financialReceivable,
      subtitle: (summary) => l10n.financialReceivableSummary(
        format.formatCurrency(summary.owed),
        summary.debtors.length,
      ),
      rows: (summary) => [
        for (final debtor in summary.debtors)
          AppListRow(
            key: ValueKey('debtor-${debtor.key}'),
            title: debtor.name ?? l10n.customerWithoutName,
            titleStyle: AppTypography.bodyStrong,
            valueBesideTitle: true,
            trailing: format.formatCurrency(debtor.amount),
            subtitle: l10n.financialSince(
              format.formatDayMonthOrDate(debtor.since),
            ),
            onTap: () => _openDebtor(debtor),
          ),
      ],
      emptyMessage: l10n.financialEmptyReceivable,
    );
  }

  void _openInProgress() {
    final l10n = context.l10n;
    final format = FormatService();
    _openList(
      title: l10n.financialInProgress,
      subtitle: (summary) => l10n.financialInProgressSummary(
        format.formatCurrency(summary.inProgress),
        summary.inProgressOrders.length,
      ),
      rows: (summary) => [
        for (final order in summary.inProgressOrders)
          _orderRow(
            order,
            amount: FinancialSummary.openAmount(order),
            subtitle: l10n.financialOrderSince(
              order.number ?? 0,
              format.formatDayMonthOrDate(order.createdAt),
            ),
          ),
      ],
      emptyMessage: l10n.financialEmptyInProgress,
    );
  }

  void _openReceived() {
    final l10n = context.l10n;
    final format = FormatService();
    final month = _store.month;
    _openList(
      title: l10n.received,
      subtitle: (summary) => l10n.financialMonthAmount(
        format.formatMonthYearTitle(month),
        format.formatCurrency(summary.entered),
      ),
      rows: (summary) => [
        for (final order in summary.receivedOrders)
          _orderRow(
            order,
            amount: FinancialSummary.receivedIn(order, month),
            subtitle: l10n.financialOrderDate(
              order.number ?? 0,
              format.formatDayMonthOrDate(
                FinancialSummary.receivedDate(order, month),
              ),
            ),
          ),
      ],
      emptyMessage: l10n.financialEmptyReceived(format.formatMonthYear(month)),
    );
  }

  void _openSold() {
    final l10n = context.l10n;
    final format = FormatService();
    final month = _store.month;
    _openList(
      title: l10n.financialSold,
      subtitle: (summary) => l10n.financialMonthAmount(
        format.formatMonthYearTitle(month),
        format.formatCurrency(summary.sold),
      ),
      rows: (summary) => [
        for (final order in summary.soldOrders)
          _orderRow(
            order,
            amount: order.total ?? 0,
            subtitle: l10n.financialOrderDate(
              order.number ?? 0,
              format.formatDayMonthOrDate(order.createdAt),
            ),
          ),
      ],
      emptyMessage: l10n.financialEmptyMonth(format.formatMonthYear(month)),
    );
  }

  Widget _orderRow(
    Order order, {
    required double amount,
    required String subtitle,
  }) {
    return AppListRow(
      key: ValueKey('order-${order.id}'),
      title: order.customer?.name ?? context.l10n.customerWithoutName,
      titleStyle: AppTypography.bodyStrong,
      valueBesideTitle: true,
      trailing: FormatService().formatCurrency(amount),
      subtitle: subtitle,
      onTap: () => _openOrderScreen(order),
    );
  }

  Future<void> _showMoreMenu() async {
    final l10n = context.l10n;
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'report',
            label: l10n.financialReportShort,
            icon: CupertinoIcons.chart_bar,
          ),
          PullDownItem(
            value: 'period',
            label: l10n.financialOtherPeriod,
            icon: CupertinoIcons.calendar,
          ),
        ]),
      ],
    );
    if (!mounted) return;
    if (picked == 'report') _openReport();
    if (picked == 'period') _openReport(customPeriod: true);
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      child: Observer(
        builder: (_) {
          final summary = _store.summary;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverNavigationBar(
                backgroundColor: AppNavBar.barBackground(context),
                alwaysShowMiddle: false,
                largeTitle: Text(context.l10n.financial),
                border: null,
                trailing: _MoreButton(onPressed: _showMoreMenu),
              ),
              CupertinoSliverRefreshControl(onRefresh: _store.refresh),
              SliverToBoxAdapter(child: _buildStepper(context)),
              ..._buildBody(context, summary),
              SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl + bottomInset),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepper(BuildContext context) {
    final l10n = context.l10n;
    return PeriodStepper(
      label: FormatService().formatMonthYearTitle(_store.month),
      previousLabel: l10n.financialPreviousMonth,
      nextLabel: l10n.financialNextMonth,
      onPrevious: _store.previousMonth,
      onNext: _store.isCurrentMonth ? null : _store.nextMonth,
      onTapLabel: _store.isCurrentMonth ? null : _store.goToCurrentMonth,
    );
  }

  List<Widget> _buildBody(BuildContext context, FinancialSummary summary) {
    final l10n = context.l10n;
    final format = FormatService();

    switch (_store.status) {
      case FinancialTabStatus.loading:
        return const [
          SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
        ];
      case FinancialTabStatus.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: l10n.financialLoadError,
              onRetry: _store.load,
            ),
          ),
        ];
      case FinancialTabStatus.ready:
        break;
    }

    final monthLoading = _store.monthLoading;
    final next = _store.nextCharge;

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MonthBlocks(
              first: _MonthBlock(
                key: const ValueKey('financialReceived'),
                label: l10n.received,
                value: monthLoading
                    ? null
                    : format.formatCurrency(summary.entered),
                onTap: monthLoading ? null : _openReceived,
              ),
              second: _MonthBlock(
                key: const ValueKey('financialSold'),
                label: l10n.financialSold,
                value: monthLoading
                    ? null
                    : format.formatCurrency(summary.sold),
                onTap: monthLoading ? null : _openSold,
              ),
            ),
            _GroupedSection(
              label: l10n.financialToday,
              children: [
                AppListRow(
                  key: const ValueKey('financialReceivable'),
                  title: l10n.financialReceivable,
                  valueBesideTitle: true,
                  horizontalPadding: AppSpacing.lg,
                  trailing: format.formatCurrency(summary.owed),
                  onTap: _openReceivable,
                ),
                AppListRow(
                  key: const ValueKey('financialInProgress'),
                  title: l10n.financialInProgress,
                  valueBesideTitle: true,
                  horizontalPadding: AppSpacing.lg,
                  trailing: format.formatCurrency(summary.inProgress),
                  onTap: _openInProgress,
                ),
              ],
            ),
            if (next != null)
              _GroupedSection(
                label: l10n.financialNextCharge,
                children: [
                  AppListRow(
                    key: const ValueKey('financialNextCharge'),
                    title: next.name ?? l10n.customerWithoutName,
                    valueBesideTitle: true,
                    horizontalPadding: AppSpacing.lg,
                    trailing: format.formatCurrency(next.amount),
                    onTap: () => _showNextCharge(next),
                  ),
                ],
              ),
            NfseMonthRow(
              month: _store.month,
              nfse: widget.nfse,
              wrap: (row) => _GroupedSection(children: [row]),
            ),
          ],
        ),
      ),
    ];
  }
}

enum _NextChargeChoice { send, snooze }

/// The two month values side by side; stacked at accessibility text sizes.
class _MonthBlocks extends StatelessWidget {
  const _MonthBlocks({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.textScalerOf(context).scale(100) / 100 >=
        kAppListRowStackScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.sm,
        AppSpacing.blockMargin,
        0,
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                first,
                const SizedBox(height: AppSpacing.md),
                second,
              ],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: second),
                ],
              ),
            ),
    );
  }
}

/// Label, value and chevron. A null [value] means it is still loading.
class _MonthBlock extends StatelessWidget {
  const _MonthBlock({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.callout.copyWith(color: secondary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 18,
                      color: secondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (value == null)
                  const CupertinoActivityIndicator()
                else
                  Text(
                    value!,
                    style: AppTypography.highlight.copyWith(
                      color: AppColors.text.resolveFrom(context),
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [SectionLabel] above an inset grouped list.
class _GroupedSection extends StatelessWidget {
  const _GroupedSection({this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label == null)
          const SizedBox(height: AppSpacing.lg)
        else
          SectionLabel(label!),
        CupertinoListSection.insetGrouped(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.blockMargin,
          ),
          topMargin: 0,
          additionalDividerMargin: 0,
          hasLeading: false,
          backgroundColor: AppColors.groupedBackground.resolveFrom(context),
          decoration: BoxDecoration(
            color: AppColors.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          separatorColor: AppColors.separator.resolveFrom(context),
          children: children,
        ),
      ],
    );
  }
}

/// "…" as the shared glass top button.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassBarButton(
      key: const Key('financialMore'),
      label: context.l10n.more,
      icon: CupertinoIcons.ellipsis,
      onPressed: onPressed,
    );
  }
}
