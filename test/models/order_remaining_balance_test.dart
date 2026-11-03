import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';

void main() {
  group('Order.remainingBalance (D4)', () {
    test('never below zero when more was paid than the total', () {
      final order = Order()
        ..total = 100
        ..paidAmount = 120;
      expect(order.remainingBalance, 0);
      expect(order.isFullyPaid, isTrue);
    });

    test('rounded to cents', () {
      final order = Order()
        ..total = 824.4200000000001
        ..paidAmount = 824.42;
      expect(order.remainingBalance, 0);
      expect((Order()
            ..total = 0.3
            ..paidAmount = 0.1)
          .remainingBalance, 0.2);
    });
  });
}
