import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/financial_payment.dart';

class FinancialKPIs {
  final double totalIncome;
  final double totalExpense;
  final double todayIncome;
  final double todayExpense;

  double get profit => totalIncome - totalExpense;
  double get todayProfit => todayIncome - todayExpense;

  const FinancialKPIs({
    required this.totalIncome,
    required this.totalExpense,
    required this.todayIncome,
    required this.todayExpense,
  });
}

class FinancialUtils {
  /// Computes the real balance of an account from its initial balance
  /// and all associated payments. Skips reversed and deleted payments.
  static double computeRealBalance(
    double initialBalance,
    List<FinancialPayment?> payments,
  ) {
    double balance = initialBalance;
    for (final p in payments) {
      if (p == null || p.deletedAt != null) continue;
      if (p.status == FinancialPaymentStatus.reversed) continue;
      if (p.type == FinancialPaymentType.income) balance += p.amount ?? 0;
      if (p.type == FinancialPaymentType.expense) balance -= p.amount ?? 0;
      if (p.type == FinancialPaymentType.transfer) {
        if (p.transferDirection == 'out') balance -= p.amount ?? 0;
        if (p.transferDirection == 'in') balance += p.amount ?? 0;
      }
    }
    return balance;
  }

  /// Computes financial KPIs from a list of payments.
  /// Filters only completed, non-deleted payments.
  /// [today] allows injecting a fixed date for testing.
  static FinancialKPIs computeKPIs(
    List<FinancialPayment?> payments, {
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final active = payments
        .where((p) =>
            p != null &&
            p.status == FinancialPaymentStatus.completed &&
            p.deletedAt == null)
        .cast<FinancialPayment>();

    final totalIncome = active
        .where((p) => p.type == FinancialPaymentType.income)
        .fold<double>(0, (acc, p) => acc + (p.amount ?? 0));

    final totalExpense = active
        .where((p) => p.type == FinancialPaymentType.expense)
        .fold<double>(0, (acc, p) => acc + (p.amount ?? 0));

    final todayPayments = active.where((p) =>
        p.paymentDate != null &&
        !p.paymentDate!.isBefore(todayStart) &&
        p.paymentDate!.isBefore(todayEnd));

    final todayIncome = todayPayments
        .where((p) => p.type == FinancialPaymentType.income)
        .fold<double>(0, (acc, p) => acc + (p.amount ?? 0));

    final todayExpense = todayPayments
        .where((p) => p.type == FinancialPaymentType.expense)
        .fold<double>(0, (acc, p) => acc + (p.amount ?? 0));

    return FinancialKPIs(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      todayIncome: todayIncome,
      todayExpense: todayExpense,
    );
  }

  /// Calculates the next due date for a recurrence.
  static DateTime calculateNextDueDate(
    DateTime current,
    String frequency,
    int interval,
  ) {
    switch (frequency) {
      case 'daily':
        return current.add(Duration(days: interval));
      case 'weekly':
        return current.add(Duration(days: 7 * interval));
      case 'monthly':
        return DateTime(current.year, current.month + interval, current.day);
      case 'yearly':
        return DateTime(current.year + interval, current.month, current.day);
      default:
        return DateTime(current.year, current.month + interval, current.day);
    }
  }

  /// Groups completed payments by category, returning category -> total amount.
  /// [fallbackCategory] is used when payment.category is null.
  static Map<String, double> groupByCategory(
    List<FinancialPayment> payments,
    FinancialPaymentType type, {
    String fallbackCategory = 'Outros',
  }) {
    final map = <String, double>{};
    for (final p in payments) {
      if (p.type != type) continue;
      if (p.status != FinancialPaymentStatus.completed) continue;
      if (p.deletedAt != null) continue;
      final cat = p.category ?? fallbackCategory;
      map[cat] = (map[cat] ?? 0) + (p.amount ?? 0);
    }
    return map;
  }

  /// Calculates projected cash flow for the next N months.
  /// Returns list of (month, receivables, payables, projectedBalance).
  static List<ProjectedCashFlow> calculateProjection(
    double currentBalance,
    List<FinancialEntry> pendingEntries, {
    int months = 3,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final result = <ProjectedCashFlow>[];
    double running = currentBalance;

    for (var i = 1; i <= months; i++) {
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
      result.add(ProjectedCashFlow(
        month: start,
        receivables: receivables,
        payables: payables,
        projectedBalance: running,
      ));
    }
    return result;
  }

  /// Checks if the stored balance diverges from the real calculated balance.
  static bool isBalanceDivergent(
    double currentBalance,
    double realBalance, {
    double tolerance = 0.01,
  }) {
    return (realBalance - currentBalance).abs() >= tolerance;
  }
}

class ProjectedCashFlow {
  final DateTime month;
  final double receivables;
  final double payables;
  final double projectedBalance;

  const ProjectedCashFlow({
    required this.month,
    required this.receivables,
    required this.payables,
    required this.projectedBalance,
  });
}
