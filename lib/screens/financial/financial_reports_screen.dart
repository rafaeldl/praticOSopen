import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_account_store.dart';
import 'package:praticos/mobx/financial_entry_store.dart';
import 'package:praticos/mobx/financial_payment_store.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/services/format_service.dart';

/// Data class for projected month in cash flow projection.
class _ProjectedMonth {
  final DateTime month;
  final double receivables;
  final double payables;
  final double projectedBalance;

  _ProjectedMonth(this.month, this.receivables, this.payables,
      this.projectedBalance);
}

/// Data class for a single month of income vs expenses.
class _MonthlyBar {
  final DateTime month;
  final double income;
  final double expense;

  _MonthlyBar(this.month, this.income, this.expense);
}

/// Reports screen with monthly summary (DRE simplified), cash flow projection,
/// and charts (bar + pie) using fl_chart.
class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() =>
      _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  final FinancialPaymentStore _paymentStore = FinancialPaymentStore();
  final FinancialAccountStore _accountStore = FinancialAccountStore();
  final FinancialEntryStore _entryStore = FinancialEntryStore();

  DateTime _currentMonth = DateTime.now();

  // Data holders (populated after loading)
  List<FinancialPayment> _currentMonthPayments = [];
  List<FinancialPayment> _last6MonthsPayments = [];
  List<FinancialEntry> _pendingEntries = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _accountStore.load();
        _entryStore.load();
        _loadData();
      }
    });
  }

  void _loadData() {
    setState(() => _isLoading = true);
    _loadCurrentMonthPayments();
    _loadLast6Months();
    _loadPendingEntries();
  }

  void _loadCurrentMonthPayments() {
    final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final end =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);
    _paymentStore.repository
        .streamByDateRange(_paymentStore.companyId ?? '', start, end)
        .first
        .then((payments) {
      if (mounted) {
        setState(() {
          _currentMonthPayments = payments
              .where((p) => p != null && p.deletedAt == null)
              .cast<FinancialPayment>()
              .toList();
        });
      }
    }).catchError((_) {});
  }

  void _loadLast6Months() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 5, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _paymentStore.repository
        .streamByDateRange(_paymentStore.companyId ?? '', start, end)
        .first
        .then((payments) {
      if (mounted) {
        setState(() {
          _last6MonthsPayments = payments
              .where((p) => p != null && p.deletedAt == null)
              .cast<FinancialPayment>()
              .toList();
          _isLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _loadPendingEntries() {
    final companyId = _entryStore.companyId;
    if (companyId == null) return;
    _entryStore.repository.streamPending(companyId).first.then((entries) {
      if (mounted) {
        setState(() {
          _pendingEntries = entries
              .where((e) => e != null && e.deletedAt == null)
              .cast<FinancialEntry>()
              .toList();
        });
      }
    }).catchError((_) {});
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadCurrentMonthPayments();
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadCurrentMonthPayments();
  }

  // ──────────────────────────────────────────────────────────
  // Data helpers
  // ──────────────────────────────────────────────────────────

  Map<String, double> _groupByCategory(
      List<FinancialPayment> payments, FinancialPaymentType type) {
    final map = <String, double>{};
    for (final p in payments) {
      if (p.type != type) continue;
      if (p.status != FinancialPaymentStatus.completed) continue;
      final cat = p.category ?? context.l10n.others;
      map[cat] = (map[cat] ?? 0) + (p.amount ?? 0);
    }
    return map;
  }

  List<_ProjectedMonth> _calculateProjection(
      double currentBalance, List<FinancialEntry> pendingEntries) {
    final now = DateTime.now();
    final months = <_ProjectedMonth>[];
    double running = currentBalance;

    for (var i = 1; i <= 3; i++) {
      final start = DateTime(now.year, now.month + i, 1);
      final end = DateTime(now.year, now.month + i + 1, 0);

      double receivables = 0, payables = 0;
      for (final e in pendingEntries) {
        if (e.dueDate == null) continue;
        if (e.dueDate!.isBefore(start) || e.dueDate!.isAfter(end)) continue;
        if (e.direction == FinancialEntryDirection.receivable) {
          receivables += e.remainingBalance;
        } else {
          payables += e.remainingBalance;
        }
      }
      running += receivables - payables;
      months.add(_ProjectedMonth(start, receivables, payables, running));
    }
    return months;
  }

  List<_MonthlyBar> _buildMonthlyBars() {
    final now = DateTime.now();
    final bars = <_MonthlyBar>[];

    for (var i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      double income = 0, expense = 0;
      for (final p in _last6MonthsPayments) {
        if (p.status != FinancialPaymentStatus.completed) continue;
        final date = p.paymentDate ?? p.createdAt;
        if (date == null) continue;
        if (date.isBefore(monthDate) || !date.isBefore(nextMonth)) continue;
        if (p.type == FinancialPaymentType.income) {
          income += p.amount ?? 0;
        } else if (p.type == FinancialPaymentType.expense) {
          expense += p.amount ?? 0;
        }
      }
      bars.add(_MonthlyBar(monthDate, income, expense));
    }
    return bars;
  }

  // ──────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabel =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(context.l10n.reports),
            previousPageTitle: context.l10n.financialStatement,
          ),
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            )
          else ...[
            // 1. Monthly Summary (DRE simplified)
            SliverToBoxAdapter(
              child: _buildMonthlySummary(
                  context, labelColor, secondaryLabel),
            ),

            // 2. Cash Flow Projection
            SliverToBoxAdapter(
              child: Observer(
                builder: (_) => _buildProjection(
                    context, labelColor, secondaryLabel),
              ),
            ),

            // 3. Bar Chart - Income vs Expenses
            SliverToBoxAdapter(
              child: _buildBarChart(context, labelColor, secondaryLabel),
            ),

            // 4. Pie Chart - Expenses by Category
            SliverToBoxAdapter(
              child:
                  _buildPieChart(context, labelColor, secondaryLabel),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Section 1: Monthly Summary
  // ──────────────────────────────────────────────────────────

  Widget _buildMonthlySummary(
      BuildContext context, Color labelColor, Color secondaryLabel) {
    final formatService = FormatService();
    final incomeByCategory =
        _groupByCategory(_currentMonthPayments, FinancialPaymentType.income);
    final expenseByCategory =
        _groupByCategory(_currentMonthPayments, FinancialPaymentType.expense);

    final totalIncome =
        incomeByCategory.values.fold<double>(0, (a, b) => a + b);
    final totalExpense =
        expenseByCategory.values.fold<double>(0, (a, b) => a + b);
    final result = totalIncome - totalExpense;
    final margin = totalIncome > 0 ? (result / totalIncome * 100) : 0.0;

    final monthName = DateFormat.yMMMM(
      Localizations.localeOf(context).toString(),
    ).format(_currentMonth);

    final cardBg =
        CupertinoColors.systemBackground.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with month selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                context.l10n.monthlySummary,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            // Month selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _goToPreviousMonth,
                    child: const Icon(CupertinoIcons.chevron_left,
                        size: 20),
                  ),
                  Text(
                    monthName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _goToNextMonth,
                    child: const Icon(CupertinoIcons.chevron_right,
                        size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 0.5, color: separatorColor),

            // Revenue section
            if (incomeByCategory.isNotEmpty) ...[
              _buildCategorySection(
                context,
                context.l10n.revenue,
                incomeByCategory,
                CupertinoColors.systemGreen,
                formatService,
                labelColor,
                secondaryLabel,
              ),
              Container(height: 0.5, color: separatorColor),
            ],

            // Expenses section
            if (expenseByCategory.isNotEmpty) ...[
              _buildCategorySection(
                context,
                context.l10n.expenses,
                expenseByCategory,
                CupertinoColors.systemRed,
                formatService,
                labelColor,
                secondaryLabel,
              ),
              Container(height: 0.5, color: separatorColor),
            ],

            // No data
            if (incomeByCategory.isEmpty && expenseByCategory.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    context.l10n.noDataForPeriod,
                    style: TextStyle(
                      fontSize: 15,
                      color: secondaryLabel,
                    ),
                  ),
                ),
              ),

            // Totals
            if (incomeByCategory.isNotEmpty ||
                expenseByCategory.isNotEmpty) ...[
              _buildTotalRow(context.l10n.revenue,
                  formatService.formatCurrency(totalIncome),
                  CupertinoColors.systemGreen, labelColor),
              _buildTotalRow(context.l10n.expenses,
                  formatService.formatCurrency(totalExpense),
                  CupertinoColors.systemRed, labelColor),
              Container(height: 0.5, color: separatorColor),
              _buildTotalRow(
                context.l10n.result,
                formatService.formatCurrency(result),
                result >= 0
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemRed,
                labelColor,
                isBold: true,
              ),
              _buildTotalRow(
                context.l10n.margin,
                '${margin.toStringAsFixed(1)}%',
                result >= 0
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemRed,
                labelColor,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    Map<String, double> categories,
    Color titleColor,
    FormatService formatService,
    Color labelColor,
    Color secondaryLabel,
  ) {
    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: titleColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...sorted.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryLabel,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatService.formatCurrency(entry.value),
                      style: TextStyle(
                        fontSize: 14,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
      String label, String value, Color valueColor, Color labelColor,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: labelColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Section 2: Cash Flow Projection
  // ──────────────────────────────────────────────────────────

  Widget _buildProjection(
      BuildContext context, Color labelColor, Color secondaryLabel) {
    final formatService = FormatService();
    final currentBalance = _accountStore.totalBalance;
    final projection = _calculateProjection(currentBalance, _pendingEntries);
    final cardBg =
        CupertinoColors.systemBackground.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                context.l10n.projection,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            ...projection.map((pm) {
              final monthName = DateFormat.yMMM(
                Localizations.localeOf(context).toString(),
              ).format(pm.month);

              return Column(
                children: [
                  Container(height: 0.5, color: separatorColor),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monthName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildProjectionItem(
                                context.l10n.toReceive,
                                formatService
                                    .formatCurrency(pm.receivables),
                                CupertinoColors.systemGreen,
                                secondaryLabel,
                              ),
                            ),
                            Expanded(
                              child: _buildProjectionItem(
                                context.l10n.toPay,
                                formatService.formatCurrency(pm.payables),
                                CupertinoColors.systemRed,
                                secondaryLabel,
                              ),
                            ),
                            Expanded(
                              child: _buildProjectionItem(
                                context.l10n.projectedBalance,
                                formatService
                                    .formatCurrency(pm.projectedBalance),
                                pm.projectedBalance >= 0
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemRed,
                                secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionItem(
      String label, String value, Color valueColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // Section 3: Bar Chart
  // ──────────────────────────────────────────────────────────

  Widget _buildBarChart(
      BuildContext context, Color labelColor, Color secondaryLabel) {
    final bars = _buildMonthlyBars();
    final cardBg =
        CupertinoColors.systemBackground.resolveFrom(context);

    final maxVal = bars.fold<double>(
        0, (m, b) => max(m, max(b.income, b.expense)));
    final maxY = maxVal > 0 ? maxVal * 1.2 : 1000.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                context.l10n.incomeVsExpenses,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            return Text(
                              _formatCompactCurrency(value),
                              style: TextStyle(
                                fontSize: 10,
                                color: secondaryLabel,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= bars.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat.MMM(
                                  Localizations.localeOf(context)
                                      .toString(),
                                ).format(bars[idx].month),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: secondaryLabel,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: CupertinoColors.separator
                            .resolveFrom(context),
                        strokeWidth: 0.5,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(bars.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: bars[i].income,
                            color: CupertinoColors.systemGreen,
                            width: 12,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: bars[i].expense,
                            color: CupertinoColors.systemRed,
                            width: 12,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            // Legend
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendDot(CupertinoColors.systemGreen,
                      context.l10n.revenue, secondaryLabel),
                  const SizedBox(width: 24),
                  _buildLegendDot(CupertinoColors.systemRed,
                      context.l10n.expenses, secondaryLabel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompactCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  // ──────────────────────────────────────────────────────────
  // Section 4: Pie Chart
  // ──────────────────────────────────────────────────────────

  Widget _buildPieChart(
      BuildContext context, Color labelColor, Color secondaryLabel) {
    final formatService = FormatService();
    final expenseByCategory =
        _groupByCategory(_currentMonthPayments, FinancialPaymentType.expense);

    final cardBg =
        CupertinoColors.systemBackground.resolveFrom(context);

    if (expenseByCategory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.expensesByCategory,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    context.l10n.noDataForPeriod,
                    style: TextStyle(
                      fontSize: 15,
                      color: secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sort and get top 5 + others
    final sorted = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = sorted.take(5).toList();
    final othersTotal = sorted.skip(5).fold<double>(0, (a, b) => a + b.value);
    if (othersTotal > 0) {
      top5.add(MapEntry(context.l10n.others, othersTotal));
    }

    final total = top5.fold<double>(0, (a, b) => a + b.value);

    const categoryColors = [
      CupertinoColors.systemBlue,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
      CupertinoColors.systemYellow,
      CupertinoColors.systemGrey,
    ];

    final sections = List.generate(top5.length, (i) {
      final pct = total > 0 ? (top5[i].value / total * 100) : 0.0;
      return PieChartSectionData(
        value: top5[i].value,
        color: categoryColors[i % categoryColors.length],
        radius: 60,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.white,
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                context.l10n.expensesByCategory,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 32,
                  sectionsSpace: 2,
                ),
              ),
            ),
            // Legend
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: List.generate(top5.length, (i) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color:
                              categoryColors[i % categoryColors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${top5[i].key} (${formatService.formatCurrency(top5[i].value)})',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryLabel,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
