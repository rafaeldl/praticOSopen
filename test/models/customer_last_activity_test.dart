import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/utils/customer_utils.dart';

void main() {
  test('lastActivityAt is read but never written back by the app', () {
    final customer = Customer.fromJson({
      'name': 'Ana',
      'lastActivityAt': '2026-11-09T12:00:00.000Z',
    });
    expect(customer.lastActivityAt, DateTime.utc(2026, 11, 9, 12));
    expect(customer.toJson().containsKey('lastActivityAt'), isFalse);
  });

  test('without lastActivityAt, the most recent of updatedAt and createdAt', () {
    final customer = Customer()
      ..createdAt = DateTime(2026, 1, 1)
      ..updatedAt = DateTime(2026, 2, 1);
    expect(customerLastActivity(customer), DateTime(2026, 2, 1));
    customer.lastActivityAt = DateTime(2026, 1, 15);
    expect(customerLastActivity(customer), DateTime(2026, 1, 15));
  });
}
