import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/utils/financial_utils.dart';
import 'package:test/test.dart';

FinancialPayment _payment({
  FinancialPaymentType? type,
  FinancialPaymentStatus? status,
  double? amount,
  DateTime? paymentDate,
  String? transferDirection,
  DateTime? deletedAt,
}) {
  return FinancialPayment()
    ..type = type
    ..status = status ?? FinancialPaymentStatus.completed
    ..amount = amount
    ..paymentDate = paymentDate
    ..transferDirection = transferDirection
    ..deletedAt = deletedAt;
}

void main() {
  group('FinancialUtils.computeRealBalance', () {
    test('empty payments returns initialBalance', () {
      expect(FinancialUtils.computeRealBalance(5000, []), equals(5000));
    });

    test('income adds to balance', () {
      final payments = [
        _payment(type: FinancialPaymentType.income, amount: 350),
        _payment(type: FinancialPaymentType.income, amount: 200),
      ];
      expect(FinancialUtils.computeRealBalance(1000, payments), equals(1550));
    });

    test('expense subtracts from balance', () {
      final payments = [
        _payment(type: FinancialPaymentType.expense, amount: 450),
      ];
      expect(FinancialUtils.computeRealBalance(1000, payments), equals(550));
    });

    test('transfer out subtracts', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.transfer,
          amount: 500,
          transferDirection: 'out',
        ),
      ];
      expect(FinancialUtils.computeRealBalance(1000, payments), equals(500));
    });

    test('transfer in adds', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.transfer,
          amount: 500,
          transferDirection: 'in',
        ),
      ];
      expect(FinancialUtils.computeRealBalance(1000, payments), equals(1500));
    });

    test('reversed payments are ignored', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.expense,
          amount: 999,
          status: FinancialPaymentStatus.reversed,
        ),
      ];
      expect(FinancialUtils.computeRealBalance(1000, payments), equals(1000));
    });

    test('deleted payments are ignored', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.expense,
          amount: 999,
          deletedAt: DateTime(2026, 3, 28),
        ),
      ];
      expect(FinancialUtils.computeRealBalance(1000, payments), equals(1000));
    });

    test('null payments in list are ignored', () {
      final payments = <FinancialPayment?>[
        null,
        _payment(type: FinancialPaymentType.income, amount: 100),
        null,
      ];
      expect(FinancialUtils.computeRealBalance(1000, payments), equals(1100));
    });

    test('null amount treated as zero', () {
      final payments = [
        _payment(type: FinancialPaymentType.income, amount: null),
      ];
      expect(FinancialUtils.computeRealBalance(1000, payments), equals(1000));
    });

    test('realistic scenario: mixed payment types', () {
      final payments = [
        _payment(type: FinancialPaymentType.income, amount: 800),
        _payment(type: FinancialPaymentType.income, amount: 1200),
        _payment(type: FinancialPaymentType.income, amount: 350),
        _payment(type: FinancialPaymentType.expense, amount: 2500),
        _payment(type: FinancialPaymentType.expense, amount: 450),
        _payment(
          type: FinancialPaymentType.transfer,
          amount: 1000,
          transferDirection: 'out',
        ),
        _payment(
          type: FinancialPaymentType.expense,
          amount: 999,
          status: FinancialPaymentStatus.reversed,
        ),
      ];
      // 5000 + 800 + 1200 + 350 - 2500 - 450 - 1000 = 3400
      expect(FinancialUtils.computeRealBalance(5000, payments), equals(3400));
    });

    test('negative balance is allowed', () {
      final payments = [
        _payment(type: FinancialPaymentType.expense, amount: 2000),
      ];
      expect(FinancialUtils.computeRealBalance(500, payments), equals(-1500));
    });
  });

  group('FinancialUtils.computeKPIs', () {
    final today = DateTime(2026, 3, 31, 12, 0);

    test('empty payments returns all zeros', () {
      final kpis = FinancialUtils.computeKPIs([], today: today);
      expect(kpis.totalIncome, equals(0));
      expect(kpis.totalExpense, equals(0));
      expect(kpis.todayIncome, equals(0));
      expect(kpis.todayExpense, equals(0));
      expect(kpis.profit, equals(0));
      expect(kpis.todayProfit, equals(0));
    });

    test('income only', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.income,
          amount: 500,
          paymentDate: today,
        ),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.totalIncome, equals(500));
      expect(kpis.totalExpense, equals(0));
      expect(kpis.profit, equals(500));
    });

    test('expense only', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.expense,
          amount: 300,
          paymentDate: today,
        ),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.totalIncome, equals(0));
      expect(kpis.totalExpense, equals(300));
      expect(kpis.profit, equals(-300));
    });

    test('reversed payments excluded', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.income,
          amount: 1000,
          paymentDate: today,
          status: FinancialPaymentStatus.reversed,
        ),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.totalIncome, equals(0));
    });

    test('deleted payments excluded', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.income,
          amount: 1000,
          paymentDate: today,
          deletedAt: DateTime(2026, 3, 30),
        ),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.totalIncome, equals(0));
    });

    test('today vs yesterday separated correctly', () {
      final yesterday = today.subtract(const Duration(days: 1));
      final payments = [
        _payment(
          type: FinancialPaymentType.income,
          amount: 500,
          paymentDate: today,
        ),
        _payment(
          type: FinancialPaymentType.income,
          amount: 800,
          paymentDate: yesterday,
        ),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.totalIncome, equals(1300));
      expect(kpis.todayIncome, equals(500));
    });

    test('null paymentDate excluded from today KPIs but included in total', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.income,
          amount: 700,
          paymentDate: null,
        ),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.totalIncome, equals(700));
      expect(kpis.todayIncome, equals(0));
    });

    test('transfers not counted as income or expense', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.transfer,
          amount: 1000,
          paymentDate: today,
          transferDirection: 'out',
        ),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.totalIncome, equals(0));
      expect(kpis.totalExpense, equals(0));
      expect(kpis.profit, equals(0));
    });

    test('today KPIs include expense', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.expense,
          amount: 450,
          paymentDate: DateTime(2026, 3, 31, 9, 0),
        ),
        _payment(
          type: FinancialPaymentType.income,
          amount: 800,
          paymentDate: DateTime(2026, 3, 31, 14, 0),
        ),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.todayIncome, equals(800));
      expect(kpis.todayExpense, equals(450));
      expect(kpis.todayProfit, equals(350));
    });

    test('realistic month scenario', () {
      final payments = [
        _payment(type: FinancialPaymentType.income, amount: 800, paymentDate: DateTime(2026, 3, 25)),
        _payment(type: FinancialPaymentType.income, amount: 1200, paymentDate: DateTime(2026, 3, 27)),
        _payment(type: FinancialPaymentType.income, amount: 350, paymentDate: today),
        _payment(type: FinancialPaymentType.expense, amount: 2500, paymentDate: DateTime(2026, 3, 10)),
        _payment(type: FinancialPaymentType.expense, amount: 450, paymentDate: today),
        _payment(type: FinancialPaymentType.transfer, amount: 1000, paymentDate: today, transferDirection: 'out'),
        _payment(type: FinancialPaymentType.income, amount: 999, paymentDate: today, status: FinancialPaymentStatus.reversed),
      ];
      final kpis = FinancialUtils.computeKPIs(payments, today: today);
      expect(kpis.totalIncome, equals(2350)); // 800 + 1200 + 350
      expect(kpis.totalExpense, equals(2950)); // 2500 + 450
      expect(kpis.profit, equals(-600));
      expect(kpis.todayIncome, equals(350));
      expect(kpis.todayExpense, equals(450));
      expect(kpis.todayProfit, equals(-100));
    });
  });

  group('FinancialUtils.isBalanceDivergent', () {
    test('equal balances are not divergent', () {
      expect(FinancialUtils.isBalanceDivergent(1000, 1000), isFalse);
    });

    test('difference within tolerance is not divergent', () {
      expect(FinancialUtils.isBalanceDivergent(1000, 1000.005), isFalse);
    });

    test('difference above tolerance is divergent', () {
      expect(FinancialUtils.isBalanceDivergent(1000, 1000.02), isTrue);
    });

    test('large difference is divergent', () {
      expect(FinancialUtils.isBalanceDivergent(1000, 1500), isTrue);
    });

    test('negative difference is divergent', () {
      expect(FinancialUtils.isBalanceDivergent(1000, 500), isTrue);
    });

    test('both negative balances', () {
      expect(FinancialUtils.isBalanceDivergent(-100, -100.005), isFalse);
      expect(FinancialUtils.isBalanceDivergent(-100, -200), isTrue);
    });

    test('custom tolerance', () {
      expect(
        FinancialUtils.isBalanceDivergent(1000, 1000.5, tolerance: 1.0),
        isFalse,
      );
      expect(
        FinancialUtils.isBalanceDivergent(1000, 1001.5, tolerance: 1.0),
        isTrue,
      );
    });
  });
}
