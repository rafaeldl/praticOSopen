import 'dart:async';

import 'package:praticos/models/order.dart';

/// Latest lists of [a] and [b] merged, without repeating an order (by id).
/// Emits once both have emitted; an error from either is forwarded.
Stream<List<Order?>> mergeOrderStreams(
  Stream<List<Order?>> a,
  Stream<List<Order?>> b,
) {
  late StreamController<List<Order?>> controller;
  StreamSubscription<List<Order?>>? subA;
  StreamSubscription<List<Order?>>? subB;
  List<Order?>? lastA;
  List<Order?>? lastB;

  void emit() {
    if (lastA == null || lastB == null) return;
    final seen = <String>{};
    final merged = <Order?>[];
    for (final order in [...lastA!, ...lastB!]) {
      if (order == null) continue;
      final id = order.id;
      if (id != null && !seen.add(id)) continue;
      merged.add(order);
    }
    controller.add(merged);
  }

  controller = StreamController<List<Order?>>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
