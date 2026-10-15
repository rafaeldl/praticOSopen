import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// Everything "Desfazer recebimento" writes in one WriteBatch: the receipt
/// turns `canceled` and each order loses its share. Built by
/// [buildReceiptUndo], applied by `TenantReceiptRepository.cancel`.
class ReceiptUndoPlan {
  const ReceiptUndoPlan({
    required this.receiptUpdate,
    required this.orderUpdates,
  });

  /// `{status: 'canceled', updatedAt, updatedBy}` (the only fields the
  /// rules let change, besides `receiptFile`).
  final Map<String, dynamic> receiptUpdate;

  /// orderId -> plain update map: `transactions`, `paidAmount`, `paid`,
  /// `payment`, `discount`, `total`, audit and, when the share had the
  /// shared receipt file, `documents` without that entry.
  final Map<String, Map<String, dynamic>> orderUpdates;
}

/// Removes the share of [receipt] from each order in [orders] (current
/// snapshots), with the same math as removing one payment by hand
/// ([OrderPaymentMath.removeTransaction]): `paidAmount` goes down and
/// `paid`/`payment` are recomputed. The `OrderDocument` that points to the
/// shared receipt file is dropped from the order, but the file itself stays
/// in Storage (it belongs to the receipt).
///
/// Orders that are missing or no longer have the share are left out.
/// [orders] are not mutated.
ReceiptUndoPlan buildReceiptUndo({
  required Receipt receipt,
  required List<Order> orders,
  required DateTime now,
  UserAggr? actor,
}) {
  final byId = {for (final o in orders) o.id: o};
  final orderUpdates = <String, Map<String, dynamic>>{};

  for (final allocation in receipt.allocations ?? const <ReceiptAllocation>[]) {
    final current = byId[allocation.orderId];
    final txId = allocation.transactionId;
    if (current == null || allocation.orderId == null || txId == null) {
      continue;
    }
    final share = (current.transactions ?? const <PaymentTransaction>[])
        .where((t) => t.id == txId)
        .firstOrNull;
    if (share == null) continue;

    final fresh = Order.fromJson(current.toJson())..id = current.id;
    OrderPaymentMath.removeTransaction(fresh, share);
    fresh.updatedAt = now;
    fresh.updatedBy = actor;
    final update = OrderPaymentMath.paymentUpdateOf(fresh);
    if (actor == null) update.remove('updatedBy');

    final documents = current.documents ?? const <OrderDocument>[];
    final kept = [
      for (final d in documents)
        if (d.linkedTransactionId != txId &&
            (share.receiptDocumentId == null ||
                d.id != share.receiptDocumentId))
          d,
    ];
    if (kept.length != documents.length) {
      update['documents'] = [for (final d in kept) d.toJson()];
    }
    orderUpdates[allocation.orderId!] = update;
  }

  return ReceiptUndoPlan(
    receiptUpdate: {
      'status': ReceiptStatus.canceled,
      'updatedAt': now.toIso8601String(),
      if (actor != null) 'updatedBy': actor.toJson(),
    },
    orderUpdates: orderUpdates,
  );
}
