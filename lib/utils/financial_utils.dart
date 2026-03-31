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

  /// Checks if the stored balance diverges from the real calculated balance.
  static bool isBalanceDivergent(
    double currentBalance,
    double realBalance, {
    double tolerance = 0.01,
  }) {
    return (realBalance - currentBalance).abs() >= tolerance;
  }
}
