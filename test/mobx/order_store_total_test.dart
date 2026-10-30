import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';

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

OrderStore _storeWith(Order order) {
  final store = OrderStore()
    ..deferSave = true
    ..order = order
    ..services = (order.services ?? []).asObservable()
    ..products = (order.products ?? []).asObservable()
    ..total = order.total
    ..paidAmount = order.paidAmount;
  store.updatePayment();
  return store;
}

Order _order({
  required List<double> services,
  double paid = 0,
  String payment = 'unpaid',
  String status = 'approved',
}) =>
    Order()
      ..id = 'o1'
      ..status = status
      ..services = [for (final v in services) OrderService()..value = v]
      ..products = []
      ..discount = 0
      ..total = services.fold<double>(0, (a, b) => a + b)
      ..paidAmount = paid
      ..paid = payment == 'paid'
      ..payment = payment;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  test('item prices sum to whole cents: no "Falta receber R\$ 0,00"', () {
    final store = _storeWith(_order(services: [0.1, 0.2]));
    store.updateTotal();
    expect(store.order!.total, 0.3);

    store.order!.paidAmount = 0.3;
    store.paidAmount = 0.3;
    expect(store.remainingBalance, 0);
    expect(store.isFullyPaid, isTrue);
  });

  test('remaining balance is rounded (50,30 - 30,30 = 20,00)', () {
    final store = _storeWith(_order(services: [50.3], paid: 30.3));
    expect(store.remainingBalance, 20);
  });

  test('a paid order that gets a new item shows as owing again', () {
    final store = _storeWith(
      _order(services: [1200], paid: 1200, payment: 'paid'),
    );
    expect(store.payment, 'Pago');

    store.order!.services!.add(OrderService()..value = 80);
    store.refreshLines();

    expect(store.order!.total, 1280);
    expect(store.order!.payment, 'unpaid');
    expect(store.order!.paid, isFalse);
    expect(store.payment, 'Parcial');
  });

  test('a partly paid order whose items shrink to what was paid is paid', () {
    final store = _storeWith(_order(services: [300, 200], paid: 300));
    store.order!.services!.removeLast();
    store.refreshLines();

    expect(store.order!.payment, 'paid');
    expect(store.payment, 'Pago');
  });

  test('quotes keep no payment status', () {
    final store = _storeWith(
      _order(services: [100], status: 'quote', payment: 'unpaid'),
    );
    store.order!.payment = null;
    store.order!.services!.add(OrderService()..value = 50);
    store.refreshLines();
    expect(store.order!.payment, isNull);
  });
}
