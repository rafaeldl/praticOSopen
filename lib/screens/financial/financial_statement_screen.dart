import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_account_store.dart';
import 'package:praticos/mobx/financial_payment_store.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/screens/financial/widgets/balance_header.dart';
import 'package:praticos/screens/financial/widgets/financial_onboarding_sheet.dart';
import 'package:praticos/screens/financial/widgets/payment_timeline_item.dart';
import 'package:praticos/services/format_service.dart';

/// Main financial statement screen showing balance, month navigation,
/// and a timeline of payments grouped by date.
class FinancialStatementScreen extends StatefulWidget {
  const FinancialStatementScreen({super.key});

  @override
  State<FinancialStatementScreen> createState() =>
      _FinancialStatementScreenState();
}

class _FinancialStatementScreenState extends State<FinancialStatementScreen> {
  final FinancialPaymentStore _paymentStore = FinancialPaymentStore();
  final FinancialAccountStore _accountStore = FinancialAccountStore();

  DateTime _currentMonth = DateTime.now();
  FinancialPaymentType? _filterType;

  @override
  void initState() {
    super.initState();
    // Delay loading until companyId is resolved from SharedPreferences
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _accountStore.load();
        _loadCurrentMonth();
      }
    });
  }

  void _loadCurrentMonth() {
    final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);
    _paymentStore.loadPayments(start, end);
    _paymentStore.loadKPIs(start, end);
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadCurrentMonth();
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadCurrentMonth();
  }

  List<FinancialPayment> _filterPayments(List<FinancialPayment?> payments) {
    final active = payments
        .where((p) => p != null && p.deletedAt == null)
        .cast<FinancialPayment>()
        .toList();

    if (_filterType == null) return active;
    return active.where((p) => p.type == _filterType).toList();
  }

  Map<String, List<FinancialPayment>> _groupByDate(
      List<FinancialPayment> payments) {
    final grouped = <String, List<FinancialPayment>>{};
    // Sort by paymentDate descending
    payments.sort((a, b) {
      final dateA = a.paymentDate ?? a.createdAt ?? DateTime(2000);
      final dateB = b.paymentDate ?? b.createdAt ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    for (final payment in payments) {
      final date = payment.paymentDate ?? payment.createdAt ?? DateTime(2000);
      final key = DateFormat('yyyy-MM-dd').format(date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(payment);
    }
    return grouped;
  }

  String _formatDateGroupLabel(BuildContext context, String dateKey) {
    final date = DateFormat('yyyy-MM-dd').parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) return context.l10n.today;
    if (dateDay == yesterday) return context.l10n.yesterday;
    return FormatService().formatDate(date);
  }

  void _showFilterSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.all),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _filterType = null);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.all),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _filterType = FinancialPaymentType.income);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.entries),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _filterType = FinancialPaymentType.expense);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.exits),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _filterType = FinancialPaymentType.transfer);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.transfers),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  void _showFABSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/financial_entry_form',
                  arguments: {'direction': 'payable'});
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.arrow_up_right,
                    color: CupertinoColors.systemRed, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.newExpense),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/financial_entry_form',
                  arguments: {'direction': 'receivable'});
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.arrow_down_left,
                    color: CupertinoColors.systemGreen, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.newIncome),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  void _showOnboarding() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => FinancialOnboardingSheet(
        accountStore: _accountStore,
        onComplete: () {
          Navigator.pop(ctx);
          // Reload accounts and payments after onboarding
          _accountStore.load();
          _loadCurrentMonth();
        },
      ),
    );
  }

  Widget _buildFirstVisitEmptyState(BuildContext context) {
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.briefcase,
              size: 64,
              color: secondaryLabelColor,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.setupFinancial,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: labelColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              child: Text(
                context.l10n.setupFinancialDescription,
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryLabelColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _showOnboarding,
              child: Text(context.l10n.getStarted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMovementsEmptyState(BuildContext context) {
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final monthName = DateFormat.yMMMM(
      Localizations.localeOf(context).toString(),
    ).format(_currentMonth);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.noMovements(monthName),
              style: TextStyle(
                fontSize: 15,
                color: secondaryLabelColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onPressed: () {
                    Navigator.pushNamed(context, '/financial_entry_form',
                        arguments: {'direction': 'payable'});
                  },
                  child: Text(context.l10n.registerExpense),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onPressed: () {
                    Navigator.pushNamed(context, '/financial_entry_form',
                        arguments: {'direction': 'receivable'});
                  },
                  child: Text(context.l10n.registerIncome),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: Stack(
        children: [
          Observer(
            builder: (_) {
              final accounts = _accountStore.accountList?.value ?? [];
              final hasAccounts = accounts
                  .where((a) => a != null && (a.active ?? false))
                  .isNotEmpty;

              // First visit: no accounts at all
              if (!hasAccounts) {
                return CustomScrollView(
                  slivers: [
                    CupertinoSliverNavigationBar(
                      largeTitle: Text(context.l10n.financialStatement),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildFirstVisitEmptyState(context),
                    ),
                  ],
                );
              }

              final payments = _paymentStore.paymentList?.value ?? [];
              final filtered = _filterPayments(payments);
              final grouped = _groupByDate(filtered);
              final dateKeys = grouped.keys.toList();

              return CustomScrollView(
                slivers: [
                  CupertinoSliverNavigationBar(
                    largeTitle: Text(context.l10n.financialStatement),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _showFilterSheet,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              _filterType != null
                                  ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
                                  : CupertinoIcons.line_horizontal_3_decrease_circle,
                              size: 22,
                              color: CupertinoColors.activeBlue,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                              context, '/financial_account_list'),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              CupertinoIcons.creditcard,
                              size: 22,
                              color: CupertinoColors.activeBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Balance header
                  SliverToBoxAdapter(
                    child: BalanceHeader(
                      totalBalance: _accountStore.totalBalance,
                      totalIncome: _paymentStore.totalIncome,
                      totalExpense: _paymentStore.totalExpense,
                      todayIncome: _paymentStore.todayIncome,
                      todayExpense: _paymentStore.todayExpense,
                      currentMonth: _currentMonth,
                      onPreviousMonth: _goToPreviousMonth,
                      onNextMonth: _goToNextMonth,
                    ),
                  ),

                  // No movements empty state
                  if (dateKeys.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildNoMovementsEmptyState(context),
                    ),

                  // Payment list grouped by date
                  if (dateKeys.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final dateKey = dateKeys[index];
                          final dayPayments = grouped[dateKey]!;
                          final label =
                              _formatDateGroupLabel(context, dateKey);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date separator
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: separatorColor,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: secondaryLabelColor,
                                  ),
                                ),
                              ),
                              // Payment items
                              ...dayPayments.map(
                                (payment) => PaymentTimelineItem(
                                  payment: payment,
                                  onOrderTap: payment.orderId != null
                                      ? () => Navigator.pushNamed(
                                          context, '/order',
                                          arguments: payment.orderId)
                                      : null,
                                  onReverse: (payment, reason) async {
                                    if (payment.type ==
                                        FinancialPaymentType.transfer) {
                                      await _paymentStore.reverseTransfer(
                                          payment, reason);
                                    } else {
                                      await _paymentStore.reversePayment(
                                          payment, reason);
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        childCount: dateKeys.length,
                      ),
                    ),

                  // Bottom padding for FAB
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              );
            },
          ),

          // FAB - only show when accounts exist
          Observer(
            builder: (_) {
              final accounts = _accountStore.accountList?.value ?? [];
              final hasAccounts = accounts
                  .where((a) => a != null && (a.active ?? false))
                  .isNotEmpty;

              if (!hasAccounts) return const SizedBox.shrink();

              return Positioned(
                right: 16,
                bottom: 16,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showFABSheet,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.activeBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.add,
                      color: CupertinoColors.white,
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
