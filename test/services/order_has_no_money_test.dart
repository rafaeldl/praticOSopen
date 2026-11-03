import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/services/authorization_service.dart';

void main() {
  group('AuthorizationService.orderHasNoMoney (order-delete)', () {
    test('no paid amount and no transaction', () {
      expect(AuthorizationService.orderHasNoMoney(Order()), isTrue);
      expect(AuthorizationService.orderHasNoMoney(Order()..paidAmount = 0), isTrue);
    });

    test('a paid amount counts as money', () {
      expect(AuthorizationService.orderHasNoMoney(Order()..paidAmount = 10), isFalse);
    });

    test('any transaction counts as money, a discount too', () {
      final order = Order()
        ..paidAmount = 0
        ..transactions = [PaymentTransaction.discount(amount: 5)];
      expect(AuthorizationService.orderHasNoMoney(order), isFalse);
    });
  });
}
