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
    test('A receber counts only completed orders, even from other months', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [
          order('1', customerId: 'a', customerName: 'Ana', total: 300, paid: 100, status: 'done'),
          // Open order from August, not in the month list.
          order('2', customerId: 'b', customerName: 'Bia', total: 500, status: 'done',
              createdAt: DateTime(2026, 8, 3)),
          order('3', customerId: 'c', customerName: 'Caio', total: 900),
          order('4', customerId: 'd', customerName: 'Dora', total: 800, status: 'progress'),
        ],
      );

      expect(summary.owed, 700); // 200 (Ana) + 500 (Bia): shows only the balance
      expect(summary.debtors.map((d) => d.name), ['Bia', 'Ana']);
    });

    test('Em andamento counts approved and running orders, oldest first', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [
          order('1', customerId: 'a', total: 300, paid: 100, createdAt: DateTime(2026, 10, 5)),
          order('2', customerId: 'b', total: 500, status: 'progress', createdAt: DateTime(2026, 10, 2)),
          order('3', customerId: 'c', total: 900, status: 'done'),
          order('4', customerId: 'd', total: 700, status: 'quote'),
          order('5', customerId: 'e', total: 600, status: 'canceled'),
          order('6', customerId: 'f', payment: 'paid', paid: 100),
        ],
      );

      expect(summary.inProgress, 700);
      expect(summary.inProgressOrders.map((o) => o.id), ['2', '1']);
    });

    test('completing an order moves its balance from Em andamento to A receber', () {
      final running = order('1', customerId: 'a', total: 300, paid: 100, status: 'progress');
      FinancialSummary compute() => FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [running],
      );

      expect(compute().inProgress, 200);
      expect(compute().owed, 0);

      running.status = 'done';
      expect(compute().inProgress, 0);
      expect(compute().owed, 200);
    });

    test('sums customers with many orders and orders them by oldest debt', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [
          order('1', customerId: 'a', customerName: 'Ana', total: 100, status: 'done',
              createdAt: DateTime(2026, 10, 8)),
          order('2', customerId: 'a', customerName: 'Ana', total: 250, status: 'done',
              createdAt: DateTime(2026, 10, 2)),
          order('3', customerId: 'b', customerName: 'Bia', total: 900, status: 'done',
              createdAt: DateTime(2026, 10, 5)),
        ],
      );

      final ana = summary.debtors.first;
      expect(ana.name, 'Ana');
      expect(ana.amount, 350);
      expect(ana.hasSingleOrder, isFalse);
      expect(ana.oldestOrder.id, '2');
      expect(ana.since, DateTime(2026, 10, 2));
    });

    test('"desde" is the oldest completed order; receiving keeps every open order', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [
          order('1', customerId: 'a', total: 400, createdAt: DateTime(2026, 9, 1)),
          order('2', customerId: 'a', total: 100, status: 'done', createdAt: DateTime(2026, 10, 2)),
        ],
      );

      final ana = summary.debtors.single;
      expect(ana.amount, 100);
      expect(ana.since, DateTime(2026, 10, 2));
      expect(ana.orders.map((o) => o.id), ['2']);
      expect(ana.openOrders.map((o) => o.id), ['1', '2']);
    });

    test('a customer with only running orders is not in A receber', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [order('1', customerId: 'a')],
      );

      expect(summary.debtors, isEmpty);
    });

    test('ignores quotes, canceled, paid and zero balance orders', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [
          order('1', customerId: 'a', status: 'quote'),
          order('2', customerId: 'a', status: 'canceled'),
          order('3', customerId: 'a', payment: 'paid', paid: 100, status: 'done'),
          order('4', customerId: 'a', total: 100, paid: 100, status: 'done'),
          order('5', customerId: 'a', total: 40, status: 'done'),
        ],
      );

      expect(summary.owed, 40);
      expect(summary.debtors.single.orders.single.id, '5');
    });

    test('orders without customer are grouped together', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: const [],
        openOrders: [order('1', status: 'done'), order('2', status: 'done')],
      );

      final debtor = summary.debtors.single;
      expect(debtor.customerId, isNull);
      expect(debtor.name, isNull);
      expect(debtor.amount, 200);
    });

    test('Vendido sums the orders opened in the month, no quotes or canceled', () {
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: [
          order('1', total: 500, createdAt: DateTime(2026, 10, 2)),
          order('2', total: 300, status: 'done', createdAt: DateTime(2026, 10, 9)),
          order('3', total: 200, status: 'progress', payment: 'paid', paid: 200, createdAt: DateTime(2026, 10, 5)),
          order('4', total: 999, status: 'quote'),
          order('5', total: 888, status: 'canceled'),
        ],
        openOrders: const [],
      );

      expect(summary.sold, 1000);
      expect(summary.soldOrders.map((o) => o.id), ['2', '3', '1']);
    });

    test('Vendido and Recebido follow the month; A receber does not', () {
      FinancialSummary compute(DateTime month, List<Order> created) =>
          FinancialSummary.compute(
            month: month,
            monthOrders: created,
            openOrders: [order('9', customerId: 'a', total: 70, status: 'done')],
          );

      expect(compute(DateTime(2026, 10), [order('1', total: 500)]).sold, 500);
      expect(compute(DateTime(2026, 9), const []).sold, 0);
      expect(compute(DateTime(2026, 10), const []).owed, 70);
      expect(compute(DateTime(2026, 9), const []).owed, 70);
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
    });

    test('old orders without transactions count in the month they were '
        'created', () {
      final old = order('1', total: 300, paid: 300, payment: 'paid');
      expect(FinancialSummary.receivedIn(old, DateTime(2026, 10)), 300);
      expect(FinancialSummary.receivedIn(old, DateTime(2026, 11)), 0);
    });

    test('receivedOrders adds up to Recebido, latest payment first, partial '
        'and canceled orders included', () {
      PaymentTransaction pay(double amount, DateTime paidAt) =>
          PaymentTransaction.payment(amount: amount, paidAt: paidAt);
      final summary = FinancialSummary.compute(
        month: DateTime(2026, 10),
        monthOrders: [order('9', total: 500)], // nothing received
        paidOrders: [
          order('1', total: 300, paid: 100, createdAt: DateTime(2026, 8, 1),
              transactions: [pay(100, DateTime(2026, 10, 5))]),
          order('2', total: 900, paid: 900, payment: 'paid', status: 'done',
              createdAt: DateTime(2026, 8, 2),
              transactions: [
                pay(400, DateTime(2026, 9, 20)),
                pay(200, DateTime(2026, 10, 20)),
                pay(300, DateTime(2026, 11, 2)),
              ]),
          order('3', total: 50, paid: 50, status: 'canceled',
              createdAt: DateTime(2026, 8, 3),
              transactions: [pay(50, DateTime(2026, 10, 10))]),
        ],
        openOrders: const [],
      );

      expect(summary.receivedOrders.map((o) => o.id), ['2', '3', '1']);
      expect(summary.entered, 350);
      expect(
        summary.receivedOrders.fold<double>(
          0,
          (sum, o) => sum + FinancialSummary.receivedIn(o, DateTime(2026, 10)),
        ),
        summary.entered,
      );
      expect(
        FinancialSummary.receivedDate(summary.receivedOrders.first, DateTime(2026, 10)),
        DateTime(2026, 10, 20),
      );
    });

    test('isSold leaves out quotes and canceled orders (Vendido and Relatório)', () {
      expect(FinancialSummary.isSold(order('1')), isTrue);
      expect(FinancialSummary.isSold(order('2', status: 'done')), isTrue);
      expect(FinancialSummary.isSold(order('3', status: 'quote')), isFalse);
      expect(FinancialSummary.isSold(order('4', status: 'canceled')), isFalse);
    });

    test('isOpen still covers running orders: receiving does not change', () {
      final orders = [
        order('1', customerId: 'a', status: 'done', createdAt: DateTime(2026, 10, 2)),
        order('2', customerId: 'a', createdAt: DateTime(2026, 10, 1)),
        order('3', customerId: 'a', status: 'progress', createdAt: DateTime(2026, 10, 3)),
        order('4', customerId: 'a', status: 'quote'),
      ];

      expect(FinancialSummary.openOrdersOldestFirst(orders).map((o) => o.id), ['2', '1', '3']);
    });
  });
}
