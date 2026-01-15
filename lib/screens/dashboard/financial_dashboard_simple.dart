import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/global.dart';
import 'package:praticos/widgets/permission_widgets.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:praticos/extensions/context_extensions.dart';

/// Dashboard financeiro protegido por permissões RBAC.
///
/// Apenas usuários com permissão [PermissionType.viewFinancialReports]
/// podem acessar esta tela (Admin e Gerente).
class FinancialDashboardSimple extends StatefulWidget {
  const FinancialDashboardSimple({super.key});

  @override
  State<FinancialDashboardSimple> createState() =>
      _FinancialDashboardSimpleState();
}

class _FinancialDashboardSimpleState extends State<FinancialDashboardSimple> {
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

  Map<String, String> get periodLabelsMap => {
    'hoje': context.l10n.today,
    'semana': context.l10n.week,
    'mês': context.l10n.month,
    'ano': context.l10n.year,
    'custom': context.l10n.period,
  };

  @override
  Widget build(BuildContext context) {
    final orderStore = Provider.of<OrderStore>(context);

    // Protege a tela com verificação de permissão RBAC
    return ProtectedRoute(
      permission: PermissionType.viewFinancialReports,
      accessDeniedMessage: context.l10n.financialAccessDenied,
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        child: Material(
          type: MaterialType.transparency,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(context.l10n.financialDashboard),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    CupertinoIcons.square_arrow_up,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                  ),
                  onPressed: () => _shareReport(orderStore),
                ),
              ),
              CupertinoSliverRefreshControl(
                onRefresh: () => orderStore.loadOrdersForDashboard(),
              ),
              _buildPeriodSelector(),
              Observer(builder: (_) => _buildKpiCards(orderStore)),
              Observer(builder: (_) => _buildRevenueBreakdown(orderStore)),
              Observer(builder: (_) => _buildCustomerRanking(orderStore)),
              Observer(builder: (_) => _buildServicesRanking(orderStore)),
              Observer(builder: (_) => _buildProductsRanking(orderStore)),
              Observer(builder: (_) => _buildRecentOrders(orderStore)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PERIOD SELECTOR
  // ============================================================

  Widget _buildPeriodSelector() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            // Segmented Control for Period Type
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: selectedPeriod,
                children: {
                  'hoje': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(context.l10n.today, style: TextStyle(fontSize: 13, decoration: TextDecoration.none, color: CupertinoColors.label.resolveFrom(context))),
                  ),
                  'semana': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(context.l10n.week, style: TextStyle(fontSize: 13, decoration: TextDecoration.none, color: CupertinoColors.label.resolveFrom(context))),
                  ),
                  'mês': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(context.l10n.month, style: TextStyle(fontSize: 13, decoration: TextDecoration.none, color: CupertinoColors.label.resolveFrom(context))),
                  ),
                  'ano': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(context.l10n.year, style: TextStyle(fontSize: 13, decoration: TextDecoration.none, color: CupertinoColors.label.resolveFrom(context))),
                  ),
                  'custom': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(context.l10n.period, style: TextStyle(fontSize: 13, decoration: TextDecoration.none, color: CupertinoColors.label.resolveFrom(context))),
                  ),
                },
                onValueChanged: (value) {
                  if (value == 'custom') {
                    _showCustomPeriodPicker();
                  } else {
                    setState(() {
                      selectedPeriod = value!;
                      _periodOffset = 0;
                      _customStartDate = null;
                      _customEndDate = null;
                    });
                    _updateDashboardPeriod();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            // Period Navigation Row
            _buildPeriodNavigationRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodNavigationRow() {
    if (selectedPeriod == 'custom') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.calendar,
              size: 20,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Text(
              periodLabel,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(28),
              child: Icon(
                CupertinoIcons.pencil,
                size: 18,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
              onPressed: () => _showCustomPeriodPicker(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            child: Icon(
              CupertinoIcons.chevron_left,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            onPressed: () {
              setState(() => _periodOffset--);
              _updateDashboardPeriod();
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: _periodOffset != 0
                  ? () {
                      setState(() => _periodOffset = 0);
                      final orderStore =
                          Provider.of<OrderStore>(context, listen: false);
                      orderStore.setPaymentFilter(null);
                      orderStore.clearCustomerRankingSelection();
                      _updateDashboardPeriod();
                    }
                  : null,
              child: Column(
                children: [
                  Text(
                    periodLabel,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_periodOffset != 0)
                    Text(
                      context.l10n.tapToReturnToCurrent,
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.none,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            onPressed: _periodOffset < 0
                ? () {
                    setState(() => _periodOffset++);
                    _updateDashboardPeriod();
                  }
                : null,
            child: Icon(
              CupertinoIcons.chevron_right,
              color: _periodOffset < 0
                  ? CupertinoColors.activeBlue.resolveFrom(context)
                  : CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomPeriodPicker() async {
    DateTime tempStartDate =
        _customStartDate ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime tempEndDate = _customEndDate ?? DateTime.now();
    bool isSelectingStart = true;

    await showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: 380,
          padding: const EdgeInsets.only(top: 6.0),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: Text(context.l10n.cancel),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        context.l10n.selectPeriod,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      CupertinoButton(
                        child: Text(context.l10n.ok),
                        onPressed: () {
                          setState(() {
                            selectedPeriod = 'custom';
                            _customStartDate = tempStartDate;
                            _customEndDate = tempEndDate;
                            _periodOffset = 0;
                          });
                          _updateDashboardPeriodCustom(
                              tempStartDate, tempEndDate);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Start/End Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoSlidingSegmentedControl<bool>(
                    groupValue: isSelectingStart,
                    children: {
                      true: Text(
                        '${context.l10n.start}: ${FormatService().formatDate(tempStartDate)}',
                        style: TextStyle(fontSize: 13, decoration: TextDecoration.none, color: CupertinoColors.label.resolveFrom(context)),
                      ),
                      false: Text(
                        '${context.l10n.end}: ${FormatService().formatDate(tempEndDate)}',
                        style: TextStyle(fontSize: 13, decoration: TextDecoration.none, color: CupertinoColors.label.resolveFrom(context)),
                      ),
                    },
                    onValueChanged: (value) {
                      setModalState(() => isSelectingStart = value!);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Date Picker
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime:
                        isSelectingStart ? tempStartDate : tempEndDate,
                    maximumDate: DateTime.now(),
                    minimumDate: DateTime(2020),
                    onDateTimeChanged: (date) {
                      setModalState(() {
                        if (isSelectingStart) {
                          tempStartDate = date;
                          if (date.isAfter(tempEndDate)) {
                            tempEndDate = date;
                          }
                        } else {
                          tempEndDate = date;
                          if (date.isBefore(tempStartDate)) {
                            tempStartDate = date;
                          }
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HERO SECTION (Health App Style)
  // ============================================================

  Widget _buildKpiCards(OrderStore orderStore) {
    final totalOrders = orderStore.recentOrders.length;
    final paidOrders =
        orderStore.recentOrders.where((o) => o?.payment == 'paid').length;
    final unpaidOrders = totalOrders - paidOrders;
    final avgTicket =
        totalOrders > 0 ? orderStore.totalRevenue / totalOrders : 0.0;

    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final tertiaryColor = CupertinoColors.tertiaryLabel.resolveFrom(context);
    final greenColor = CupertinoColors.systemGreen.resolveFrom(context);
    final orangeColor = CupertinoColors.systemOrange.resolveFrom(context);

    final paidPercent = orderStore.totalRevenue > 0
        ? orderStore.totalPaidAmount / orderStore.totalRevenue
        : 0.0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero: Large Revenue Number
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.billing.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _convertToCurrency(orderStore.totalRevenue),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalOrders ordens • Média ${_convertToCurrency(avgTicket)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Horizontal Stacked Bar (Health app style)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (paidPercent * 100).round().clamp(1, 100),
                            child: Container(color: greenColor),
                          ),
                          if (paidPercent < 1)
                            Expanded(
                              flex: ((1 - paidPercent) * 100).round().clamp(1, 100),
                              child: Container(color: orangeColor),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Legend Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildHealthLegendItem(
                          label: context.l10n.received,
                          value: _convertToCurrency(orderStore.totalPaidAmount),
                          count: paidOrders,
                          color: greenColor,
                          isSelected: orderStore.paymentFilter == 'paid',
                          onTap: () => _togglePaymentFilter(orderStore, 'paid'),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: tertiaryColor,
                      ),
                      Expanded(
                        child: _buildHealthLegendItem(
                          label: context.l10n.toReceive,
                          value: _convertToCurrency(orderStore.totalUnpaidAmount),
                          count: unpaidOrders,
                          color: orangeColor,
                          isSelected: orderStore.paymentFilter == 'unpaid',
                          onTap: () => _togglePaymentFilter(orderStore, 'unpaid'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthLegendItem({
    required String label,
    required String value,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: secondaryColor,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.checkmark,
                    size: 10,
                    color: color,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            Text(
              '$count ordens',
              style: TextStyle(
                fontSize: 11,
                color: secondaryColor,
              ),
            ),
          ],
        ),
      ),
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
  // REVENUE COMPOSITION (Services vs Products - Health App Style)
  // ============================================================

  Widget _buildRevenueBreakdown(OrderStore orderStore) {
    final servicesRanking = _calculateServicesRanking(orderStore);
    final productsRanking = _calculateProductsRanking(orderStore);

    final totalServices = servicesRanking.fold<double>(
        0, (sum, item) => sum + (item['total'] as double));
    final totalProducts = productsRanking.fold<double>(
        0, (sum, item) => sum + (item['total'] as double));
    final totalComposition = totalServices + totalProducts;

    if (totalComposition == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final blueColor = CupertinoColors.systemBlue.resolveFrom(context);
    final purpleColor = CupertinoColors.systemPurple.resolveFrom(context);

    final servicesPercent = totalComposition > 0 ? totalServices / totalComposition : 0.0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground
                .resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.composition.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Horizontal stacked bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (totalServices > 0)
                        Expanded(
                          flex: (servicesPercent * 100).round().clamp(1, 100),
                          child: Container(color: blueColor),
                        ),
                      if (totalProducts > 0)
                        Expanded(
                          flex: ((1 - servicesPercent) * 100).round().clamp(1, 100),
                          child: Container(color: purpleColor),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Two columns
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: blueColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.services,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _convertToCurrency(totalServices),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: purpleColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.products,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _convertToCurrency(totalProducts),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOMER RANKING
  // ============================================================

  Widget _buildCustomerRanking(OrderStore orderStore) {
    if (orderStore.customerRanking.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.person_2,
        message: 'Sem dados de clientes neste período',
      );
    }

    var filteredRanking = _filterRankingByPayment(orderStore);
    final itemCount = _isRankingExpanded
        ? filteredRanking.length
        : (filteredRanking.length > 5 ? 5 : filteredRanking.length);

    String sectionTitle = orderStore.paymentFilter == 'paid'
        ? context.l10n.customersReceived.toUpperCase()
        : orderStore.paymentFilter == 'unpaid'
            ? context.l10n.customersToReceive.toUpperCase()
            : context.l10n.customers.toUpperCase();

    // Calculate total for header
    final totalValue = filteredRanking.fold<double>(0, (sum, customer) {
      final double totalAmount = customer['total'] ?? 0.0;
      final double unpaidAmount = customer['unpaidTotal'] ?? 0.0;
      final double paidAmount = totalAmount - unpaidAmount;

      return sum + (orderStore.paymentFilter == 'paid'
          ? paidAmount
          : orderStore.paymentFilter == 'unpaid'
              ? unpaidAmount
              : totalAmount);
    });

    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardColor = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sectionTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: secondaryColor,
                      ),
                    ),
                    Text(
                      _convertToCurrency(totalValue),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < itemCount; i++)
                _buildRankingListTile(
                  rank: i + 1,
                  customer: filteredRanking[i],
                  orderStore: orderStore,
                ),
              if (filteredRanking.length > 5)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => setState(() => _isRankingExpanded = !_isRankingExpanded),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRankingExpanded ? context.l10n.seeLess : context.l10n.seeAllCount(filteredRanking.length),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isRankingExpanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterRankingByPayment(OrderStore orderStore) {
    var filteredRanking = List<Map<String, dynamic>>.from(orderStore.customerRanking);

    if (orderStore.paymentFilter != null) {
      filteredRanking = filteredRanking.where((customer) {
        final double total = customer['total'] ?? 0.0;
        final double unpaidTotal = customer['unpaidTotal'] ?? 0.0;
        final double paidTotal = total - unpaidTotal;

        if (orderStore.paymentFilter == 'paid') {
          return paidTotal > 0;
        } else if (orderStore.paymentFilter == 'unpaid') {
          return unpaidTotal > 0;
        }
        return true;
      }).toList();

      filteredRanking.sort((a, b) {
        final double totalA = a['total'] ?? 0.0;
        final double unpaidTotalA = a['unpaidTotal'] ?? 0.0;
        final double paidTotalA = totalA - unpaidTotalA;

        final double totalB = b['total'] ?? 0.0;
        final double unpaidTotalB = b['unpaidTotal'] ?? 0.0;
        final double paidTotalB = totalB - unpaidTotalB;

        if (orderStore.paymentFilter == 'paid') {
          return paidTotalB.compareTo(paidTotalA);
        }
        return unpaidTotalB.compareTo(unpaidTotalA);
      });
    }

    return filteredRanking;
  }

  Widget _buildRankingListTile({
    required int rank,
    required Map<String, dynamic> customer,
    required OrderStore orderStore,
  }) {
    final isSelected =
        orderStore.selectedCustomerInRanking?['id'] == customer['id'];

    final labelColor = CupertinoColors.label.resolveFrom(context);
    final selectedBgColor = CupertinoColors.systemGrey5.resolveFrom(context);

    final double totalAmount = customer['total'] ?? 0.0;
    final double unpaidAmount = customer['unpaidTotal'] ?? 0.0;
    final double paidAmount = totalAmount - unpaidAmount;

    final displayValue = orderStore.paymentFilter == 'paid'
        ? paidAmount
        : orderStore.paymentFilter == 'unpaid'
            ? unpaidAmount
            : totalAmount;

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          orderStore.clearCustomerRankingSelection();
        } else {
          orderStore.selectCustomerInRanking(customer);
        }
      },
      child: Container(
        color: isSelected ? selectedBgColor : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer['name'] ?? context.l10n.customerWithoutName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: labelColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (unpaidAmount > 0 && orderStore.paymentFilter == null)
                    Text(
                      'A receber: ${_convertToCurrency(unpaidAmount)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemOrange,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _convertToCurrency(displayValue),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SERVICES RANKING
  // ============================================================

  List<Map<String, dynamic>> _calculateServicesRanking(OrderStore orderStore) {
    final Map<String, Map<String, dynamic>> servicesMap = {};

    for (final order in orderStore.recentOrders) {
      if (order?.services != null) {
        for (final service in order!.services!) {
          final name =
              service.service?.name ?? service.description ?? context.l10n.serviceWithoutName;
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
    ranking.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return ranking;
  }

  Widget _buildServicesRanking(OrderStore orderStore) {
    final servicesRanking = _calculateServicesRanking(orderStore);

    if (servicesRanking.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.wrench,
        message: 'Sem dados de serviços neste período',
      );
    }

    final itemCount = _isServicesExpanded
        ? servicesRanking.length
        : (servicesRanking.length > 5 ? 5 : servicesRanking.length);

    final totalServicesValue = servicesRanking.fold<double>(
        0, (sum, item) => sum + (item['total'] as double));
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardColor = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.services.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: secondaryColor,
                      ),
                    ),
                    Text(
                      _convertToCurrency(totalServicesValue),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < itemCount; i++)
                _buildRankingItemWithQty(
                  rank: i + 1,
                  name: servicesRanking[i]['name'] as String,
                  value: servicesRanking[i]['total'] as double,
                  quantity: servicesRanking[i]['quantity'] as int,
                ),
              if (servicesRanking.length > 5)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => setState(() => _isServicesExpanded = !_isServicesExpanded),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isServicesExpanded ? context.l10n.seeLess : context.l10n.seeAllCount(servicesRanking.length),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isServicesExpanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCTS RANKING
  // ============================================================

  List<Map<String, dynamic>> _calculateProductsRanking(OrderStore orderStore) {
    final Map<String, Map<String, dynamic>> productsMap = {};

    for (final order in orderStore.recentOrders) {
      if (order?.products != null) {
        for (final product in order!.products!) {
          final name =
              product.product?.name ?? product.description ?? context.l10n.productWithoutName;
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
    ranking.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return ranking;
  }

  Widget _buildProductsRanking(OrderStore orderStore) {
    final productsRanking = _calculateProductsRanking(orderStore);

    if (productsRanking.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.cube_box,
        message: 'Sem dados de produtos neste período',
      );
    }

    final itemCount = _isProductsExpanded
        ? productsRanking.length
        : (productsRanking.length > 5 ? 5 : productsRanking.length);

    final totalProductsValue = productsRanking.fold<double>(
        0, (sum, item) => sum + (item['total'] as double));
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardColor = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.products.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: secondaryColor,
                      ),
                    ),
                    Text(
                      _convertToCurrency(totalProductsValue),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < itemCount; i++)
                _buildRankingItemWithQty(
                  rank: i + 1,
                  name: productsRanking[i]['name'] as String,
                  value: productsRanking[i]['total'] as double,
                  quantity: productsRanking[i]['quantity'] as int,
                ),
              if (productsRanking.length > 5)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => setState(() => _isProductsExpanded = !_isProductsExpanded),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isProductsExpanded ? context.l10n.seeLess : context.l10n.seeAllCount(productsRanking.length),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isProductsExpanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankingItemWithQty({
    required int rank,
    required String name,
    required double value,
    required int quantity,
  }) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  context.l10n.nItemsCount(quantity),
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _convertToCurrency(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECENT ORDERS
  // ============================================================

  Widget _buildRecentOrders(OrderStore orderStore) {
    String sectionTitle = orderStore.paymentFilter == 'paid'
        ? context.l10n.paidOrders.toUpperCase()
        : orderStore.paymentFilter == 'unpaid'
            ? context.l10n.ordersToReceive.toUpperCase()
            : context.l10n.recentOrders.toUpperCase();

    final filteredOrders = orderStore.paymentFilter == null
        ? orderStore.recentOrders
        : orderStore.recentOrders
            .where((order) => order?.payment == orderStore.paymentFilter)
            .toList();

    if (filteredOrders.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.doc_text,
        message: context.l10n.noOrdersInPeriod,
      );
    }

    final itemCount = _isRecentOrdersExpanded
        ? filteredOrders.length
        : (filteredOrders.length > 5 ? 5 : filteredOrders.length);

    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardColor = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sectionTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: secondaryColor,
                      ),
                    ),
                    Text(
                      '${filteredOrders.length} ordens',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < itemCount; i++)
                _buildOrderListTile(filteredOrders[i]),
              if (filteredOrders.length > 5)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => setState(() => _isRecentOrdersExpanded = !_isRecentOrdersExpanded),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRecentOrdersExpanded ? context.l10n.seeLess : context.l10n.seeAllCount(filteredOrders.length),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isRecentOrdersExpanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderListTile(dynamic order) {
    final dateFormat = DateFormat('dd/MM/yy');
    final dateStr =
        order?.createdAt != null ? dateFormat.format(order!.createdAt!) : '';
    final isPaid = order?.payment == 'paid';

    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/order',
        arguments: {'order': order},
      ),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order?.customer?.name ?? context.l10n.customer,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${context.l10n.orderShort} #${order?.number} • $dateStr',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _convertToCurrency(order?.total),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPaid
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.systemOrange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPaid ? context.l10n.paid : context.l10n.pendingPayment,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground
                .resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
              'Preparando relatório...',
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
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
        await Printing.sharePdf(
          bytes: pdf,
          filename: 'Relatorio_Financeiro_${periodLabel.replaceAll('/', '-').replaceAll(' ', '_')}.pdf',
        );
      }
    } catch (e) {
      if (currentContext.mounted) {
        Navigator.of(currentContext).pop();

        showCupertinoDialog(
          context: currentContext,
          builder: (context) => CupertinoAlertDialog(
            title: Text(currentContext.l10n.error),
            content: Text('${currentContext.l10n.errorGeneratingReport}: ${e.toString()}'),
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
    final selectedClientName = isClientSelected
        ? orderStore.selectedCustomerInRanking!['name'] ?? 'Cliente'
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
                            company?.name ?? Global.companyAggr?.name ?? 'Empresa'),
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
                        'RELATORIO FINANCEIRO',
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
                      'Gerado em ${FormatService().formatDateTime(DateTime.now())}',
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
                  'PraticOS - Sistema de Gestao de Ordens de Servico',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfColors.grey400,
                  ),
                ),
                pw.Text(
                  'Pagina ${context.pageNumber} de ${context.pagesCount}',
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
                            'Cliente: ',
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
                            'Faturamento Total',
                            _convertToCurrency(clientTotal),
                            primaryColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            'Recebido',
                            _convertToCurrency(clientPaidTotal),
                            successColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            'A Receber',
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
                  clientOrders, boldFont, baseFont, textColor, accentColor, true));
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
                          'Resumo Financeiro',
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
                            'Faturamento Total',
                            _convertToCurrency(orderStore.totalRevenue),
                            primaryColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            'Ticket Medio',
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
                            'Recebido ($paidPercentage%)',
                            _convertToCurrency(orderStore.totalPaidAmount),
                            successColor,
                            boldFont,
                            baseFont,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: _buildPdfKpiBox(
                            'A Receber ($unpaidPercentage%)',
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
                            'Ranking de Clientes',
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
                        headers: ['#', 'Cliente', 'Recebido', 'A Receber', 'Total'],
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
                                  filteredRanking[index]['name'] ?? 'Cliente'),
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
                            'Ranking de Servicos',
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
                        headers: ['#', 'Servico', 'Qtd', 'Valor'],
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
                            'Ranking de Produtos',
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
                        headers: ['#', 'Produto', 'Qtd', 'Valor'],
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
                  filteredOrders, boldFont, baseFont, textColor, accentColor, false));
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
        String vehicleInfo = _getVehicleInfo(order);

        if (isClientReport) {
          return [
            '#${order?.number ?? ""}',
            dateStr,
            vehicleInfo,
            _convertToCurrency(order?.total ?? 0.0),
            isPaid ? 'Pago' : 'Pendente',
          ];
        } else {
          return [
            '#${order?.number ?? ""}',
            _latinCharactersOnly(order?.customer?.name ?? 'Cliente'),
            dateStr,
            _convertToCurrency(order?.total ?? 0.0),
            isPaid ? 'Pago' : 'Pendente',
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
                'Ordens de Servico',
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
                      '$paidCount pagos',
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
                      '$pendingCount pendentes',
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
                ? ['OS', 'Data', 'Veiculo', 'Valor', 'Status']
                : ['OS', 'Cliente', 'Data', 'Valor', 'Status'],
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
                    'TOTAL (${orders.length} ordens)',
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
