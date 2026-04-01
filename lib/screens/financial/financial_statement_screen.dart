import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_account_store.dart';
import 'package:praticos/mobx/financial_entry_store.dart';
import 'package:praticos/mobx/financial_payment_store.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/screens/financial/widgets/balance_header.dart';
import 'package:praticos/screens/financial/widgets/entry_timeline_item.dart';
import 'package:praticos/screens/financial/widgets/payment_detail_sheet.dart';
import 'package:praticos/screens/financial/widgets/financial_onboarding_sheet.dart';
import 'package:praticos/screens/financial/widgets/payment_confirmation_sheet.dart';
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
  final FinancialEntryStore _entryStore = FinancialEntryStore();

  DateTime _currentMonth = DateTime.now();
  FinancialPaymentType? _filterType;
  int _activeTab = 0; // 0 = Statement, 1 = Bills
  FinancialEntryDirection? _entryDirectionFilter;
  bool _overdueFilter = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Delay loading until companyId is resolved from SharedPreferences
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _accountStore.load();
        _loadCurrentMonth();
        _entryStore.processRecurrences(); // fire-and-forget
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCurrentMonth() {
    final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);
    _paymentStore.loadPayments(start, end);
    _paymentStore.loadKPIs(start, end);
    _entryStore.loadByDueDateRange(start, end);
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
    var active = payments
        .where((p) => p != null && p.deletedAt == null)
        .cast<FinancialPayment>()
        .toList();

    if (_filterType != null) {
      active = active.where((p) => p.type == _filterType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      active = active.where((p) {
        final query = _searchQuery;
        return (p.description?.toLowerCase().contains(query) ?? false) ||
            (p.supplier?.toLowerCase().contains(query) ?? false) ||
            (p.customer?.name?.toLowerCase().contains(query) ?? false) ||
            (p.category?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return active;
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
    if (_activeTab == 0) {
      _showPaymentFilterSheet();
    } else {
      _showEntryFilterSheet();
    }
  }

  void _showPaymentFilterSheet() {
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

  void _showEntryFilterSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.filter),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _entryDirectionFilter = null;
                _overdueFilter = false;
              });
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.all),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _entryDirectionFilter = FinancialEntryDirection.payable;
                _overdueFilter = false;
              });
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.toPay),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _entryDirectionFilter = FinancialEntryDirection.receivable;
                _overdueFilter = false;
              });
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.toReceive),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _entryDirectionFilter = null;
                _overdueFilter = true;
              });
              Navigator.pop(ctx);
            },
            child: Text(
              context.l10n.overdue,
              style: const TextStyle(color: CupertinoColors.systemOrange),
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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
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

  List<FinancialEntry> _filterEntries(List<FinancialEntry?> entries) {
    var active = entries
        .where((e) => e != null && e.deletedAt == null)
        .cast<FinancialEntry>()
        .toList();

    if (_entryDirectionFilter != null) {
      active = active.where((e) => e.direction == _entryDirectionFilter).toList();
    }

    if (_overdueFilter) {
      active = active.where((e) => e.isOverdue).toList();
    }

    if (_searchQuery.isNotEmpty) {
      active = active.where((e) {
        final query = _searchQuery;
        return (e.description?.toLowerCase().contains(query) ?? false) ||
            (e.supplier?.toLowerCase().contains(query) ?? false) ||
            (e.customer?.name?.toLowerCase().contains(query) ?? false) ||
            (e.category?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return active;
  }

  Map<String, List<FinancialEntry>> _groupEntriesByDueDate(
      List<FinancialEntry> entries) {
    entries.sort((a, b) {
      final dateA = a.dueDate ?? DateTime(2099);
      final dateB = b.dueDate ?? DateTime(2099);
      return dateA.compareTo(dateB);
    });
    final grouped = <String, List<FinancialEntry>>{};
    for (final entry in entries) {
      final date = entry.dueDate ?? DateTime(2099);
      final key = DateFormat('yyyy-MM-dd').format(date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(entry);
    }
    return grouped;
  }

  Widget _buildNoBillsEmptyState(BuildContext context) {
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
              context.l10n.noBillsInMonth(monthName),
              style: TextStyle(
                fontSize: 15,
                color: secondaryLabelColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
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

  void _showPayEntrySheet(FinancialEntry entry) {
    final accounts = _accountStore.accountList?.value
            ?.where((a) => a != null && (a.active ?? false))
            .cast<FinancialAccount>()
            .toList() ??
        [];
    if (accounts.isEmpty) return;

    PaymentConfirmationSheet.show(
      context,
      entry: entry,
      accounts: accounts,
      onConfirm: (amount, accountId, account, method, date,
          {double? discount}) async {
        await _paymentStore.payEntry(
          entry,
          amount: amount,
          accountId: accountId,
          account: account,
          method: method,
          paymentDate: date,
          discount: discount,
        );
      },
    );
  }

  void _showDeleteEntrySheet(FinancialEntry entry) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(entry.description ?? ''),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _entryStore.deleteEntry(entry);
            },
            child: Text(context.l10n.deleteEntry),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _entryStore.cancelEntry(entry);
            },
            child: Text(
              context.l10n.cancelEntry,
              style: const TextStyle(color: CupertinoColors.systemOrange),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  bool get _isFilterActive =>
      _searchQuery.isNotEmpty ||
      (_activeTab == 0 && _filterType != null) ||
      (_activeTab == 1 && (_entryDirectionFilter != null || _overdueFilter));

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: Material(
        type: MaterialType.transparency,
        child: Observer(
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

              // Payment data
              final payments = _paymentStore.paymentList?.value ?? [];
              final filtered = _filterPayments(payments);
              final grouped = _groupByDate(filtered);
              final dateKeys = grouped.keys.toList();

              // Entry data
              final allEntries = _entryStore.monthEntryList?.value ?? [];
              _entryStore.calculateEntryKPIs(allEntries);
              final filteredEntries = _filterEntries(allEntries);
              final groupedEntries = _groupEntriesByDueDate(filteredEntries);
              final entryDateKeys = groupedEntries.keys.toList();

              return CustomScrollView(
                slivers: [
                  CupertinoSliverNavigationBar(
                    largeTitle: Text(context.l10n.financialStatement),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pushNamed(
                              context, '/financial_reports'),
                          child: const Icon(CupertinoIcons.chart_bar,
                              size: 22),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showFilterSheet,
                          child: Icon(
                            _isFilterActive
                                ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
                                : CupertinoIcons.line_horizontal_3_decrease_circle,
                            size: 22,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pushNamed(
                              context, '/financial_account_list'),
                          child: const Icon(CupertinoIcons.creditcard,
                              size: 22),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showFABSheet,
                          child: const Icon(CupertinoIcons.add),
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
                      showEntryKPIs: _activeTab == 1,
                      totalPayable: _entryStore.totalPayable,
                      totalReceivable: _entryStore.totalReceivable,
                      overdueCount: _entryStore.overdueCount,
                      onOverdueTap: _entryStore.overdueCount > 0
                          ? () {
                              setState(() {
                                _activeTab = 1;
                                _overdueFilter = true;
                                _entryDirectionFilter = null;
                              });
                            }
                          : null,
                    ),
                  ),

                  // Segmented control: Statement | Bills
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<int>(
                          groupValue: _activeTab,
                          onValueChanged: (value) {
                            setState(() {
                              _activeTab = value ?? 0;
                            });
                          },
                          children: {
                            0: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: Text(context.l10n.statementTab),
                            ),
                            1: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: Text(context.l10n.billsTab),
                            ),
                          },
                        ),
                      ),
                    ),
                  ),

                  // Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: context.l10n.searchFinancial,
                        onChanged: (value) {
                          setState(() =>
                              _searchQuery = value.toLowerCase());
                        },
                      ),
                    ),
                  ),

                  // === Tab 0: Statement (payments) ===
                  if (_activeTab == 0) ...[
                    if (dateKeys.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildNoMovementsEmptyState(context),
                      ),
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
                                ...dayPayments.map(
                                  (payment) => PaymentTimelineItem(
                                    payment: payment,
                                    onTap: () => PaymentDetailSheet.show(
                                      context,
                                      payment: payment,
                                      companyId: _paymentStore.companyId,
                                      onReverse: (p, reason) async {
                                        if (p.type ==
                                            FinancialPaymentType.transfer) {
                                          await _paymentStore
                                              .reverseTransfer(p, reason);
                                        } else {
                                          await _paymentStore
                                              .reversePayment(p, reason);
                                        }
                                      },
                                      onOrderTap: payment.orderId != null
                                          ? () => Navigator.pushNamed(
                                              context, '/order',
                                              arguments: payment.orderId)
                                          : null,
                                      onAttachmentAdded: (p, url) async {
                                        p.attachments ??= [];
                                        p.attachments!.add(url);
                                        if (_paymentStore.companyId != null) {
                                          await _paymentStore.repository
                                              .updateItem(
                                                  _paymentStore.companyId!,
                                                  p);
                                        }
                                      },
                                    ),
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
                  ],

                  // === Tab 1: Bills (entries) ===
                  if (_activeTab == 1) ...[
                    if (entryDateKeys.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildNoBillsEmptyState(context),
                      ),
                    if (entryDateKeys.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final dateKey = entryDateKeys[index];
                            final dayEntries = groupedEntries[dateKey]!;
                            final label =
                                _formatDateGroupLabel(context, dateKey);
                            final date =
                                DateFormat('yyyy-MM-dd').parse(dateKey);
                            final isOverdueDate = date.isBefore(
                                DateTime.now().subtract(
                                    const Duration(days: 0)));

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                      color: isOverdueDate
                                          ? CupertinoColors.systemOrange
                                          : secondaryLabelColor,
                                    ),
                                  ),
                                ),
                                ...dayEntries.map(
                                  (entry) => EntryTimelineItem(
                                    entry: entry,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/financial_entry_form',
                                      arguments: {
                                        'entryId': entry.id,
                                        'direction':
                                            entry.direction?.name,
                                      },
                                    ),
                                    onSwipePay: entry.status ==
                                            FinancialEntryStatus.pending
                                        ? () => _showPayEntrySheet(entry)
                                        : null,
                                    onSwipeDelete: entry.status ==
                                            FinancialEntryStatus.pending
                                        ? () => _showDeleteEntrySheet(entry)
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          },
                          childCount: entryDateKeys.length,
                        ),
                      ),
                  ],

                ],
              );
            },
          ),
      ),
    );
  }
}
