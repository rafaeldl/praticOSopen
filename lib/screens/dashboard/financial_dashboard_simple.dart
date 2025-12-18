import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/global.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

class FinancialDashboardSimple extends StatefulWidget {
  @override
  _FinancialDashboardSimpleState createState() =>
      _FinancialDashboardSimpleState();
}

class _FinancialDashboardSimpleState extends State<FinancialDashboardSimple> {
  String selectedPeriod = 'mês';
  final List<String> periodFilters = ['hoje', 'semana', 'mês', 'ano'];
  DateTime _lastTouchTime = DateTime.now();
  int _periodOffset = 0;
  bool _isRankingExpanded = false;
  bool _isRecentOrdersExpanded = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

  String get periodLabel {
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
        return _periodOffset != 0 ? dayFormat.format(periodDate) : 'Hoje';
      case 'semana':
        DateTime startOfWeek =
            periodDate.subtract(Duration(days: periodDate.weekday));
        DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
        return "${dayFormat.format(startOfWeek)} - ${dayFormat.format(endOfWeek)}";
      case 'mês':
        return _periodOffset != 0
            ? monthFormat.format(periodDate)
            : 'Mês atual';
      case 'ano':
        return _periodOffset != 0
            ? yearFormat.format(periodDate)
            : 'Ano atual';
      default:
        return selectedPeriod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderStore = Provider.of<OrderStore>(context);
    final theme = Theme.of(context);

    orderStore.loadOrdersForDashboard();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Painel Financeiro'),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Gerar Relatório PDF',
            onPressed: () => _generateReport(orderStore),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await orderStore.loadOrdersForDashboard();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(theme),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Observer(builder: (_) => _buildKpiCards(orderStore, theme)),
                    const SizedBox(height: 20),
                    Observer(
                        builder: (_) =>
                            _buildRevenueBreakdown(orderStore, theme)),
                    const SizedBox(height: 20),
                    Observer(
                        builder: (_) =>
                            _buildCustomerRanking(orderStore, theme)),
                    const SizedBox(height: 20),
                    Observer(
                        builder: (_) => _buildRecentOrders(orderStore, theme)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Period type selector
          SegmentedButton<String>(
            segments: periodFilters.map((period) {
              return ButtonSegment<String>(
                value: period,
                label: Text(period.toUpperCase()),
              );
            }).toList(),
            selected: {selectedPeriod},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                selectedPeriod = selection.first;
                _periodOffset = 0;
              });
              _updateDashboardPeriod();
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 12),
          // Period navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() => _periodOffset--);
                    _updateDashboardPeriod();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_periodOffset != 0) {
                        setState(() => _periodOffset = 0);
                        final orderStore =
                            Provider.of<OrderStore>(context, listen: false);
                        orderStore.setPaymentFilter(null);
                        orderStore.clearCustomerRankingSelection();
                        _updateDashboardPeriod();
                      }
                    },
                    child: Column(
                      children: [
                        Text(
                          periodLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_periodOffset != 0)
                          Text(
                            'Toque para voltar ao atual',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: _periodOffset < 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.3),
                  ),
                  onPressed: _periodOffset < 0
                      ? () {
                          setState(() => _periodOffset++);
                          _updateDashboardPeriod();
                        }
                      : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards(OrderStore orderStore, ThemeData theme) {
    final totalOrders = orderStore.recentOrders.length;
    final paidOrders =
        orderStore.recentOrders.where((o) => o?.payment == 'paid').length;
    final unpaidOrders = totalOrders - paidOrders;
    final avgTicket = totalOrders > 0
        ? orderStore.totalRevenue / totalOrders
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo do Período',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                theme: theme,
                title: 'Faturamento',
                value: _convertToCurrency(orderStore.totalRevenue),
                icon: Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.primary,
                subtitle: '$totalOrders ordens',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                theme: theme,
                title: 'Ticket Médio',
                value: _convertToCurrency(avgTicket),
                icon: Icons.receipt_long_outlined,
                color: theme.colorScheme.tertiary,
                subtitle: 'por ordem',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                theme: theme,
                title: 'Recebido',
                value: _convertToCurrency(orderStore.totalPaidAmount),
                icon: Icons.check_circle_outline,
                color: Colors.green.shade600,
                subtitle: '$paidOrders ordens',
                onTap: () {
                  if (orderStore.paymentFilter == 'paid') {
                    orderStore.setPaymentFilter(null);
                  } else {
                    orderStore.setPaymentFilter('paid');
                  }
                },
                isSelected: orderStore.paymentFilter == 'paid',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                theme: theme,
                title: 'A Receber',
                value: _convertToCurrency(orderStore.totalUnpaidAmount),
                icon: Icons.schedule_outlined,
                color: Colors.orange.shade700,
                subtitle: '$unpaidOrders ordens',
                onTap: () {
                  if (orderStore.paymentFilter == 'unpaid') {
                    orderStore.setPaymentFilter(null);
                  } else {
                    orderStore.setPaymentFilter('unpaid');
                  }
                },
                isSelected: orderStore.paymentFilter == 'unpaid',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Material(
      color: isSelected
          ? color.withOpacity(0.1)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: color, width: 2)
                : Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueBreakdown(OrderStore orderStore, ThemeData theme) {
    if (orderStore.totalRevenue == 0) {
      return _buildEmptyState(
        theme: theme,
        icon: Icons.analytics_outlined,
        message: 'Sem dados de faturamento neste período',
      );
    }

    final paidPercentage = orderStore.totalRevenue > 0
        ? (orderStore.totalPaidAmount / orderStore.totalRevenue * 100)
        : 0.0;
    final unpaidPercentage = orderStore.totalRevenue > 0
        ? (orderStore.totalUnpaidAmount / orderStore.totalRevenue * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Composição do Faturamento',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Mini pie chart
              SizedBox(
                width: 80,
                height: 80,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 20,
                    sections: [
                      PieChartSectionData(
                        color: Colors.green.shade500,
                        value: orderStore.totalPaidAmount,
                        title: '',
                        radius: 18,
                      ),
                      PieChartSectionData(
                        color: Colors.orange.shade500,
                        value: orderStore.totalUnpaidAmount,
                        title: '',
                        radius: 18,
                      ),
                    ],
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        final now = DateTime.now();
                        if (event.isInterestedForInteractions &&
                            now.difference(_lastTouchTime).inMilliseconds >
                                500 &&
                            pieTouchResponse != null &&
                            pieTouchResponse.touchedSection != null) {
                          _lastTouchTime = now;
                          final touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                          if (touchedIndex == 0) {
                            if (orderStore.paymentFilter == 'paid') {
                              orderStore.setPaymentFilter(null);
                            } else {
                              orderStore.setPaymentFilter('paid');
                            }
                          } else if (touchedIndex == 1) {
                            if (orderStore.paymentFilter == 'unpaid') {
                              orderStore.setPaymentFilter(null);
                            } else {
                              orderStore.setPaymentFilter('unpaid');
                            }
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                child: Column(
                  children: [
                    _buildBreakdownItem(
                      theme: theme,
                      label: 'Recebido',
                      value: _convertToCurrency(orderStore.totalPaidAmount),
                      percentage: paidPercentage,
                      color: Colors.green.shade500,
                      isSelected: orderStore.paymentFilter == 'paid',
                      onTap: () {
                        if (orderStore.paymentFilter == 'paid') {
                          orderStore.setPaymentFilter(null);
                        } else {
                          orderStore.setPaymentFilter('paid');
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildBreakdownItem(
                      theme: theme,
                      label: 'A Receber',
                      value: _convertToCurrency(orderStore.totalUnpaidAmount),
                      percentage: unpaidPercentage,
                      color: Colors.orange.shade500,
                      isSelected: orderStore.paymentFilter == 'unpaid',
                      onTap: () {
                        if (orderStore.paymentFilter == 'unpaid') {
                          orderStore.setPaymentFilter(null);
                        } else {
                          orderStore.setPaymentFilter('unpaid');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem({
    required ThemeData theme,
    required String label,
    required String value,
    required double percentage,
    required Color color,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 1) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerRanking(OrderStore orderStore, ThemeData theme) {
    if (orderStore.customerRanking.isEmpty) {
      return _buildEmptyState(
        theme: theme,
        icon: Icons.people_outline,
        message: 'Sem dados de clientes neste período',
      );
    }

    var filteredRanking = List.from(orderStore.customerRanking);

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

    final itemCount = _isRankingExpanded
        ? filteredRanking.length
        : (filteredRanking.length > 5 ? 5 : filteredRanking.length);

    String sectionTitle = 'Ranking de Clientes';
    if (orderStore.paymentFilter == 'paid') {
      sectionTitle = 'Clientes - Recebido';
    } else if (orderStore.paymentFilter == 'unpaid') {
      sectionTitle = 'Clientes - A Receber';
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.leaderboard_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  sectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredRanking.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final customer = filteredRanking[index];
              final isSelected =
                  orderStore.selectedCustomerInRanking != null &&
                      orderStore.selectedCustomerInRanking!['id'] ==
                          customer['id'];

              final double totalAmount = customer['total'] ?? 0.0;
              final double unpaidAmount = customer['unpaidTotal'] ?? 0.0;
              final double paidAmount = totalAmount - unpaidAmount;

              return _buildCustomerItem(
                theme: theme,
                index: index,
                name: customer['name'] ?? 'Cliente sem nome',
                paidAmount: paidAmount,
                unpaidAmount: unpaidAmount,
                totalAmount: totalAmount,
                isSelected: isSelected,
                paymentFilter: orderStore.paymentFilter,
                onTap: () {
                  if (isSelected) {
                    orderStore.clearCustomerRankingSelection();
                  } else {
                    orderStore.selectCustomerInRanking(customer);
                  }
                },
              );
            },
          ),
          if (filteredRanking.length > 5)
            InkWell(
              onTap: () {
                setState(() => _isRankingExpanded = !_isRankingExpanded);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isRankingExpanded ? 'Ver menos' : 'Ver todos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isRankingExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerItem({
    required ThemeData theme,
    required int index,
    required String name,
    required double paidAmount,
    required double unpaidAmount,
    required double totalAmount,
    required bool isSelected,
    String? paymentFilter,
    VoidCallback? onTap,
  }) {
    Color rankColor;
    if (index == 0) {
      rankColor = Colors.amber.shade600;
    } else if (index == 1) {
      rankColor = Colors.blueGrey.shade400;
    } else if (index == 2) {
      rankColor = Colors.brown.shade400;
    } else {
      rankColor = theme.colorScheme.outline;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: index < 3
                    ? Border.all(color: rankColor, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (paymentFilter == 'paid')
                  Text(
                    _convertToCurrency(paidAmount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  )
                else if (paymentFilter == 'unpaid')
                  Text(
                    _convertToCurrency(unpaidAmount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  )
                else ...[
                  Text(
                    _convertToCurrency(totalAmount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (unpaidAmount > 0)
                    Text(
                      _convertToCurrency(unpaidAmount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                        fontSize: 11,
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(OrderStore orderStore, ThemeData theme) {
    String sectionTitle = 'Ordens de Serviço';
    if (orderStore.paymentFilter == 'paid') {
      sectionTitle = 'Ordens Pagas';
    } else if (orderStore.paymentFilter == 'unpaid') {
      sectionTitle = 'Ordens a Receber';
    }

    final filteredOrders = orderStore.paymentFilter == null
        ? orderStore.recentOrders
        : orderStore.recentOrders
            .where((order) => order?.payment == orderStore.paymentFilter)
            .toList();

    if (filteredOrders.isEmpty) {
      return _buildEmptyState(
        theme: theme,
        icon: Icons.receipt_long_outlined,
        message: 'Nenhuma ordem neste período',
      );
    }

    final itemCount = _isRecentOrdersExpanded
        ? filteredOrders.length
        : (filteredOrders.length > 5 ? 5 : filteredOrders.length);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  sectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredOrders.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              final dateFormat = DateFormat('dd/MM/yy');
              final dateStr = order?.createdAt != null
                  ? dateFormat.format(order!.createdAt!)
                  : '';
              final isPaid = order?.payment == 'paid';

              return InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/order',
                    arguments: {'order': order},
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPaid
                              ? Icons.check_circle_outline
                              : Icons.schedule_outlined,
                          color: isPaid
                              ? Colors.green.shade600
                              : Colors.orange.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order?.customer?.name ?? 'Cliente',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'OS #${order?.number} • $dateStr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _convertToCurrency(order?.total),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? Colors.green.shade600
                                  : Colors.orange.shade700,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPaid ? 'Pago' : 'Pendente',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isPaid
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (filteredOrders.length > 5)
            InkWell(
              onTap: () {
                setState(() => _isRecentOrdersExpanded = !_isRecentOrdersExpanded);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isRecentOrdersExpanded ? 'Ver menos' : 'Ver todas',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isRecentOrdersExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required ThemeData theme,
    required IconData icon,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _updateDashboardPeriod() {
    final orderStore = Provider.of<OrderStore>(context, listen: false);
    orderStore.setCustomPeriod(selectedPeriod, _periodOffset);
  }

  String _convertToCurrency(double? total) {
    if (total == null) total = 0.0;
    NumberFormat numberFormat =
        NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$');
    return numberFormat.format(total);
  }

  String _getVehicleInfo(dynamic order) {
    if (order == null || order.device == null) return 'Não informado';

    String vehicleInfo = 'Não informado';
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
          var deviceMap = device as Map;
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
        vehicleInfo = device?.toString() ?? 'Não informado';
      }
    }

    return _latinCharactersOnly(vehicleInfo);
  }

  void _generateReport(OrderStore orderStore) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.picture_as_pdf_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Gerar Relatório'),
        content: const Text(
          'Deseja gerar um relatório PDF com os dados financeiros do período selecionado?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _proceedWithReportGeneration(orderStore),
            child: const Text('Gerar PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedWithReportGeneration(OrderStore orderStore) async {
    Navigator.of(context).pop();
    final currentContext = context;

    showDialog<void>(
      context: currentContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            const Text("Gerando relatório..."),
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
        await Printing.layoutPdf(
          onLayout: (format) async => pdf,
          name: 'Relatório Financeiro - $periodLabel',
        );

        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: const Text('Relatório gerado com sucesso!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (currentContext.mounted) {
        Navigator.of(currentContext).pop();

        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar relatório: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Uint8List> _buildPdf(OrderStore orderStore) async {
    final pdf = pw.Document();
    final bool isClientSelected = orderStore.selectedCustomerInRanking != null;
    final selectedClientName = isClientSelected
        ? orderStore.selectedCustomerInRanking!['name'] ?? 'Cliente'
        : '';

    final primaryColor = PdfColors.blue700;
    final accentColor = PdfColors.blue900;
    final successColor = PdfColors.green700;
    final warningColor = PdfColors.orange700;
    final backgroundColor = PdfColors.grey100;
    final textColor = PdfColors.grey800;

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final totalValue = orderStore.totalRevenue;
    final totalOrders = orderStore.recentOrders.length;
    final avgTicket = totalOrders > 0 ? totalValue / totalOrders : 0.0;

    final paidPercentage = totalValue > 0
        ? (orderStore.totalPaidAmount / totalValue * 100).toStringAsFixed(1)
        : "0";
    final unpaidPercentage = totalValue > 0
        ? (orderStore.totalUnpaidAmount / totalValue * 100).toStringAsFixed(1)
        : "0";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Relatorio Financeiro',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 24,
                        color: accentColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _latinCharactersOnly(Global.companyAggr?.name ?? 'PraticOS'),
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    _latinCharactersOnly(periodLabel),
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 14,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(
                  'Pagina ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 9,
                    color: PdfColors.grey500,
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
            final double clientUnpaidTotal = selectedClientData['unpaidTotal'] ?? 0.0;
            final double clientPaidTotal = clientTotal - clientUnpaidTotal;

            var clientOrders = orderStore.recentOrders
                .where((order) => order?.customer?.id == selectedClientData['id'])
                .toList();

            if (orderStore.paymentFilter != null) {
              clientOrders = clientOrders
                  .where((order) => order?.payment == orderStore.paymentFilter)
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
                            style: pw.TextStyle(font: baseFont, color: textColor),
                          ),
                          pw.Text(
                            _latinCharactersOnly(selectedClientName),
                            style: pw.TextStyle(font: boldFont, color: accentColor, fontSize: 16),
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
              content.add(_buildPdfOrdersTable(clientOrders, boldFont, baseFont, textColor, accentColor, true));
            }
          } else {
            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Resumo Financeiro',
                      style: pw.TextStyle(font: boldFont, fontSize: 16, color: accentColor),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildPdfKpiBox(
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
                            PdfColors.purple700,
                            boldFont,
                            baseFont,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
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

              if (orderStore.paymentFilter != null) {
                filteredRanking = filteredRanking.where((customer) {
                  final double total = customer['total'] ?? 0.0;
                  final double unpaidTotal = customer['unpaidTotal'] ?? 0.0;
                  final double paidTotal = total - unpaidTotal;

                  if (orderStore.paymentFilter == 'paid') return paidTotal > 0;
                  if (orderStore.paymentFilter == 'unpaid') return unpaidTotal > 0;
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

              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Ranking de Clientes',
                        style: pw.TextStyle(font: boldFont, fontSize: 16, color: accentColor),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Table.fromTextArray(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                        headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
                        headerDecoration: pw.BoxDecoration(color: accentColor),
                        cellStyle: pw.TextStyle(font: baseFont, color: textColor, fontSize: 9),
                        cellPadding: const pw.EdgeInsets.all(8),
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
                            final double total = filteredRanking[index]['total'] ?? 0.0;
                            final double unpaidTotal = filteredRanking[index]['unpaidTotal'] ?? 0.0;
                            final double paidTotal = total - unpaidTotal;

                            return [
                              '${index + 1}',
                              _latinCharactersOnly(filteredRanking[index]['name'] ?? 'Cliente'),
                              _convertToCurrency(paidTotal),
                              _convertToCurrency(unpaidTotal),
                              _convertToCurrency(total),
                            ];
                          },
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
                      .where((order) => order?.payment == orderStore.paymentFilter)
                      .toList();

              content.add(_buildPdfOrdersTable(filteredOrders, boldFont, baseFont, textColor, accentColor, false));
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
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: baseFont, fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(font: boldFont, fontSize: 16, color: color),
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
    final tableData = List<List<String>>.generate(
      orders.length,
      (index) {
        final order = orders[index];
        final dateStr = order?.createdAt != null
            ? DateFormat('dd/MM/yyyy').format(order!.createdAt!)
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
          pw.Text(
            'Ordens de Servico',
            style: pw.TextStyle(font: boldFont, fontSize: 16, color: accentColor),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
            headerDecoration: pw.BoxDecoration(color: accentColor),
            cellStyle: pw.TextStyle(font: baseFont, color: textColor, fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(8),
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
