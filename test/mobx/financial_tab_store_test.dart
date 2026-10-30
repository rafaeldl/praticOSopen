import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/financial_tab_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';

Order _order(String id, double total, {String? customer, String payment = 'unpaid'}) {
  final o = Order()
    ..id = id
    ..number = 1
    ..total = total
    ..paidAmount = payment == 'paid' ? total : 0
    ..payment = payment
    ..status = 'approved'
    ..createdAt = DateTime(2026, 10, 2);
  if (customer != null) {
    o.customer = CustomerAggr()
      ..id = customer
      ..name = customer;
  }
  return o;
}

void main() {
  final now = DateTime(2026, 10, 15);

  test('loads the month and the open orders', () async {
    final offsets = <int>[];
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) async {
        offsets.add(offset);
        return [_order('m1', 300, payment: 'paid')];
      },
      paidLoader: (_) async => [],
      openLoader: () async => [_order('o1', 200, customer: 'ana')],
    );

    expect(store.status, FinancialTabStatus.loading);
    await store.load();

    expect(store.status, FinancialTabStatus.ready);
    expect(offsets, [0]);
    expect(store.summary.entered, 300);
    expect(store.summary.owed, 200);
    expect(store.month, DateTime(2026, 10, 1));
  });

  test('stepping months reloads the month, never goes past the current one',
      () async {
    final offsets = <int>[];
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) async {
        offsets.add(offset);
        return [];
      },
      paidLoader: (_) async => [],
      openLoader: () async => [],
    );
    await store.load();

    await store.nextMonth(); // already current: no-op
    expect(offsets, [0]);

    await store.previousMonth();
    expect(store.monthOffset, -1);
    expect(store.isCurrentMonth, isFalse);
    expect(store.month, DateTime(2026, 9, 1));

    await store.goToCurrentMonth();
    expect(store.monthOffset, 0);
    expect(offsets, [0, -1, 0]);
  });

  test('month wraps across years', () async {
    final store = FinancialTabStore(
      clock: () => DateTime(2026, 1, 20),
      monthLoader: (_) async => [],
      paidLoader: (_) async => [],
      openLoader: () async => [],
    );
    await store.previousMonth();
    expect(store.month, DateTime(2025, 12, 1));
  });

  test('failure sets error and load retries', () async {
    var fail = true;
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (_) async => [],
      paidLoader: (_) async => [],
      openLoader: () async {
        if (fail) throw Exception('offline');
        return [];
      },
    );

    await store.load();
    expect(store.status, FinancialTabStatus.error);

    fail = false;
    await store.load();
    expect(store.status, FinancialTabStatus.ready);
  });

  test('refresh keeps old data when it fails', () async {
    var fail = false;
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (_) async => [],
      paidLoader: (_) async => [],
      openLoader: () async {
        if (fail) throw Exception('offline');
        return [_order('o1', 80, customer: 'ana')];
      },
    );
    await store.load();

    fail = true;
    await store.refresh();

    expect(store.status, FinancialTabStatus.ready);
    expect(store.summary.owed, 80);
  });

  test('a late answer for a month already left is ignored', () async {
    final slow = Completer<List<Order?>>();
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) =>
          offset == -1 ? slow.future : Future.value([_order('cur', 10, payment: 'paid')]),
      paidLoader: (_) async => [],
      openLoader: () async => [],
    );
    await store.load();

    final stepping = store.previousMonth(); // waits on `slow`
    await store.goToCurrentMonth();
    slow.complete([_order('old', 999, payment: 'paid')]);
    await stepping;

    expect(store.monthOffset, 0);
    expect(store.summary.entered, 10);
  });
}
