import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';

/// A customer with money to receive on completed orders (A receber).
class Debtor {
  Debtor({
    required this.key,
    required this.customerId,
    required this.name,
    required this.amount,
    required this.orders,
    List<Order>? openOrders,
  }) : openOrders = openOrders ?? orders;

  /// Grouping key: the customer id, or [noCustomerKey] for orders without one.
  final String key;
  final String? customerId;
  final String? name;

  /// Sum of what is still open on [orders].
  final double amount;

  /// Completed orders with a balance, oldest first.
  final List<Order> orders;

  /// Every open order of this customer, completed or not, oldest first:
  /// receiving is not limited to what A receber shows.
  final List<Order> openOrders;

  static const noCustomerKey = '_none';

  Order get oldestOrder => orders.first;
  DateTime? get since => oldestOrder.createdAt;
  bool get hasSingleOrder => orders.length == 1;
}

/// Numbers behind the Financeiro tab.
///
/// Change with the month:
/// - [entered] (Recebido): money received in the chosen month, by payment
///   date, on orders of any month and status.
/// - [sold] (Vendido): total of the orders opened in the chosen month.
///
/// Are about today, whatever the month:
/// - [owed] (A receber): balance of the completed orders, in [debtors],
///   grouped by customer, longest-overdue first.
/// - [inProgress] (Em andamento): balance of [inProgressOrders], the approved
///   and running orders; it moves to [owed] when the order is completed.
class FinancialSummary {
  FinancialSummary({
    required this.entered,
    required this.sold,
    required this.soldOrders,
    required this.owed,
    required this.debtors,
    required this.inProgress,
    required this.inProgressOrders,
  });

  final double entered;
  final double sold;

  /// Orders opened in the chosen month, newest first.
  final List<Order> soldOrders;
  final double owed;
  final List<Debtor> debtors;
  final double inProgress;

  /// Approved and running orders with a balance, oldest first.
  final List<Order> inProgressOrders;

  static final empty = FinancialSummary(
    entered: 0,
    sold: 0,
    soldOrders: const [],
    owed: 0,
    debtors: const [],
    inProgress: 0,
    inProgressOrders: const [],
  );

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

    final sold = created.where(isSold).toList()
      ..sort((a, b) => _oldestFirst(b, a));

    final open = openOrders.whereType<Order>().where(isOpen).toList()
      ..sort(_oldestFirst);

    final byCustomer = <String, List<Order>>{};
    final names = <String, String?>{};
    for (final order in open) {
      final key = order.customer?.id ?? Debtor.noCustomerKey;
      byCustomer.putIfAbsent(key, () => []).add(order);
      names[key] ??= order.customer?.name;
    }

    final debtors = <Debtor>[];
    byCustomer.forEach((key, customerOrders) {
      final orders = customerOrders.where(isReceivable).toList();
      if (orders.isEmpty) return;
      debtors.add(
        Debtor(
          key: key,
          customerId: key == Debtor.noCustomerKey ? null : key,
          name: names[key],
          amount: _openSum(orders),
          orders: orders,
          openOrders: customerOrders,
        ),
      );
    });
    debtors.sort((a, b) => _oldestFirst(a.oldestOrder, b.oldestOrder));

    final running = open.where(isInProgress).toList();

    return FinancialSummary(
      entered: entered,
      sold: sold.fold<double>(0, (sum, o) => sum + (o.total ?? 0)),
      soldOrders: sold,
      owed: debtors.fold<double>(0, (sum, d) => sum + d.amount),
      debtors: debtors,
      inProgress: _openSum(running),
      inProgressOrders: running,
    );
  }

  static double _openSum(Iterable<Order> orders) =>
      orders.fold<double>(0, (sum, o) => sum + openAmount(o));

  /// Counts as sold (Vendido, and every total of the Relatório): anything but
  /// quotes and canceled orders.
  static bool isSold(Order? order) =>
      order?.status != 'quote' && order?.status != 'canceled';

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

  /// Open and completed: shows in A receber.
  static bool isReceivable(Order order) =>
      isOpen(order) && order.status == 'done';

  /// Open and not completed yet: shows in Em andamento.
  static bool isInProgress(Order order) =>
      isOpen(order) &&
      (order.status == 'approved' || order.status == 'progress');

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
