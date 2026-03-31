import 'package:praticos/models/financial_entry.dart';
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

  group('FinancialUtils.calculateNextDueDate', () {
    test('monthly +1 from Jan 15', () {
      final result = FinancialUtils.calculateNextDueDate(
          DateTime(2026, 1, 15), 'monthly', 1);
      expect(result, equals(DateTime(2026, 2, 15)));
    });

    test('monthly +1 from Dec crosses year', () {
      final result = FinancialUtils.calculateNextDueDate(
          DateTime(2026, 12, 10), 'monthly', 1);
      expect(result, equals(DateTime(2027, 1, 10)));
    });

    test('monthly +2 (bimonthly)', () {
      final result = FinancialUtils.calculateNextDueDate(
          DateTime(2026, 3, 1), 'monthly', 2);
      expect(result, equals(DateTime(2026, 5, 1)));
    });

    test('weekly +1', () {
      final result = FinancialUtils.calculateNextDueDate(
          DateTime(2026, 3, 10), 'weekly', 1);
      expect(result, equals(DateTime(2026, 3, 17)));
    });

    test('weekly +2 (biweekly)', () {
      final result = FinancialUtils.calculateNextDueDate(
          DateTime(2026, 3, 10), 'weekly', 2);
      expect(result, equals(DateTime(2026, 3, 24)));
    });

    test('daily +1', () {
      final result = FinancialUtils.calculateNextDueDate(
          DateTime(2026, 3, 31), 'daily', 1);
      expect(result, equals(DateTime(2026, 4, 1)));
    });

    test('yearly +1', () {
      final result = FinancialUtils.calculateNextDueDate(
          DateTime(2026, 6, 15), 'yearly', 1);
      expect(result, equals(DateTime(2027, 6, 15)));
    });

    test('default falls back to monthly', () {
      final result = FinancialUtils.calculateNextDueDate(
          DateTime(2026, 3, 1), 'unknown', 1);
      expect(result, equals(DateTime(2026, 4, 1)));
    });
  });

  group('FinancialUtils.groupByCategory', () {
    test('empty list returns empty map', () {
      final result = FinancialUtils.groupByCategory(
          [], FinancialPaymentType.expense);
      expect(result, isEmpty);
    });

    test('groups expenses by category', () {
      final payments = [
        _payment(type: FinancialPaymentType.expense, amount: 500)
          ..category = 'Aluguel',
        _payment(type: FinancialPaymentType.expense, amount: 200)
          ..category = 'Material',
        _payment(type: FinancialPaymentType.expense, amount: 300)
          ..category = 'Aluguel',
      ];
      final result = FinancialUtils.groupByCategory(
          payments, FinancialPaymentType.expense);
      expect(result['Aluguel'], equals(800));
      expect(result['Material'], equals(200));
    });

    test('ignores income when filtering expense', () {
      final payments = [
        _payment(type: FinancialPaymentType.income, amount: 1000)
          ..category = 'Servicos',
        _payment(type: FinancialPaymentType.expense, amount: 500)
          ..category = 'Material',
      ];
      final result = FinancialUtils.groupByCategory(
          payments, FinancialPaymentType.expense);
      expect(result.containsKey('Servicos'), isFalse);
      expect(result['Material'], equals(500));
    });

    test('ignores reversed payments', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.expense,
          amount: 999,
          status: FinancialPaymentStatus.reversed,
        )..category = 'Aluguel',
      ];
      final result = FinancialUtils.groupByCategory(
          payments, FinancialPaymentType.expense);
      expect(result, isEmpty);
    });

    test('ignores deleted payments', () {
      final payments = [
        _payment(
          type: FinancialPaymentType.expense,
          amount: 999,
          deletedAt: DateTime(2026, 3, 28),
        )..category = 'Aluguel',
      ];
      final result = FinancialUtils.groupByCategory(
          payments, FinancialPaymentType.expense);
      expect(result, isEmpty);
    });

    test('null category uses fallback', () {
      final payments = [
        _payment(type: FinancialPaymentType.expense, amount: 100),
      ];
      final result = FinancialUtils.groupByCategory(
          payments, FinancialPaymentType.expense,
          fallbackCategory: 'Sem categoria');
      expect(result['Sem categoria'], equals(100));
    });
  });

  group('FinancialUtils.calculateProjection', () {
    final refDate = DateTime(2026, 3, 15);

    FinancialEntry makeEntry({
      required FinancialEntryDirection direction,
      required double amount,
      required DateTime dueDate,
      double paidAmount = 0,
      double discountAmount = 0,
    }) {
      return FinancialEntry()
        ..direction = direction
        ..amount = amount
        ..dueDate = dueDate
        ..paidAmount = paidAmount
        ..discountAmount = discountAmount
        ..status = FinancialEntryStatus.pending;
    }

    test('empty entries = balance stays same for 3 months', () {
      final result = FinancialUtils.calculateProjection(
        10000,
        [],
        referenceDate: refDate,
      );
      expect(result.length, equals(3));
      expect(result[0].projectedBalance, equals(10000));
      expect(result[1].projectedBalance, equals(10000));
      expect(result[2].projectedBalance, equals(10000));
    });

    test('receivable in month 1 increases balance', () {
      final entries = [
        makeEntry(
          direction: FinancialEntryDirection.receivable,
          amount: 5000,
          dueDate: DateTime(2026, 4, 10), // April = month+1 from March ref
        ),
      ];
      final result = FinancialUtils.calculateProjection(
        10000,
        entries,
        referenceDate: refDate,
      );
      expect(result[0].receivables, equals(5000));
      expect(result[0].payables, equals(0));
      expect(result[0].projectedBalance, equals(15000));
    });

    test('payable in month 2 decreases balance', () {
      final entries = [
        makeEntry(
          direction: FinancialEntryDirection.payable,
          amount: 3000,
          dueDate: DateTime(2026, 5, 15), // May = month+2 from March ref
        ),
      ];
      final result = FinancialUtils.calculateProjection(
        10000,
        entries,
        referenceDate: refDate,
      );
      expect(result[0].projectedBalance, equals(10000));
      expect(result[1].payables, equals(3000));
      expect(result[1].projectedBalance, equals(7000));
    });

    test('balance accumulates across months', () {
      final entries = [
        makeEntry(
          direction: FinancialEntryDirection.receivable,
          amount: 8000,
          dueDate: DateTime(2026, 4, 5),
        ),
        makeEntry(
          direction: FinancialEntryDirection.payable,
          amount: 5000,
          dueDate: DateTime(2026, 4, 10),
        ),
        makeEntry(
          direction: FinancialEntryDirection.payable,
          amount: 2000,
          dueDate: DateTime(2026, 5, 1),
        ),
      ];
      final result = FinancialUtils.calculateProjection(
        10000,
        entries,
        referenceDate: refDate,
      );
      // April: 10000 + 8000 - 5000 = 13000
      expect(result[0].projectedBalance, equals(13000));
      // May: 13000 - 2000 = 11000
      expect(result[1].projectedBalance, equals(11000));
      // June: 11000 (no entries)
      expect(result[2].projectedBalance, equals(11000));
    });

    test('partially paid entry uses remainingBalance', () {
      final entries = [
        makeEntry(
          direction: FinancialEntryDirection.receivable,
          amount: 1000,
          dueDate: DateTime(2026, 4, 10),
          paidAmount: 400,
        ),
      ];
      final result = FinancialUtils.calculateProjection(
        5000,
        entries,
        referenceDate: refDate,
      );
      // remainingBalance = 1000 - 400 = 600
      expect(result[0].receivables, equals(600));
      expect(result[0].projectedBalance, equals(5600));
    });

    test('entries outside 3-month window are ignored', () {
      final entries = [
        makeEntry(
          direction: FinancialEntryDirection.receivable,
          amount: 9999,
          dueDate: DateTime(2026, 8, 1), // Too far in future
        ),
      ];
      final result = FinancialUtils.calculateProjection(
        5000,
        entries,
        referenceDate: refDate,
      );
      expect(result[0].receivables, equals(0));
      expect(result[1].receivables, equals(0));
      expect(result[2].receivables, equals(0));
    });

    test('custom month count', () {
      final result = FinancialUtils.calculateProjection(
        1000,
        [],
        months: 6,
        referenceDate: refDate,
      );
      expect(result.length, equals(6));
    });
  });
}
