import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';

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

Order _order(String id) => Order()..id = id;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  test('two loads in flight show each order once (Início duplicated OS)',
      () async {
    final store = OrderStore();
    final pages = <Completer<List<Order>>>[];
    store.fetchOrdersPage = (_, __, ___, ____, _____) async {
      final c = Completer<List<Order>>();
      pages.add(c);
      return (orders: await c.future, last: null);
    };

    final first = store.loadOrdersInfinite('open');
    final second = store.loadOrdersInfinite('open');
    pages[0].complete([_order('a'), _order('b')]);
    pages[1].complete([_order('a'), _order('b')]);
    await Future.wait([first, second]);

    expect(store.orders.map((o) => o!.id), ['a', 'b']);
    expect(store.isLoading, isFalse);
  });

  test('a stale load finishing last does not replace the newer one', () async {
    final store = OrderStore();
    final pages = <Completer<List<Order>>>[];
    store.fetchOrdersPage = (_, __, ___, ____, _____) async {
      final c = Completer<List<Order>>();
      pages.add(c);
      return (orders: await c.future, last: null);
    };

    final open = store.loadOrdersInfinite('open');
    final all = store.loadOrdersInfinite(null);
    pages[1].complete([_order('x')]);
    await all;
    pages[0].complete([_order('a')]);
    await open;

    expect(store.orders.map((o) => o!.id), ['x']);
  });
}
