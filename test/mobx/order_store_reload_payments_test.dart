import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';

PaymentTransaction _tx(String id, PaymentTransactionType type, double amount) =>
    PaymentTransaction(
      id: id,
      type: type,
      amount: amount,
      createdAt: DateTime(2026, 10, 4),
    );

Order _localOrder() => Order()
  ..id = 'o1'
  ..services = [OrderService()..value = 1000]
  ..products = []
  ..discount = 0
  ..total = 1000
  ..paidAmount = 0
  ..paid = false
  ..payment = 'unpaid'
  ..transactions = [];

/// Firebase core mock whose default app has a storage bucket.
class _FirebaseCoreMockWithBucket extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
        CoreInitializeResponse(
          name: defaultFirebaseAppName,
          options: CoreFirebaseOptions(
            apiKey: '123',
            projectId: '123',
            appId: '123',
            messagingSenderId: '123',
            storageBucket: 'test.appspot.com',
          ),
          pluginConstants: {},
        ),
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // OrderStore creates Firestore/Storage repositories in its fields
    // (PhotoService needs a storage bucket).
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  late OrderStore store;
  late List<String> fetched;

  setUp(() {
    Global.companyAggr = CompanyAggr()..id = 'c1';
    store = OrderStore()..order = _localOrder();
    fetched = [];
  });

  tearDown(() => Global.companyAggr = null);

  test('copies payment fields of the server order into the store', () async {
    store.fetchOrderFromServer = (companyId, orderId) async {
      fetched.add('$companyId/$orderId');
      return Order()
        ..id = 'o1'
        ..services = [OrderService()..value = 1000]
        ..discount = 50
        ..total = 950
        ..paidAmount = 950
        ..paid = true
        ..payment = 'paid'
        ..transactions = [
          _tx('d1', PaymentTransactionType.discount, 50),
          _tx('asaas_pay_1', PaymentTransactionType.payment, 950),
        ];
    };

    final ok = await store.reloadPayments();

    expect(ok, isTrue);
    expect(fetched, ['c1/o1']);
    expect(store.order!.transactions!.map((t) => t.id),
        ['d1', 'asaas_pay_1']);
    expect(store.transactions.map((t) => t.id), ['d1', 'asaas_pay_1']);
    expect(store.order!.paidAmount, 950);
    expect(store.paidAmount, 950);
    expect(store.order!.paid, isTrue);
    expect(store.order!.payment, 'paid');
    expect(store.order!.discount, 50);
    expect(store.discount, 50);
    // total = items - discount
    expect(store.order!.total, 950);
    expect(store.total, 950);
  });

  test('waits for the pending offline payment write before reading',
      () async {
    final write = Completer<void>();
    store.pendingPaymentFieldWriteForTest = write.future;
    store.fetchOrderFromServer = (companyId, orderId) async {
      fetched.add(orderId);
      return Order()
        ..id = 'o1'
        ..paidAmount = 300
        ..payment = 'unpaid'
        ..transactions = [];
    };

    final result = store.reloadPayments();
    await Future<void>.delayed(Duration.zero);
    expect(fetched, isEmpty);

    write.complete();
    expect(await result, isTrue);
    expect(fetched, ['o1']);
    expect(store.order!.paidAmount, 300);
  });

  test('offline keeps the local state and returns false', () async {
    store.fetchOrderFromServer = (_, __) async => throw FirebaseException(
        plugin: 'cloud_firestore', code: 'unavailable');

    expect(await store.reloadPayments(), isFalse);
    expect(store.order!.paidAmount, 0);
    expect(store.order!.payment, 'unpaid');
  });

  test('missing order on the server returns false', () async {
    store.fetchOrderFromServer = (_, __) async => null;

    expect(await store.reloadPayments(), isFalse);
    expect(store.order!.paidAmount, 0);
  });

  test('ignores the result when the store moved to another order', () async {
    store.fetchOrderFromServer = (_, __) async {
      store.order = _localOrder()..id = 'o2';
      return Order()
        ..id = 'o1'
        ..paidAmount = 1000
        ..payment = 'paid';
    };

    expect(await store.reloadPayments(), isFalse);
    expect(store.order!.paidAmount, 0);
  });

  test('unsaved order or no company does not read', () async {
    store.fetchOrderFromServer = (companyId, orderId) async {
      fetched.add(orderId);
      return null;
    };

    store.order!.id = null;
    expect(await store.reloadPayments(), isFalse);

    store.order!.id = 'o1';
    Global.companyAggr = null;
    expect(await store.reloadPayments(), isFalse);
    expect(fetched, isEmpty);
  });
}
