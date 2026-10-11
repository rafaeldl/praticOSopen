import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/utils/order_items.dart';

OrderService _service(String? id, double? value) => OrderService()
  ..service = (ServiceAggr()..id = id)
  ..value = value;

OrderProduct _product(String? id, double? value, [int quantity = 1]) =>
    OrderProduct()
      ..product = (ProductAggr()..id = id)
      ..value = value
      ..quantity = quantity;

void main() {
  group('summarizeOrderItems', () {
    test('items without price are counted apart and not summed', () {
      final summary = summarizeOrderItems(
        [_service('a', 100), _service('b', null)],
        [_product('p', 10, 3), _product('q', null, 2)],
      );
      expect(summary.total, 130);
      expect(summary.unpricedCount, 2);
      expect(summary.hasUnpriced, isTrue);
    });

    test('a product total, when present, wins over value × quantity', () {
      final p = _product('p', 10, 3)..total = 25;
      expect(productLineTotal(p), 25);
      expect(productLineTotal(_product('q', null)), isNull);
    });

    test('a free item (0) is priced, not "sem valor"', () {
      final summary = summarizeOrderItems([_service('g', 0)], const []);
      expect(summary.total, 0);
      expect(summary.hasUnpriced, isFalse);
    });
  });

  group('mostUsedItemKeys', () {
    test('orders by use count, ties by most recent', () {
      final orders = [
        Order()
          ..services = [_service('oil', 1)]
          ..products = [_product('filter', 1)],
        Order()
          ..services = [_service('align', 1), _service('oil', 1)]
          ..products = [],
        Order()
          ..services = [_service(null, 1)]
          ..products = [_product('filter', 1)],
      ];
      expect(mostUsedItemKeys(orders), [
        'service:oil',
        'product:filter',
        'service:align',
      ]);
      expect(mostUsedItemKeys(orders, limit: 1), ['service:oil']);
    });
  });
}
