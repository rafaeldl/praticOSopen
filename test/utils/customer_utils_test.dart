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

  group('shortList (customer screen lists)', () {
    final items = List.generate(
      12,
      (i) =>
          vehicle('d$i', 'Carro $i')
            ..serial = 'ABC${i.toString().padLeft(4, '0')}',
    );

    test('5 or fewer: everything, no "Ver todos", no search', () {
      final view = shortList(
        items.take(5).toList(),
        open: false,
        matches: vehicleMatches,
      );
      expect(view.shown, hasLength(5));
      expect(view.canOpen, isFalse);
      expect(view.searchable, isFalse);
    });

    test('more than 5: the first 5, everything once open', () {
      final closed = shortList(
        items.take(8).toList(),
        open: false,
        matches: vehicleMatches,
      );
      expect(closed.shown.map((d) => d.id), ['d0', 'd1', 'd2', 'd3', 'd4']);
      expect(closed.canOpen, isTrue);
      final open = shortList(
        items.take(8).toList(),
        open: true,
        matches: vehicleMatches,
      );
      expect(open.shown, hasLength(8));
      expect(open.searchable, isFalse);
    });

    test('search only open and past 10, by plate or name', () {
      expect(
        shortList(
          items,
          open: false,
          query: 'ABC0011',
          matches: vehicleMatches,
        ).searchable,
        isFalse,
      );
      final byPlate = shortList(
        items,
        open: true,
        query: 'abc-0011',
        matches: vehicleMatches,
      );
      expect(byPlate.searchable, isTrue);
      expect(byPlate.shown.map((d) => d.id), ['d11']);
      expect(
        shortList(
          items,
          open: true,
          query: 'carro 3',
          matches: vehicleMatches,
        ).shown.map((d) => d.id),
        ['d3'],
      );
    });

    test('orders by number', () {
      final o = order('1')..number = 1234;
      expect(orderNumberMatches(o, 'OS 123'), isTrue);
      expect(orderNumberMatches(o, '99'), isFalse);
      expect(orderNumberMatches(o, 'abc'), isFalse);
    });
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
    final now = DateTime(2026, 10, 10, 15);
    final summary = summarizeOpenOrders([
      order('1', status: 'approved', dueDate: DateTime(2026, 10, 1)),
      order('1', status: 'progress', dueDate: DateTime(2026, 10, 20)),
      order('2', status: 'progress'),
      order('2', status: 'done'),
      // Quotes are "em aberto" too, as in the Início (issue #588).
      order('2', status: 'quote'),
      // Due earlier today is not late yet: by day, as in the Início.
      order('3', status: 'approved', dueDate: DateTime(2026, 10, 10, 9)),
    ], now);
    expect(summary['1']!.open, 2);
    expect(summary['1']!.late, 1);
    expect(summary['2']!.open, 2);
    expect(summary['2']!.late, 0);
    expect(summary['3']!.open, 1);
    expect(summary['3']!.late, 0);
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

  group('whatsappNumber', () {
    test('adds Brazil code to local numbers', () {
      expect(whatsappNumber('(11) 90000-0001'), '5511900000001');
      expect(whatsappNumber('+55 11 90000-0001'), '5511900000001');
    });

    test('area code 55 is not mistaken for the country code', () {
      expect(whatsappNumber('55999990000'), '5555999990000');
      expect(whatsappNumber('(55) 99999-0000'), '5555999990000');
      expect(whatsappNumber('5532223344'), '555532223344');
      expect(whatsappNumber('5599990000'), '555599990000');
    });

    test('keeps the country code that is already there', () {
      expect(whatsappNumber('5555999990000'), '5555999990000');
      expect(whatsappNumber('5548981234567'), '5548981234567');
      expect(whatsappNumber('+1 (202) 555-0123'), '12025550123');
      expect(whatsappNumber('+351 912 345 678'), '351912345678');
      expect(whatsappNumber('+351 912 345 678', country: 'US'), '351912345678');
    });

    test('drops the leading zero of a national number', () {
      expect(whatsappNumber('048 98123-4567'), '5548981234567');
    });

    test('old Brazilian mobile with 8 digits gets the 55', () {
      expect(whatsappNumber('(48) 8123-4567'), '554881234567');
      expect(whatsappNumber('+55 48 8123-4567'), '554881234567');
    });

    test('a company in the US does not get the 55', () {
      expect(whatsappNumber('(202) 555-0123', country: 'US'), '12025550123');
      expect(whatsappNumber('5599990000', country: 'US'), '15599990000');
    });

    test('an unknown or empty country falls back to Brazil', () {
      expect(whatsappNumber('48981234567', country: ''), '5548981234567');
      expect(whatsappNumber('48981234567', country: 'XX'), '5548981234567');
    });

    test('an invalid number goes back as digits only', () {
      expect(whatsappNumber('123'), '123');
      expect(whatsappNumber('abc'), '');
      expect(whatsappNumber(''), '');
      expect(whatsappNumber('ramal 12', country: 'US'), '12');
    });
  });

  group('findCustomerByPhone', () {
    final list = [
      customer('c1', 'Sem telefone'),
      customer('c2', 'Vazio', phone: '  '),
      customer('c3', 'Ana', phone: '(48) 98123-4567'),
      customer('c4', 'Bia', phone: '+55 48 3222-3344'),
    ];

    test('the same number in another format is a match', () {
      expect(findCustomerByPhone(list, '48981234567')?.id, 'c3');
      expect(findCustomerByPhone(list, '+55 48 98123-4567')?.id, 'c3');
      expect(findCustomerByPhone(list, '(48) 3222-3344')?.id, 'c4');
    });

    test('in Brazil the ninth digit is ignored', () {
      expect(findCustomerByPhone(list, '+55 48 8123-4567')?.id, 'c3');
      expect(findCustomerByPhone(list, '(48) 8123-4567')?.id, 'c3');
      expect(
        findCustomerByPhone([customer('c', 'Old', phone: '554881234567')],
                '(48) 98123-4567')
            ?.id,
        'c',
      );
    });

    test('another number or area code is no match', () {
      expect(findCustomerByPhone(list, '(48) 98408-7802'), isNull);
      expect(findCustomerByPhone(list, '(47) 98123-4567'), isNull);
    });

    test('outside Brazil the ninth digit is not touched', () {
      final us = [customer('c', 'Al', phone: '+1 202 555 0123')];
      expect(
        findCustomerByPhone(us, '(202) 555-0123', country: 'US')?.id,
        'c',
      );
      expect(phoneMatchKey('+351 912 345 678'), '351912345678');
      expect(phoneMatchKey('+55 48 3222-3344'), '554832223344');
    });

    test('a phone without digits matches nothing', () {
      expect(findCustomerByPhone(list, 'abc'), isNull);
    });
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
