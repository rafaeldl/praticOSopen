import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';

/// A customer who owes money, with the open orders that add up to the debt.
class Debtor {
  Debtor({
    required this.key,
    required this.customerId,
    required this.name,
    required this.amount,
    required this.orders,
  });

  /// Grouping key: the customer id, or [noCustomerKey] for orders without one.
  final String key;
  final String? customerId;
  final String? name;

  /// Sum of what is still open on [orders].
  final double amount;

  /// Open orders of this customer, oldest first.
  final List<Order> orders;

  static const noCustomerKey = '_none';

  Order get oldestOrder => orders.first;
  DateTime? get since => oldestOrder.createdAt;
  bool get hasSingleOrder => orders.length == 1;
}

/// Numbers behind the Financeiro tab ("Quem me deve").
///
/// - [entered]: money received on the orders of the chosen month.
/// - [owed]: everything still open, in any month ("Falta receber").
/// - [debtors]: customers who owe, longest-overdue first.
/// - [receivedOrders]: orders of the month already paid, latest first.
class FinancialSummary {
  FinancialSummary({
    required this.entered,
    required this.owed,
    required this.debtors,
    required this.receivedOrders,
    required this.monthOrderCount,
  });

  final double entered;
  final double owed;
  final List<Debtor> debtors;
  final List<Order> receivedOrders;

  /// Orders (without quotes) created in the chosen month.
  final int monthOrderCount;

  static final empty = FinancialSummary(
    entered: 0,
    owed: 0,
    debtors: const [],
    receivedOrders: const [],
    monthOrderCount: 0,
  );

  bool get hasDebt => debtors.isNotEmpty;
  bool get isEmpty => monthOrderCount == 0 && debtors.isEmpty;

  /// The debtor to charge first (the one owing for the longest).
  Debtor? get oldestDebtor => debtors.isEmpty ? null : debtors.first;

  /// Builds the summary from the orders of the month and from every order
  /// with an open payment (any month).
  factory FinancialSummary.compute({
    required Iterable<Order?> monthOrders,
    required Iterable<Order?> openOrders,
  }) {
    final month = monthOrders
        .whereType<Order>()
        .where((o) => o.status != 'quote')
        .toList();

    // Same rule as the dashboard store: old paid orders may have no
    // paidAmount, so they count their total.
    final entered = month.fold<double>(0, (sum, o) {
      if (o.payment == 'paid') return sum + (o.paidAmount ?? o.total ?? 0);
      return sum + (o.paidAmount ?? 0);
    });

    final received = month.where((o) => o.payment == 'paid').toList()
      ..sort((a, b) => paidDate(b).compareTo(paidDate(a)));

    final byCustomer = <String, List<Order>>{};
    final names = <String, String?>{};
    for (final order in openOrders.whereType<Order>()) {
      if (order.status == 'quote' || order.status == 'canceled') continue;
      if (order.payment == 'paid' || openAmount(order) <= 0) continue;
      final id = order.customer?.id;
      final key = id ?? Debtor.noCustomerKey;
      byCustomer.putIfAbsent(key, () => []).add(order);
      names[key] ??= order.customer?.name;
    }

    final debtors = byCustomer.entries.map((e) {
      final orders = [...e.value]..sort(_oldestFirst);
      return Debtor(
        key: e.key,
        customerId: e.key == Debtor.noCustomerKey ? null : e.key,
        name: names[e.key],
        amount: orders.fold<double>(0, (sum, o) => sum + openAmount(o)),
        orders: orders,
      );
    }).toList()
      ..sort((a, b) => _oldestFirst(a.oldestOrder, b.oldestOrder));

    return FinancialSummary(
      entered: entered,
      owed: debtors.fold<double>(0, (sum, d) => sum + d.amount),
      debtors: debtors,
      receivedOrders: received,
      monthOrderCount: month.length,
    );
  }

  /// What is still open on [order].
  static double openAmount(Order order) =>
      (order.total ?? 0) - (order.paidAmount ?? 0);

  /// When [order] was paid: its latest payment, falling back to its last
  /// update (old orders have no transactions).
  static DateTime paidDate(Order order) {
    final payments = (order.transactions ?? const <PaymentTransaction>[])
        .where((t) => t.type == PaymentTransactionType.payment)
        .map((t) => t.createdAt)
        .toList()
      ..sort();
    if (payments.isNotEmpty) return payments.last;
    return order.updatedAt ??
        order.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int _oldestFirst(Order a, Order b) {
    final da = a.createdAt;
    final db = b.createdAt;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }
}
