import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/receive_share_service.dart';

void main() {
  group('newOrderIdAfter ("+" Nova OS in "Em qual OS?")', () {
    test('"X" (closed without saving): no order, nothing saved', () async {
      final created = Completer<String>();
      expect(await newOrderIdAfter(Future.value(null), created.future), isNull);
    });

    test('"✓": waits for the order written after the sheet closed', () async {
      final created = Completer<String>();
      final id = newOrderIdAfter(Future.value(true), created.future);
      created.complete('o42');
      expect(await id, 'o42');
    });

    test('created before the sheet finished closing still counts', () async {
      final created = Completer<String>()..complete('o7');
      expect(await newOrderIdAfter(Future.value(true), created.future), 'o7');
    });

    test('never created (offline): times out', () async {
      final created = Completer<String>();
      expect(
        newOrderIdAfter(
          Future.value(true),
          created.future,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
