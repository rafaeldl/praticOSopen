import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/payment_allocation.dart';

OpenBalance _b(String id, double open, [int? number]) =>
    OpenBalance(orderId: id, open: open, orderNumber: number);

void main() {
  group('allocatePayment', () {
    final balances = [_b('a', 450, 182), _b('b', 500, 190), _b('c', 500, 201)];

    test('pays the oldest first and stops when the money ends', () {
      expect(allocatePayment(balances, 750), [
        const PaymentAllocation(orderId: 'a', orderNumber: 182, amount: 450),
        const PaymentAllocation(orderId: 'b', orderNumber: 190, amount: 300),
      ]);
    });

    test('the total owed settles every order', () {
      final result = allocatePayment(balances, 1450);
      expect(result.map((a) => a.amount), [450, 500, 500]);
    });

    test('less than the first order goes all to it', () {
      expect(allocatePayment(balances, 100).single,
          const PaymentAllocation(orderId: 'a', orderNumber: 182, amount: 100));
    });

    test('caps each order at its open amount; extra is not allocated', () {
      final result = allocatePayment(balances, 2000);
      expect(result.map((a) => a.amount), [450, 500, 500]);
    });

    test('zero or negative amount allocates nothing', () {
      expect(allocatePayment(balances, 0), isEmpty);
      expect(allocatePayment(balances, -10), isEmpty);
    });

    test('skips orders with nothing open', () {
      final result = allocatePayment([_b('a', 0), _b('b', 10)], 5);
      expect(result.single.orderId, 'b');
    });

    test('cents-safe: shares add up exactly to the amount', () {
      final odd = [_b('a', 0.1), _b('b', 0.2), _b('c', 33.33)];
      final result = allocatePayment(odd, 10.3);
      expect(result.map((a) => a.amount), [0.1, 0.2, 10.0]);
      final cents = result.fold<int>(0, (s, a) => s + (a.amount * 100).round());
      expect(cents, 1030);
    });

    test('floating noise in the open amount is rounded to cents', () {
      final result = allocatePayment([_b('a', 0.1 + 0.2), _b('b', 1)], 0.3);
      expect(result.single.amount, 0.3);
    });

    test('keeps the order it was given (a manual choice can be passed)', () {
      final result = allocatePayment([balances[2], balances[0]], 600);
      expect(result.map((a) => a.orderId), ['c', 'a']);
      expect(result.map((a) => a.amount), [500, 100]);
    });
  });

  test('totalOpen sums in cents', () {
    expect(totalOpen([_b('a', 0.1), _b('b', 0.2)]), 0.3);
  });

  test('OpenBalance.ofOrder never goes negative', () {
    final order = Order()
      ..id = 'x'
      ..number = 7
      ..total = 100
      ..paidAmount = 130;
    final balance = OpenBalance.ofOrder(order);
    expect(balance.open, 0);
    expect(balance.orderNumber, 7);
    final partial = OpenBalance.ofOrder(Order()
      ..id = 'y'
      ..total = 100
      ..paidAmount = 40);
    expect(partial.open, 60);
  });

  test('previewAllocation: settles, partial and untouched', () {
    final balances = [_b('a', 450), _b('b', 500), _b('c', 500)];
    final preview =
        previewAllocation(balances, allocatePayment(balances, 750));
    expect(preview[0].settles, isTrue);
    expect(preview[0].received, 450);
    expect(preview[1].settles, isFalse);
    expect(preview[1].received, 300);
    expect(preview[1].remaining, 200);
    expect(preview[2].untouched, isTrue);
    expect(preview[2].remaining, 500);
  });
}
