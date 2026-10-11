import 'package:praticos/models/order.dart';

/// Line total of a product: null when it has no price ("sem valor").
double? productLineTotal(OrderProduct product) {
  final value = product.value;
  if (value == null) return null;
  return product.total ?? value * (product.quantity ?? 1);
}

/// Sum of the priced items and how many items have no price.
///
/// Items without a price are `null` (not 0): they show "sem valor" and are
/// left out of the total. Saving the order stays allowed.
class OrderItemsSummary {
  const OrderItemsSummary({required this.total, required this.unpricedCount});

  final double total;
  final int unpricedCount;

  bool get hasUnpriced => unpricedCount > 0;
}

OrderItemsSummary summarizeOrderItems(
  Iterable<OrderService> services,
  Iterable<OrderProduct> products,
) {
  var total = 0.0;
  var unpriced = 0;
  for (final s in services) {
    final value = s.value;
    if (value == null) {
      unpriced++;
    } else {
      total += value;
    }
  }
  for (final p in products) {
    final line = productLineTotal(p);
    if (line == null) {
      unpriced++;
    } else {
      total += line;
    }
  }
  return OrderItemsSummary(total: total, unpricedCount: unpriced);
}

/// Key of a catalog item in [mostUsedItemKeys]: `service:<id>` / `product:<id>`.
String catalogItemKey(String kind, String id) => '$kind:$id';

/// Catalog items most used in [orders] (the last ~50 of the company), most
/// used first, ties by most recent use. No new field: derived on the fly.
List<String> mostUsedItemKeys(List<Order> orders, {int limit = 5}) {
  final counts = <String, int>{};
  final firstSeen = <String, int>{};
  var position = 0;
  void count(String key) {
    counts[key] = (counts[key] ?? 0) + 1;
    firstSeen.putIfAbsent(key, () => position);
    position++;
  }

  for (final order in orders) {
    for (final s in order.services ?? const <OrderService>[]) {
      final id = s.service?.id;
      if (id != null) count(catalogItemKey('service', id));
    }
    for (final p in order.products ?? const <OrderProduct>[]) {
      final id = p.product?.id;
      if (id != null) count(catalogItemKey('product', id));
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : firstSeen[a]!.compareTo(firstSeen[b]!);
    });
  return keys.take(limit).toList();
}
