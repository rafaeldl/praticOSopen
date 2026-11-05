import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/utils/order_field_diff.dart';
import 'package:praticos/utils/order_payment_math.dart';

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

/// Applies a field update the way Firestore `update()` does: only the given
/// top-level fields change, [DeleteFieldOp] removes the field.
void applyUpdate(Map<String, dynamic> doc, Map<String, dynamic> fields) {
  fields.forEach((key, value) {
    if (value is DeleteFieldOp) {
      doc.remove(key);
    } else {
      doc[key] = value;
    }
  });
}

Map<String, dynamic> serviceJson(String id, String name, double value) => {
  'service': {'id': id, 'name': name},
  'value': value,
  'description': null,
  'photo': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  late OrderStore store;
  late Map<String, dynamic> serverDoc;
  late List<Map<String, dynamic>> writes;

  /// When true, the money transaction can't reach the server (offline).
  var offline = false;

  Order loaded() => Order.fromJson({
    ...serverDoc,
    'id': 'o1',
  });

  setUp(() {
    Global.companyAggr = CompanyAggr()..id = 'c1';
    writes = [];
    offline = false;
    serverDoc = {
      'status': 'approved',
      'total': 100.0,
      'discount': 0.0,
      'payment': 'unpaid',
      'services': [serviceJson('s1', 'Troca de óleo', 100.0)],
      'products': <Map<String, dynamic>>[],
    };
    store = OrderStore()
      ..streamOrder = ((_, _) => const Stream.empty())
      ..writeOrderFields = (companyId, orderId, fields) async {
        writes.add(fields);
        applyUpdate(serverDoc, fields);
      }
      // Same decision as TenantOrderRepository.updateMoney: online the
      // transaction merges with the server copy; offline the local four go.
      ..writeOrderMoney =
          (companyId, orderId, fields, appMoney, localMoney) async {
            final money = offline
                ? localMoney
                : OrderFieldDiff.mergeMoney(serverDoc, appMoney);
            final update = {...fields, ...money};
            writes.add(update);
            applyUpdate(serverDoc, update);
          };
    store.order = loaded();
    store.rememberSaved();
  });

  tearDown(() => Global.companyAggr = null);

  test('an item written elsewhere survives an app save', () async {
    // The web adds an item while the app has the order open.
    (serverDoc['services'] as List).add(serviceJson('s2', 'Filtro', 40.0));

    // The app changes something else and saves.
    store.order!.scheduledDate = DateTime.utc(2026, 11, 5, 9);
    await store.createItem();

    final services = serverDoc['services'] as List;
    expect(services.map((s) => (s as Map)['service']['id']), ['s1', 's2']);
    expect(writes.single.keys, ['scheduledDate']);
  });

  group('web adds an item, the app changes only the discount', () {
    setUp(() {
      (serverDoc['services'] as List).add(serviceJson('s2', 'Filtro', 40.0));
      serverDoc['total'] = 140.0;
      store.order!.discount = 10.0;
      store.updateTotal();
    });

    test('online: the item stays and the total counts it', () async {
      await store.createItem();
      expect((serverDoc['services'] as List), hasLength(2));
      expect(serverDoc['discount'], 10.0);
      expect(serverDoc['total'], 130.0);
      // Items, discount and total went in the same write.
      expect(
        writes.single.keys,
        containsAll(['services', 'products', 'discount', 'total']),
      );
    });

    test('offline: the four go as the app has them, total matches', () async {
      offline = true;
      await store.createItem();
      final stored = Order.fromJson(serverDoc);
      expect(stored.discount, 10.0);
      // Never a total of other items: it matches what was stored.
      expect(stored.total, OrderPaymentMath.computeTotal(stored));
      expect(stored.total, 90.0);
    });
  });

  test('a device reading goes by its own key: another device\'s reading '
      'saved elsewhere stays', () async {
    // Another phone saves the reading of d2 while this one has the order open.
    serverDoc['deviceReadings'] = {'d2': 1250};

    store.setDeviceReading('d1', 98000);
    await Future<void>.delayed(Duration.zero);
    expect(writes.single, {'deviceReadings.d1': 98000});

    writes.clear();
    store.setDeviceReading('d1', null);
    await Future<void>.delayed(Duration.zero);
    expect(writes.single, {'deviceReadings.d1': const DeleteFieldOp()});
  });

  test('mergeMoney recomputes the total from the merged items', () {
    final merged = OrderFieldDiff.mergeMoney(
      {
        'services': [serviceJson('s1', 'A', 100.0), serviceJson('s2', 'B', 40.0)],
        'products': <Map<String, dynamic>>[],
        'discount': 5.0,
        'total': 999.0,
      },
      {'discount': 20.0},
    );
    expect(merged['total'], 120.0);
    expect(merged['discount'], 20.0);
    expect(merged['services'], hasLength(2));
  });

  test('a late refusal only touches the snapshot of the same order', () async {
    late void Function(Object) refuse;
    store.writeOrderFields = (companyId, orderId, fields) {
      final c = Completer<void>();
      refuse = c.completeError;
      return c.future;
    };
    store.order!.status = 'progress';
    final saving = store.createItem()!;

    // The store moves to another order before the refusal arrives.
    store.order = Order.fromJson({...serverDoc, 'id': 'o2', 'status': 'done'});
    store.rememberSaved();
    refuse(StateError('permission-denied'));
    await expectLater(saving, throwsStateError);

    // o2's snapshot was not touched: saving o2 unchanged writes nothing.
    writes.clear();
    store.writeOrderFields = (companyId, orderId, fields) async {
      writes.add(fields);
    };
    await store.createItem();
    expect(writes, isEmpty);
  });

  test('writes nothing when nothing changed', () async {
    await store.createItem();
    expect(writes, isEmpty);
  });

  test('never writes the payment fields', () async {
    store.order!
      ..payment = 'paid'
      ..paidAmount = 100
      ..status = 'done';
    await store.createItem();
    expect(writes.single.keys, ['status']);
  });

  test('a field changed in place (nested map) is detected', () async {
    store.order!.customData = {'km': '1000'};
    await store.createItem();
    store.order!.customData!['km'] = '1200';
    await store.createItem();
    expect(writes.last, {
      'customData': {'km': '1200'},
    });
  });

  test('a refused write is retried by the next save', () async {
    var fail = true;
    store.writeOrderFields = (companyId, orderId, fields) async {
      if (fail) throw Exception('permission-denied');
      writes.add(fields);
    };
    store.order!.status = 'progress';
    await expectLater(store.createItem(), throwsException);

    fail = false;
    await store.createItem();
    expect(writes.single, {'status': 'progress'});
  });

  test('items added by the web show up and are kept with the app item',
      () async {
    (serverDoc['services'] as List).add(serviceJson('s2', 'Filtro', 40.0));
    serverDoc['total'] = 140.0;
    store.applyServerOrder(loaded());

    expect(store.services!.map((s) => s.service?.id), ['s1', 's2']);
    expect(store.total, 140.0);

    store.order!.services!.add(
      OrderService()
        ..service = (ServiceAggr()
          ..id = 's3'
          ..name = 'Alinhamento')
        ..value = 60.0,
    );
    store.updateTotal();
    await store.createItem();

    final ids = (serverDoc['services'] as List).map(
      (s) => (s as Map)['service']['id'],
    );
    expect(ids, ['s1', 's2', 's3']);
    expect(serverDoc['total'], 200.0);
  });

  test('a list the app changed is not replaced by the server copy', () {
    store.order!.services!.clear();
    (serverDoc['services'] as List).add(serviceJson('s2', 'Filtro', 40.0));
    store.applyServerOrder(loaded());
    expect(store.order!.services, isEmpty);
  });

  test('a new order whose create fails reports the error', () async {
    Object? reported;
    store
      ..order = (Order()..status = 'quote')
      ..findOrderByNumber = ((_, _) async => null)
      ..createOrderDoc = ((_, _) async => throw Exception('denied'));
    store.createItem(onError: (e) => reported = e);
    await pumpEventQueue();
    expect(reported, isA<Exception>());
  });
}
