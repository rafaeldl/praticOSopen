import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/receipt.dart';

void main() {
  test('Receipt JSON round trip with English keys', () {
    final receipt = Receipt()
      ..id = 'r1'
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'João')
      ..amount = 750
      ..paidAt = DateTime(2026, 10, 12)
      ..status = ReceiptStatus.active
      ..receiptFile = ReceiptFile(
          url: 'u', storagePath: 'p', fileName: 'f.pdf', contentType: 'application/pdf')
      ..allocations = [
        ReceiptAllocation(
            orderId: 'a', orderNumber: 182, amount: 450, transactionId: 't1'),
      ];

    final json = receipt.toJson();
    expect(json.keys, containsAll(
        ['customer', 'amount', 'paidAt', 'status', 'receiptFile', 'allocations']));
    expect(json['customer'], isA<Map>());
    expect((json['allocations'] as List).single, isA<Map>());
    expect(json['status'], 'active');

    final back = Receipt.fromJson(json);
    expect(back.customer?.name, 'João');
    expect(back.amount, 750);
    expect(back.paidAt, DateTime(2026, 10, 12));
    expect(back.receiptFile?.contentType, 'application/pdf');
    expect(back.allocations!.single.orderNumber, 182);
    expect(back.allocations!.single.transactionId, 't1');
  });

  group('PaymentTransaction paidAt / receiptGroupId', () {
    test('round trip', () {
      final tx = PaymentTransaction(
        id: 't1',
        type: PaymentTransactionType.payment,
        amount: 10,
        createdAt: DateTime(2026, 10, 14),
        paidAt: DateTime(2026, 10, 10),
        receiptGroupId: 'r1',
      );
      final back = PaymentTransaction.fromJson(tx.toJson());
      expect(back.paidAt, DateTime(2026, 10, 10));
      expect(back.receiptGroupId, 'r1');
      expect(back.paidOn, DateTime(2026, 10, 10));
    });

    test('old payments without paidAt use createdAt', () {
      final json = PaymentTransaction(
        id: 't1',
        type: PaymentTransactionType.payment,
        amount: 10,
        createdAt: DateTime(2026, 10, 14),
      ).toJson()
        ..remove('paidAt')
        ..remove('receiptGroupId');
      final back = PaymentTransaction.fromJson(json);
      expect(back.paidAt, isNull);
      expect(back.receiptGroupId, isNull);
      expect(back.paidOn, DateTime(2026, 10, 14));
    });
  });

  test('a customer receipt file is shared: undoing one order keeps it', () {
    final shared = OrderDocument()
      ..storagePath = 'tenants/co/receipts/r1/pix.jpg';
    final own = OrderDocument()
      ..storagePath = 'tenants/co/orders/o1/documents/pix.jpg';
    expect(shared.isSharedReceiptFile, isTrue);
    expect(own.isSharedReceiptFile, isFalse);
    expect(OrderDocument().isSharedReceiptFile, isFalse);
  });
}
