import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/nfse/nfse_invoice_screen.dart';
import 'package:praticos/screens/nfse/nfse_setup_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/period_stepper.dart';
import 'package:praticos/screens/widgets/picker_screen.dart'
    show AppSearchField;
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// From this many notas the list shows the search field.
const kNfseSearchThreshold = 10;

/// The notas of a month: of the company, or of one customer when
/// [customerId] is set. One sentence with what came out, then what needs
/// attention, then the notas. Opens from the Financeiro tab and the customer.
class NfseListScreen extends StatefulWidget {
  const NfseListScreen({
    super.key,
    this.month,
    this.customerId,
    this.customerName,
    this.nfse,
    this.canSetUp,
    this.today,
  });

  /// Month to open; defaults to this month, or the latest with a nota of
  /// the customer.
  final DateTime? month;
  final String? customerId;
  final String? customerName;

  /// Test seam; defaults to a new [NfseController].
  final NfseController? nfse;

  /// Who sees "Configurar"; defaults to "manages the company".
  final bool? canSetUp;

  /// Test seam; defaults to now.
  final DateTime? today;

  static Future<void> open(
    BuildContext context, {
    DateTime? month,
    String? customerId,
    String? customerName,
  }) => Navigator.of(context, rootNavigator: true).push<void>(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: '/nfse_list'),
      builder: (_) => NfseListScreen(
        month: month,
        customerId: customerId,
        customerName: customerName,
      ),
    ),
  );

  @override
  State<NfseListScreen> createState() => _NfseListScreenState();
}

class _NfseListScreenState extends State<NfseListScreen> {
  late final NfseController _nfse = widget.nfse ?? NfseController();
  final _format = FormatService();
  late final DateTime _today = widget.today ?? DateTime.now();
  late DateTime _month = widget.month == null
      ? DateTime(_today.year, _today.month)
      : DateTime(widget.month!.year, widget.month!.month);
  late bool _pickMonth = widget.customerId != null && widget.month == null;
  String _query = '';

  bool get _ofCustomer => widget.customerId != null;

  bool get _canSetUp =>
      !_ofCustomer &&
      (widget.canSetUp ?? AuthorizationService.instance.canManageCompany);

  @override
  void initState() {
    super.initState();
    _nfse.addListener(_onNfse);
    _watch();
  }

  @override
  void dispose() {
    _nfse.removeListener(_onNfse);
    if (widget.nfse == null) _nfse.dispose();
    super.dispose();
  }

  void _watch() {
    if (_ofCustomer) {
      _nfse.watchCustomer(widget.customerId);
    } else {
      _nfse.watchMonth(_month);
    }
  }

  void _onNfse() {
    if (!mounted) return;
    setState(() {
      if (_pickMonth && _nfse.loaded) {
        _pickMonth = false;
        final latest = _latestMonth;
        if (latest != null) _month = latest;
      }
    });
  }

  /// Month of the newest nota read.
  DateTime? get _latestMonth {
    DateTime? latest;
    for (final invoice in _nfse.invoices) {
      final day = invoice.effectiveDay;
      if (day == null) continue;
      final month = DateTime(day.year, day.month);
      if (latest == null || month.isAfter(latest)) latest = month;
    }
    return latest;
  }

  /// A nota can be scheduled for a later month: the stepper reaches it.
  bool get _hasNext {
    final current = DateTime(_today.year, _today.month);
    final latest = _latestMonth;
    final last = latest != null && latest.isAfter(current) ? latest : current;
    return _month.isBefore(last);
  }

