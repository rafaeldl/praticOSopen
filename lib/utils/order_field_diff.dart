import 'package:collection/collection.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// Marks a field the app removed from the order (`FieldValue.delete()` when
/// written).
class DeleteFieldOp {
  const DeleteFieldOp();

  @override
  bool operator ==(Object other) => other is DeleteFieldOp;

  @override
  int get hashCode => 0;
}

/// Saving an order writes only the top-level fields the app changed since it
/// last read or saved the order, so a field written elsewhere (an item added
/// by the web, a payment by the server) survives the app's next save.
class OrderFieldDiff {
  OrderFieldDiff._();

  /// Never written by the order save: `id` is the doc id, `number` is set
  /// once on create, payments have their own writes
  /// ([OrderPaymentMath.paymentFields]) and the audit fields are stamped by
  /// the save itself.
  static const Set<String> ignoredFields = {
    'id',
    'number',
    'updatedAt',
    'updatedBy',
    ...OrderPaymentMath.paymentFields,
  };

  static const _equality = DeepCollectionEquality();

  /// Fields that make up the money of an order: they are written together.
  static const Set<String> moneyFields = {
    'services',
    'products',
    'discount',
    'total',
  };

  /// Money fields the person edits; `total` is derived from them.
  static const Set<String> moneyInputs = {'services', 'products', 'discount'};

  /// The four money fields after applying [appMoney] (items or discount the
  /// app changed) over [server] (the order as stored), with the total
  /// recomputed from the result: never a total of old items.
  static Map<String, dynamic> mergeMoney(
    Map<String, dynamic> server,
    Map<String, dynamic> appMoney,
  ) {
    final merged = <String, dynamic>{
      for (final key in moneyInputs)
        key: appMoney.containsKey(key) ? appMoney[key] : server[key],
    };
    final order = Order.fromJson({
      'services': merged['services'],
      'products': merged['products'],
      'discount': merged['discount'],
    });
    merged['total'] = OrderPaymentMath.computeTotal(order);
    return merged;
  }

  /// Deep copy of the order's JSON, without [ignoredFields]. The copy must be
  /// deep: the screens change nested maps and lists of the order in place.
  static Map<String, dynamic> snapshotOf(Order order) {
    final json = deepCopy(order.toJson()) as Map<String, dynamic>;
    ignoredFields.forEach(json.remove);
    return json;
  }

  /// Top-level fields of [current] that differ from [base]. A field present
  /// in [base] and gone from [current] comes as [DeleteFieldOp].
  static Map<String, dynamic> changedFields(
    Map<String, dynamic> base,
    Map<String, dynamic> current,
  ) {
    final changed = <String, dynamic>{};
    current.forEach((key, value) {
      if (ignoredFields.contains(key)) return;
      if (!base.containsKey(key) && value == null) return;
      if (!_equality.equals(base[key], value)) changed[key] = value;
    });
    for (final key in base.keys) {
      if (ignoredFields.contains(key)) continue;
      if (!current.containsKey(key) && base[key] != null) {
        changed[key] = const DeleteFieldOp();
      }
    }
    return changed;
  }

  /// Copies maps and lists recursively; other values are kept as they are.
  static dynamic deepCopy(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): deepCopy(entry.value),
      };
    }
    if (value is List) return [for (final item in value) deepCopy(item)];
    return value;
  }

  /// Whether [a] and [b] hold the same JSON value.
  static bool same(dynamic a, dynamic b) => _equality.equals(a, b);
}
