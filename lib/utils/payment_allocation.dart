import 'package:praticos/models/order.dart';

/// What is still open on one order, the input of [allocatePayment].
class OpenBalance {
  const OpenBalance({
    required this.orderId,
    required this.open,
    this.orderNumber,
  });

  /// Open balance of [order] (total - paidAmount, never negative).
  factory OpenBalance.ofOrder(Order order) {
    final open = (order.total ?? 0) - (order.paidAmount ?? 0);
    return OpenBalance(
      orderId: order.id ?? '',
      orderNumber: order.number,
      open: open > 0 ? open : 0,
    );
  }

  final String orderId;
  final int? orderNumber;
  final double open;
}

/// The share of a payment that goes to one order.
class PaymentAllocation {
  const PaymentAllocation({
    required this.orderId,
    required this.amount,
    this.orderNumber,
  });

  final String orderId;
  final int? orderNumber;
  final double amount;

  @override
  bool operator ==(Object other) =>
      other is PaymentAllocation &&
      other.orderId == orderId &&
      other.orderNumber == orderNumber &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(orderId, orderNumber, amount);

  @override
  String toString() => 'PaymentAllocation($orderId, #$orderNumber, $amount)';
}

int _toCents(double value) => (value * 100).round();

double _fromCents(int cents) => cents / 100;

/// Sum of the open balances, rounded to cents.
double totalOpen(Iterable<OpenBalance> balances) =>
    _fromCents(balances.fold<int>(0, (sum, b) => sum + _toCents(b.open)));

/// The balances of the orders the user chose ("Escolher as OS"), still in
/// the order of [balances] (oldest first). A null [chosen] means all of them.
List<OpenBalance> chosenBalances(
  List<OpenBalance> balances,
  Set<String>? chosen,
) {
  if (chosen == null) return List.of(balances);
  return [
    for (final b in balances)
      if (chosen.contains(b.orderId)) b,
  ];
}

/// Splits [amount] over [balances] in the given order (the caller passes
/// them oldest first, as `Debtor.orders`): each order gets at most what is
/// open on it, in whole cents. Orders that get nothing are left out.
///
/// The amount above the total open is not allocated (callers block
/// overpayment before). "Escolher as OS" passes only the chosen orders
/// ([chosenBalances]), still oldest first.
List<PaymentAllocation> allocatePayment(
  List<OpenBalance> balances,
  double amount,
) {
  var left = _toCents(amount);
  final result = <PaymentAllocation>[];
  for (final balance in balances) {
    if (left <= 0) break;
    final open = _toCents(balance.open);
    if (open <= 0) continue;
    final share = open < left ? open : left;
    result.add(PaymentAllocation(
      orderId: balance.orderId,
      orderNumber: balance.orderNumber,
      amount: _fromCents(share),
    ));
    left -= share;
  }
  return result;
}

/// How one order ends after a payment: what it gets and what stays open.
class AllocationPreview {
  const AllocationPreview({
    required this.balance,
    required this.received,
    required this.remaining,
  });

  final OpenBalance balance;
  final double received;
  final double remaining;

  bool get settles => received > 0 && remaining <= 0;
  bool get untouched => received <= 0;
}

/// One [AllocationPreview] per balance, in the same order ("Como fica").
List<AllocationPreview> previewAllocation(
  List<OpenBalance> balances,
  List<PaymentAllocation> allocations,
) {
  final byOrder = <String, int>{};
  for (final a in allocations) {
    byOrder[a.orderId] = (byOrder[a.orderId] ?? 0) + _toCents(a.amount);
  }
  return [
    for (final b in balances)
      AllocationPreview(
        balance: b,
        received: _fromCents(byOrder[b.orderId] ?? 0),
        remaining: _fromCents(
          _toCents(b.open) - (byOrder[b.orderId] ?? 0) < 0
              ? 0
              : _toCents(b.open) - (byOrder[b.orderId] ?? 0),
        ),
      ),
  ];
}
