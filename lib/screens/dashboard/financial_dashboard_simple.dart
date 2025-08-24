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
    // Inicializar dados de localização para formatação de datas em português
    initializeDateFormatting('pt_BR', null);
  }

  String get periodLabel {
    // Obter a data atual
    DateTime now = DateTime.now();

    // Aplicar o offset ao período selecionado
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

    // Formatar a data de acordo com o tipo de período
    final DateFormat monthFormat = DateFormat('MMMM/yy', 'pt_BR');
    final DateFormat dayFormat = DateFormat('dd MMM', 'pt_BR');
    final DateFormat yearFormat = DateFormat('yyyy', 'pt_BR');

    switch (selectedPeriod) {
      case 'hoje':
        return "Hoje ${_periodOffset != 0 ? '(' + dayFormat.format(periodDate) + ')' : ''}";
      case 'semana':
        // Para semana, mostramos a data inicial e final da semana
        DateTime startOfWeek =
            periodDate.subtract(Duration(days: periodDate.weekday));
        DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
        String weekRange =
            "${dayFormat.format(startOfWeek)} - ${dayFormat.format(endOfWeek)}";
        return "Semana ${_periodOffset != 0 ? '(' + weekRange + ')' : 'atual'}";
      case 'mês':
        String monthName = monthFormat.format(periodDate).toUpperCase();
        return "Mês ${_periodOffset != 0 ? '(' + monthName + ')' : 'atual'}";
      case 'ano':
        String yearValue = yearFormat.format(periodDate);
        return "Ano ${_periodOffset != 0 ? '(' + yearValue + ')' : 'atual'}";
      default:
        return selectedPeriod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderStore = Provider.of<OrderStore>(context);

    // Carregar dados para o dashboard
    orderStore.loadOrdersForDashboard();

    return Scaffold(
      appBar: AppBar(
        title: Text('Painel Financeiro'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: 'Gerar relatório',
              child: IconButton(
                icon: Icon(Icons.description),
                onPressed: () {
                  _generateReport(orderStore);
                },
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await orderStore.loadOrdersForDashboard();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodFilter(),
              SizedBox(height: 16.0),
              Observer(builder: (_) => _buildFinancialSummary(orderStore)),
              SizedBox(height: 24.0),
              Observer(builder: (_) => _buildCustomerRanking(orderStore)),
              SizedBox(height: 24.0),
              Observer(builder: (_) => _buildRecentOrders(orderStore)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header com título
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    SizedBox(width: 8),
                    Text(
                      'PERÍODO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedPeriod = 'mês';
                        _periodOffset = 0;
                      });
                      final orderStore =
                          Provider.of<OrderStore>(context, listen: false);
                      orderStore.setPaymentFilter(null);
                      orderStore.clearCustomerRankingSelection();
                      _updateDashboardPeriod();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        SizedBox(width: 4),
                        Text(
                          'LIMPAR',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Conteúdo com navegação e filtros
          Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Navegação entre períodos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        size: 18,
                        color: Colors.blue[700],
                      ),
                      onPressed: () {
                        setState(() {
                          _periodOffset--;
                        });
                        _updateDashboardPeriod();
                      },
                    ),
                    Text(
                      periodLabel.toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: _periodOffset < 0
                            ? Colors.blue[700]
                            : Colors.grey[400],
                      ),
                      onPressed: _periodOffset < 0
                          ? () {
                              setState(() {
                                _periodOffset++;
                              });
                              _updateDashboardPeriod();
                            }
                          : null,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Chips de filtro
                Container(
                  height: 36,
                  child: Center(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: periodFilters.length,
                      itemBuilder: (context, index) {
                        final period = periodFilters[index];
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(
                              period.toUpperCase(),
                              style: TextStyle(
                                color: selectedPeriod == period
                                    ? Colors.white
                                    : Colors.blue[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            selected: selectedPeriod == period,
                            selectedColor: Colors.blue[700],
                            backgroundColor: Colors.blue[50],
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            labelPadding: EdgeInsets.symmetric(horizontal: 4),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  selectedPeriod = period;
                                  _periodOffset = 0;
                                });
                                _updateDashboardPeriod();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateDashboardPeriod() {
    final orderStore = Provider.of<OrderStore>(context, listen: false);
    orderStore.setCustomPeriod(selectedPeriod, _periodOffset);
  }

  Widget _buildFinancialSummary(OrderStore orderStore) {
    if (orderStore.totalRevenue == 0) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Sem dados financeiros para exibir',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final Map<String, Color> paymentColors = {
      'paid': Colors.green[400]!,
      'unpaid': Colors.red[400]!,
    };

    final Map<String, String> paymentLabels = {
      'paid': 'Recebido',
      'unpaid': 'A Receber',
    };

    // Preparar dados para o gráfico
    List<PieChartSectionData> sections = [];
    Map<String, double> paymentValues = {
      'paid': orderStore.totalPaidAmount,
      'unpaid': orderStore.totalUnpaidAmount,
    };

    double totalValue = orderStore.totalRevenue;

    paymentValues.forEach((payment, value) {
      double percentage = totalValue > 0 ? value / totalValue * 100 : 0;
      bool isSelected = orderStore.paymentFilter == payment;

      sections.add(
        PieChartSectionData(
          color: paymentColors[payment] ?? Colors.grey,
          value: value,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: isSelected ? 70 : 65,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titlePositionPercentageOffset: 0.5,
        ),
      );
    });

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header com Faturamento Total
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    SizedBox(width: 8),
                    Text(
                      'FATURAMENTO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                Text(
                  _convertToCurrency(orderStore.totalRevenue),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          // Conteúdo com gráfico e valores
          Container(
            padding: EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gráfico de Pizza
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 0,
                        sections: sections
                            .map(
                              (section) => PieChartSectionData(
                                color: section.color,
                                value: section.value,
                                title:
                                    '${(section.value / totalValue * 100).toStringAsFixed(0)}%',
                                radius: section.radius,
                                titleStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                titlePositionPercentageOffset: 0.5,
                              ),
                            )
                            .toList(),
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                            final now = DateTime.now();
                            if (event.isInterestedForInteractions &&
                                now.difference(_lastTouchTime).inMilliseconds >
                                    500 &&
                                pieTouchResponse != null &&
                                pieTouchResponse.touchedSection != null) {
                              _lastTouchTime = now;
                              final touchedIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                              if (touchedIndex >= 0 &&
                                  touchedIndex < paymentValues.length) {
                                final paymentStatus =
                                    paymentValues.keys.elementAt(touchedIndex);
                                if (orderStore.paymentFilter == paymentStatus) {
                                  orderStore.setPaymentFilter(null);
                                } else {
                                  orderStore.setPaymentFilter(paymentStatus);
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 24),
                // Valores detalhados
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (orderStore.paymentFilter == 'paid') {
                            orderStore.setPaymentFilter(null);
                          } else {
                            orderStore.setPaymentFilter('paid');
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: orderStore.paymentFilter == 'paid'
                                ? Colors.green[50]
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green[400]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 20,
                                    color: Colors.green[400],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Recebido',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                _convertToCurrency(orderStore.totalPaidAmount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          if (orderStore.paymentFilter == 'unpaid') {
                            orderStore.setPaymentFilter(null);
                          } else {
                            orderStore.setPaymentFilter('unpaid');
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: orderStore.paymentFilter == 'unpaid'
                                ? Colors.red[50]
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red[400]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.pending,
                                    size: 20,
                                    color: Colors.red[400],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'A Receber',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                _convertToCurrency(
                                    orderStore.totalUnpaidAmount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(
      String label, String value, IconData icon, Color color, double percentage,
      {bool isSelected = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? color : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFinancialDetailItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isSelected = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRanking(OrderStore orderStore) {
    if (orderStore.customerRanking.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Sem dados de clientes para exibir',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    // Filtrar e ordenar o ranking de acordo com o filtro de pagamento
    var filteredRanking = List.from(orderStore.customerRanking);

    // Aplicar filtro se necessário
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

      // Reordenar baseado no filtro
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

    String rankingTitle = 'CLIENTES';
    if (orderStore.paymentFilter == 'paid') {
      rankingTitle = 'CLIENTES - RECEBIDO';
    } else if (orderStore.paymentFilter == 'unpaid') {
      rankingTitle = 'CLIENTES - A RECEBER';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$rankingTitle (${filteredRanking.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxHeight: _isRankingExpanded ? double.infinity : 300,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      final customer = filteredRanking[index];
                      final isSelected =
                          orderStore.selectedCustomerInRanking != null &&
                              orderStore.selectedCustomerInRanking!['id'] ==
                                  customer['id'];

                      final double totalAmount = customer['total'] ?? 0.0;
                      final double unpaidAmount =
                          customer['unpaidTotal'] ?? 0.0;
                      final double paidAmount = totalAmount - unpaidAmount;
                      final bool hasUnpaidAmount = unpaidAmount > 0;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          customer['name'] ?? 'Cliente sem nome',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: null,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (orderStore.paymentFilter == 'paid')
                              Text(
                                _convertToCurrency(paidAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                  fontSize: 14,
                                ),
                              )
                            else if (orderStore.paymentFilter == 'unpaid')
                              Text(
                                _convertToCurrency(unpaidAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                  fontSize: 14,
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _convertToCurrency(totalAmount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (hasUnpaidAmount)
                                    Text(
                                      _convertToCurrency(unpaidAmount),
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.blue[50],
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
                ),
                if (!_isRankingExpanded && filteredRanking.length > 5)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isRankingExpanded = !_isRankingExpanded;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver todos',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 14,
                                  color: Colors.blue[700],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isRankingExpanded)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isRankingExpanded = !_isRankingExpanded;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver menos',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_up,
                                  size: 14,
                                  color: Colors.blue[700],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders(OrderStore orderStore) {
    String sectionTitle = orderStore.paymentFilter == 'paid'
        ? 'PAGOS RECENTES'
        : orderStore.paymentFilter == 'unpaid'
            ? 'A RECEBER RECENTES'
            : 'RECENTES';

    // Filtrar ordens de acordo com o filtro de pagamento
    final filteredOrders = orderStore.paymentFilter == null
        ? orderStore.recentOrders
        : orderStore.recentOrders
            .where((order) => order?.payment == orderStore.paymentFilter)
            .toList();

    if (filteredOrders.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Nenhuma ordem recente neste período',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final itemCount = _isRecentOrdersExpanded
        ? filteredOrders.length
        : (filteredOrders.length > 10 ? 10 : filteredOrders.length);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$sectionTitle (${filteredOrders.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final dateFormat = DateFormat('dd/MM/yyyy');
                    final dateStr = order?.createdAt != null
                        ? dateFormat.format(order!.createdAt!)
                        : '';

                    final isPaid = order?.payment == 'paid';

                    // Obter informações do veículo
                    String vehicleInfo = _getVehicleInfo(order);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Text(order?.customer?.name ?? 'Cliente'),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  isPaid ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPaid ? 'Pago' : 'A receber',
                              style: TextStyle(
                                fontSize: 10,
                                color: isPaid
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text('OS #${order?.number} - $dateStr'),
                      trailing: Text(
                        _convertToCurrency(order?.total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/order',
                          arguments: {'order': order},
                        );
                      },
                    );
                  },
                ),
                if (!_isRecentOrdersExpanded && filteredOrders.length > 10)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isRecentOrdersExpanded =
                                  !_isRecentOrdersExpanded;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver todos',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 14,
                                  color: Colors.blue[700],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isRecentOrdersExpanded)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isRecentOrdersExpanded =
                                  !_isRecentOrdersExpanded;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver menos',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_up,
                                  size: 14,
                                  color: Colors.blue[700],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) total = 0.0;
    NumberFormat numberFormat =
        NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$');
    return numberFormat.format(total);
  }

  // Método auxiliar para extrair informações do veículo de forma segura
  String _getVehicleInfo(dynamic order) {
    if (order == null || order.device == null) return 'Não informado';

    String vehicleInfo = 'Não informado';
    var device = order.device;

    // Tenta obter modelo e placa
    String? modelo;
    String? placa;

    try {
      // Tenta acessar diretamente
      modelo = device?.name?.toString() ?? '';
      placa = device?.serial?.toString() ?? '';

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
        // Tenta acessar como Map
        if (device is Map) {
          var deviceMap = device as Map;
          modelo = deviceMap['name']?.toString() ?? '';
          placa = deviceMap['serial']?.toString() ?? '';

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
        // Se tudo falhar, tenta toString
        vehicleInfo = device?.toString() ?? 'Não informado';
      }
    }

    return _latinCharactersOnly(vehicleInfo);
  }

  void _generateReport(OrderStore orderStore) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerar Relatório'),
        content:
            const Text('Deseja gerar um relatório com os dados do painel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => _proceedWithReportGeneration(orderStore),
            child: const Text('GERAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedWithReportGeneration(OrderStore orderStore) async {
    // Fechar o diálogo de confirmação
    Navigator.of(context).pop();

    // Referência ao contexto atual
    final currentContext = context;

    // Mostrar diálogo de carregamento
    showDialog<void>(
      context: currentContext,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Gerando relatório..."),
          ],
        ),
      ),
    );

    try {
      // Gerar o PDF
      final pdf = await _buildPdf(orderStore);

      // Fechar diálogo de carregamento
      if (currentContext.mounted) {
        Navigator.of(currentContext).pop();
      }

      // Mostrar o PDF
      if (currentContext.mounted) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdf,
          name: 'Relatório Financeiro - ${periodLabel}',
        );

        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text('Relatório gerado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Fechar diálogo de carregamento em caso de erro
      if (currentContext.mounted) {
        Navigator.of(currentContext).pop();

        // Mostrar mensagem de erro
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar relatório: ${e.toString()}'),
            backgroundColor: Colors.red,
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

    // Definir cores para um design mais moderno
    final primaryColor = PdfColors.blueAccent;
    final secondaryColor = PdfColors.blue800;
    final backgroundColor = PdfColors.grey100;
    final textColor = PdfColors.blueGrey800;
    final highlightColor = PdfColors.amber700;

    // Fontes básicas sem suporte a Unicode
    final baseFont = pw.Font.courier();
    final boldFont = pw.Font.courierBold();
    final italicFont = pw.Font.courierOblique();

    // Variáveis auxiliares para cálculos
    final totalValue = orderStore.totalRevenue;
    final hasRecentOrders = orderStore.recentOrders.isNotEmpty;
    final hasCustomerRanking = orderStore.customerRanking.isNotEmpty;

    // Cálculo de porcentagens com segurança contra divisão por zero
    final paidPercentage = totalValue > 0
        ? (orderStore.totalPaidAmount / totalValue * 100).toStringAsFixed(1)
        : "0";
    final unpaidPercentage = totalValue > 0
        ? (orderStore.totalUnpaidAmount / totalValue * 100).toStringAsFixed(1)
        : "0";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        header: (context) {
          return pw.Container(
            color: primaryColor,
            padding: pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isClientSelected
                          ? 'Relatório Financeiro - Cliente'
                          : 'PraticOS - Relatório Financeiro',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _latinCharactersOnly(Global.companyAggr?.name ?? ''),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  _latinCharactersOnly(periodLabel),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: pw.EdgeInsets.only(top: 10),
            padding: pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          List<pw.Widget> content = [];

          if (isClientSelected) {
            // RELATÓRIO ESPECÍFICO PARA CLIENTE SELECIONADO
            final selectedClientData = orderStore.selectedCustomerInRanking!;
            final double clientTotal = selectedClientData['total'] ?? 0.0;
            final double clientUnpaidTotal =
                selectedClientData['unpaidTotal'] ?? 0.0;
            final double clientPaidTotal = clientTotal - clientUnpaidTotal;

            // Pedidos do cliente - filtra por cliente
            var clientOrders = orderStore.recentOrders
                .where(
                    (order) => order?.customer?.id == selectedClientData['id'])
                .toList();

            // Aplica filtro adicional de pagamento, se houver
            if (orderStore.paymentFilter != null) {
              clientOrders = clientOrders
                  .where((order) => order?.payment == orderStore.paymentFilter)
                  .toList();
            }

            // Resumo do Cliente
            content.add(
              pw.Container(
                margin: pw.EdgeInsets.only(bottom: 20),
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: backgroundColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Título
                    pw.Container(
                      padding: pw.EdgeInsets.only(bottom: 8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                            bottom: pw.BorderSide(color: primaryColor)),
                      ),
                      child: pw.Text(
                        'INFORMAÇÕES DO CLIENTE',
                        style: pw.TextStyle(
                          font: boldFont,
                          color: secondaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    // Nome do cliente
                    pw.Container(
                      margin: pw.EdgeInsets.only(top: 10, bottom: 15),
                      padding: pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            'Cliente: ',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 12,
                              color: textColor,
                            ),
                          ),
                          pw.Text(
                            _latinCharactersOnly(selectedClientName),
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 12,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Faturamento Total do Cliente
                    pw.Container(
                      margin: pw.EdgeInsets.symmetric(vertical: 5),
                      padding: pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(5),
                        border: pw.Border.all(color: primaryColor),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'FATURAMENTO TOTAL',
                            style: pw.TextStyle(
                              font: boldFont,
                              color: secondaryColor,
                            ),
                          ),
                          pw.Text(
                            _convertToCurrency(clientTotal),
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              color: highlightColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // Valores Pagos/A Receber
                    pw.Row(
                      children: [
                        // Recebido
                        pw.Expanded(
                          child: pw.Container(
                            padding: pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(5),
                              border: pw.Border.all(color: PdfColors.green),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 10,
                                      height: 10,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.green,
                                        shape: pw.BoxShape.circle,
                                      ),
                                    ),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      'Recebido',
                                      style: pw.TextStyle(
                                        font: boldFont,
                                        color: PdfColors.green800,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  'Quantidade: ${clientOrders.where((order) => order?.payment == 'paid').length}',
                                  style: pw.TextStyle(
                                    font: baseFont,
                                    fontSize: 10,
                                    color: textColor,
                                  ),
                                ),
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  _convertToCurrency(clientPaidTotal),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 14,
                                    color: PdfColors.green800,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                if (clientTotal > 0)
                                  pw.Text(
                                    '${(clientPaidTotal / clientTotal * 100).toStringAsFixed(1)}% do total',
                                    style: pw.TextStyle(
                                      font: italicFont,
                                      fontSize: 9,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        pw.SizedBox(width: 10),

                        // A Receber
                        pw.Expanded(
                          child: pw.Container(
                            padding: pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(5),
                              border: pw.Border.all(color: PdfColors.red),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 10,
                                      height: 10,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.red,
                                        shape: pw.BoxShape.circle,
                                      ),
                                    ),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      'A Receber',
                                      style: pw.TextStyle(
                                        font: boldFont,
                                        color: PdfColors.red800,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  'Quantidade: ${clientOrders.where((order) => order?.payment == 'unpaid').length}',
                                  style: pw.TextStyle(
                                    font: baseFont,
                                    fontSize: 10,
                                    color: textColor,
                                  ),
                                ),
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  _convertToCurrency(clientUnpaidTotal),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 14,
                                    color: PdfColors.red800,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                if (clientTotal > 0)
                                  pw.Text(
                                    '${(clientUnpaidTotal / clientTotal * 100).toStringAsFixed(1)}% do total',
                                    style: pw.TextStyle(
                                      font: italicFont,
                                      fontSize: 9,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            // Pedidos do Cliente
            if (clientOrders.isNotEmpty) {
              final tableData = List<List<String>>.generate(
                clientOrders.length,
                (index) {
                  final order = clientOrders[index];
                  final dateStr = order?.createdAt != null
                      ? DateFormat('dd/MM/yyyy').format(order!.createdAt!)
                      : '';
                  final isPaid = order?.payment == 'paid';

                  // Obter informações do veículo
                  String vehicleInfo = _getVehicleInfo(order);

                  return [
                    '#${order?.number ?? ""}',
                    dateStr,
                    vehicleInfo,
                    _convertToCurrency(order?.total ?? 0.0),
                    isPaid ? 'Pago' : 'A receber',
                  ];
                },
              );

              content.add(
                pw.Container(
                  margin: pw.EdgeInsets.only(bottom: 20),
                  padding: pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: backgroundColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Título
                      pw.Container(
                        padding: pw.EdgeInsets.only(bottom: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                              bottom: pw.BorderSide(color: primaryColor)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text(
                              'ORDENS DE SERVIÇO',
                              style: pw.TextStyle(
                                font: boldFont,
                                color: secondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),

                      // Tabela de pedidos do cliente
                      pw.Table.fromTextArray(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        headerStyle: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                        headerDecoration: pw.BoxDecoration(
                          color: secondaryColor,
                        ),
                        cellStyle: pw.TextStyle(
                          font: baseFont,
                          color: textColor,
                          fontSize: 9,
                        ),
                        cellPadding: pw.EdgeInsets.all(4),
                        cellHeight: 20,
                        columnWidths: {
                          0: const pw.FlexColumnWidth(0.8),
                          1: const pw.FlexColumnWidth(1.8),
                          2: const pw.FlexColumnWidth(2),
                          3: const pw.FlexColumnWidth(1.5),
                          4: const pw.FlexColumnWidth(1.5),
                        },
                        cellAlignments: {
                          0: pw.Alignment.center,
                          1: pw.Alignment.center,
                          2: pw.Alignment.centerLeft,
                          3: pw.Alignment.centerRight,
                          4: pw.Alignment.center,
                        },
                        headers: [
                          'OS',
                          'Data',
                          'Veículo',
                          'Valor',
                          'Status',
                        ],
                        data: tableData,
                      ),
                    ],
                  ),
                ),
              );
            }
          } else {
            // RELATÓRIO GERAL (SEM CLIENTE SELECIONADO)

            // Resumo Financeiro
            content.add(
              pw.Container(
                margin: pw.EdgeInsets.only(bottom: 20),
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: backgroundColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Título
                    pw.Container(
                      padding: pw.EdgeInsets.only(bottom: 8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                            bottom: pw.BorderSide(color: primaryColor)),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            'RESUMO FINANCEIRO',
                            style: pw.TextStyle(
                              font: boldFont,
                              color: secondaryColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    // Faturamento Total
                    pw.Container(
                      margin: pw.EdgeInsets.symmetric(vertical: 5),
                      padding: pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(5),
                        border: pw.Border.all(color: primaryColor),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'FATURAMENTO TOTAL',
                            style: pw.TextStyle(
                              font: boldFont,
                              color: secondaryColor,
                            ),
                          ),
                          pw.Text(
                            _convertToCurrency(orderStore.totalRevenue),
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              color: highlightColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // Valores Pagos/A Receber
                    pw.Row(
                      children: [
                        // Recebido
                        pw.Expanded(
                          child: pw.Container(
                            padding: pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(5),
                              border: pw.Border.all(color: PdfColors.green),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 10,
                                      height: 10,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.green,
                                        shape: pw.BoxShape.circle,
                                      ),
                                    ),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      'Recebido',
                                      style: pw.TextStyle(
                                        font: boldFont,
                                        color: PdfColors.green800,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  'Quantidade: ${orderStore.recentOrders.where((order) => order?.payment == 'paid').length}',
                                  style: pw.TextStyle(
                                    font: baseFont,
                                    fontSize: 10,
                                    color: textColor,
                                  ),
                                ),
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  _convertToCurrency(
                                      orderStore.totalPaidAmount),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 14,
                                    color: PdfColors.green800,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  '$paidPercentage% do total',
                                  style: pw.TextStyle(
                                    font: italicFont,
                                    fontSize: 9,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        pw.SizedBox(width: 10),

                        // A Receber
                        pw.Expanded(
                          child: pw.Container(
                            padding: pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(5),
                              border: pw.Border.all(color: PdfColors.red),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 10,
                                      height: 10,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.red,
                                        shape: pw.BoxShape.circle,
                                      ),
                                    ),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      'A Receber',
                                      style: pw.TextStyle(
                                        font: boldFont,
                                        color: PdfColors.red800,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  'Quantidade: ${orderStore.recentOrders.where((order) => order?.payment == 'unpaid').length}',
                                  style: pw.TextStyle(
                                    font: baseFont,
                                    fontSize: 10,
                                    color: textColor,
                                  ),
                                ),
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  _convertToCurrency(
                                      orderStore.totalUnpaidAmount),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 14,
                                    color: PdfColors.red800,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  '$unpaidPercentage% do total',
                                  style: pw.TextStyle(
                                    font: italicFont,
                                    fontSize: 9,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            // Ranking de Clientes
            if (hasCustomerRanking) {
              // Filtrar e ordenar o ranking de acordo com o filtro de pagamento
              var filteredRanking = List.from(orderStore.customerRanking);

              // Aplicar filtro se necessário
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

                // Reordenar baseado no filtro
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
                  margin: pw.EdgeInsets.only(bottom: 20),
                  padding: pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: backgroundColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Título
                      pw.Container(
                        padding: pw.EdgeInsets.only(bottom: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                              bottom: pw.BorderSide(color: primaryColor)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text(
                              orderStore.paymentFilter == 'paid'
                                  ? 'RANKING DE CLIENTES - RECEBIDO'
                                  : orderStore.paymentFilter == 'unpaid'
                                      ? 'RANKING DE CLIENTES - A RECEBER'
                                      : 'RANKING DE CLIENTES',
                              style: pw.TextStyle(
                                font: boldFont,
                                color: secondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),

                      // Tabela de clientes
                      pw.Table.fromTextArray(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        headerStyle: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                        headerDecoration: pw.BoxDecoration(
                          color: secondaryColor,
                        ),
                        cellStyle: pw.TextStyle(
                          font: baseFont,
                          color: textColor,
                          fontSize: 9,
                        ),
                        cellPadding: pw.EdgeInsets.all(4),
                        cellHeight: 20,
                        cellAlignments: {
                          0: pw.Alignment.center,
                          1: pw.Alignment.centerLeft,
                          2: pw.Alignment.centerRight,
                          3: pw.Alignment.centerRight,
                          4: pw.Alignment.centerRight,
                        },
                        headers: [
                          'Pos',
                          'Cliente',
                          'Valor Pago',
                          'A Receber',
                          'Total',
                        ],
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
                              _latinCharactersOnly(filteredRanking[index]
                                      ['name'] ??
                                  'Cliente sem nome'),
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

            // Pedidos Recentes
            if (hasRecentOrders) {
              // Filtrar ordens de acordo com o filtro de pagamento
              final filteredOrders = orderStore.paymentFilter == null
                  ? orderStore.recentOrders
                  : orderStore.recentOrders
                      .where(
                          (order) => order?.payment == orderStore.paymentFilter)
                      .toList();

              final tableData = List<List<String>>.generate(
                filteredOrders.length,
                (index) {
                  final order = filteredOrders[index];
                  final dateStr = order?.createdAt != null
                      ? DateFormat('dd/MM/yyyy').format(order!.createdAt!)
                      : '';
                  final isPaid = order?.payment == 'paid';

                  // Obter informações do veículo
                  String vehicleInfo = _getVehicleInfo(order);

                  return [
                    '#${order?.number ?? ""}',
                    _latinCharactersOnly(order?.customer?.name ?? 'Cliente'),
                    vehicleInfo,
                    dateStr,
                    _convertToCurrency(order?.total ?? 0.0),
                    isPaid ? 'Pago' : 'A receber',
                  ];
                },
              );

              content.add(
                pw.Container(
                  margin: pw.EdgeInsets.only(bottom: 20),
                  padding: pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: backgroundColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Título
                      pw.Container(
                        padding: pw.EdgeInsets.only(bottom: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                              bottom: pw.BorderSide(color: primaryColor)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text(
                              'ORDENS DE SERVIÇO',
                              style: pw.TextStyle(
                                font: boldFont,
                                color: secondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),

                      // Tabela de pedidos
                      pw.Table.fromTextArray(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        headerStyle: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                        headerDecoration: pw.BoxDecoration(
                          color: secondaryColor,
                        ),
                        cellStyle: pw.TextStyle(
                          font: baseFont,
                          color: textColor,
                          fontSize: 9,
                        ),
                        cellPadding: pw.EdgeInsets.all(4),
                        cellHeight: 20,
                        columnWidths: {
                          0: const pw.FlexColumnWidth(0.8),
                          1: const pw.FlexColumnWidth(2),
                          2: const pw.FlexColumnWidth(2),
                          3: const pw.FlexColumnWidth(1.8),
                          4: const pw.FlexColumnWidth(1.5),
                          5: const pw.FlexColumnWidth(1.5),
                        },
                        cellAlignments: {
                          0: pw.Alignment.center,
                          1: pw.Alignment.centerLeft,
                          2: pw.Alignment.centerLeft,
                          3: pw.Alignment.center,
                          4: pw.Alignment.centerRight,
                          5: pw.Alignment.center,
                        },
                        headers: [
                          'OS',
                          'Cliente',
                          'Veículo',
                          'Data',
                          'Valor',
                          'Status',
                        ],
                        data: tableData,
                      ),
                    ],
                  ),
                ),
              );
            }
          }

          // Rodapé adicional
          content.add(
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(5),
                border: pw.Border.all(color: PdfColors.blue100),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'PraticOS - Sistema de Gestão Automotiva',
                    style: pw.TextStyle(
                      font: italicFont,
                      fontSize: 10,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );

          return content;
        },
      ),
    );

    return pdf.save();
  }

  // Função auxiliar para remover acentos e caracteres especiais
  String _latinCharactersOnly(String text) {
    if (text.isEmpty) {
      return '';
    }

    // Mapeamento simples para caracteres latinos comuns
    final Map<String, String> accentMap = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ã': 'A',
      'Ä': 'A',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ö': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'Ç': 'C',
      'Ñ': 'N',
    };

    try {
      String result = text;
      accentMap.forEach((key, value) {
        result = result.replaceAll(key, value);
      });

      // Remover outros caracteres não ASCII que possam causar problemas
      result = result.replaceAll(RegExp(r'[^\x00-\x7F]'), '');

      return result;
    } catch (e) {
      // Em caso de erro, retornar uma string vazia ou safe
      return 'texto';
    }
  }
}
