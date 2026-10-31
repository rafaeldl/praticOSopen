import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/financial_summary.dart';
import 'package:praticos/utils/next_charge.dart';
import 'package:shared_preferences/shared_preferences.dart';

Debtor debtor(String key, DateTime? since) => Debtor(
  key: key,
  customerId: key,
  name: key,
  amount: 100,
  orders: [
    Order()
      ..id = key
      ..createdAt = since,
  ],
);

void main() {
  final now = DateTime(2026, 10, 31, 12);
  DateTime daysAgo(int days) => now.subtract(Duration(days: days));

  group('nextChargeCandidates', () {
    test('within 90 days, oldest first', () {
      final result = nextChargeCandidates([
        debtor('a', daysAgo(5)),
        debtor('b', daysAgo(80)),
        debtor('c', daysAgo(30)),
      ], now: now);
      expect(result.map((d) => d.key), ['b', 'c', 'a']);
    });

    test('older debts come after the recent ones, newest first', () {
      final result = nextChargeCandidates([
        debtor('ancient', daysAgo(900)),
        debtor('old', daysAgo(120)),
        debtor('recent', daysAgo(10)),
        debtor('older', daysAgo(400)),
      ], now: now);
      expect(result.map((d) => d.key), ['recent', 'old', 'older', 'ancient']);
    });

    test('exactly 90 days ago is still recent; a day more is not', () {
      final result = nextChargeCandidates([
        debtor('new', daysAgo(1)),
        debtor('limit', daysAgo(90)),
        debtor('past', daysAgo(91)),
      ], now: now);
      expect(result.map((d) => d.key), ['limit', 'new', 'past']);
    });

    test('with no recent debt it starts at the newest of the old ones', () {
      final result = nextChargeCandidates([
        debtor('old', daysAgo(400)),
        debtor('less', daysAgo(100)),
      ], now: now);
      expect(result.first.key, 'less');
    });

    test('skips snoozed customers', () {
      final result = nextChargeCandidates(
        [debtor('a', daysAgo(80)), debtor('b', daysAgo(5))],
        now: now,
        snoozed: {'a'},
      );
      expect(result.map((d) => d.key), ['b']);
    });

    test('no date goes last', () {
      final result = nextChargeCandidates([
        debtor('none', null),
        debtor('old', daysAgo(500)),
      ], now: now);
      expect(result.map((d) => d.key), ['old', 'none']);
    });

    test('nobody: empty', () {
      expect(nextChargeCandidates(const [], now: now), isEmpty);
    });
  });

  group('NextChargeSnoozes', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('pauses for 30 days, per company, and then forgets', () async {
      var today = now;
      NextChargeSnoozes of(String company) =>
          NextChargeSnoozes(companyId: () => company, clock: () => today);

      await of('c1').snooze('ana');

      expect(await of('c1').active(), {'ana'});
      expect(await of('c2').active(), isEmpty);

      today = now.add(const Duration(days: 29));
      expect(await of('c1').active(), {'ana'});

      today = now.add(const Duration(days: 30));
      expect(await of('c1').active(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('a customer id with dots stays whole', () async {
      final snoozes = NextChargeSnoozes(companyId: () => 'c1', clock: () => now);
      await snoozes.snooze('a.b');
      expect(await snoozes.active(), {'a.b'});
    });
  });
}
