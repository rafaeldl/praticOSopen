import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';

/// Thrown when someone tries to remove a payment created by the Asaas
/// integration. Those can only be undone by refunding the charge in Asaas.
class AsaasTransactionLockedException implements Exception {
  final String transactionId;

  const AsaasTransactionLockedException(this.transactionId);

  @override
  String toString() => 'AsaasTransactionLockedException($transactionId)';
}

/// Marker for `FieldValue.arrayUnion(values)`; converted by the repository.
class ArrayUnionOp {
  final List<Object?> values;

  const ArrayUnionOp(this.values);
}

/// Marker for `FieldValue.increment(by)`; converted by the repository.
class IncrementOp {
  final num by;

  const IncrementOp(this.by);
}

/// Pure payment rules for an [Order].
///
/// Used inside Firestore transactions (TenantOrderRepository.updatePayments):
/// every function mutates and returns the `fresh` order it receives and never
/// reads global state. Same rules as the server (order.service.ts):
/// - `total` is net of discount (items - discount);
/// - remaining balance = total - paidAmount;
/// - `payment` is stored only as 'paid' | 'unpaid' ('partial' is in memory).
class OrderPaymentMath {
  OrderPaymentMath._();

  static const String asaasTransactionPrefix = 'asaas_';

  /// Fields owned by the payment flow. A full-order save must never write
  /// them, otherwise it overwrites payments written by the server.
  static const List<String> paymentFields = [
    'transactions',
    'paidAmount',
    'paid',
    'payment',
  ];

  static double roundMoney(double value) =>
      (value * 100).roundToDouble() / 100;

