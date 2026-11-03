import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/utils/order_field_diff.dart';

class _FailingQueries extends TenantOrderRepository {
  @override
  Future<List<Order?>> getQueryList(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
    dynamic startAfter,
  }) async => throw FirebaseException(plugin: 'cloud_firestore');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('fieldUpdateOf', () {
    final actor = UserAggr()
      ..id = 'u2'
      ..name = 'Bia';
    final now = DateTime(2026, 11, 3, 10);

    test('writes only the given fields, stamped with the actor', () {
      final out = TenantOrderRepository.fieldUpdateOf(
        {'status': 'progress'},
        actor: actor,
        now: now,
      );
      expect(out, {
        'status': 'progress',
        'updatedAt': now.toIso8601String(),
        'updatedBy': actor.toJson(),
      });
    });

    test('a removed field becomes FieldValue.delete()', () {
      final out = TenantOrderRepository.fieldUpdateOf({
        'scheduledDate': const DeleteFieldOp(),
      }, now: now);
      expect(out['scheduledDate'], FieldValue.delete());
    });

    test('never writes payment fields, id or number', () {
      final out = TenantOrderRepository.fieldUpdateOf({
        'paidAmount': 10.0,
        'transactions': [],
        'payment': 'paid',
        'paid': true,
        'id': 'o1',
        'number': 7,
        'total': 50.0,
      }, now: now);
      expect(out.keys, unorderedEquals(['total', 'updatedAt']));
    });
  });

  test('only "no server" sends the local money copy; refusals are errors', () {
    expect(
      TenantOrderRepository.isOfflineFailure(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      isTrue,
    );
    expect(
      TenantOrderRepository.isOfflineFailure(TimeoutException('slow')),
      isTrue,
    );
    for (final code in ['permission-denied', 'aborted', 'not-found']) {
      expect(
        TenantOrderRepository.isOfflineFailure(
          FirebaseException(plugin: 'cloud_firestore', code: code),
        ),
        isFalse,
      );
    }
  });

  test('the consultant contract write never erases what exists', () {
    final out = TenantOrderRepository.contractFallbackWrite({
      'number': null,
      'status': 'quote',
      'discount': null,
      'createdAt': '2026-11-03T02:00:00.000',
      'createdBy': {'id': 'u1', 'name': 'Ana', 'photo': null},
      'customer': {'id': 'c1', 'email': null},
      'services': [
        {'value': 10, 'photo': null},
      ],
    });
    expect(out.containsKey('number'), isFalse);
    expect(out.containsKey('discount'), isFalse);
    expect(out['createdBy'], {'id': 'u1', 'name': 'Ana'});
    expect(out['customer'], {'id': 'c1'});
    expect(out['createdAt'], '2026-11-03T02:00:00.000');
    // Lists are written as they are.
    expect(out['services'], [
      {'value': 10, 'photo': null},
    ]);
  });

  test('a number in the order is never sent either', () {
    expect(
      TenantOrderRepository.contractFallbackWrite({'number': 7}).containsKey(
        'number',
      ),
      isFalse,
    );
  });

  test('a month that fails to load is an error, not R\$ 0', () async {
    await expectLater(
      _FailingQueries().getOrdersByDateRange(
        'c1',
        DateTime(2026, 10, 1),
        DateTime(2026, 11, 1),
      ),
      throwsA(isA<FirebaseException>()),
    );
  });
}
