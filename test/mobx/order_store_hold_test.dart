import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  late OrderStore store;
  late List<OrderHold?> writes;
  final clock = DateTime(2026, 11, 2, 9, 30);

  Order order(String status, {OrderHold? hold}) => Order()
    ..id = 'o1'
    ..status = status
    ..payment = 'unpaid'
    ..services = []
    ..products = []
    ..onHold = hold;

  OrderHold stopped() => OrderHold()
    ..reason = OrderHoldReason.part
    ..since = DateTime.utc(2026, 10, 30);

  setUp(() {
    Global.companyAggr = CompanyAggr()..id = 'c1';
    writes = [];
    store = OrderStore()
      // The full save is not the subject here.
      ..deferSave = true
      ..holdClock = (() => clock)
      ..writeHold = (companyId, orderId, hold) async => writes.add(hold);
  });

  tearDown(() => Global.companyAggr = null);

  test('marks with reason, note and start date, keeping the status', () {
    store.order = order('progress');

    store.markOnHold(
      reason: OrderHoldReason.authorization,
      note: '  Seguro não respondeu ',
    );

    final hold = store.hold!;
    expect(hold.reason, OrderHoldReason.authorization);
    expect(hold.note, 'Seguro não respondeu');
    expect(hold.since, clock.toUtc());
    expect(store.order!.onHold, same(hold));
    expect(store.order!.status, 'progress');
    expect(writes, [hold]);
  });

  test('a blank note is not stored', () {
    store.order = order('approved');
    store.markOnHold(reason: OrderHoldReason.other, note: '   ');
    expect(store.hold!.note, isNull);
  });

  test('does not mark quotes, finished or unsaved orders', () {
    for (final status in ['quote', 'done', 'canceled']) {
      store.order = order(status);
      store.markOnHold(reason: OrderHoldReason.part);
      expect(store.hold, isNull, reason: status);
    }
    store.order = order('approved')..id = null;
    store.markOnHold(reason: OrderHoldReason.part);
    expect(store.hold, isNull);
    expect(writes, isEmpty);
  });

  test('"Retomar" removes the mark and keeps the status', () {
    store.order = order('approved', hold: stopped());
    store.hold = store.order!.onHold;

    store.resumeHold();

    expect(store.hold, isNull);
    expect(store.order!.onHold, isNull);
    expect(store.order!.status, 'approved');
    expect(writes, [null]);
  });

  test('"Retomar" does nothing on an order that is not stopped', () {
    store.order = order('approved');
    store.resumeHold();
    expect(writes, isEmpty);
  });

  for (final status in ['done', 'canceled', 'quote']) {
    test('going to $status removes the mark', () {
      store.order = order('progress', hold: stopped())
        // Same payment field as the target status: no payment write here.
        ..payment = status == 'done' ? 'unpaid' : null;
      store.hold = store.order!.onHold;

      store.setStatus(status);

      expect(store.order!.status, status);
      expect(store.hold, isNull);
      expect(store.order!.onHold, isNull);
      expect(writes, [null]);
    });
  }

  test('moving between approved and in progress keeps the mark', () {
    final hold = stopped();
    store.order = order('approved', hold: hold);
    store.hold = hold;

    store.setStatus('progress');

    expect(store.hold, same(hold));
    expect(writes, isEmpty);
  });

  test('finishing an order that is not stopped writes no mark', () {
    store.order = order('progress');
    store.setStatus('done');
    expect(writes, isEmpty);
  });

  test('opening an order picks up the mark, ignoring a leftover one', () {
    // No id: nothing to stream from Firestore here.
    store.setOrder(order('progress', hold: stopped())..id = null);
    expect(store.hold?.reason, OrderHoldReason.part);

    store.setOrder(order('done', hold: stopped())..id = null);
    expect(store.hold, isNull);

    store.setOrder(order('approved')..id = null);
    expect(store.hold, isNull);
  });

  group('when the server answers', () {
    late List<String> events;

    Future<void> refuse(Object error) async => throw error;

    setUp(() => events = []);

    test('an accepted mark tells the screen', () async {
      store.order = order('approved');
      store.markOnHold(
        reason: OrderHoldReason.customer,
        onSaved: () => events.add('saved'),
        onFailed: () => events.add('failed'),
      );
      await pumpEventQueue();
      expect(events, ['saved']);
      expect(store.hold?.reason, OrderHoldReason.customer);
    });

    test('a refused mark is undone and only "failed" runs', () async {
      store
        ..order = order('approved')
        ..writeHold = (_, _, _) => refuse(StateError('denied'));
      store.markOnHold(
        reason: OrderHoldReason.customer,
        onSaved: () => events.add('saved'),
        onFailed: () => events.add('failed'),
      );
      expect(store.hold?.reason, OrderHoldReason.customer);

      await pumpEventQueue();

      expect(events, ['failed']);
      expect(store.hold, isNull);
      expect(store.order!.onHold, isNull);
    });

    test('a refused "Retomar" brings the mark back', () async {
      final previous = stopped();
      store
        ..order = order('progress', hold: previous)
        ..hold = previous
        ..writeHold = (_, _, _) => refuse(StateError('denied'));
      store.resumeHold(
        onSaved: () => events.add('saved'),
        onFailed: () => events.add('failed'),
      );
      expect(store.hold, isNull);

      await pumpEventQueue();

      expect(events, ['failed']);
      expect(store.hold, same(previous));
      expect(store.order!.onHold, same(previous));
    });

    test('a write that throws at once is handled the same way', () async {
      store
        ..order = order('approved')
        ..writeHold = (_, _, _) => throw StateError('no app');
      store.markOnHold(
        reason: OrderHoldReason.other,
        onFailed: () => events.add('failed'),
      );
      await pumpEventQueue();
      expect(events, ['failed']);
      expect(store.hold, isNull);
    });

    test('a late refusal does not undo a newer mark', () async {
      final first = Completer<void>();
      store
        ..order = order('approved')
        ..writeHold = (_, _, _) => first.future;
      store.markOnHold(reason: OrderHoldReason.part);

      store.writeHold = (_, _, _) async {};
      store.resumeHold();
      store.markOnHold(reason: OrderHoldReason.customer);
      first.completeError(StateError('denied'));
      await pumpEventQueue();

      expect(store.hold?.reason, OrderHoldReason.customer);
    });

    test('a refused removal on finishing keeps the mark gone', () async {
      store
        ..order = (order('progress', hold: stopped())..payment = 'unpaid')
        ..hold = store.order?.onHold
        ..writeHold = (_, _, _) => refuse(StateError('denied'));
      store.setStatus('done');
      await pumpEventQueue();
      expect(store.hold, isNull);
      expect(store.order!.onHold, isNull);
    });
  });
}
