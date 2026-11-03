import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/utils/order_field_diff.dart';

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

  Order loaded() => Order.fromJson({
    ...serverDoc,
    'id': 'o1',
  });

  setUp(() {
    Global.companyAggr = CompanyAggr()..id = 'c1';
    writes = [];
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
