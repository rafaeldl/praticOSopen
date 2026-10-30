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
/// - [entered]: money received in the chosen month, by payment date, on
///   orders of any month.
/// - [owed]: everything still open, in any month ("Falta receber").
/// - [debtors]: customers who owe, longest-overdue first.
/// - [receivedOrders]: paid orders with money received in the month, latest
///   first.
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
  bool get isEmpty => monthOrderCount == 0 && debtors.isEmpty && entered == 0;

  /// The debtor to charge first (the one owing for the longest).
  Debtor? get oldestDebtor => debtors.isEmpty ? null : debtors.first;

  /// Builds the summary of [month] from the orders created in it, the orders
  /// that may have been paid in it ([paidOrders], any month) and every order
  /// with an open payment (any month).
  factory FinancialSummary.compute({
    required DateTime month,
    required Iterable<Order?> monthOrders,
    required Iterable<Order?> openOrders,
    Iterable<Order?> paidOrders = const [],
  }) {
    final created = monthOrders
        .whereType<Order>()
        .where((o) => o.status != 'quote')
        .toList();
    final createdIds = created.map((o) => o.id).toSet();
    final candidates = [
      ...created,
      ...paidOrders.whereType<Order>().where(
        (o) => o.status != 'quote' && !createdIds.contains(o.id),
      ),
    ];

    final entered = candidates.fold<double>(
      0,
      (sum, o) => sum + receivedIn(o, month),
    );

    final received =
        candidates
            .where((o) => o.payment == 'paid' && receivedIn(o, month) > 0)
            .toList()
          ..sort((a, b) => paidDate(b).compareTo(paidDate(a)));

    final byCustomer = <String, List<Order>>{};
    final names = <String, String?>{};
    for (final order in openOrders.whereType<Order>()) {
      if (!isOpen(order)) continue;
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
      monthOrderCount: created.length,
    );
  }

  /// Money received on [order] in [month], by the date of each payment. Old
  /// orders have no transactions (and old paid ones may have no paidAmount,
  /// so they count their total): that money counts in the month the order
  /// was created.
  static double receivedIn(Order order, DateTime month) {
    bool inMonth(DateTime? date) {
      final local = date?.toLocal();
      return local?.year == month.year && local?.month == month.month;
    }

    final payments = (order.transactions ?? const <PaymentTransaction>[]).where(
      (t) => t.type == PaymentTransactionType.payment,
    );
    final tracked = payments.fold<double>(0, (sum, t) => sum + t.amount);
    final dated = payments
        .where((t) => inMonth(t.paidOn))
        .fold<double>(0, (sum, t) => sum + t.amount);
    final paid = order.payment == 'paid'
        ? order.paidAmount ?? order.total ?? 0
        : order.paidAmount ?? 0;
    final untracked = paid - tracked;
    return dated + (untracked > 0 && inMonth(order.createdAt) ? untracked : 0);
  }

  /// What is still open on [order].
  static double openAmount(Order order) =>
      (order.total ?? 0) - (order.paidAmount ?? 0);

  /// When [order] was paid: its latest payment (its chosen date, `paidAt`,
  /// or when it was recorded), falling back to its last
  /// update (old orders have no transactions).
  static DateTime paidDate(Order order) {
    final payments = (order.transactions ?? const <PaymentTransaction>[])
        .where((t) => t.type == PaymentTransactionType.payment)
        .map((t) => t.paidOn)
        .toList()
      ..sort();
    if (payments.isNotEmpty) return payments.last;
    return order.updatedAt ??
        order.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Whether [order] still has money to receive (not a quote, not
  /// canceled, not paid, something open).
  static bool isOpen(Order order) =>
      order.status != 'quote' &&
      order.status != 'canceled' &&
      order.payment != 'paid' &&
      openAmount(order) > 0;

  /// The open orders among [orders], oldest first: the same list and order
  /// as `Debtor.orders` (the order a customer payment is split in).
  static List<Order> openOrdersOldestFirst(Iterable<Order?> orders) =>
      orders.whereType<Order>().where(isOpen).toList()..sort(_oldestFirst);

  static int _oldestFirst(Order a, Order b) {
    final da = a.createdAt;
    final db = b.createdAt;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }
}
