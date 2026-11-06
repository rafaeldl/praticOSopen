import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/work_stage.dart';

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
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  late OrderStore store;
  late List<String> writes;
  Completer<void>? pending;
  final clock = DateTime(2026, 11, 6, 9, 30);

  Order order(String status, [String? stageId]) => Order()
    ..id = 'o1'
    ..status = status
    ..payment = 'unpaid'
    ..services = []
    ..products = []
    ..stage = stageId == null ? null : (OrderStage()..id = stageId);

  setUp(() {
    Global.companyAggr = CompanyAggr()..id = 'c1';
    writes = [];
    pending = null;
    store = OrderStore()
      ..deferSave = true
      ..holdClock = (() => clock)
      ..writeHold = ((companyId, orderId, hold) async {})
      ..writeStage = (companyId, orderId, stageId) {
        writes.add('$companyId/$orderId/$stageId');
        return pending?.future ?? Future.value();
      };
  });

  tearDown(() => Global.companyAggr = null);

  test('moves at once and asks the server', () async {
    store.order = order('progress', 'paint');
    pending = Completer<void>();

    final done = store.moveToStage('polish');

    expect(store.stage?.id, 'polish');
    expect(store.order!.stage?.id, 'polish');
    expect(store.stage?.since, clock.toUtc());
    expect(store.order!.status, 'progress');
    expect(writes, ['c1/o1/polish']);
    pending!.complete();
    await done;
    expect(store.stage?.id, 'polish');
  });

  test('a refusal brings the previous stage back and warns', () async {
    final before = OrderStage()..id = 'paint';
    store.order = order('progress')..stage = before;
    store.stage = before;
    store.writeStage = (_, _, _) async => throw Exception('403');
    var warned = false;

    await store.moveToStage('polish', onFailed: () => warned = true);

    expect(store.stage, same(before));
    expect(store.order!.stage, same(before));
    expect(warned, isTrue);
  });

  test('only an in-progress, saved order changes stage', () async {
    store.order = order('approved');
    await store.moveToStage('polish');
    store.order = order('progress')..id = null;
    await store.moveToStage('polish');

    expect(writes, isEmpty);
    expect(store.stage, isNull);
  });

  test('leaving progress drops the stage', () {
    store.order = order('progress', 'polish');
    store.stage = store.order!.stage;

    store.setStatus('done');

    expect(store.stage, isNull);
    expect(store.order!.stage, isNull);
  });

  test('a refused status brings the stage back', () {
    store.order = order('progress', 'polish');
    store.stage = store.order!.stage;

    store.setStatus('done');
    store.restoreStatus('progress');

    expect(store.stage?.id, 'polish');
    expect(store.order!.stage?.id, 'polish');
  });
}
