import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/repositories/tenant/tenant_device_repository.dart';
import 'package:praticos/services/device_maintenance_service.dart';

void main() {
  group('addMonths', () {
    test('lands on the same day', () {
      expect(addMonths(DateTime(2026, 11, 2), 6), DateTime(2027, 5, 2));
      expect(addMonths(DateTime(2026, 11, 2), 12), DateTime(2027, 11, 2));
    });

    test('takes the last day of a shorter month', () {
      expect(addMonths(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(addMonths(DateTime(2027, 8, 31), 6), DateTime(2028, 2, 29));
    });

    test('crosses the year', () {
      expect(addMonths(DateTime(2026, 11, 30), 3), DateTime(2027, 2, 28));
    });
  });

  group('maintenanceIsNear', () {
    final now = DateTime(2026, 11, 2, 15);

    test('from any late day to 7 days ahead', () {
      expect(maintenanceIsNear('2026-01-01', now), isTrue);
      expect(maintenanceIsNear('2026-11-09', now), isTrue);
      expect(maintenanceIsNear('2026-11-10', now), isFalse);
    });

    test('not without a date', () {
      expect(maintenanceIsNear(null, now), isFalse);
    });

    test('the window crosses the month', () {
      expect(maintenanceWindowEnd(DateTime(2026, 11, 28)), '2026-12-05');
    });
  });

  group('whatsappMessageUri', () {
    test('carries the number and the message, encoded', () {
      final uri = whatsappMessageUri('(47) 99999-1234', 'Olá, Ana & cia!');
      expect(uri?.host, 'wa.me');
      expect(
        uri.toString(),
        'https://wa.me/5547999991234?text=Ol%C3%A1%2C%20Ana%20%26%20cia!',
      );
    });

    test('a space is never a "+", and a "+" of the text survives', () {
      final url = whatsappMessageUri('47999991234', 'a b+c').toString();
      expect(url, endsWith('?text=a%20b%2Bc'));
    });

    test('is null without a phone', () {
      expect(whatsappMessageUri(null, 'x'), isNull);
      expect(whatsappMessageUri('  ', 'x'), isNull);
    });
  });

  group('writeEachExisting', () {
    bool missing(Object e) => e == 'not-found';

    test('a deleted device does not stop the others', () async {
      final done = <String>[];
      await writeEachExisting([
        () async => done.add('a'),
        () async => throw 'not-found',
        () async => done.add('c'),
      ], isMissing: missing);
      expect(done, ['a', 'c']);
    });

    test('any other failure reaches the caller, after all were tried', () async {
      final done = <String>[];
      await expectLater(
        writeEachExisting([
          () async => throw 'permission-denied',
          () async => done.add('b'),
        ], isMissing: missing),
        throwsA('permission-denied'),
      );
      expect(done, ['b']);
    });

    test('every device deleted is not a failure', () async {
      await writeEachExisting([
        () async => throw 'not-found',
      ], isMissing: missing);
    });
  });

  group('lastDoneOrder', () {
    Order order(String id, String status, DateTime done) => Order()
      ..id = id
      ..status = status
      ..createdAt = done;

    test('takes the newest finished one', () {
      final last = lastDoneOrder([
        order('a', 'done', DateTime(2026, 1, 1)),
        order('b', 'done', DateTime(2026, 5, 1)),
        order('c', 'progress', DateTime(2026, 9, 1)),
      ]);
      expect(last?.id, 'b');
    });

    test('prefers the day it was finished over the day it was created', () {
      final old = order('a', 'done', DateTime(2026, 1, 1))
        ..completedAt = DateTime(2026, 6, 1);
      final last = lastDoneOrder([
        old,
        order('b', 'done', DateTime(2026, 5, 1)),
      ]);
      expect(last?.id, 'a');
    });

    test('is null when none was finished', () {
      expect(lastDoneOrder([order('a', 'quote', DateTime(2026))]), isNull);
    });
  });

  group('maintenanceOrder', () {
    Device device() => Device()
      ..id = 'd1'
      ..name = 'Split 12000'
      ..nextMaintenanceCustomer = (CustomerAggr()
        ..id = 'cu1'
        ..name = 'Padaria');

    OrderService line(String? deviceId, {String? photo}) => OrderService()
      ..service = (ServiceAggr()..name = 'Limpeza')
      ..description = 'Limpeza completa'
      ..value = 250
      ..photo = photo
      ..deviceId = deviceId;

    test('brings the customer, the device and the services', () {
      final order = maintenanceOrder(
        device(),
        Order()..services = [line(null)],
      );
      expect(order.id, isNull);
      expect(order.customer?.name, 'Padaria');
      expect(order.effectiveDevices.single.id, 'd1');
      expect(order.services?.single.value, 250);
      expect(order.services?.single.description, 'Limpeza completa');
    });

    test('only the services of this device, and no old photos', () {
      final order = maintenanceOrder(
        device(),
        Order()
          ..services = [
            line('d1', photo: 'antes.jpg'),
            line('d2'),
          ],
      );
      expect(order.services, hasLength(1));
      expect(order.services?.single.photo, isNull);
    });

    test('is the customer of the last order when the date has none', () {
      final order = maintenanceOrder(
        device()..nextMaintenanceCustomer = null,
        Order()..customer = (CustomerAggr()..name = 'Ana'),
      );
      expect(order.customer?.name, 'Ana');
    });

    test('starts without services when there is no last order', () {
      expect(maintenanceOrder(device(), null).services, isEmpty);
    });

    test('never carries the old status or number', () {
      final order = maintenanceOrder(
        device(),
        Order()
          ..status = 'done'
          ..number = 7,
      );
      expect(order.status, isNot('done'));
      expect(order.number, isNull);
    });
  });
}
