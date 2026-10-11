import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_tab_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/widgets/permission_widgets.dart';
import 'package:praticos/screens/dashboard/financial_report_screen.dart';
import 'package:praticos/screens/payments/send_charge_flow.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/period_stepper.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/financial_summary.dart';

/// How many customers/orders each list shows before "See all".
const int kFinancialPreviewCount = 5;

/// Height of the fixed summary line above the tab bar.
const double _kSummaryHeight = 56;

/// Financeiro tab: answers "who owes me?".
///
/// Month only, with "Falta receber" counting everything still open (any
/// month). Charts, rankings and other periods live in
/// [FinancialReportScreen], reached from here.
///
/// The `on*` callbacks default to the real navigation and exist so tests can
/// observe what the tab asks for. Permission (`viewFinancialReports`) is
/// enforced by the caller (see `NavigationController`).
class FinancialTab extends StatefulWidget {
  const FinancialTab({
    super.key,
    this.store,
    this.onOpenOrder,
    this.onSendCharge,
    this.onOpenReport,
    this.sendChargeFlow,
  });

  final FinancialTabStore? store;

  /// Opens one order.
  final void Function(BuildContext context, Order order)? onOpenOrder;

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
  bool _showAllDebtors = false;
  bool _showAllReceived = false;

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
          child: FinancialReportScreen(openCustomPeriod: customPeriod),
        ),
      ),
    );
  }

  void _openDebtor(Debtor debtor) {
    if (debtor.hasSingleOrder) {
      _openOrder(debtor.oldestOrder);
      return;
    }
    final l10n = context.l10n;
    final format = FormatService();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(
          l10n.financialPickOrderTitle(debtor.name ?? l10n.customerWithoutName),
        ),
        actions: [
          for (final order in debtor.orders)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _openOrder(order);
              },
              child: Text(
                l10n.financialOrderOption(
                  order.number ?? 0,
                  format.formatCurrency(FinancialSummary.openAmount(order)),
                  format.formatDayMonthOrDate(order.createdAt),
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  void _showMoreMenu() {
    final l10n = context.l10n;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openReport();
            },
            child: Text(l10n.financialReportShort),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openReport(customPeriod: true);
            },
            child: Text(l10n.financialOtherPeriod),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Observer(
        builder: (_) {
          final ready = _store.status == FinancialTabStatus.ready;
          final summary = _store.summary;
          final showSummary = ready && !summary.isEmpty;

          return Stack(
            children: [
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  CupertinoSliverNavigationBar(
                    largeTitle: Text(context.l10n.financial),
                    backgroundColor: AppColors.background.resolveFrom(context),
                    border: null,
                    trailing: _MoreButton(onPressed: _showMoreMenu),
                  ),
                  CupertinoSliverRefreshControl(onRefresh: _store.refresh),
                  SliverToBoxAdapter(child: _buildStepper(context)),
                  ..._buildBody(context, summary),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          AppSpacing.xxl +
                          (showSummary ? _kSummaryHeight + bottomInset : 0),
                    ),
                  ),
                ],
              ),
              if (showSummary)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomInset,
                  child: _SummaryLine(summary: summary),
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
      label: FormatService().formatMonthYear(_store.month),
      previousLabel: l10n.financialPreviousMonth,
      nextLabel: l10n.financialNextMonth,
      onPrevious: _store.previousMonth,
      onNext: _store.isCurrentMonth ? null : _store.nextMonth,
      onTapLabel: _store.isCurrentMonth ? null : _store.goToCurrentMonth,
    );
  }

  List<Widget> _buildBody(BuildContext context, FinancialSummary summary) {
    final l10n = context.l10n;

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

    if (summary.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: l10n.financialEmptyMonth(
              FormatService().formatMonthYear(_store.month),
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary.hasDebt) ...[
              _NextStepBlock(
                summary: summary,
                busy: _sendingCharge,
                onSend: () => _sendCharge(summary.oldestDebtor!.oldestOrder),
              ),
              SectionLabel(l10n.financialToReceive),
              ..._debtorRows(context, summary),
            ],
            if (summary.receivedOrders.isNotEmpty) ...[
              SectionLabel(l10n.financialReceived),
              ..._receivedRows(context, summary),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppListRow(
              title: l10n.financialReportShort,
              onTap: () => _openReport(),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _debtorRows(BuildContext context, FinancialSummary summary) {
    final l10n = context.l10n;
    final format = FormatService();
    final debtors = summary.debtors;
    final shown = _showAllDebtors
        ? debtors
        : debtors.take(kFinancialPreviewCount).toList();

    return [
      for (final debtor in shown)
        AppListRow(
          key: ValueKey('debtor-${debtor.key}'),
          title: debtor.name ?? l10n.customerWithoutName,
          trailing: format.formatCurrency(debtor.amount),
          subtitle: debtor.hasSingleOrder
              ? l10n.financialOrderSince(
                  debtor.oldestOrder.number ?? 0,
                  format.formatDayMonthOrDate(debtor.since),
                )
              : l10n.financialOrdersSince(
                  debtor.orders.length,
                  format.formatDayMonthOrDate(debtor.since),
                ),
          onTap: () => _openDebtor(debtor),
        ),
      if (debtors.length > kFinancialPreviewCount)
        _SeeAllLink(
          label: _showAllDebtors
              ? l10n.seeLess
              : l10n.seeAllCount(debtors.length),
          onPressed: () => setState(() => _showAllDebtors = !_showAllDebtors),
        ),
    ];
  }

  List<Widget> _receivedRows(BuildContext context, FinancialSummary summary) {
    final l10n = context.l10n;
    final format = FormatService();
    final received = summary.receivedOrders;
    final shown = _showAllReceived
        ? received
        : received.take(kFinancialPreviewCount).toList();

    return [
      for (final order in shown)
        AppListRow(
          key: ValueKey('received-${order.id}'),
          leading: StatusDot(color: AppColors.success),
          title: order.customer?.name ?? l10n.customerWithoutName,
          trailing: format.formatCurrency(order.paidAmount ?? order.total ?? 0),
          subtitle: l10n.financialPaidOn(
            order.number ?? 0,
            format.formatDayMonth(FinancialSummary.paidDate(order)),
          ),
          onTap: () => _openOrder(order),
        ),
      if (received.length > kFinancialPreviewCount)
        _SeeAllLink(
          label: _showAllReceived
              ? l10n.seeLess
              : l10n.seeAllCount(received.length),
          onPressed: () => setState(() => _showAllReceived = !_showAllReceived),
        ),
    ];
  }
}

/// "Falta receber R$ 1.730 de 3 clientes" + the single filled button.
class _NextStepBlock extends StatelessWidget {
  const _NextStepBlock({
    required this.summary,
    required this.onSend,
    this.busy = false,
  });

  final FinancialSummary summary;
  final VoidCallback onSend;

  /// Shows a spinner and ignores taps while the charge is being prepared.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    final debtor = summary.oldestDebtor!;
    final name = debtor.name ?? l10n.customerWithoutName;
    final onSoft = AppColors.onAccentSoft.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.sm,
        AppSpacing.blockMargin,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accentSoft.resolveFrom(context),
          borderRadius: BorderRadius.circular(AppRadii.block),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.financialNextStep(
                  format.formatCurrency(summary.owed),
                  summary.debtors.length,
                ),
                style: AppTypography.highlight.copyWith(color: onSoft),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.financialOldestDebt(
                  name,
                  format.formatCurrency(debtor.amount),
                  format.formatDayMonthOrDate(debtor.since),
                ),
                style: AppTypography.callout.copyWith(color: onSoft),
              ),
              const SizedBox(height: AppSpacing.lg),
              CupertinoButton(
                key: const Key('financialSendCharge'),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
                color: AppColors.accent.resolveFrom(context),
                borderRadius: BorderRadius.circular(AppRadii.button),
                onPressed: busy ? null : onSend,
                disabledColor: AppColors.accent.resolveFrom(context),
                child: busy
                    ? Semantics(
                        label: l10n.financialSendChargeTo(name),
                        child: CupertinoActivityIndicator(
                          color: AppColors.onAccent.resolveFrom(context),
                        ),
                      )
                    : Text(
                        l10n.financialSendChargeTo(name),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyStrong.copyWith(
                          color: AppColors.onAccent.resolveFrom(context),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Entrou R$ 8.300 · Falta R$ 1.730", fixed above the tab bar.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final format = FormatService();
    final owed = format.formatCurrency(summary.owed);
    final text = context.l10n.financialSummaryLine(
      format.formatCurrency(summary.entered),
      owed,
    );
    final color = AppColors.text.resolveFrom(context);
    final style = AppTypography.callout.copyWith(
      color: color,
      fontFeatures: AppTypography.tabular,
    );

    // "Falta" amount gets the warning color (only when something is owed).
    final split = text.lastIndexOf(owed);
    final spans = split <= 0 || summary.owed <= 0
        ? [TextSpan(text: text)]
        : [
            TextSpan(text: text.substring(0, split)),
            TextSpan(
              text: owed,
              style: TextStyle(
                color: AppColors.warning.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: text.substring(split + owed.length)),
          ];

    return AppGlass(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.separator.resolveFrom(context)),
          ),
        ),
        child: SizedBox(
          height: _kSummaryHeight,
          child: Center(
            child: Semantics(
              container: true,
              child: Text.rich(
                TextSpan(style: style, children: spans),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
        minimumSize: const Size.square(AppSizes.minTouchTarget),
        onPressed: onPressed,
        child: Text(
          label,
          style: AppTypography.callout.copyWith(
            color: AppColors.accentText.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

/// "…" in a glass circle (opaque fallback with Reduce Transparency).
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.more,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('financialMore'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: AppSizes.minTouchTarget,
          child: Center(
            child: AppGlass(
              tint: AppColors.secondaryFill,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(
                  CupertinoIcons.ellipsis,
                  size: 20,
                  color: AppColors.accentText.resolveFrom(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
