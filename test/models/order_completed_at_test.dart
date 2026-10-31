import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';

void main() {
  test('reads completedAt from the server', () {
    final order = Order.fromJson({'completedAt': '2026-10-31T15:00:00.000Z'});
    expect(order.completedAt, DateTime.utc(2026, 10, 31, 15));
  });

  test('never sends completedAt: a full save cannot overwrite it', () {
    final order = Order()..completedAt = DateTime.utc(2026, 10, 31, 15);
    expect(order.toJson().containsKey('completedAt'), isFalse);

    final empty = Order();
    expect(empty.toJson().containsKey('completedAt'), isFalse);
  });
}
