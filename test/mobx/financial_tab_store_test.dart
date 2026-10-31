import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/financial_tab_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/next_charge.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _order(
  String id,
  double total, {
  String? customer,
  String payment = 'unpaid',
  String status = 'approved',
  DateTime? createdAt,
}) {
  final o = Order()
    ..id = id
    ..number = 1
    ..total = total
    ..paidAmount = payment == 'paid' ? total : 0
    ..payment = payment
    ..status = status
    ..createdAt = createdAt ?? DateTime(2026, 10, 2);
  if (customer != null) {
    o.customer = CustomerAggr()
      ..id = customer
      ..name = customer;
  }
  return o;
}

void main() {
  final now = DateTime(2026, 10, 15);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads the month and the open orders', () async {
    final offsets = <int>[];
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) async {
        offsets.add(offset);
        return [_order('m1', 300, payment: 'paid')];
      },
      paidLoader: (_) async => [],
      openLoader: () async => [
        _order('o1', 200, customer: 'ana', status: 'done'),
      ],
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
        return [_order('o1', 80, customer: 'ana', status: 'done')];
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

  test('changing month reads only the month: Hoje keeps its numbers', () async {
    var openCalls = 0;
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) async => offset == 0
          ? [_order('m1', 300)]
          : [_order('m2', 100, createdAt: DateTime(2026, 9, 3))],
      paidLoader: (_) async => [],
      openLoader: () async {
        openCalls++;
        return [
          _order('o1', 200, customer: 'ana', status: 'done'),
          _order('o2', 50, customer: 'bia', status: 'progress'),
        ];
      },
      openChargeChecker: (_) async => false,
      snoozes: NextChargeSnoozes(companyId: () => 'c1', clock: () => now),
    );
    await store.load();
    expect(store.summary.sold, 300);

    await store.previousMonth();

    expect(store.summary.sold, 100);
    expect(store.summary.owed, 200);
    expect(store.summary.inProgress, 50);
    expect(store.nextCharge?.key, 'ana');
    expect(openCalls, 1);
  });

  test('monthLoading covers the numbers of the new month while they load',
      () async {
    final slow = Completer<List<Order?>>();
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) => offset == 0 ? Future.value([]) : slow.future,
      paidLoader: (_) async => [],
      openLoader: () async => [],
      openChargeChecker: (_) async => false,
    );
    await store.load();

    final stepping = store.previousMonth();
    expect(store.monthLoading, isTrue);
    expect(store.status, FinancialTabStatus.ready);

    slow.complete([]);
    await stepping;
    expect(store.monthLoading, isFalse);
  });

  test('a reload that ends after the month changed does not bring the old '
      'month back', () async {
    final slowOpen = Completer<List<Order?>>();
    var slow = false;
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) async =>
          offset == 0 ? [_order('cur', 300)] : [_order('old', 100)],
      paidLoader: (_) async => [],
      openLoader: () => slow ? slowOpen.future : Future.value([]),
      openChargeChecker: (_) async => false,
    );
    await store.load();

    slow = true;
    final refreshing = store.refresh();
    await store.previousMonth();
    slowOpen.complete([]);
    await refreshing;

    expect(store.summary.sold, 100);
  });

  test('changing month during the first load does not show the new month '
      'before its numbers arrive', () async {
    final firstMonth = Completer<List<Order?>>();
    final secondMonth = Completer<List<Order?>>();
    final store = FinancialTabStore(
      clock: () => now,
      monthLoader: (offset) =>
          offset == 0 ? firstMonth.future : secondMonth.future,
      paidLoader: (_) async => [],
      openLoader: () async => [],
      openChargeChecker: (_) async => false,
    );
    final loading = store.load();

    final stepping = store.previousMonth();
    firstMonth.complete([_order('cur', 300)]);
    await loading;
    expect(store.status, FinancialTabStatus.loading);

    secondMonth.complete([_order('old', 100)]);
    await stepping;
    expect(store.status, FinancialTabStatus.ready);
    expect(store.summary.sold, 100);
  });

  group('next charge', () {
    FinancialTabStore storeWith(
      List<Order> open, {
      Set<String> withLink = const {},
    }) {
      return FinancialTabStore(
        clock: () => now,
        monthLoader: (_) async => [],
        paidLoader: (_) async => [],
        openLoader: () async => open,
        openChargeChecker: (debtor) async => withLink.contains(debtor.key),
        snoozes: NextChargeSnoozes(companyId: () => 'c1', clock: () => now),
      );
    }

    final old = _order('o1', 300, customer: 'old', status: 'done');
    final newer = _order(
      'o2',
      200,
      customer: 'newer',
      status: 'done',
      createdAt: DateTime(2026, 10, 10),
    );

    test('suggests the oldest debt of the last 90 days', () async {
      final store = storeWith([newer, old]);
      await store.load();
      expect(store.nextCharge?.key, 'old');
    });

    test('after a reload the suggestion is never stale while links are read',
        () async {
      var open = <Order>[old, newer];
      final links = Completer<bool>();
      var waitOnLinks = false;
      final store = FinancialTabStore(
        clock: () => now,
        monthLoader: (_) async => [],
        paidLoader: (_) async => [],
        openLoader: () async => open,
        openChargeChecker: (_) => waitOnLinks ? links.future : Future.value(false),
        snoozes: NextChargeSnoozes(companyId: () => 'c1', clock: () => now),
      );
      await store.load();
      expect(store.nextCharge?.key, 'old');

      // "old" was received in the meantime.
      open = [newer];
      waitOnLinks = true;
      final refreshing = store.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(store.nextCharge, isNull);

      links.complete(false);
      await refreshing;
      expect(store.nextCharge?.key, 'newer');
    });

    test('skips a customer with an open link', () async {
      final store = storeWith([newer, old], withLink: {'old'});
      await store.load();
      expect(store.nextCharge?.key, 'newer');
    });

    test('nothing to suggest hides the section', () async {
      final store = storeWith([old], withLink: {'old'});
      await store.load();
      expect(store.nextCharge, isNull);
    });

    test('when the links cannot be read it suggests nobody', () async {
      final store = FinancialTabStore(
        clock: () => now,
        monthLoader: (_) async => [],
        paidLoader: (_) async => [],
        openLoader: () async => [old],
        openChargeChecker: (_) async => throw Exception('offline'),
        snoozes: NextChargeSnoozes(companyId: () => 'c1', clock: () => now),
      );
      await store.load();
      expect(store.nextCharge, isNull);
      expect(store.status, FinancialTabStatus.ready);
    });

    test('"Agora não" moves to the next one and keeps the customer in A '
        'receber', () async {
      final store = storeWith([newer, old]);
      await store.load();

      await store.snoozeNextCharge(store.nextCharge!);

      expect(store.nextCharge?.key, 'newer');
      expect(store.summary.debtors.map((d) => d.key), contains('old'));
      expect(store.summary.owed, 500);
    });
  });
}
