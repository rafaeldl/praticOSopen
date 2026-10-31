import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/nfse.dart';

NfseInvoice _nota(
  String id,
  String status, {
  String date = '2026-10-20',
  double value = 100,
  List<String> orderIds = const ['o1'],
  bool conflict = false,
  String? createdAt,
  String? customer,
  String? number,
  int? orderNumber,
}) => NfseInvoice.fromJson({
  'status': status,
  'effectiveDate': date,
  'value': value,
  'orderIds': orderIds,
  'conflict': conflict,
  'createdAt': createdAt ?? '2026-10-20T10:00:00.000',
  'customer': {'id': 'c1', 'name': customer},
  'number': number,
  'orders': [
    {'orderId': orderIds.first, 'orderNumber': orderNumber, 'value': value},
  ],
}, id: id);

void main() {
  final october = DateTime(2026, 10);
  final now = DateTime(2026, 10, 31, 12);

  group('nfseMonthList', () {
    test('counts only issued notas of the month, in cents', () {
      final list = nfseMonthList(
        [
          _nota('a', 'authorized', value: 0.1, orderIds: ['o1']),
          _nota('b', 'authorized', value: 0.2, orderIds: ['o2']),
          _nota('c', 'canceled', value: 50, orderIds: ['o3']),
          _nota('d', 'synchronized', value: 50, orderIds: ['o4']),
          _nota('e', 'authorized', date: '2026-09-30', orderIds: ['o5']),
        ],
        october,
        now: now,
      );
      expect(list.issuedCount, 2);
      expect(list.issuedTotal, 0.3);
      expect(list.rows.map((i) => i.id), ['a', 'b', 'c', 'd']..sort());
    });

    test('newest first', () {
      final list = nfseMonthList(
        [
          _nota('old', 'authorized', date: '2026-10-02', orderIds: ['o1']),
          _nota('new', 'authorized', date: '2026-10-30', orderIds: ['o2']),
        ],
        october,
        now: now,
      );
      expect(list.rows.map((i) => i.id), ['new', 'old']);
    });

    test('an error needs attention and stays out of the rows', () {
      final list = nfseMonthList([_nota('e', 'error')], october, now: now);
      expect(list.attention.map((i) => i.id), ['e']);
      expect(list.rows, isEmpty);
      expect(list.issuedCount, 0);
    });

    test('an error whose order was issued again disappears', () {
      final list = nfseMonthList(
        [_nota('e', 'error'), _nota('ok', 'authorized')],
        october,
        now: now,
      );
      expect(list.attention, isEmpty);
      expect(list.rows.map((i) => i.id), ['ok']);
    });

    test('an error reissued in the next month also disappears', () {
      final list = nfseMonthList(
        [
          _nota('e', 'error', date: '2026-10-30'),
          _nota('ok', 'authorized', date: '2026-11-02'),
        ],
        october,
        now: DateTime(2026, 11, 3),
      );
      expect(list.attention, isEmpty);
      expect(list.rows, isEmpty);
    });

    test('an error of several orders stays until all have a nota', () {
      final list = nfseMonthList(
        [
          _nota('e', 'error', orderIds: ['o1', 'o2']),
          _nota('ok', 'authorized', orderIds: ['o1']),
        ],
        october,
        now: now,
      );
      expect(list.attention.map((i) => i.id), ['e']);
    });

    test('a canceled nota does not resolve an error', () {
      final list = nfseMonthList(
        [_nota('e', 'error'), _nota('c', 'canceled')],
        october,
        now: now,
      );
      expect(list.attention.map((i) => i.id), ['e']);
    });

    test('a denied cancellation needs attention and still counts', () {
      final list = nfseMonthList(
        [_nota('d', 'cancellationDenied', value: 70)],
        october,
        now: now,
      );
      expect(list.attention.map((i) => i.id), ['d']);
      expect(list.issuedCount, 1);
      expect(list.issuedTotal, 70);
    });

    test('a nota in conflict needs attention and does not count', () {
      final list = nfseMonthList(
        [_nota('c', 'authorized', conflict: true)],
        october,
        now: now,
      );
      expect(list.attention.map((i) => i.id), ['c']);
      expect(list.issuedCount, 0);
    });

    test('a stale creating is hidden, a fresh one shows', () {
      final stale = nfseMonthList(
        [_nota('s', 'creating', createdAt: '2026-10-31T11:00:00.000')],
        october,
        now: now,
      );
      expect(stale.isEmpty, isTrue);
      final fresh = nfseMonthList(
        [_nota('s', 'creating', createdAt: '2026-10-31T11:55:00.000')],
        october,
        now: now,
      );
      expect(fresh.rows.map((i) => i.id), ['s']);
    });

    test('a problem of last month still shows when the month turns', () {
      final list = nfseMonthList(
        [_nota('e', 'error', date: '2026-10-30')],
        DateTime(2026, 11),
        now: DateTime(2026, 11, 1),
      );
      expect(list.attention.map((i) => i.id), ['e']);
    });

    test('a problem older than last month leaves the list', () {
      final list = nfseMonthList(
        [_nota('e', 'error', date: '2026-08-30')],
        DateTime(2026, 10),
        now: now,
      );
      expect(list.isEmpty, isTrue);
    });
  });

  group('nfseQuerySince', () {
    test('reads from last month for the current month', () {
      expect(nfseQuerySince(october, now: now), DateTime(2026, 9));
    });

    test('reads from the month itself when it is older', () {
      expect(
        nfseQuerySince(DateTime(2026, 3, 15), now: now),
        DateTime(2026, 3),
      );
    });

    test('crosses the year', () {
      expect(
        nfseQuerySince(DateTime(2027, 1), now: DateTime(2027, 1, 5)),
        DateTime(2026, 12),
      );
    });
  });

  group('nfseMatches', () {
    final nota = _nota(
      'a',
      'authorized',
      customer: 'João Conceição',
      number: '1048',
      orderNumber: 214,
    );

    test('finds by name without accents or case', () {
      expect(nfseMatches(nota, 'joao conc'), isTrue);
      expect(nfseMatches(nota, 'CONCEIÇÃO'), isTrue);
    });

    test('finds by nota and order number', () {
      expect(nfseMatches(nota, '1048'), isTrue);
      expect(nfseMatches(nota, '214'), isTrue);
    });

    test('blank matches everything, others nothing', () {
      expect(nfseMatches(nota, '  '), isTrue);
      expect(nfseMatches(nota, 'Maria'), isFalse);
    });
  });
}
