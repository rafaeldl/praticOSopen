import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/utils/receipt_plan.dart';
import 'package:praticos/utils/receipt_undo.dart';

Order _order(String id, int number, double total, {double paid = 0}) => Order()
  ..id = id
  ..number = number
  ..total = total
  ..paidAmount = paid
  ..paid = false
  ..payment = 'unpaid'
  ..transactions = [
    if (paid > 0)
      PaymentTransaction(
        id: 'old_$id',
        type: PaymentTransactionType.payment,
        amount: paid,
        createdAt: DateTime(2026, 9, 1),
      ),
  ]
  ..documents = [
    OrderDocument()
      ..id = 'photo_$id'
      ..type = OrderDocumentType.other,
  ];

/// The order as it is after the receipt batch landed.
Order _applied(Order order, ReceiptPlan plan) {
  final tx = plan.transactions[order.id];
  if (tx == null) return order;
  final copy = Order.fromJson(order.toJson())..id = order.id;
  copy.transactions = [...?copy.transactions, tx];
  copy.paidAmount = (copy.paidAmount ?? 0) + tx.amount;
  copy.paid = (copy.paidAmount ?? 0) >= (copy.total ?? 0);
  copy.payment = copy.paid! ? 'paid' : 'unpaid';
  if (tx.receiptDocumentId != null) {
    copy.documents = [
      ...?copy.documents,
      OrderDocument()
        ..id = tx.receiptDocumentId
        ..type = OrderDocumentType.receipt
        ..storagePath = 'tenants/co/receipts/r1/r1.jpg'
        ..linkedTransactionId = tx.id,
    ];
  }
  return copy;
}

void main() {
  final now = DateTime(2026, 10, 15, 10);
  final actor = UserAggr()
    ..id = 'u1'
    ..name = 'Ana';
  final before = [
    _order('a', 182, 450),
    _order('b', 190, 600, paid: 100),
    _order('c', 201, 500),
  ];
  final plan = buildReceiptPlan(
    receiptId: 'r1',
    customer: CustomerAggr()
      ..id = 'c1'
      ..name = 'João',
    orders: before,
    allocations: allocatePayment(before.map(OpenBalance.ofOrder).toList(), 750),
    paidAt: DateTime(2026, 10, 14),
    now: DateTime(2026, 10, 14, 9),
    file: ReceiptFile(
      url: 'https://x/r1.jpg',
      storagePath: 'tenants/co/receipts/r1/r1.jpg',
      fileName: 'r1.jpg',
      contentType: 'image/jpeg',
    ),
  );
  final receipt = plan.receipt;
  final after = [for (final o in before) _applied(o, plan)];

  test('sanity: the receipt settled 182 and paid 300 on 190', () {
    expect(after[0].paid, isTrue);
    expect(after[1].paidAmount, 400);
  });

  test('cancels the receipt, with audit', () {
    final undo = buildReceiptUndo(
      receipt: receipt,
      orders: after,
      now: now,
      actor: actor,
    );
    expect(undo.receiptUpdate['status'], ReceiptStatus.canceled);
    expect(undo.receiptUpdate['updatedAt'], now.toIso8601String());
    expect((undo.receiptUpdate['updatedBy'] as Map)['id'], 'u1');
    // Only status/audit change on the receipt (rules allow nothing else).
    expect(undo.receiptUpdate.keys.toSet(), {
      'status',
      'updatedAt',
      'updatedBy',
    });
  });

  test('each order goes back to what it was before the receipt', () {
    final undo = buildReceiptUndo(
      receipt: receipt,
      orders: after,
      now: now,
      actor: actor,
    );
    // Order c got nothing: untouched.
    expect(undo.orderUpdates.keys.toSet(), {'a', 'b'});

    final a = undo.orderUpdates['a']!;
    expect(a['paidAmount'], 0);
    expect(a['paid'], isFalse);
    expect(a['payment'], 'unpaid');
    expect(a['transactions'], isEmpty);

    final b = undo.orderUpdates['b']!;
    expect(b['paidAmount'], 100);
    expect(b['paid'], isFalse);
    // The payment from before the receipt stays.
    expect((b['transactions'] as List).map((t) => (t as Map)['id']), ['old_b']);
  });

  test('drops the receipt document from the order but keeps the others', () {
    final undo = buildReceiptUndo(receipt: receipt, orders: after, now: now);
    final docs = undo.orderUpdates['a']!['documents'] as List;
    expect(docs.map((d) => (d as Map)['id']), ['photo_a']);
    // The plan never deletes the shared file: no storage path in the update.
    expect(undo.orderUpdates['a']!.toString(), isNot(contains('delete')));
    expect(undo.receiptUpdate.containsKey('receiptFile'), isFalse);
  });

  test(
    'an order that no longer has the share (or was not read) is skipped',
    () {
      final undo = buildReceiptUndo(
        receipt: receipt,
        orders: [before[0], after[1]],
        now: now,
      );
      expect(undo.orderUpdates.keys, ['b']);
    },
  );

  test('does not touch the orders it was given', () {
    buildReceiptUndo(receipt: receipt, orders: after, now: now);
    expect(after[0].paidAmount, 450);
    expect(after[0].transactions, hasLength(1));
  });
}
