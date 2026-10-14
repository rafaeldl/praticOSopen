import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/global.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/period_stepper.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Relatório financeiro (gráficos, ranking de clientes/serviços/produtos e
/// escolha de outro período), aberto a partir da aba Financeiro.
///
/// Quem abre esta tela deve garantir a permissão `viewFinancialReports`
/// (Admin e Gerente): a aba e a rota `/financial_report` a protegem com
/// `ProtectedRoute`.
class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key, this.openCustomPeriod = false});

  /// Abre o seletor de "Outro período" assim que a tela carrega.
  final bool openCustomPeriod;

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  String selectedPeriod = 'mês';
  int _periodOffset = 0;
  bool _isRankingExpanded = false;
  bool _isServicesExpanded = false;
  bool _isProductsExpanded = false;
  bool _isRecentOrdersExpanded = false;
  bool _initialLoadDone = false;

  // Custom period dates
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      final orderStore = Provider.of<OrderStore>(context, listen: false);
      orderStore.setCustomPeriod(selectedPeriod, _periodOffset);
      if (widget.openCustomPeriod) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showCustomPeriodPicker();
        });
      }
    }
  }

  String get periodLabel {
    if (selectedPeriod == 'custom' &&
        _customStartDate != null &&
        _customEndDate != null) {
      return '${FormatService().formatDate(_customStartDate)} - ${FormatService().formatDate(_customEndDate)}';
    }

    DateTime now = DateTime.now();
    DateTime periodDate = now;

    if (_periodOffset != 0) {
      switch (selectedPeriod) {
        case 'hoje':
          periodDate = now.add(Duration(days: _periodOffset));
          break;
        case 'semana':
          periodDate = now.add(Duration(days: 7 * _periodOffset));
          break;
        case 'mês':
          periodDate = DateTime(now.year, now.month + _periodOffset, now.day);
          break;
        case 'ano':
          periodDate = DateTime(now.year + _periodOffset, now.month, now.day);
          break;
      }
    }

    final DateFormat monthFormat = DateFormat('MMMM/yy', 'pt_BR');
    final DateFormat dayFormat = DateFormat('dd MMM', 'pt_BR');
    final DateFormat yearFormat = DateFormat('yyyy', 'pt_BR');

    switch (selectedPeriod) {
      case 'hoje':
        return _periodOffset != 0 ? dayFormat.format(periodDate) : context.l10n.today;
      case 'semana':
        DateTime startOfWeek =
            periodDate.subtract(Duration(days: periodDate.weekday));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        return "${dayFormat.format(startOfWeek)} - ${dayFormat.format(endOfWeek)}";
      case 'mês':
        return _periodOffset != 0 ? monthFormat.format(periodDate) : context.l10n.currentMonth;
      case 'ano':
        return _periodOffset != 0 ? yearFormat.format(periodDate) : context.l10n.currentYear;
      default:
        return selectedPeriod;
    }
  }

  /// Period label shown on screen (locale aware). The PDF keeps using
  /// [periodLabel].
  String get _displayPeriodLabel {
    final format = FormatService();
    if (selectedPeriod == 'custom' &&
        _customStartDate != null &&
        _customEndDate != null) {
      return '${format.formatDate(_customStartDate)} - ${format.formatDate(_customEndDate)}';
    }

    final now = DateTime.now();
    switch (selectedPeriod) {
      case 'hoje':
        if (_periodOffset == 0) return context.l10n.today;
        return format.formatDate(now.add(Duration(days: _periodOffset)));
      case 'semana':
        final date = now.add(Duration(days: 7 * _periodOffset));
        final start = date.subtract(Duration(days: date.weekday % 7));
        final end = start.add(const Duration(days: 6));
        return '${format.formatDayMonth(start)} - ${format.formatDayMonth(end)}';
      case 'mês':
        if (_periodOffset == 0) return context.l10n.currentMonth;
        return format.formatMonthYearTitle(
            DateTime(now.year, now.month + _periodOffset, 1));
      case 'ano':
        if (_periodOffset == 0) return context.l10n.currentYear;
        return '${now.year + _periodOffset}';
      default:
        return selectedPeriod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderStore = Provider.of<OrderStore>(context);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Stack(
        children: [
      CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: AppNavBar.barBackground(context),
            alwaysShowMiddle: false,
            largeTitle: Text(context.l10n.financialReport),
            border: null,
            trailing: GlassBarButton(
              key: const Key('reportMore'),
              label: context.l10n.more,
              icon: CupertinoIcons.ellipsis,
              onPressed: _showPeriodMenu,
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () => orderStore.loadOrdersForDashboard(),
          ),
          SliverToBoxAdapter(child: _buildPeriodSelector()),
          Observer(builder: (_) => _buildBody(orderStore)),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSizes.primaryButtonHeight + 64),
          ),
        ],
      ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SendPdfBar(onPressed: () => _shareReport(orderStore)),
          ),
        ],
      ),
    );
  }

  /// Everything below the period selector, as one sliver list. Sections with
  /// no data are left out; a period with no orders shows a single sentence.
  Widget _buildBody(OrderStore orderStore) {
    if (orderStore.recentOrders.isEmpty && orderStore.customerRanking.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl),
          child: EmptyState(
            icon: CupertinoIcons.doc_text,
            title: context.l10n.noOrdersInPeriod,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSummary(orderStore),
        _buildComposition(orderStore),
        _buildCustomerRanking(orderStore),
        _buildItemRanking(
          title: context.l10n.services,
          ranking: _calculateServicesRanking(orderStore),
          expanded: _isServicesExpanded,
          onToggle: () =>
              setState(() => _isServicesExpanded = !_isServicesExpanded),
        ),
        _buildItemRanking(
          title: context.l10n.products,
          ranking: _calculateProductsRanking(orderStore),
          expanded: _isProductsExpanded,
          onToggle: () =>
              setState(() => _isProductsExpanded = !_isProductsExpanded),
        ),
        _buildRecentOrders(orderStore),
      ]),
    );
  }

  // ============================================================
  // PERIOD SELECTOR
  // ============================================================

  /// Only the period stepper (or the chosen dates). Other periods come from
  /// the "…" menu.
  Widget _buildPeriodSelector() {
    final isCustom = selectedPeriod == 'custom';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.blockMargin, AppSpacing.sm, AppSpacing.blockMargin, 0),
      child: isCustom
          ? AppListRow(
              leading: Icon(
                CupertinoIcons.calendar,
                size: 22,
                color: AppColors.accentText.resolveFrom(context),
              ),
              title: _displayPeriodLabel,
              onTap: _showCustomPeriodPicker,
            )
          : PeriodStepper(
              label: _displayPeriodLabel,
              previousLabel: context.l10n.reportPreviousPeriod,
              nextLabel: context.l10n.reportNextPeriod,
              onPrevious: () {
                setState(() => _periodOffset--);
                _updateDashboardPeriod();
              },
              onNext: _periodOffset < 0
                  ? () {
                      setState(() => _periodOffset++);
                      _updateDashboardPeriod();
                    }
                  : null,
              onTapLabel: _periodOffset != 0
                  ? () {
                      setState(() => _periodOffset = 0);
                      final orderStore =
                          Provider.of<OrderStore>(context, listen: false);
                      orderStore.setPaymentFilter(null);
                      orderStore.clearCustomerRankingSelection();
                      _updateDashboardPeriod();
                    }
                  : null,
            ),
    );
  }

  /// "…": "Ver outro período" (today, this week, month, year, dates).
  Future<void> _showPeriodMenu() async {
    final l10n = context.l10n;
    final picked = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup(title: l10n.reportSeeOtherPeriod, [
          PullDownItem(
            value: 'hoje',
            label: l10n.today,
            icon: CupertinoIcons.sun_max,
          ),
          PullDownItem(
            value: 'semana',
            label: l10n.reportThisWeek,
            icon: CupertinoIcons.calendar_today,
          ),
          PullDownItem(
            value: 'mês',
            label: l10n.reportThisMonth,
            icon: CupertinoIcons.calendar,
          ),
          PullDownItem(
            value: 'ano',
            label: l10n.reportThisYear,
            icon: CupertinoIcons.calendar_circle,
          ),
        ]),
        PullDownGroup([
          PullDownItem(
            value: 'custom',
            label: l10n.reportPickDates,
            icon: CupertinoIcons.calendar_badge_plus,
          ),
        ]),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked == 'custom') {
      _showCustomPeriodPicker();
      return;
    }
    setState(() {
      selectedPeriod = picked;
      _periodOffset = 0;
      _customStartDate = null;
      _customEndDate = null;
    });
    _updateDashboardPeriod();
  }

  /// "Outro período": start and end dates in a sheet.
  Future<void> _showCustomPeriodPicker() async {
    final range = await FormSheet.show<({DateTime start, DateTime end})>(
      context,
      (_) => _CustomPeriodSheet(
        start: _customStartDate ??
            DateTime.now().subtract(const Duration(days: 30)),
        end: _customEndDate ?? DateTime.now(),
      ),
    );
    if (range == null || !mounted) return;
    setState(() {
      selectedPeriod = 'custom';
      _customStartDate = range.start;
      _customEndDate = range.end;
      _periodOffset = 0;
    });
    _updateDashboardPeriodCustom(range.start, range.end);
  }

  // ============================================================
  // SUMMARY (billing, paid vs to receive)
  // ============================================================

  Widget _buildSummary(OrderStore orderStore) {
    final totalOrders = orderStore.recentOrders.length;
    final paidOrders =
        orderStore.recentOrders.where((o) => o?.payment == 'paid').length;
    final unpaidOrders = totalOrders - paidOrders;
    final avgTicket =
        totalOrders > 0 ? orderStore.totalRevenue / totalOrders : 0.0;

    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final segConfig = context.read<SegmentConfigProvider>();
    // Segment labels fall back to the i18n text when the key is not set.
    String segmentLabel(String key, String fallback) {
      final value = segConfig.label(key);
      return value.isEmpty || value == key ? fallback : value;
    }

    final paidLabel =
        segmentLabel('financial.total_paid', context.l10n.received);
    final remainingLabel =
        segmentLabel('financial.remaining', context.l10n.toReceive);

    final paidAmount = orderStore.totalPaidAmount;
    final unpaidAmount = orderStore.totalUnpaidAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(context.l10n.billing),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _convertToCurrency(orderStore.totalRevenue),
                style: AppTypography.title.copyWith(
                  color: text,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${context.l10n.nOrdersCount(totalOrders)} · '
                '${context.l10n.averageTicket} ${_convertToCurrency(avgTicket)}',
                style: AppTypography.label.copyWith(color: secondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _StackedBar(
                semanticsLabel:
                    '${context.l10n.received} ${_convertToCurrency(paidAmount)}, '
                    '${context.l10n.toReceive} ${_convertToCurrency(unpaidAmount)}',
                segments: [
                  _BarSegment(
                      paidAmount, AppColors.success.resolveFrom(context)),
                  _BarSegment(
                      unpaidAmount, AppColors.warning.resolveFrom(context)),
                ],
                emptyColor: AppColors.secondaryFill.resolveFrom(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LegendRow(
          color: AppColors.success,
          label: paidLabel,
          value: _convertToCurrency(paidAmount),
          count: context.l10n.nOrdersCount(paidOrders),
          selected: orderStore.paymentFilter == 'paid',
          onTap: () => _togglePaymentFilter(orderStore, 'paid'),
        ),
        _LegendRow(
          color: AppColors.warning,
          label: remainingLabel,
          value: _convertToCurrency(unpaidAmount),
          count: context.l10n.nOrdersCount(unpaidOrders),
          selected: orderStore.paymentFilter == 'unpaid',
          onTap: () => _togglePaymentFilter(orderStore, 'unpaid'),
        ),
      ],
    );
  }

  void _togglePaymentFilter(OrderStore orderStore, String filter) {
    if (orderStore.paymentFilter == filter) {
      orderStore.setPaymentFilter(null);
    } else {
      orderStore.setPaymentFilter(filter);
    }
  }

  // ============================================================
  // COMPOSITION (services vs products)
  // ============================================================

  Widget _buildComposition(OrderStore orderStore) {
    final totalServices = _calculateServicesRanking(orderStore)
        .fold<double>(0, (sum, item) => sum + (item['total'] as double));
    final totalProducts = _calculateProductsRanking(orderStore)
        .fold<double>(0, (sum, item) => sum + (item['total'] as double));
    if (totalServices + totalProducts == 0) return const SizedBox.shrink();

    final servicesColor = AppColors.accent.resolveFrom(context);
    final productsColor = AppColors.textSecondary.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(context.l10n.composition),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
          child: _StackedBar(
            semanticsLabel:
                '${context.l10n.services} ${_convertToCurrency(totalServices)}, '
                '${context.l10n.products} ${_convertToCurrency(totalProducts)}',
            segments: [
              _BarSegment(totalServices, servicesColor),
              _BarSegment(totalProducts, productsColor),
            ],
            emptyColor: AppColors.secondaryFill.resolveFrom(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LegendRow(
          color: AppColors.accent,
          label: context.l10n.services,
          value: _convertToCurrency(totalServices),
        ),
        _LegendRow(
          color: AppColors.textSecondary,
          label: context.l10n.products,
          value: _convertToCurrency(totalProducts),
        ),
      ],
    );
  }

  // ============================================================
  // RANKINGS
  // ============================================================

  /// Section header: label on the left, total on the right.
  Widget _sectionHeader(String title, String total) {
    return Row(
      children: [
        Expanded(child: SectionLabel(title)),
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xl,
            right: AppSpacing.pageMargin,
          ),
          child: Text(
            total,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ),
      ],
    );
  }

  Widget _seeAllLink({
    required int total,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
        child: TextLink(
          label: expanded
              ? context.l10n.seeLess
              : context.l10n.seeAllCount(total),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildCustomerRanking(OrderStore orderStore) {
    if (orderStore.customerRanking.isEmpty) return const SizedBox.shrink();

    final filteredRanking = _filterRankingByPayment(orderStore);
    final itemCount = _isRankingExpanded
        ? filteredRanking.length
        : (filteredRanking.length > 5 ? 5 : filteredRanking.length);

    final sectionTitle = orderStore.paymentFilter == 'paid'
        ? context.l10n.customersReceived
        : orderStore.paymentFilter == 'unpaid'
            ? context.l10n.customersToReceive
            : context.l10n.customers;

    final totalValue = filteredRanking.fold<double>(
        0, (sum, customer) => sum + _customerDisplayValue(orderStore, customer));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(sectionTitle, _convertToCurrency(totalValue)),
        for (int i = 0; i < itemCount; i++)
          _buildCustomerRow(filteredRanking[i], orderStore),
        if (filteredRanking.length > 5)
          _seeAllLink(
            total: filteredRanking.length,
            expanded: _isRankingExpanded,
            onToggle: () =>
                setState(() => _isRankingExpanded = !_isRankingExpanded),
          ),
      ],
    );
  }

  double _customerDisplayValue(
      OrderStore orderStore, Map<String, dynamic> customer) {
    final double total = customer['total'] ?? 0.0;
    final double unpaid = customer['unpaidTotal'] ?? 0.0;
    return orderStore.paymentFilter == 'paid'
        ? total - unpaid
        : orderStore.paymentFilter == 'unpaid'
            ? unpaid
            : total;
  }

  List<Map<String, dynamic>> _filterRankingByPayment(OrderStore orderStore) {
    var filteredRanking =
        List<Map<String, dynamic>>.from(orderStore.customerRanking);

    if (orderStore.paymentFilter != null) {
      double paidOf(Map<String, dynamic> c) =>
          ((c['total'] ?? 0.0) as double) - ((c['unpaidTotal'] ?? 0.0) as double);
      double unpaidOf(Map<String, dynamic> c) =>
          (c['unpaidTotal'] ?? 0.0) as double;

      final isPaid = orderStore.paymentFilter == 'paid';
      filteredRanking = filteredRanking
          .where((c) => isPaid ? paidOf(c) > 0 : unpaidOf(c) > 0)
          .toList();
      filteredRanking.sort((a, b) => isPaid
          ? paidOf(b).compareTo(paidOf(a))
          : unpaidOf(b).compareTo(unpaidOf(a)));
    }

    return filteredRanking;
  }

  Widget _buildCustomerRow(
      Map<String, dynamic> customer, OrderStore orderStore) {
    final isSelected =
        orderStore.selectedCustomerInRanking?['id'] == customer['id'];
    final double unpaidAmount = customer['unpaidTotal'] ?? 0.0;

    final row = AppListRow(
      title: customer['name'] ?? context.l10n.customerWithoutName,
      titleStyle: AppTypography.bodyStrong,
      valueBesideTitle: true,
      subtitle: unpaidAmount > 0 && orderStore.paymentFilter == null
          ? '${context.l10n.toReceive}: ${_convertToCurrency(unpaidAmount)}'
          : null,
      trailing: _convertToCurrency(_customerDisplayValue(orderStore, customer)),
      leading: isSelected
          ? Icon(
              CupertinoIcons.checkmark_alt,
              size: 20,
              color: AppColors.accentText.resolveFrom(context),
            )
          : null,
      showChevron: false,
      onTap: () {
        if (isSelected) {
          orderStore.clearCustomerRankingSelection();
        } else {
          orderStore.selectCustomerInRanking(customer);
        }
      },
    );

    return Semantics(
      selected: isSelected,
      child: ColoredBox(
        color: isSelected
            ? AppColors.secondaryFill.resolveFrom(context)
            : const Color(0x00000000),
        child: row,
      ),
    );
  }

  List<Map<String, dynamic>> _calculateServicesRanking(OrderStore orderStore) {
    final Map<String, Map<String, dynamic>> servicesMap = {};

    for (final order in orderStore.recentOrders) {
      if (order?.services != null) {
        for (final service in order!.services!) {
          final name = service.service?.name ??
              service.description ??
              context.l10n.serviceWithoutName;
          final value = service.value ?? 0.0;

          if (servicesMap.containsKey(name)) {
            servicesMap[name]!['total'] =
                (servicesMap[name]!['total'] as double) + value;
            servicesMap[name]!['quantity'] =
                (servicesMap[name]!['quantity'] as int) + 1;
          } else {
            servicesMap[name] = {
              'name': name,
              'total': value,
              'quantity': 1,
            };
          }
        }
      }
    }

    final ranking = servicesMap.values.toList();
    ranking.sort(
        (a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return ranking;
  }

  List<Map<String, dynamic>> _calculateProductsRanking(OrderStore orderStore) {
    final Map<String, Map<String, dynamic>> productsMap = {};

    for (final order in orderStore.recentOrders) {
      if (order?.products != null) {
        for (final product in order!.products!) {
          final name = product.product?.name ??
              product.description ??
              context.l10n.productWithoutName;
          final total =
              product.total ?? (product.value ?? 0.0) * (product.quantity ?? 1);
          final quantity = product.quantity ?? 1;

          if (productsMap.containsKey(name)) {
            productsMap[name]!['total'] =
                (productsMap[name]!['total'] as double) + total;
            productsMap[name]!['quantity'] =
                (productsMap[name]!['quantity'] as int) + quantity;
          } else {
            productsMap[name] = {
              'name': name,
              'total': total,
              'quantity': quantity,
            };
          }
        }
      }
    }

    final ranking = productsMap.values.toList();
    ranking.sort(
        (a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return ranking;
  }

  /// Ranking of services or products. Left out when empty.
  Widget _buildItemRanking({
    required String title,
    required List<Map<String, dynamic>> ranking,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    if (ranking.isEmpty) return const SizedBox.shrink();

    final itemCount =
        expanded ? ranking.length : (ranking.length > 5 ? 5 : ranking.length);
    final total = ranking.fold<double>(
        0, (sum, item) => sum + (item['total'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, _convertToCurrency(total)),
        for (int i = 0; i < itemCount; i++)
          AppListRow(
            title: ranking[i]['name'] as String,
            titleStyle: AppTypography.bodyStrong,
            valueBesideTitle: true,
            subtitle: context.l10n.nItemsCount(ranking[i]['quantity'] as int),
            trailing: _convertToCurrency(ranking[i]['total'] as double),
          ),
        if (ranking.length > 5)
          _seeAllLink(
              total: ranking.length, expanded: expanded, onToggle: onToggle),
      ],
    );
  }

  // ============================================================
  // RECENT ORDERS
  // ============================================================

  Widget _buildRecentOrders(OrderStore orderStore) {
    final sectionTitle = orderStore.paymentFilter == 'paid'
        ? context.l10n.paidOrders
        : orderStore.paymentFilter == 'unpaid'
            ? context.l10n.ordersToReceive
            : context.l10n.recentOrders;

    final filteredOrders = orderStore.paymentFilter == null
        ? orderStore.recentOrders
        : orderStore.recentOrders
            .where((order) => order?.payment == orderStore.paymentFilter)
            .toList();

    if (filteredOrders.isEmpty) return const SizedBox.shrink();

    final itemCount = _isRecentOrdersExpanded
        ? filteredOrders.length
        : (filteredOrders.length > 5 ? 5 : filteredOrders.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
            sectionTitle, context.l10n.nOrdersCount(filteredOrders.length)),
        for (int i = 0; i < itemCount; i++)
          _buildOrderRow(filteredOrders[i]),
        if (filteredOrders.length > 5)
          _seeAllLink(
            total: filteredOrders.length,
            expanded: _isRecentOrdersExpanded,
            onToggle: () => setState(
                () => _isRecentOrdersExpanded = !_isRecentOrdersExpanded),
          ),
      ],
    );
  }

  Widget _buildOrderRow(dynamic order) {
    final dateStr = order?.createdAt != null
        ? FormatService().formatDate(order!.createdAt!)
        : '';
    final isPaid = order?.payment == 'paid';
    final status = isPaid ? context.l10n.paid : context.l10n.pendingPayment;

    return AppListRow(
      leading: StatusDot(
        color: isPaid ? AppColors.success : AppColors.warning,
        size: 10,
      ),
      title: order?.customer?.name ?? context.l10n.customer,
      titleStyle: AppTypography.bodyStrong,
      valueBesideTitle: true,
      subtitle: [
        '${context.l10n.orderShort} ${order?.number}',
        if (dateStr.isNotEmpty) dateStr,
        status,
      ].join(' · '),
      trailing: _convertToCurrency(order?.total),
      onTap: () => Navigator.pushNamed(
        context,
        '/order',
        arguments: {'order': order},
      ),
    );
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  void _updateDashboardPeriod() {
    final orderStore = Provider.of<OrderStore>(context, listen: false);
    orderStore.setCustomPeriod(selectedPeriod, _periodOffset);
  }

  void _updateDashboardPeriodCustom(DateTime start, DateTime end) {
    final orderStore = Provider.of<OrderStore>(context, listen: false);
    orderStore.setCustomDateRange(start, end);
  }

  String _convertToCurrency(double? total) {
    return FormatService().formatCurrency(total ?? 0.0);
  }

  // ============================================================
  // PDF REPORT GENERATION
  // ============================================================

  void _shareReport(OrderStore orderStore) {
    _proceedWithShare(orderStore);
  }

  Future<void> _proceedWithShare(OrderStore orderStore) async {
    final currentContext = context;

    showCupertinoDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: 16),
            Text(
              currentContext.l10n.preparingReport,
              style: AppTypography.body.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final pdf = await _buildPdf(orderStore);

      if (currentContext.mounted) {
        Navigator.of(currentContext).pop();
      }

      if (currentContext.mounted) {
        final reportName = _latinCharactersOnly(currentContext.l10n.financialReport).replaceAll(' ', '_');
        await Printing.sharePdf(
          bytes: pdf,
          filename: '${reportName}_${periodLabel.replaceAll('/', '-').replaceAll(' ', '_')}.pdf',
        );
      }
    } catch (e) {
      if (currentContext.mounted) {
        Navigator.of(currentContext).pop();

        showCupertinoDialog(
          context: currentContext,
          builder: (context) => CupertinoAlertDialog(
            title: Text(currentContext.l10n.error),
            content: Text(currentContext.l10n.errorGeneratingReport),
            actions: [
              CupertinoDialogAction(
                child: Text(currentContext.l10n.ok),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  String _getVehicleInfo(dynamic order, {String? notInformedText}) {
    final notInformed = notInformedText ?? context.l10n.notInformed;
    if (order == null || order.device == null) return notInformed;

    String vehicleInfo = notInformed;
    var device = order.device;

    try {
      String? modelo = device?.name?.toString() ?? '';
      String? placa = device?.serial?.toString() ?? '';

      if (modelo.isNotEmpty || placa.isNotEmpty) {
        if (modelo.isNotEmpty && placa.isNotEmpty) {
          vehicleInfo = '$modelo, $placa';
        } else if (modelo.isNotEmpty) {
          vehicleInfo = modelo;
        } else if (placa.isNotEmpty) {
          vehicleInfo = placa;
        }
      }
    } catch (error) {
      try {
        if (device is Map) {
          var deviceMap = device;
          String? modelo = deviceMap['name']?.toString() ?? '';
          String? placa = deviceMap['serial']?.toString() ?? '';

          if (modelo.isNotEmpty || placa.isNotEmpty) {
            if (modelo.isNotEmpty && placa.isNotEmpty) {
              vehicleInfo = '$modelo, $placa';
            } else if (modelo.isNotEmpty) {
              vehicleInfo = modelo;
            } else if (placa.isNotEmpty) {
              vehicleInfo = placa;
            }
          }
        }
      } catch (_) {
        vehicleInfo = device?.toString() ?? notInformed;
      }
    }

    return _latinCharactersOnly(vehicleInfo);
  }

  Future<Uint8List> _buildPdf(OrderStore orderStore) async {
    final pdf = pw.Document();
    final bool isClientSelected = orderStore.selectedCustomerInRanking != null;

    // Capture l10n strings before entering PDF builder context
    final l10n = context.l10n;
    final l10nFinancialReport = _latinCharactersOnly(l10n.financialReport.toUpperCase());
    final l10nFinancialSummary = _latinCharactersOnly(l10n.financialSummary);
    final l10nTotalBilling = _latinCharactersOnly(l10n.totalBilling);
    final l10nReceived = _latinCharactersOnly(l10n.received);
    final l10nToReceive = _latinCharactersOnly(l10n.toReceive);
    final l10nAverageTicket = _latinCharactersOnly(l10n.averageTicket);
    final l10nCustomerRanking = _latinCharactersOnly(l10n.customerRanking);
    final l10nServiceRanking = _latinCharactersOnly(l10n.serviceRanking);
    final l10nProductRanking = _latinCharactersOnly(l10n.productRanking);
    final l10nCustomer = _latinCharactersOnly(l10n.customer);
    final l10nTotal = _latinCharactersOnly(l10n.total);
    final l10nService = _latinCharactersOnly(l10n.service);
    final l10nProduct = _latinCharactersOnly(l10n.product);
    final l10nQuantityShort = _latinCharactersOnly(l10n.quantityShort);
    final l10nValueColumn = _latinCharactersOnly(l10n.valueColumn);
    final l10nOrders = _latinCharactersOnly(l10n.orders);
    final l10nOrderShort = _latinCharactersOnly(l10n.orderShort);
    final l10nDate = _latinCharactersOnly(l10n.date);
    final l10nVehicle = _latinCharactersOnly(l10n.vehicle);
    final l10nStatusColumn = _latinCharactersOnly(l10n.statusColumn);
    final l10nPaid = _latinCharactersOnly(l10n.paid);
    final l10nPendingPayment = _latinCharactersOnly(l10n.pendingPayment);
    final l10nCompany = _latinCharactersOnly(l10n.company);
    final l10nNotInformed = _latinCharactersOnly(l10n.notInformed);
    final l10nOrderSingular = _latinCharactersOnly(l10n.orderSingular);
    final l10nOrderPlural = _latinCharactersOnly(l10n.orderPlural);
    final l10nAppTagline = _latinCharactersOnly(l10n.appTagline);
    final l10nGeneratedAt = _latinCharactersOnly(l10n.generatedAt(FormatService().formatDateTime(DateTime.now())));
    // Capture pageOf format function to use in PDF footer
    String formatPageOf(int current, int total) => _latinCharactersOnly(l10n.pageOf(current, total));
    // Capture receivedWithPercent format function
    String formatReceivedWithPercent(String percent) => _latinCharactersOnly(l10n.receivedWithPercent(percent));
    // Capture toReceiveWithPercent format function
    String formatToReceiveWithPercent(String percent) => _latinCharactersOnly(l10n.toReceiveWithPercent(percent));

    // Map for passing to _buildPdfOrdersTable
    final l10nStrings = {
      'orders': l10nOrders,
      'orderShort': l10nOrderShort,
      'date': l10nDate,
      'vehicle': l10nVehicle,
      'value': l10nValueColumn,
      'status': l10nStatusColumn,
      'customer': l10nCustomer,
      'paid': l10nPaid,
      'pending': l10nPendingPayment,
      'total': l10nTotal,
      'notInformed': l10nNotInformed,
      'orderSingular': l10nOrderSingular,
      'orderPlural': l10nOrderPlural,
    };

    final selectedClientName = isClientSelected
        ? orderStore.selectedCustomerInRanking!['name'] ?? l10nCustomer
        : '';

    // Fetch full company data for logo and contact info
    Company? company;
    pw.MemoryImage? logoImage;

    try {
      if (Global.companyAggr?.id != null) {
        final companyStore = CompanyStore();
        company = await companyStore.retrieveCompany(Global.companyAggr!.id);

        // Download logo if available
        if (company?.logo != null && company!.logo!.isNotEmpty) {
          try {
            final response = await http.get(Uri.parse(company.logo!));
            if (response.statusCode == 200) {
              logoImage = pw.MemoryImage(response.bodyBytes);
            }
          } catch (_) {
            // Ignore logo loading errors
          }
        }
      }
    } catch (_) {
      // Ignore company loading errors
    }

    // Paleta de cores profissional
    const primaryColor = PdfColors.blueGrey800;
    const accentColor = PdfColors.blueGrey700;
    const successColor = PdfColors.green700;
    const warningColor = PdfColors.orange700;
    const textColor = PdfColors.grey800;
    const lightGrey = PdfColors.grey200;

    // Use fonts with Unicode support for Portuguese characters
    pw.Font baseFont;
    pw.Font boldFont;
    try {
      baseFont = await PdfGoogleFonts.nunitoSansRegular();
      boldFont = await PdfGoogleFonts.nunitoSansBold();
    } catch (e) {
      // Fallback to Helvetica if Google Fonts fail to load
      baseFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    final totalValue = orderStore.totalRevenue;
    final totalOrders = orderStore.recentOrders.length;
    final totalCustomers = orderStore.customerRanking.length;
    final avgTicket = totalOrders > 0 ? totalValue / totalOrders : 0.0;

    final paidPercentage = totalValue > 0
        ? (orderStore.totalPaidAmount / totalValue * 100).toStringAsFixed(1)
        : "0";
    final unpaidPercentage = totalValue > 0
        ? (orderStore.totalUnpaidAmount / totalValue * 100).toStringAsFixed(1)
        : "0";

    final servicesRanking = _calculateServicesRanking(orderStore);
    final productsRanking = _calculateProductsRanking(orderStore);

    // Build company contact info string
    List<String> contactParts = [];
    if (company?.phone != null && company!.phone!.isNotEmpty) {
      contactParts.add(_latinCharactersOnly(company.phone!));
    }
    if (company?.email != null && company!.email!.isNotEmpty) {
      contactParts.add(_latinCharactersOnly(company.email!));
    }
    final contactInfo = contactParts.join(' | ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: lightGrey, width: 1),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Logo
                if (logoImage != null)
                  pw.Container(
                    width: 50,
                    height: 50,
                    margin: const pw.EdgeInsets.only(right: 16),
                    child: pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ),
                // Company info
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _latinCharactersOnly(
                            company?.name ?? Global.companyAggr?.name ?? l10nCompany),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 16,
                          color: primaryColor,
                        ),
                      ),
                      if (contactInfo.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          contactInfo,
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                      if (company?.address != null && company!.address!.isNotEmpty) ...[
                        pw.SizedBox(height: 1),
                        pw.Text(
                          _latinCharactersOnly(company.address!),
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Report info
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        l10nFinancialReport,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 8,
                          color: PdfColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _latinCharactersOnly(periodLabel),
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 11,
                        color: accentColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      l10nGeneratedAt,
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: lightGrey, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PraticOS - $l10nAppTagline',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfColors.grey400,
                  ),
                ),
                pw.Text(
                  formatPageOf(context.pageNumber, context.pagesCount),
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfColors.grey400,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          List<pw.Widget> content = [];

          if (isClientSelected) {
            final selectedClientData = orderStore.selectedCustomerInRanking!;
            final double clientTotal = selectedClientData['total'] ?? 0.0;
            final double clientUnpaidTotal =
                selectedClientData['unpaidTotal'] ?? 0.0;
            final double clientPaidTotal = clientTotal - clientUnpaidTotal;

            var clientOrders = orderStore.recentOrders
                .where((order) =>
                    order?.customer?.id == selectedClientData['id'])
                .toList();

            if (orderStore.paymentFilter != null) {
              clientOrders = clientOrders
                  .where(
                      (order) => order?.payment == orderStore.paymentFilter)
                  .toList();
            }

            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            '$l10nCustomer: ',
                            style:
                                pw.TextStyle(font: baseFont, color: textColor),
                          ),
                          pw.Text(
                            _latinCharactersOnly(selectedClientName),
                            style: pw.TextStyle(
                                font: boldFont,
                                color: accentColor,
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            l10nTotalBilling,
                            _convertToCurrency(clientTotal),
                            primaryColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            l10nReceived,
                            _convertToCurrency(clientPaidTotal),
                            successColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            l10nToReceive,
                            _convertToCurrency(clientUnpaidTotal),
                            warningColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            if (clientOrders.isNotEmpty) {
              content.add(_buildPdfOrdersTable(
                  clientOrders, boldFont, baseFont, textColor, accentColor, true, l10nStrings));
            }
          } else {
            // Summary header with stats
            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          l10nFinancialSummary,
                          style: pw.TextStyle(
                              font: boldFont, fontSize: 16, color: accentColor),
                        ),
                        pw.Row(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                '$totalOrders ordens',
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 9,
                                  color: textColor,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                '$totalCustomers clientes',
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 9,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    // First row: Main KPIs
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: _buildPdfKpiBoxLarge(
                            l10nTotalBilling,
                            _convertToCurrency(orderStore.totalRevenue),
                            primaryColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            l10nAverageTicket,
                            _convertToCurrency(avgTicket),
                            PdfColors.blueGrey600,
                            boldFont,
                            baseFont,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    // Second row: Payment status
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            formatReceivedWithPercent(paidPercentage),
                            _convertToCurrency(orderStore.totalPaidAmount),
                            successColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            formatToReceiveWithPercent(unpaidPercentage),
                            _convertToCurrency(orderStore.totalUnpaidAmount),
                            warningColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            if (orderStore.customerRanking.isNotEmpty) {
              var filteredRanking = List.from(orderStore.customerRanking);

              // Calculate totals for customers
              double totalCustomerPaid = 0;
              double totalCustomerUnpaid = 0;
              double totalCustomerAmount = 0;
              for (var customer in filteredRanking) {
                final double t = customer['total'] ?? 0.0;
                final double u = customer['unpaidTotal'] ?? 0.0;
                totalCustomerAmount += t;
                totalCustomerUnpaid += u;
                totalCustomerPaid += (t - u);
              }

              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            l10nCustomerRanking,
                            style: pw.TextStyle(
                                font: boldFont, fontSize: 14, color: accentColor),
                          ),
                          pw.Text(
                            '${filteredRanking.length} clientes',
                            style: pw.TextStyle(
                                font: baseFont, fontSize: 9, color: PdfColors.grey500),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      pw.TableHelper.fromTextArray(
                        border: const pw.TableBorder(
                          horizontalInside: pw.BorderSide(
                              color: PdfColors.grey200, width: 0.5),
                          bottom: pw.BorderSide(
                              color: PdfColors.grey300, width: 1),
                        ),
                        headerStyle: pw.TextStyle(
                            font: boldFont,
                            color: PdfColors.white,
                            fontSize: 9),
                        headerDecoration:
                            const pw.BoxDecoration(color: PdfColors.blueGrey700),
                        cellStyle: pw.TextStyle(
                            font: baseFont, color: textColor, fontSize: 9),
                        cellPadding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        cellAlignments: {
                          0: pw.Alignment.center,
                          1: pw.Alignment.centerLeft,
                          2: pw.Alignment.centerRight,
                          3: pw.Alignment.centerRight,
                          4: pw.Alignment.centerRight,
                        },
                        headers: ['#', l10nCustomer, l10nReceived, l10nToReceive, l10nTotal],
                        data: List.generate(
                          filteredRanking.length,
                          (index) {
                            final double total =
                                filteredRanking[index]['total'] ?? 0.0;
                            final double unpaidTotal =
                                filteredRanking[index]['unpaidTotal'] ?? 0.0;
                            final double paidTotal = total - unpaidTotal;

                            return [
                              '${index + 1}',
                              _latinCharactersOnly(
                                  filteredRanking[index]['name'] ?? l10nCustomer),
                              _convertToCurrency(paidTotal),
                              _convertToCurrency(unpaidTotal),
                              _convertToCurrency(total),
                            ];
                          },
                        ),
                      ),
                      // Totals row
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey100,
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                          ),
                        ),
                        child: pw.Row(
                          children: [
                            pw.SizedBox(width: 20),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                'TOTAL',
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: textColor),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                _convertToCurrency(totalCustomerPaid),
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: successColor),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                _convertToCurrency(totalCustomerUnpaid),
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: warningColor),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                _convertToCurrency(totalCustomerAmount),
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: primaryColor),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (servicesRanking.isNotEmpty) {
              // Calculate totals for services
              int totalServicesQty = 0;
              double totalServicesAmount = 0;
              for (var service in servicesRanking) {
                totalServicesQty += service['quantity'] as int;
                totalServicesAmount += service['total'] as double;
              }

              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            l10nServiceRanking,
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 14,
                                color: accentColor),
                          ),
                          pw.Text(
                            '${servicesRanking.length} servicos',
                            style: pw.TextStyle(
                                font: baseFont, fontSize: 9, color: PdfColors.grey500),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      pw.TableHelper.fromTextArray(
                        border: const pw.TableBorder(
                          horizontalInside: pw.BorderSide(
                              color: PdfColors.grey200, width: 0.5),
                          bottom: pw.BorderSide(
                              color: PdfColors.grey300, width: 1),
                        ),
                        headerStyle: pw.TextStyle(
                            font: boldFont,
                            color: PdfColors.white,
                            fontSize: 9),
                        headerDecoration:
                            const pw.BoxDecoration(color: PdfColors.blue700),
                        cellStyle: pw.TextStyle(
                            font: baseFont, color: textColor, fontSize: 9),
                        cellPadding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        cellAlignments: {
                          0: pw.Alignment.center,
                          1: pw.Alignment.centerLeft,
                          2: pw.Alignment.center,
                          3: pw.Alignment.centerRight,
                        },
                        headers: ['#', l10nService, l10nQuantityShort, l10nValueColumn],
                        data: List.generate(
                          servicesRanking.length,
                          (index) => [
                            '${index + 1}',
                            _latinCharactersOnly(
                                servicesRanking[index]['name'] as String),
                            '${servicesRanking[index]['quantity']}',
                            _convertToCurrency(
                                servicesRanking[index]['total'] as double),
                          ],
                        ),
                      ),
                      // Totals row
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue50,
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.blue200, width: 1),
                          ),
                        ),
                        child: pw.Row(
                          children: [
                            pw.SizedBox(width: 20),
                            pw.Expanded(
                              flex: 4,
                              child: pw.Text(
                                'TOTAL',
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.blue800),
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                '$totalServicesQty',
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.blue800),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                _convertToCurrency(totalServicesAmount),
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.blue800),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (productsRanking.isNotEmpty) {
              // Calculate totals for products
              int totalProductsQty = 0;
              double totalProductsAmount = 0;
              for (var product in productsRanking) {
                totalProductsQty += product['quantity'] as int;
                totalProductsAmount += product['total'] as double;
              }

              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            l10nProductRanking,
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 14,
                                color: accentColor),
                          ),
                          pw.Text(
                            '${productsRanking.length} produtos',
                            style: pw.TextStyle(
                                font: baseFont, fontSize: 9, color: PdfColors.grey500),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      pw.TableHelper.fromTextArray(
                        border: const pw.TableBorder(
                          horizontalInside: pw.BorderSide(
                              color: PdfColors.grey200, width: 0.5),
                          bottom: pw.BorderSide(
                              color: PdfColors.grey300, width: 1),
                        ),
                        headerStyle: pw.TextStyle(
                            font: boldFont,
                            color: PdfColors.white,
                            fontSize: 9),
                        headerDecoration:
                            const pw.BoxDecoration(color: PdfColors.purple700),
                        cellStyle: pw.TextStyle(
                            font: baseFont, color: textColor, fontSize: 9),
                        cellPadding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        cellAlignments: {
                          0: pw.Alignment.center,
                          1: pw.Alignment.centerLeft,
                          2: pw.Alignment.center,
                          3: pw.Alignment.centerRight,
                        },
                        headers: ['#', l10nProduct, l10nQuantityShort, l10nValueColumn],
                        data: List.generate(
                          productsRanking.length,
                          (index) => [
                            '${index + 1}',
                            _latinCharactersOnly(
                                productsRanking[index]['name'] as String),
                            '${productsRanking[index]['quantity']}',
                            _convertToCurrency(
                                productsRanking[index]['total'] as double),
                          ],
                        ),
                      ),
                      // Totals row
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.purple50,
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.purple200, width: 1),
                          ),
                        ),
                        child: pw.Row(
                          children: [
                            pw.SizedBox(width: 20),
                            pw.Expanded(
                              flex: 4,
                              child: pw.Text(
                                'TOTAL',
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.purple800),
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                '$totalProductsQty',
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.purple800),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                _convertToCurrency(totalProductsAmount),
                                style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.purple800),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (orderStore.recentOrders.isNotEmpty) {
              final filteredOrders = orderStore.paymentFilter == null
                  ? orderStore.recentOrders
                  : orderStore.recentOrders
                      .where(
                          (order) => order?.payment == orderStore.paymentFilter)
                      .toList();

              content.add(_buildPdfOrdersTable(
                  filteredOrders, boldFont, baseFont, textColor, accentColor, false, l10nStrings));
            }
          }

          return content;
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfKpiBox(
    String title,
    String value,
    PdfColor color,
    pw.Font boldFont,
    pw.Font baseFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 12,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                title,
                style: pw.TextStyle(
                    font: baseFont, fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
                font: boldFont, fontSize: 16, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfKpiBoxLarge(
    String title,
    String value,
    PdfColor color,
    pw.Font boldFont,
    pw.Font baseFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 9,
              color: PdfColors.white,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 24,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfOrdersTable(
    List<dynamic> orders,
    pw.Font boldFont,
    pw.Font baseFont,
    PdfColor textColor,
    PdfColor accentColor,
    bool isClientReport,
    Map<String, String> l10nStrings,
  ) {
    // Calculate totals
    double totalAmount = 0;
    int paidCount = 0;
    int pendingCount = 0;
    for (var order in orders) {
      totalAmount += (order?.total ?? 0.0) as double;
      if (order?.payment == 'paid') {
        paidCount++;
      } else {
        pendingCount++;
      }
    }

    final tableData = List<List<String>>.generate(
      orders.length,
      (index) {
        final order = orders[index];
        final dateStr = order?.createdAt != null
            ? FormatService().formatDate(order!.createdAt!)
            : '';
        final isPaid = order?.payment == 'paid';
        String vehicleInfo = _getVehicleInfo(order, notInformedText: l10nStrings['notInformed']);

        if (isClientReport) {
          return [
            '#${order?.number ?? ""}',
            dateStr,
            vehicleInfo,
            _convertToCurrency(order?.total ?? 0.0),
            isPaid ? l10nStrings['paid']! : l10nStrings['pending']!,
          ];
        } else {
          return [
            '#${order?.number ?? ""}',
            _latinCharactersOnly(order?.customer?.name ?? l10nStrings['customer']!),
            dateStr,
            _convertToCurrency(order?.total ?? 0.0),
            isPaid ? l10nStrings['paid']! : l10nStrings['pending']!,
          ];
        }
      },
    );

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                l10nStrings['orders']!,
                style:
                    pw.TextStyle(font: boldFont, fontSize: 14, color: accentColor),
              ),
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(
                      '$paidCount ${l10nStrings['paid']!.toLowerCase()}',
                      style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.green800),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange100,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(
                      '$pendingCount ${l10nStrings['pending']!.toLowerCase()}',
                      style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.orange800),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
            ),
            headerStyle: pw.TextStyle(
                font: boldFont, color: PdfColors.white, fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey600),
            cellStyle:
                pw.TextStyle(font: baseFont, color: textColor, fontSize: 9),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            columnWidths: isClientReport
                ? {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(2.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.2),
                  }
                : {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.2),
                  },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.center,
            },
            headers: isClientReport
                ? [l10nStrings['orderShort']!, l10nStrings['date']!, l10nStrings['vehicle']!, l10nStrings['value']!, l10nStrings['status']!]
                : [l10nStrings['orderShort']!, l10nStrings['customer']!, l10nStrings['date']!, l10nStrings['value']!, l10nStrings['status']!],
            data: tableData,
          ),
          // Totals row
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    '${l10nStrings['total']!.toUpperCase()} (${orders.length} ${orders.length == 1 ? l10nStrings['orderSingular']! : l10nStrings['orderPlural']!})',
                    style: pw.TextStyle(font: boldFont, fontSize: 9, color: textColor),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    _convertToCurrency(totalAmount),
                    style: pw.TextStyle(font: boldFont, fontSize: 9, color: accentColor),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.SizedBox(width: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _latinCharactersOnly(String text) {
    if (text.isEmpty) return '';

    final Map<String, String> accentMap = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C', 'Ñ': 'N',
    };

    try {
      String result = text;
      accentMap.forEach((key, value) {
        result = result.replaceAll(key, value);
      });
      result = result.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
      return result;
    } catch (e) {
      return 'texto';
    }
  }
}

class _BarSegment {
  const _BarSegment(this.value, this.color);
  final double value;
  final Color color;
}

/// Horizontal stacked bar (8pt). Segment widths follow [segments] values;
/// colors come from the caller (already resolved for light/dark).
class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.segments,
    required this.emptyColor,
    required this.semanticsLabel,
  });

  final List<_BarSegment> segments;
  final Color emptyColor;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.value > 0).toList();
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: visible.isEmpty
                ? ColoredBox(color: emptyColor)
                : Row(
                    children: [
                      for (final s in visible)
                        Expanded(
                          flex: (s.value * 1000).round().clamp(1, 1000000),
                          child: ColoredBox(color: s.color),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Legend line of a chart: dot, label, optional count and value. Tappable
/// (with a check on the trailing edge when selected) when [onTap] is set.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    this.count,
    this.selected = false,
    this.onTap,
  });

  final CupertinoDynamicColor color;
  final String label;
  final String value;
  final String? count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = AppListRow(
      leading: StatusDot(color: color, size: 10),
      title: label,
      subtitle: count,
      trailing: selected ? null : value,
      showChevron: false,
    );

    final content = selected
        ? Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              row,
              PositionedDirectional(
                end: AppSpacing.pageMargin,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary.resolveFrom(context),
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 20,
                      color: AppColors.accentText.resolveFrom(context),
                    ),
                  ],
                ),
              ),
            ],
          )
        : row;

    if (onTap == null) return content;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// "Escolher datas": start and end in a [FormSheet] (X and ✓). The row
/// being changed is marked in blue and the date wheel below edits it. Pops a
/// record on ✓.
class _CustomPeriodSheet extends StatefulWidget {
  const _CustomPeriodSheet({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  State<_CustomPeriodSheet> createState() => _CustomPeriodSheetState();
}

class _CustomPeriodSheetState extends State<_CustomPeriodSheet> {
  late DateTime _start = widget.start;
  late DateTime _end = widget.end;
  bool _selectingStart = true;

  bool get _dirty => _start != widget.start || _end != widget.end;

  Widget _dateRow(String label, DateTime date, {required bool isStart}) {
    final selecting = _selectingStart == isStart;
    final format = FormatService();
    return Semantics(
      button: true,
      selected: selecting,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectingStart = isStart),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppSizes.minTouchTarget + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body.copyWith(
                      color: AppColors.text.resolveFrom(context),
                    ),
                  ),
                ),
                Text(
                  format.formatDate(date),
                  style: AppTypography.body.copyWith(
                    color: selecting
                        ? AppColors.accentText.resolveFrom(context)
                        : AppColors.textSecondary.resolveFrom(context),
                    fontWeight: selecting ? FontWeight.w600 : null,
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSheet(
      title: l10n.reportWhichPeriod,
      canSave: true,
      dirty: _dirty,
      onSave: () => Navigator.of(context).pop((start: _start, end: _end)),
      children: [
        FormFieldsCard(
          children: [
            _dateRow(l10n.reportStarts, _start, isStart: true),
            _dateRow(l10n.reportEnds, _end, isStart: false),
          ],
        ),
        FormFieldsCard(
          children: [
            SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              key: ValueKey(_selectingStart),
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selectingStart ? _start : _end,
              maximumDate: DateTime.now(),
              minimumDate: DateTime(2020),
              onDateTimeChanged: (date) {
                setState(() {
                  if (_selectingStart) {
                    _start = date;
                    if (date.isAfter(_end)) _end = date;
                  } else {
                    _end = date;
                    if (date.isBefore(_start)) _start = date;
                  }
                });
              },
            ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Mandar relatório em PDF": the single filled button, fixed at the bottom.
class _SendPdfBar extends StatelessWidget {
  const _SendPdfBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background.resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0.72, 1],
          colors: [bg, bg.withValues(alpha: 0)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.blockMargin,
            AppSpacing.xl,
            AppSpacing.blockMargin,
            AppSpacing.md,
          ),
          child: CupertinoButton(
            key: const Key('financialSendReportPdf'),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
            color: AppColors.accent.resolveFrom(context),
            borderRadius: BorderRadius.circular(AppRadii.button),
            onPressed: onPressed,
            child: Text(
              context.l10n.financialSendReportPdf,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.onAccent.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
