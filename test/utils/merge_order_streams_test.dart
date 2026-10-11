import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/merge_order_streams.dart';

Order _order(String id) => Order()..id = id;

void main() {
  test('merges both lists without repeating an order', () async {
    final a = StreamController<List<Order?>>();
    final b = StreamController<List<Order?>>();
    final out = <List<String?>>[];
    final sub = mergeOrderStreams(a.stream, b.stream)
        .listen((list) => out.add(list.map((o) => o?.id).toList()));

    a.add([_order('1'), _order('2')]);
    await pumpEventQueue();
    expect(out, isEmpty); // waits for both
    b.add([_order('2'), _order('3'), null]);
    await pumpEventQueue();
    expect(out.last, ['1', '2', '3']);

    a.add([_order('4')]);
    await pumpEventQueue();
    expect(out.last, ['4', '2', '3']);
    await sub.cancel();
  });
}
