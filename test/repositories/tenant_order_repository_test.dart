import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/utils/order_payment_math.dart';

void main() {
  group('TenantOrderRepository.toFirestoreUpdate', () {
    final actor = UserAggr()
      ..id = 'u2'
      ..name = 'Actor';

    test('converts ArrayUnionOp and IncrementOp to FieldValue transforms', () {
      final out = TenantOrderRepository.toFirestoreUpdate({
        'transactions': ArrayUnionOp([
          {'id': 't1'}
        ]),
        'paidAmount': const IncrementOp(10.5),
        'paid': false,
        'payment': 'unpaid',
      }, actor: actor);

      expect(
        out['transactions'],
        FieldValue.arrayUnion([
          {'id': 't1'}
        ]),
      );
      expect(out['paidAmount'], FieldValue.increment(10.5));
      expect(out['paid'], false);
      expect(out['payment'], 'unpaid');
    });

    test('FieldValue equality really checks operation and value', () {
      // Guards the assertions above: a wrong op or value must not match.
      expect(FieldValue.increment(10.5), isNot(FieldValue.increment(10)));
      expect(
        FieldValue.arrayUnion([
          {'id': 't1'}
        ]),
        isNot(FieldValue.arrayRemove([
          {'id': 't1'}
        ])),
      );
      expect(
        FieldValue.arrayUnion([
          {'id': 't1'}
        ]),
        isNot(FieldValue.arrayUnion([
          {'id': 't2'}
        ])),
      );
    });

    test('discount update converts to discount +x and total -x', () {
      final out = TenantOrderRepository.toFirestoreUpdate({
        'transactions': ArrayUnionOp([
          {'id': 'd1', 'type': 'discount', 'amount': 15.0}
        ]),
        'discount': const IncrementOp(15.0),
        'total': const IncrementOp(-15.0),
        'paid': true,
        'payment': 'paid',
      }, actor: actor);

      expect(
        out['transactions'],
        FieldValue.arrayUnion([
          {'id': 'd1', 'type': 'discount', 'amount': 15.0}
        ]),
      );
      expect(out['discount'], FieldValue.increment(15.0));
      expect(out['total'], FieldValue.increment(-15.0));
      expect(out['paid'], true);
      expect(out['payment'], 'paid');
      expect(out['updatedBy'], actor.toJson());
    });

    test('updatedBy is the acting user, not the one in the map', () {
      final out = TenantOrderRepository.toFirestoreUpdate({
        'updatedAt': '2026-10-04T10:00:00.000',
        'updatedBy': {'id': 'old', 'name': 'Old'},
      }, actor: actor);

      expect(out['updatedBy'], actor.toJson());
      expect(out['updatedAt'], '2026-10-04T10:00:00.000');
    });

    test('without actor, previous updatedBy is dropped', () {
      final out = TenantOrderRepository.toFirestoreUpdate({
        'updatedBy': {'id': 'old'},
        'paid': true,
      });

      expect(out.containsKey('updatedBy'), false);
      expect(out['paid'], true);
    });
  });
}
