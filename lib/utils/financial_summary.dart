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
/// - [receivable] (A receber): what customers owe now, in two parts.
///   [owed] is the balance of the completed orders, in [debtors], grouped by
///   customer, longest-overdue first. [depositOwed] is the balance of
///   [depositOrders], running orders that already got a partial payment.
/// - [inProgress] (Em andamento): balance of [inProgressOrders], the approved
///   and running orders with nothing received yet. Each order counts in one
///   place: it moves to [depositOrders] on the first payment and to [owed]
///   when completed.
class FinancialSummary {
  FinancialSummary({
    required this.entered,
    required this.receivedOrders,
    required this.sold,
    required this.soldOrders,
    required this.owed,
    required this.debtors,
    required this.depositOwed,
    required this.depositOrders,
    required this.inProgress,
    required this.inProgressOrders,
  });

  final double entered;

  /// Orders with money received in the chosen month, latest payment first.
  /// Their [receivedIn] adds up to [entered].
  final List<Order> receivedOrders;
  final double sold;

  /// Orders opened in the chosen month, newest first.
  final List<Order> soldOrders;
  final double owed;
  final List<Debtor> debtors;
  final double depositOwed;

  /// Approved and running orders with a partial payment, oldest first.
  final List<Order> depositOrders;
  final double inProgress;

  /// Approved and running orders with nothing received, oldest first.
  final List<Order> inProgressOrders;

  /// The value of A receber.
  double get receivable => owed + depositOwed;

  /// How many customers A receber lists: one with completed and running
  /// orders counts once.
  int get receivableCustomers => {
    ...debtors.map((d) => d.key),
    ...depositOrders.map(_customerKey),
  }.length;

  static final empty = FinancialSummary(
    entered: 0,
    receivedOrders: const [],
    sold: 0,
    soldOrders: const [],
    owed: 0,
    debtors: const [],
    depositOwed: 0,
    depositOrders: const [],
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

    final received = candidates.where((o) => receivedIn(o, month) != 0).toList()
      ..sort((a, b) => receivedDate(b, month).compareTo(receivedDate(a, month)));

    final sold = created.where(isSold).toList()
      ..sort((a, b) => _oldestFirst(b, a));

    final open = openOrders.whereType<Order>().where(isOpen).toList()
      ..sort(_oldestFirst);

    final byCustomer = <String, List<Order>>{};
    final names = <String, String?>{};
    for (final order in open) {
      final key = _customerKey(order);
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
    final deposits = running.where(hasPartialPayment).toList();
    final notPaid = running.where((o) => !hasPartialPayment(o)).toList();

    return FinancialSummary(
      entered: entered,
      receivedOrders: received,
      sold: sold.fold<double>(0, (sum, o) => sum + (o.total ?? 0)),
      soldOrders: sold,
      owed: debtors.fold<double>(0, (sum, d) => sum + d.amount),
      debtors: debtors,
      depositOwed: _openSum(deposits),
      depositOrders: deposits,
      inProgress: _openSum(notPaid),
      inProgressOrders: notPaid,
    );
  }

  static String _customerKey(Order order) =>
      order.customer?.id ?? Debtor.noCustomerKey;

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
    bool inMonth(DateTime? date) => _isInMonth(date, month);

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

  /// The last day money came in on [order] in [month]. Old orders without
  /// transactions count on the day they were created (see [receivedIn]).
  static DateTime receivedDate(Order order, DateTime month) {
    final dates = (order.transactions ?? const <PaymentTransaction>[])
        .where((t) => t.type == PaymentTransactionType.payment)
        .map((t) => t.paidOn)
        .where((date) => _isInMonth(date, month))
        .toList()
      ..sort();
    if (dates.isNotEmpty) return dates.last;
    return order.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static bool _isInMonth(DateTime? date, DateTime month) {
    final local = date?.toLocal();
    return local?.year == month.year && local?.month == month.month;
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

  /// Open and not completed yet: in Em andamento, or in A receber once it
  /// has a partial payment.
  static bool isInProgress(Order order) =>
      isOpen(order) &&
      (order.status == 'approved' || order.status == 'progress');

  /// Counts in A receber: completed with a balance, or running with a
  /// partial payment. The one rule for "what the customer owes now"
  /// (Financeiro, Clientes and the customer screen).
  static bool owesNow(Order order) =>
      isReceivable(order) || (isInProgress(order) && hasPartialPayment(order));

  /// Part of [order] was already received.
  static bool hasPartialPayment(Order order) => (order.paidAmount ?? 0) > 0;

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
