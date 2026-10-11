import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/customer_utils.dart';

Customer customer(String id, String name, {String? phone}) => Customer()
  ..id = id
  ..name = name
  ..phone = phone;

DeviceAggr vehicle(String id, String name) => DeviceAggr()
  ..id = id
  ..name = name;

Order order(
  String customerId, {
  String status = 'done',
  double? total,
  DateTime? createdAt,
  DateTime? dueDate,
  List<DeviceAggr>? devices,
}) {
  final o = Order()
    ..customer = (CustomerAggr()..id = customerId)
    ..status = status
    ..total = total
    ..dueDate = dueDate
    ..devices = devices;
  o.createdAt = createdAt;
  return o;
}

void main() {
  test('normalizePlate ignores case and punctuation', () {
    expect(normalizePlate('abc-1d23'), 'abc1d23');
    expect(normalizePlate('ABC 1D23'), 'abc1d23');
    expect(normalizePlate(null), '');
  });

  test('deviceMatchesPlate needs 3 characters', () {
    final d = Device()..serial = 'ABC-1D23';
    expect(deviceMatchesPlate(d, 'ab'), isFalse);
    expect(deviceMatchesPlate(d, 'abc1'), isTrue);
    expect(deviceMatchesPlate(d, 'ABC 1d'), isTrue);
    expect(deviceMatchesPlate(d, 'xyz'), isFalse);
  });

  test('filterCustomers matches name and phone digits', () {
    final list = [
      customer('1', 'Ana Ribeiro', phone: '(11) 90000-0001'),
      customer('2', 'Bruno', phone: '(21) 98888-7777'),
    ];
    expect(filterCustomers(list, 'ana').map((c) => c.id), ['1']);
    expect(filterCustomers(list, '988887777').map((c) => c.id), ['2']);
    expect(filterCustomers(list, '').length, 2);
    // Letters are never matched against the phone digits.
    expect(filterCustomers(list, 'abc1'), isEmpty);
  });

  test('groupByInitial strips accents and groups symbols under #', () {
    final groups = groupByInitial([
      customer('1', 'Ágata'),
      customer('2', 'Ana'),
      customer('3', '3M Ltda'),
    ]);
    expect(groups.keys, ['A', '#']);
    expect(groups['A']!.length, 2);
  });

  test('totalSpent sums only completed orders', () {
    final orders = [
      order('1', status: 'done', total: 100),
      order('1', status: 'done', total: 40.5),
      order('1', status: 'progress', total: 999),
      order('1', status: 'canceled', total: 999),
      order('1', status: 'done'),
    ];
    expect(totalSpent(orders), 140.5);
    expect(totalSpent(const []), 0);
  });

  test('distinctVehicles keeps one per id, newest order first', () {
    final orders = [
      order('1',
          createdAt: DateTime(2026, 1, 1), devices: [vehicle('a', 'Uno')]),
      order('1',
          createdAt: DateTime(2026, 3, 1),
          devices: [vehicle('b', 'Gol'), vehicle('a', 'Uno')]),
    ];
    expect(distinctVehicles(orders).map((d) => d.id), ['b', 'a']);
  });

  test('distinctVehicles falls back to the legacy single device', () {
    final o = order('1')..device = vehicle('z', 'Palio');
    expect(distinctVehicles([o]).single.id, 'z');
  });

  test('recentCustomerIdsOf is distinct and newest first', () {
    final orders = [
      order('1', createdAt: DateTime(2026, 1, 1)),
      order('2', createdAt: DateTime(2026, 2, 1)),
      order('1', createdAt: DateTime(2026, 3, 1)),
    ];
    expect(recentCustomerIdsOf(orders), ['1', '2']);
    expect(latestCustomerIdOf(orders), '1');
    expect(latestCustomerIdOf(const []), isNull);
  });

  test('summarizeOpenOrders counts open and late per customer', () {
    final now = DateTime(2026, 10, 10);
    final summary = summarizeOpenOrders([
      order('1', status: 'approved', dueDate: DateTime(2026, 10, 1)),
      order('1', status: 'progress', dueDate: DateTime(2026, 10, 20)),
      order('2', status: 'progress'),
      order('2', status: 'done'),
    ], now);
    expect(summary['1']!.open, 2);
    expect(summary['1']!.late, 1);
    expect(summary['2']!.open, 1);
    expect(summary['2']!.late, 0);
  });

  test('orderCountForDevice counts orders with the device, legacy included',
      () {
    final d = DeviceAggr()..id = 'd1';
    final orders = [
      Order()..devices = [d],
      Order()..device = d,
      Order()..devices = [DeviceAggr()..id = 'd2'],
    ];
    expect(orderCountForDevice(orders, 'd1'), 2);
    expect(orderCountForDevice(orders, null), 0);
  });

  test('whatsappNumber adds Brazil code to local numbers', () {
    expect(whatsappNumber('(11) 90000-0001'), '5511900000001');
    expect(whatsappNumber('+55 11 90000-0001'), '5511900000001');
  });
}
