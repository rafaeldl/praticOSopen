import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/utils/financial_summary.dart';

Order order(
  String id, {
  String? customerId,
  String? customerName,
  double total = 100,
  double paid = 0,
  String payment = 'unpaid',
  String status = 'approved',
  DateTime? createdAt,
  DateTime? updatedAt,
  List<PaymentTransaction>? transactions,
}) {
  final o = Order()
    ..id = id
    ..number = int.tryParse(id) ?? 1
    ..total = total
    ..paidAmount = paid
    ..payment = payment
    ..status = status
    ..createdAt = createdAt ?? DateTime(2026, 10, 1)
    ..updatedAt = updatedAt
    ..transactions = transactions;
  if (customerId != null) {
    o.customer = CustomerAggr()
      ..id = customerId
      ..name = customerName;
  }
  return o;
}

void main() {
  group('FinancialSummary.compute', () {
    test('owed counts every open order, even from other months', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: [
          order('1', customerId: 'a', customerName: 'Ana', total: 300, paid: 100),
        ],
        openOrders: [
          // Open order from August, not in the month list.
          order('2', customerId: 'b', customerName: 'Bia', total: 500,
              createdAt: DateTime(2026, 8, 3)),
          order('1', customerId: 'a', customerName: 'Ana', total: 300, paid: 100),
        ],
      );

      expect(summary.owed, 700); // 200 (Ana) + 500 (Bia)
      expect(summary.debtors.map((d) => d.name), ['Bia', 'Ana']);
    });

    test('sums customers with many orders and orders them by oldest debt', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [
          order('1', customerId: 'a', customerName: 'Ana', total: 100,
              createdAt: DateTime(2026, 10, 8)),
          order('2', customerId: 'a', customerName: 'Ana', total: 250,
              createdAt: DateTime(2026, 10, 2)),
          order('3', customerId: 'b', customerName: 'Bia', total: 900,
              createdAt: DateTime(2026, 10, 5)),
        ],
      );

      final ana = summary.debtors.first;
      expect(ana.name, 'Ana');
      expect(ana.amount, 350);
      expect(ana.hasSingleOrder, isFalse);
      expect(ana.oldestOrder.id, '2');
      expect(ana.since, DateTime(2026, 10, 2));
      expect(summary.oldestDebtor, same(ana));
    });

    test('ignores quotes, canceled, paid and zero balance orders', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [
          order('1', customerId: 'a', status: 'quote'),
          order('2', customerId: 'a', status: 'canceled'),
          order('3', customerId: 'a', payment: 'paid', paid: 100),
          order('4', customerId: 'a', total: 100, paid: 100),
          order('5', customerId: 'a', total: 40),
        ],
      );

      expect(summary.owed, 40);
      expect(summary.debtors.single.orders.single.id, '5');
    });

    test('orders without customer are grouped together', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [order('1'), order('2')],
      );

      final debtor = summary.debtors.single;
      expect(debtor.customerId, isNull);
      expect(debtor.name, isNull);
      expect(debtor.amount, 200);
    });

    test('entered sums payments of the month, legacy paid orders use total',
        () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: [
          order('1', total: 500, payment: 'paid', paid: 500),
          Order()
            ..id = '2'
            ..total = 300
            ..createdAt = DateTime(2026, 10, 1)
            ..payment = 'paid', // legacy: no paidAmount
          order('3', total: 400, paid: 150), // partial
          order('4', total: 999, status: 'quote'),
        ],
        openOrders: const [],
      );

      expect(summary.entered, 950);
      expect(summary.monthOrderCount, 3);
      expect(summary.receivedOrders.map((o) => o.id).toSet(), {'1', '2'});
    });

    test('received orders come latest paid first', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: [
          order('1', payment: 'paid', paid: 100, updatedAt: DateTime(2026, 10, 3)),
          order('2', payment: 'paid', paid: 100, updatedAt: DateTime(2026, 10, 9)),
          order(
            '3',
            payment: 'paid',
            paid: 100,
            updatedAt: DateTime(2026, 10, 1),
            transactions: [
              PaymentTransaction(
                type: PaymentTransactionType.payment,
                amount: 100,
                createdAt: DateTime(2026, 10, 12),
              ),
            ],
          ),
        ],
        openOrders: const [],
      );

      expect(summary.receivedOrders.map((o) => o.id), ['3', '2', '1']);
    });

    test('counts the money by payment date, on orders of any month', () {
      PaymentTransaction pay(double amount, DateTime paidAt) =>
          PaymentTransaction.payment(amount: amount, paidAt: paidAt);
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: [
          order(
            '1',
            total: 300,
            paid: 300,
            payment: 'paid',
            transactions: [pay(100, DateTime(2026, 11, 2)), pay(200, DateTime(2026, 10, 3))],
          ),
        ],
        paidOrders: [
          order(
            '1',
            total: 300,
            paid: 300,
            payment: 'paid',
            transactions: [pay(100, DateTime(2026, 11, 2)), pay(200, DateTime(2026, 10, 3))],
          ),
          order(
            '2',
            total: 500,
            paid: 500,
            payment: 'paid',
            createdAt: DateTime(2026, 8, 1),
            transactions: [pay(500, DateTime(2026, 10, 20))],
          ),
          order(
            '3',
            total: 700,
            paid: 700,
            payment: 'paid',
            createdAt: DateTime(2026, 8, 1),
            transactions: [pay(700, DateTime(2026, 9, 20))],
          ),
        ],
        openOrders: const [],
      );

      expect(summary.entered, 700);
      expect(summary.receivedOrders.map((o) => o.id).toSet(), {'1', '2'});
      expect(summary.monthOrderCount, 1);
    });

    test('old orders without transactions count in the month they were '
        'created', () {
      final old = order('1', total: 300, paid: 300, payment: 'paid');
      expect(FinancialSummary.receivedIn(old, DateTime(2026, 10)), 300);
      expect(FinancialSummary.receivedIn(old, DateTime(2026, 11)), 0);
    });

    test('a month with only money from older orders is not empty', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        paidOrders: [
          order(
            '2',
            total: 500,
            paid: 500,
            payment: 'paid',
            createdAt: DateTime(2026, 8, 1),
            transactions: [
              PaymentTransaction.payment(
                amount: 500,
                paidAt: DateTime(2026, 10, 20),
              ),
            ],
          ),
        ],
        openOrders: const [],
      );
      expect(summary.isEmpty, isFalse);
    });

    test('empty when there are no orders and no debt', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: const [],
      );
      expect(summary.isEmpty, isTrue);
      expect(summary.hasDebt, isFalse);
      expect(summary.oldestDebtor, isNull);
    });
  });
}
