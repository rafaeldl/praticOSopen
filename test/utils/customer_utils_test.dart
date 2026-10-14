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

  group('currentCustomerId', () {
    CustomerAggr aggr({String? id, String? name, String? phone}) =>
        CustomerAggr()
          ..id = id
          ..name = name
          ..phone = phone;

    final list = [
      customer('a', 'Elias Souza', phone: '(11) 90000-0001'),
      customer('b', 'Maria'),
      customer('c', 'João', phone: '11 90000-0002'),
      customer('d', 'João', phone: '11 90000-0003'),
    ];

    test('matches by id', () {
      expect(currentCustomerId(aggr(id: 'b', name: 'Other'), list), 'b');
    });

    test('null order customer has no match', () {
      expect(currentCustomerId(null, list), isNull);
      expect(currentCustomerId(aggr(), list), isNull);
    });

    test('without id falls back to the unique name', () {
      expect(currentCustomerId(aggr(name: '  elias   souza '), list), 'a');
      expect(currentCustomerId(aggr(name: 'Maria'), list), 'b');
    });

    test('unknown id falls back to name and phone', () {
      expect(
        currentCustomerId(
          aggr(id: 'old', name: 'Elias Souza', phone: '+55 11 90000-0001'),
          list,
        ),
        'a',
      );
    });

    test('a different phone is a different customer', () {
      expect(
        currentCustomerId(
          aggr(name: 'Elias Souza', phone: '11 98888-7777'),
          list,
        ),
        isNull,
      );
    });

    test('same name twice: only the phone tells them apart', () {
      expect(currentCustomerId(aggr(name: 'João'), list), isNull);
      expect(
        currentCustomerId(aggr(id: 'gone', name: 'João'), list),
        isNull,
      );
      expect(
        currentCustomerId(aggr(name: 'João', phone: '(11) 90000-0003'), list),
        'd',
      );
    });

    test('order phone with a phoneless unique namesake still matches', () {
      expect(
        currentCustomerId(aggr(name: 'Maria', phone: '11 90000-0009'), list),
        'b',
      );
    });

    test('no match when the name is not in the list', () {
      expect(currentCustomerId(aggr(name: 'Pedro'), list), isNull);
    });
  });

  group('currentDeviceIds', () {
    Device device(String id, {String? serial}) => Device()
      ..id = id
      ..serial = serial;
    DeviceAggr aggr({String? id, String? serial}) => DeviceAggr()
      ..id = id
      ..serial = serial;

    final list = [
      device('v1', serial: 'ABC-1D23'),
      device('v2', serial: 'XYZ9876'),
      device('v3', serial: 'DUP0001'),
      device('v4', serial: 'dup-0001'),
      device('v5'),
    ];

    test('matches by id', () {
      expect(currentDeviceIds([aggr(id: 'v5')], list), {'v5'});
    });

    test('without id, or unknown id, falls back to the plate', () {
      expect(currentDeviceIds([aggr(serial: 'abc1d23')], list), {'v1'});
      expect(
        currentDeviceIds([aggr(id: 'old', serial: 'XYZ 9876')], list),
        {'v2'},
      );
    });

    test('a plate shared by two devices matches none', () {
      expect(currentDeviceIds([aggr(serial: 'DUP0001')], list), isEmpty);
    });

    test('no id and no plate matches none', () {
      expect(currentDeviceIds([aggr()], list), isEmpty);
    });

    test('orderDevices uses the legacy single device', () {
      final legacy = Order()..device = (DeviceAggr()..id = 'v1');
      expect(orderDevices(legacy).map((d) => d.id), ['v1']);
      final both = Order()
        ..device = (DeviceAggr()..id = 'v1')
        ..devices = [DeviceAggr()..id = 'v2'];
      expect(orderDevices(both).map((d) => d.id), ['v2']);
      expect(orderDevices(null), isEmpty);
    });
  });
}