  void _step(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
      _query = '';
    });
    _watch();
  }

  Future<void> _showMenu() async {
    final l10n = context.l10n;
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'setup',
            label: l10n.nfseListSetup,
            icon: CupertinoIcons.gear,
          ),
        ]),
      ],
    );
    if (picked != 'setup' || !mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => NfseSetupScreen(sandbox: _nfse.sandbox),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _ofCustomer
        ? l10n.nfseListCustomerTitle(widget.customerName ?? '')
        : l10n.nfseListTitle;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: AppNavBar.barBackground(context),
            alwaysShowMiddle: false,
            largeTitle: Text(title),
            border: null,
            trailing: _canSetUp
                ? GlassBarButton(
                    key: const Key('nfseListMenu'),
                    label: l10n.nfseListMenu,
                    icon: CupertinoIcons.ellipsis,
                    onPressed: _showMenu,
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: PeriodStepper(
              label: _format.formatMonthYearTitle(_month),
              previousLabel: l10n.financialPreviousMonth,
              nextLabel: l10n.financialNextMonth,
              onPrevious: () => _step(-1),
              onNext: _hasNext ? () => _step(1) : null,
            ),
          ),
          ..._buildBody(title),
          SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxl + bottomInset),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBody(String title) {
    final l10n = context.l10n;
    if (!_nfse.loaded) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }
    if (_nfse.failed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(onRetry: _nfse.retry),
        ),
      ];
    }
    final monthName = _format.formatMonthYear(_month);
    final list = nfseMonthList(_nfse.invoices, _month, now: _today);
    if (list.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: l10n.nfseListEmpty(monthName),
            message: l10n.nfseListEmptyHint,
          ),
        ),
      ];
    }

    final count = list.attention.length + list.rows.length;
    final attention = list.attention
        .where((invoice) => nfseMatches(invoice, _query))
        .toList();
    final rows = list.rows
        .where((invoice) => nfseMatches(invoice, _query))
        .toList();
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final searching = _query.trim().isNotEmpty;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Text(
            l10n.nfseListSummary(
              list.issuedCount,
              monthName,
              _format.formatBrl(list.issuedTotal),
            ),
            key: const Key('nfseListSummary'),
            style: AppTypography.body.copyWith(
              color: AppColors.text.resolveFrom(context),
            ),
          ),
        ),
      ),
      if (count > kNfseSearchThreshold)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.md,
              AppSpacing.pageMargin,
              0,
            ),
            child: AppSearchField(
              key: const Key('nfseListSearch'),
              placeholder: l10n.nfseListSearch,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
      if (attention.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionLabel(l10n.nfseListAttention)),
        SliverList.list(
          children: [for (final invoice in attention) _row(invoice, title)],
        ),
      ],
      if (rows.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverList.list(
          children: [for (final invoice in rows) _row(invoice, title)],
        ),
      ],
      if (searching && attention.isEmpty && rows.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageMargin),
            child: Text(
              l10n.nfseListNoResults(monthName),
              style: AppTypography.body.copyWith(color: secondary),
            ),
          ),
        ),
      if (!searching)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.lg,
              AppSpacing.pageMargin,
              0,
            ),
            child: Text(
              l10n.nfseListOnlyServices,
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ),
        ),
    ];
  }

  Widget _row(NfseInvoice invoice, String title) {
    final l10n = context.l10n;
    final day = invoice.effectiveDay;
    final numberText = invoice.number == null
        ? null
        : l10n.nfseListNumber(invoice.number!);
    final details = [
      if (numberText != null && !_ofCustomer) numberText,
      if (invoice.orderNumbers.isNotEmpty)
        l10n.nfseListOrders(invoice.orderNumbers),
      if (day != null) _format.formatDayMonth(day),
    ].join(' · ');
    final name = _ofCustomer
        ? numberText ?? l10n.nfseRowTitle
        : invoice.customerName ?? l10n.customerWithoutName;
    final secondary = AppColors.textSecondary.resolveFrom(context);

    return AppListRow(
      key: ValueKey('nfseListRow_${invoice.id}'),
      title: name,
      valueBesideTitle: true,
      trailing: _format.formatBrl(invoice.value),
      subtitle: invoice.status == NfseStatus.authorized && !invoice.conflict
          ? details
          : null,
      subtitleWidget:
          invoice.status == NfseStatus.authorized && !invoice.conflict
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  details,
                  style: AppTypography.callout.copyWith(color: secondary),
                ),
                _Problem(invoice: invoice),
              ],
            ),
      onTap: () =>
          NfseInvoiceScreen.open(context, invoice, previousPageTitle: title),
    );
  }
}

/// The status of a nota, or what went wrong with it in the city's words.
class _Problem extends StatelessWidget {
  const _Problem({required this.invoice});

  final NfseInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reason = invoice.conflict
        ? l10n.nfseConflictNotice
        : invoice.status != NfseStatus.error
        ? null
        : invoice.errorCode == 'CUSTOMER_DATA_REQUIRED'
        // The same long text on many rows is noise: the detail has it whole.
        ? l10n.nfseCustomerDataMissing
        : invoice.errorCode == 'TAX_ID_REQUIRED'
        ? l10n.nfseTaxIdMissing
        : nfseReasonText(l10n, invoice);
    if (reason == null) return NfseStatusLine(invoice: invoice);
    final danger = AppColors.danger.resolveFrom(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
          child: StatusDot(color: danger),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.callout.copyWith(
              color: danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Notas fiscais · 9" of the Financeiro tab: the [month]'s issued notas,
/// never money (a nota has only services, so its total is not the Vendido),
/// with a red line when something needs attention. [wrap] places the row;
/// nothing shows while notas are off for the company or the user.
class NfseMonthRow extends StatefulWidget {
  const NfseMonthRow({
    super.key,
    required this.month,
    required this.wrap,
    this.nfse,
  });

  final DateTime month;
  final Widget Function(Widget row) wrap;

  /// Test seam; defaults to a new [NfseController].
  final NfseController? nfse;

  @override
  State<NfseMonthRow> createState() => _NfseMonthRowState();
}

class _NfseMonthRowState extends State<NfseMonthRow> {
  late final NfseController _nfse = widget.nfse ?? NfseController();

  @override
  void initState() {
    super.initState();
    _nfse.addListener(_onNfse);
    _nfse.watchMonth(widget.month);
  }

  @override
  void didUpdateWidget(NfseMonthRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _nfse.watchMonth(widget.month);
  }

  @override
  void dispose() {
    _nfse.removeListener(_onNfse);
    if (widget.nfse == null) _nfse.dispose();
    super.dispose();
  }

  void _onNfse() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_nfse.enabled) return const SizedBox.shrink();
    final l10n = context.l10n;
    final list = nfseMonthList(_nfse.invoices, widget.month);
    final problems = list.attention.length;
    final danger = AppColors.danger.resolveFrom(context);
    return widget.wrap(
      AppListRow(
        key: const Key('financialNfse'),
        title: l10n.nfseListTitle,
        valueBesideTitle: true,
        horizontalPadding: AppSpacing.lg,
        trailing: _nfse.loaded ? '${list.issuedCount}' : null,
        subtitleWidget: problems == 0
            ? null
            : Row(
                children: [
                  StatusDot(color: danger),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      l10n.nfseListAttentionCount(problems),
                      style: AppTypography.callout.copyWith(
                        color: danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
        onTap: () => NfseListScreen.open(context, month: widget.month),
      ),
    );
  }
}
