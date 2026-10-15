import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer_charge.dart';
import 'package:praticos/repositories/tenant/customer_charge_repository.dart';

void main() {
  CustomerCharge charge(String status, String due) => CustomerCharge.fromJson({
    'status': status,
    'dueDate': due,
    'value': 100,
  }, id: '$status-$due');

  test('open is pending or overdue', () {
    expect(charge('pending', '2026-10-01').isOpen, isTrue);
    expect(charge('overdue', '2026-10-01').isOpen, isTrue);
    expect(charge('paid', '2026-10-01').isOpen, isFalse);
    expect(charge('canceled', '2026-10-01').isOpen, isFalse);
    expect(charge('refunded', '2026-10-01').isOpen, isFalse);
  });

  test('openOf picks the open one (later due date on a race)', () {
    expect(
      CustomerChargeRepository.openOf([charge('paid', '2026-10-01')]),
      isNull,
    );
    final open = CustomerChargeRepository.openOf([
      charge('canceled', '2026-12-01'),
      charge('pending', '2026-10-01'),
      charge('overdue', '2026-10-05'),
    ]);
    expect(open?.id, 'overdue-2026-10-05');
  });

  test('fromJson tolerates missing fields', () {
    final c = CustomerCharge.fromJson({});
    expect(c.allocations, isEmpty);
    expect(c.dueDay, isNull);
    expect(c.paidOutside, isFalse);
  });
}
