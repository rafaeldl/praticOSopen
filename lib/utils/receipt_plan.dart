import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_allocation.dart';

/// Everything one customer receipt writes: the receipt document and, per
/// order, the offline-safe payment update (arrayUnion + increment markers,
/// see [OrderPaymentMath.addPaymentUpdate]). Applied in one WriteBatch by
/// `TenantReceiptRepository.save`.
class ReceiptPlan {
  const ReceiptPlan({
    required this.receipt,
    required this.orderUpdates,
    required this.transactions,
  });

  final Receipt receipt;

  /// orderId -> update map (with [ArrayUnionOp] / [IncrementOp] markers).
  final Map<String, Map<String, dynamic>> orderUpdates;

  /// orderId -> the payment transaction written on that order.
  final Map<String, PaymentTransaction> transactions;
}

/// Builds the [ReceiptPlan] of a payment split as [allocations] over
/// [orders] (current snapshots, used for the `paid`/`payment` status).
///
/// Each order gets a regular `payment` transaction with its share,
/// [paidAt] and `receiptGroupId` = [receiptId]. With [file], each order also
/// gets a receipt [OrderDocument] pointing to the same Storage file, linked
/// to its transaction, so "Ver comprovante" on the order keeps working.
ReceiptPlan buildReceiptPlan({
  required String receiptId,
  required CustomerAggr? customer,
  required List<Order> orders,
  required List<PaymentAllocation> allocations,
  required DateTime paidAt,
  required DateTime now,
  UserAggr? actor,
  CompanyAggr? company,
  ReceiptFile? file,
}) {
  final byId = {for (final o in orders) o.id: o};
  final orderUpdates = <String, Map<String, dynamic>>{};
  final transactions = <String, PaymentTransaction>{};
  final receiptAllocations = <ReceiptAllocation>[];
  var totalCents = 0;

  for (var i = 0; i < allocations.length; i++) {
    final allocation = allocations[i];
    final order = byId[allocation.orderId];
    if (order == null) {
      throw ArgumentError('Order ${allocation.orderId} not in orders');
    }
    if (allocation.amount <= 0) continue;
    final amount = OrderPaymentMath.roundMoney(allocation.amount);
    final tx = PaymentTransaction(
      id: '${receiptId}_$i',
      type: PaymentTransactionType.payment,
      amount: amount,
      createdAt: now,
      createdBy: actor,
      paidAt: paidAt,
      receiptGroupId: receiptId,
    );

    OrderDocument? document;
    if (file != null) {
      document = OrderDocument()
        ..id = 'receipt_${receiptId}_$i'
        ..url = file.url
        ..storagePath = file.storagePath
        ..fileName = file.fileName
        ..contentType = file.contentType
        ..type = OrderDocumentType.receipt
        ..createdAt = now
        ..createdBy = actor
        ..linkedTransactionId = tx.id;
      tx.receiptDocumentId = document.id;
    }

    final update = OrderPaymentMath.addPaymentUpdate(
      current: order,
      tx: tx,
      updatedAt: now,
    );
    if (document != null) {
      update['documents'] = ArrayUnionOp([document.toJson()]);
    }

    orderUpdates[allocation.orderId] = update;
    transactions[allocation.orderId] = tx;
    receiptAllocations.add(ReceiptAllocation(
      orderId: allocation.orderId,
      orderNumber: allocation.orderNumber ?? order.number,
      amount: amount,
      transactionId: tx.id,
    ));
    totalCents += (amount * 100).round();
  }

  final receipt = Receipt()
    ..id = receiptId
    ..company = company
    ..customer = customer
    ..amount = totalCents / 100
    ..paidAt = paidAt
    ..receiptFile = file
    ..allocations = receiptAllocations
    ..status = ReceiptStatus.active
    ..createdAt = now
    ..createdBy = actor
    ..updatedAt = now
    ..updatedBy = actor;

  return ReceiptPlan(
    receipt: receipt,
    orderUpdates: orderUpdates,
    transactions: transactions,
  );
}