  /// Copy of [json] without [paymentFields].
  static Map<String, dynamic> stripPaymentFields(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final field in paymentFields) {
      copy.remove(field);
    }
    return copy;
  }

  /// Map written by updatePayments: payment fields, discount and total
  /// (a discount transaction changes both) and the audit fields.
  static Map<String, dynamic> paymentUpdateOf(Order order) {
    final json = order.toJson();
    return {
      'transactions': json['transactions'] ?? <Map<String, dynamic>>[],
      'paidAmount': order.paidAmount ?? 0.0,
      'paid': order.paid ?? false,
      'payment': order.payment,
      'discount': order.discount ?? 0.0,
      'total': order.total ?? 0.0,
      if (json['updatedAt'] != null) 'updatedAt': json['updatedAt'],
      if (json['updatedBy'] != null) 'updatedBy': json['updatedBy'],
    };
  }

  static bool isAsaasTransaction(PaymentTransaction transaction) =>
      transaction.id?.startsWith(asaasTransactionPrefix) ?? false;

  /// Same transaction? By id when both have one; legacy transactions
  /// (no id) match by type, amount and creation date.
  static bool sameTransaction(PaymentTransaction a, PaymentTransaction b) {
    if (a.id != null && b.id != null) return a.id == b.id;
    return a.type == b.type &&
        a.amount == b.amount &&
        a.createdAt.toIso8601String() == b.createdAt.toIso8601String();
  }

  static double _itemsTotal(Order order) {
    double sum = 0.0;
    for (final service in order.services ?? const <OrderService>[]) {
      sum += service.value ?? 0.0;
    }
    for (final product in order.products ?? const <OrderProduct>[]) {
      sum += product.total ?? 0.0;
    }
    return sum;
  }

  /// total = services + products - discount (same rule as OrderStore.updateTotal).
  static double computeTotal(Order order) =>
      roundMoney(_itemsTotal(order) - (order.discount ?? 0.0));

  static String paymentStatusFor({
    required double total,
    required double paidAmount,
  }) =>
      (total > 0 && roundMoney(paidAmount) >= roundMoney(total))
          ? 'paid'
          : 'unpaid';

  static double remainingBalance(Order order) {
    final remaining =
        roundMoney((order.total ?? 0.0) - (order.paidAmount ?? 0.0));
    return remaining > 0 ? remaining : 0.0;
  }

  static Order _refreshStatus(Order order) {
    order.payment = paymentStatusFor(
      total: order.total ?? 0.0,
      paidAmount: order.paidAmount ?? 0.0,
    );
    order.paid = order.payment == 'paid';
    return order;
  }

  static Order addPayment(Order fresh, PaymentTransaction transaction) {
    fresh.transactions = [...?fresh.transactions, transaction];
    fresh.paidAmount =
        roundMoney((fresh.paidAmount ?? 0.0) + transaction.amount);
    return _refreshStatus(fresh);
  }

  static Order addDiscount(Order fresh, PaymentTransaction transaction) {
    fresh.transactions = [...?fresh.transactions, transaction];
    fresh.discount = roundMoney((fresh.discount ?? 0.0) + transaction.amount);
    fresh.total = computeTotal(fresh);
    return _refreshStatus(fresh);
  }

  /// Offline-safe update map for adding a payment (applied with field
  /// transforms by the repository). `paid`/`payment` are computed from
  /// [current] plus the new amount; [current] is not mutated.
  static Map<String, dynamic> addPaymentUpdate({
    required Order current,
    required PaymentTransaction tx,
    DateTime? updatedAt,
  }) {
    final newPaid = roundMoney((current.paidAmount ?? 0.0) + tx.amount);
    final status = paymentStatusFor(
      total: current.total ?? 0.0,
      paidAmount: newPaid,
    );
    return {
      'transactions': ArrayUnionOp([tx.toJson()]),
      'paidAmount': IncrementOp(tx.amount),
      'paid': status == 'paid',
      'payment': status,
      ..._auditOf(current, updatedAt),
    };
  }

  /// Offline-safe update map for adding a discount: `discount` grows and the
  /// (net) `total` shrinks by the same amount. [current] is not mutated.
  static Map<String, dynamic> addDiscountUpdate({
    required Order current,
    required PaymentTransaction tx,
    DateTime? updatedAt,
  }) {
    final newTotal = roundMoney((current.total ?? 0.0) - tx.amount);
    final status = paymentStatusFor(
      total: newTotal,
      paidAmount: current.paidAmount ?? 0.0,
    );
    return {
      'transactions': ArrayUnionOp([tx.toJson()]),
      'discount': IncrementOp(tx.amount),
      'total': IncrementOp(-tx.amount),
      'paid': status == 'paid',
      'payment': status,
      ..._auditOf(current, updatedAt),
    };
  }

  static Map<String, dynamic> _auditOf(Order current, DateTime? updatedAt) => {
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        if (current.updatedBy != null)
          'updatedBy': current.updatedBy!.toJson(),
      };

  /// Adds the remaining balance as a payment (when > 0) and forces 'paid'.
  static Order markAsFullyPaid(
    Order fresh,
    PaymentTransaction Function(double remaining) buildPayment,
  ) {
    final remaining = remainingBalance(fresh);
    if (remaining > 0) {
      addPayment(fresh, buildPayment(remaining));
    }
    fresh.payment = 'paid';
    fresh.paid = true;
    return fresh;
  }

  /// Removes [target] from the fresh order. Asaas transactions are locked.
  static Order removeTransaction(Order fresh, PaymentTransaction target) {
    if (isAsaasTransaction(target)) {
      throw AsaasTransactionLockedException(target.id!);
    }
    final list = [...?fresh.transactions];
    final index = list.indexWhere((t) => sameTransaction(t, target));
    if (index < 0) return fresh;

    final removed = list.removeAt(index);
    fresh.transactions = list;

    if (removed.type == PaymentTransactionType.payment) {
      final paid = roundMoney((fresh.paidAmount ?? 0.0) - removed.amount);
      fresh.paidAmount = paid < 0 ? 0.0 : paid;
    } else {
      final discount = roundMoney((fresh.discount ?? 0.0) - removed.amount);
      fresh.discount = discount < 0 ? 0.0 : discount;
      fresh.total = computeTotal(fresh);
    }
    return _refreshStatus(fresh);
  }

  /// Removes every manual transaction and discount. Asaas payments stay.
  static Order resetPayments(Order fresh) {
    final kept = (fresh.transactions ?? const <PaymentTransaction>[])
        .where(isAsaasTransaction)
        .toList();
    fresh.transactions = kept;
    fresh.paidAmount = roundMoney(kept
        .where((t) => t.type == PaymentTransactionType.payment)
        .fold<double>(0.0, (sum, t) => sum + t.amount));
    fresh.discount = 0.0;
    fresh.total = computeTotal(fresh);
    return _refreshStatus(fresh);
  }

  static Order setReceipt(
    Order fresh,
    PaymentTransaction target,
    String? receiptDocumentId,
  ) {
    for (final transaction in fresh.transactions ?? const <PaymentTransaction>[]) {
      if (sameTransaction(transaction, target)) {
        transaction.receiptDocumentId = receiptDocumentId;
      }
    }
    return fresh;
  }

  /// Payment status driven by the order status: quotes and canceled orders
  /// have no payment status; otherwise keep it (or compute when missing).
  static Order applyOrderStatus(Order fresh, String? orderStatus) {
    if (orderStatus == 'quote' || orderStatus == 'canceled') {
      fresh.payment = null;
      return fresh;
    }
    if (fresh.payment == null) return _refreshStatus(fresh);
    return fresh;
  }
}
