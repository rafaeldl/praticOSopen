import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/utils/receipt_plan.dart';

Order _order(String id, int number, double total, {double paid = 0}) => Order()
  ..id = id
  ..number = number
  ..total = total
  ..paidAmount = paid
  ..payment = 'unpaid';

void main() {
  final paidAt = DateTime(2026, 10, 12);
  final now = DateTime(2026, 10, 14, 9, 30);
  final customer = CustomerAggr()
    ..id = 'c1'
    ..name = 'João';
  final orders = [
    _order('a', 182, 450),
    _order('b', 190, 600, paid: 100),
    _order('c', 201, 500),
  ];
  List<PaymentAllocation> split(double amount) =>
      allocatePayment(orders.map(OpenBalance.ofOrder).toList(), amount);

  test('one payment per order with its share, date and receipt id', () {
    final plan = buildReceiptPlan(
      receiptId: 'r1',
      customer: customer,
      orders: orders,
      allocations: split(750),
      paidAt: paidAt,
      now: now,
    );

    expect(plan.orderUpdates.keys, ['a', 'b']);
    final txA = plan.transactions['a']!;
    expect(txA.type, PaymentTransactionType.payment);
    expect(txA.amount, 450);
    expect(txA.paidAt, paidAt);
    expect(txA.createdAt, now);
    expect(txA.receiptGroupId, 'r1');
    expect(plan.transactions['b']!.amount, 300);
    expect(plan.transactions['a']!.id, isNot(plan.transactions['b']!.id));
  });

  test('flips paid/payment for orders that become fully paid', () {
    final plan = buildReceiptPlan(
      receiptId: 'r1',
      customer: customer,
      orders: orders,
      allocations: split(1000),
      paidAt: paidAt,
      now: now,
    );
    final a = plan.orderUpdates['a']!;
    expect(a['paid'], isTrue);
    expect(a['payment'], 'paid');
    expect((a['paidAmount'] as IncrementOp).by, 450);
    expect(a['transactions'], isA<ArrayUnionOp>());

    // b: 100 already paid + 500 = 600 -> paid too.
    final b = plan.orderUpdates['b']!;
    expect(b['paid'], isTrue);
    expect(b['payment'], 'paid');

    // c: 50 of 500 -> still unpaid (the app has only paid/unpaid).
    final c = plan.orderUpdates['c']!;
    expect(c['paid'], isFalse);
    expect(c['payment'], 'unpaid');
  });

  test('the receipt lists the allocations and the total', () {
    final plan = buildReceiptPlan(
      receiptId: 'r1',
      customer: customer,
      orders: orders,
      allocations: split(750.55),
      paidAt: paidAt,
      now: now,
    );
    final receipt = plan.receipt;
    expect(receipt.id, 'r1');
    expect(receipt.amount, 750.55);
    expect(receipt.status, ReceiptStatus.active);
    expect(receipt.customer?.name, 'João');
    expect(receipt.paidAt, paidAt);
    expect(receipt.allocations!.map((a) => a.orderNumber), [182, 190]);
    expect(receipt.allocations!.map((a) => a.amount), [450, 300.55]);
    expect(receipt.allocations!.first.transactionId,
        plan.transactions['a']!.id);
    expect(receipt.receiptFile, isNull);
    expect(plan.orderUpdates['a']!.containsKey('documents'), isFalse);
  });

  test('with a file, each order gets a receipt document linked to its '
      'payment, pointing to the same file', () {
    final file = ReceiptFile(
      url: 'https://x/r1.jpg',
      storagePath: 'tenants/co/receipts/r1/r1.jpg',
      fileName: 'r1.jpg',
      contentType: 'image/jpeg',
    );
    final plan = buildReceiptPlan(
      receiptId: 'r1',
      customer: customer,
      orders: orders,
      allocations: split(750),
      paidAt: paidAt,
      now: now,
      file: file,
    );
    for (final id in ['a', 'b']) {
      final union = plan.orderUpdates[id]!['documents'] as ArrayUnionOp;
      final doc = OrderDocument.fromJson(
          Map<String, dynamic>.from(union.values.single as Map));
      final tx = plan.transactions[id]!;
      expect(doc.type, OrderDocumentType.receipt);
      expect(doc.url, file.url);
      expect(doc.storagePath, file.storagePath);
      expect(doc.linkedTransactionId, tx.id);
      expect(tx.receiptDocumentId, doc.id);
    }
    expect(plan.receipt.receiptFile?.url, file.url);
  });

  test('an allocation for an unknown order is an error', () {
    expect(
      () => buildReceiptPlan(
        receiptId: 'r1',
        customer: customer,
        orders: orders,
        allocations: const [PaymentAllocation(orderId: 'zz', amount: 1)],
        paidAt: paidAt,
        now: now,
      ),
      throwsArgumentError,
    );
  });
}
