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

      expect(out['transactions'], isA<FieldValue>());
      expect(out['paidAmount'], isA<FieldValue>());
      expect(out['paid'], false);
      expect(out['payment'], 'unpaid');
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
