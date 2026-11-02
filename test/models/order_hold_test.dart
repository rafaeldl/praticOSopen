import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/authorization_service.dart';

Order _order(String status, {String? creator}) => Order()
  ..status = status
  ..createdBy = (UserAggr()..id = creator);

void main() {
  group('Order.isOnHold', () {
    final hold = OrderHold()
      ..reason = OrderHoldReason.part
      ..since = DateTime.utc(2026, 11, 1);

    test('only approved and in progress orders can be stopped', () {
      for (final status in ['approved', 'progress']) {
        expect((_order(status)..onHold = hold).isOnHold, isTrue);
      }
      for (final status in ['quote', 'done', 'canceled']) {
        expect(_order(status).canBeOnHold, isFalse);
        expect((_order(status)..onHold = hold).isOnHold, isFalse);
      }
    });

    test('no mark, not stopped', () {
      expect(_order('progress').isOnHold, isFalse);
    });
  });

  group('OrderHold.daysSince', () {
    OrderHold since(DateTime date) => OrderHold()..since = date;

    test('counts calendar days, not 24-hour periods', () {
      final hold = since(DateTime(2026, 11, 1, 23, 50));
      expect(hold.daysSince(DateTime(2026, 11, 1, 23, 55)), 0);
      expect(hold.daysSince(DateTime(2026, 11, 2, 0, 5)), 1);
      expect(hold.daysSince(DateTime(2026, 11, 4, 12)), 3);
    });

    test('reads the stored UTC date in local time', () {
      final local = DateTime(2026, 11, 1, 23, 50);
      expect(since(local.toUtc()).daysSince(DateTime(2026, 11, 1, 23, 55)), 0);
    });

    test('never negative, and 0 without a date', () {
      expect(since(DateTime(2026, 11, 5)).daysSince(DateTime(2026, 11, 1)), 0);
      expect(OrderHold().daysSince(DateTime(2026, 11, 1)), 0);
    });
  });

  group('persistence', () {
    test('reads the mark, and a full save never sends it', () {
      final order = Order.fromJson({
        'status': 'progress',
        'onHold': {
          'reason': 'customer',
          'note': 'Aguardando retorno',
          'since': '2026-11-01T12:00:00.000Z',
        },
      });
      expect(order.onHold?.reason, OrderHoldReason.customer);
      expect(order.onHold?.note, 'Aguardando retorno');
      expect(order.onHold?.since, DateTime.utc(2026, 11, 1, 12));
      expect(order.toJson().containsKey('onHold'), isFalse);
    });

    test('the mark is stored without empty fields', () {
      final hold = OrderHold()
        ..reason = OrderHoldReason.other
        ..since = DateTime.utc(2026, 11, 1, 12);
      expect(hold.toJson(), {
        'reason': 'other',
        'since': '2026-11-01T12:00:00.000Z',
      });
    });

    test('orders without the mark still load', () {
      expect(Order.fromJson({'status': 'approved'}).onHold, isNull);
    });
  });

  group('canChangeOrderHoldFor', () {
    bool can(RolesType? role, Order order, {String? userId = 'me'}) =>
        AuthorizationService.canChangeOrderHoldFor(
          role: role,
          userId: userId,
          order: order,
        );

    test('same people who change the status of a running order', () {
      final order = _order('approved', creator: 'me');
      expect(can(RolesType.admin, order), isTrue);
      expect(can(RolesType.manager, order), isTrue);
      expect(can(RolesType.supervisor, order), isTrue);
      expect(can(RolesType.technician, order), isTrue);
      expect(can(RolesType.consultant, order), isFalse);
      expect(can(null, order), isFalse);
    });

    test('a technician only on orders they can see', () {
      final other = _order('progress', creator: 'someone');
      expect(can(RolesType.technician, other), isFalse);
      expect(can(RolesType.supervisor, other), isTrue);
    });

    test('never outside approved and in progress', () {
      for (final status in ['quote', 'done', 'canceled']) {
        expect(can(RolesType.admin, _order(status)), isFalse);
      }
    });
  });
}
