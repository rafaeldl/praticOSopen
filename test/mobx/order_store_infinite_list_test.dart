import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';

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

  late Future<String?> Function() defaultScope;
  late Stream<String?> Function() defaultScopeChanges;
  setUpAll(() {
    defaultScope = TenantOrderRepository.creatorScope;
    defaultScopeChanges = TenantOrderRepository.creatorScopeChanges;
  });

  setUp(() {
    Global.companyAggr = CompanyAggr()..id = 'c1';
    TenantOrderRepository.creatorScope = () async => null;
    TenantOrderRepository.creatorScopeChanges = () => Stream.value(null);
  });
  tearDown(() {
    Global.companyAggr = null;
    TenantOrderRepository.creatorScope = defaultScope;
    TenantOrderRepository.creatorScopeChanges = defaultScopeChanges;
  });

  test('reloads when the role arrives after a provisionally filtered page',
      () async {
    // Role not loaded in time: the page was read filtered by the own uid.
    TenantOrderRepository.creatorScope = () async => 'me';
    final changes = StreamController<String?>.broadcast();
    TenantOrderRepository.creatorScopeChanges = () => changes.stream;
    final store = OrderStore();
    var fetches = 0;
    store.fetchOrdersPage = (_, __, ___, ____, _____) async {
      fetches++;
      return (orders: [_order('o$fetches')], last: null);
    };

    await store.loadOrdersInfinite('open');
    expect(fetches, 1);

    changes.add('me'); // same filter: nothing to do
    await pumpEventQueue();
    expect(fetches, 1);

    // Owner role arrives: the filter goes away and the list reloads.
    TenantOrderRepository.creatorScope = () async => null;
    changes.add(null);
    await pumpEventQueue();
    expect(fetches, 2);
    expect(store.orders.map((o) => o!.id), ['o2']);

    // The reload watches the new scope; no reload loop.
    changes.add(null);
    await pumpEventQueue();
    expect(fetches, 2);
    await changes.close();
  });

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

  test('"Em aberto" loads every open order in one page', () async {
    final store = OrderStore();
    final limits = <int>[];
    store.fetchOrdersPage = (_, __, ___, limit, ____) async {
      limits.add(limit);
      return (
        orders: [for (var i = 0; i < 12; i++) _order('o$i')],
        last: null,
      );
    };

    await store.loadOrdersInfinite('open');

    expect(limits, [kOpenOrdersLimit]);
    expect(store.orders, hasLength(12));
    expect(store.hasMoreOrders, isFalse);
  });

  test('"Todas" keeps loading page by page', () async {
    final store = OrderStore();
    final limits = <int>[];
    store.fetchOrdersPage = (_, __, ___, limit, ____) async {
      limits.add(limit);
      return (
        orders: [for (var i = 0; i < limit; i++) _order('o$i')],
        last: null,
      );
    };

    await store.loadOrdersInfinite(null);

    expect(limits, [10]);
    expect(store.hasMoreOrders, isTrue);
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
