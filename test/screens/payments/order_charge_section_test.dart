import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/payments/widgets/order_charge_section.dart';

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
    // OrderStore creates Firestore/Storage repositories in its fields.
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  OrderCharge charge({
    String id = 'ch1',
    ChargeStatus status = ChargeStatus.pending,
    List<String>? paid,
  }) => OrderCharge(
    id: id,
    status: status,
    value: 600,
    paidAsaasPaymentIds: paid,
  );

  /// Store whose server reloads are counted in [reloads].
  OrderStore storeCounting(List<int> reloads) {
    final order = Order()
      ..id = 'o1'
      ..number = 42
      ..status = 'approved'
      ..total = 1000
      ..paidAmount = 400;
    return OrderStore()
      ..order = order
      ..status = 'approved'
      ..total = 1000
      ..paidAmount = 400
      ..fetchOrderFromServer = (companyId, orderId) async {
        reloads.add(1);
        return null;
      };
  }

  OrderChargeController controllerWith({
    required OrderStore store,
    bool canCharge = true,
    PaymentSettings? settings,
    Stream<PaymentSettings>? settingsStream,
    Stream<List<OrderCharge>>? charges,
  }) {
    final controller = OrderChargeController(
      store: store,
      canCharge: canCharge,
      settingsStream:
          settingsStream ??
          Stream.value(
            settings ??
                PaymentSettings(asaasEnabled: true, asaasConnected: true),
          ),
      chargesStream: charges ?? Stream.value(const <OrderCharge>[]),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('habilitado e conectado: sem cobrança aberta', () async {
    final c = controllerWith(store: storeCounting([]));
    await pumpEventQueue();
    expect(c.enabled, isTrue);
    expect(c.connected, isTrue);
    expect(c.openCharge, isNull);
  });

  test('sem a permissão chargeOrder fica desligado', () async {
    final c = controllerWith(store: storeCounting([]), canCharge: false);
    await pumpEventQueue();
    expect(c.enabled, isFalse);
  });

  test('asaasEnabled false: desligado e não lê as cobranças', () async {
    var listened = false;
    final charges = StreamController<List<OrderCharge>>(
      onListen: () => listened = true,
    );
    // Never listened: don't wait for close() to complete.
    addTearDown(() {
      charges.close();
    });
    final c = controllerWith(
      store: storeCounting([]),
      settings: PaymentSettings(asaasEnabled: false, asaasConnected: true),
      charges: charges.stream,
    );
    await pumpEventQueue();
    expect(c.enabled, isFalse);
    expect(listened, isFalse);
  });

  test('erro no stream de configurações vira desligado', () async {
    final c = controllerWith(
      store: storeCounting([]),
      settingsStream: Stream.error(Exception('permission-denied')),
    );
    await pumpEventQueue();
    expect(c.enabled, isFalse);
  });

  test('desconectado: cobrança aberta continua visível', () async {
    final c = controllerWith(
      store: storeCounting([]),
      settings: PaymentSettings(asaasEnabled: true, asaasConnected: false),
      charges: Stream.value([charge(status: ChargeStatus.overdue)]),
    );
    await pumpEventQueue();
    expect(c.connected, isFalse);
    expect(c.openCharge?.status, ChargeStatus.overdue);
  });

  test('cobrança paga não conta como aberta', () async {
    final c = controllerWith(
      store: storeCounting([]),
      charges: Stream.value([charge(status: ChargeStatus.paid)]),
    );
    await pumpEventQueue();
    expect(c.openCharge, isNull);
  });

  test('parcela paga bloqueia trocar ou cancelar', () async {
    final c = controllerWith(
      store: storeCounting([]),
      charges: Stream.value([
        charge(paid: ['pay_1']),
      ]),
    );
    await pumpEventQueue();
    expect(c.blockedByInstallments, isTrue);
  });

  test('erro no stream de cobranças vira "sem cobrança"', () async {
    final c = controllerWith(
      store: storeCounting([]),
      charges: Stream.error(Exception('permission-denied')),
    );
    await pumpEventQueue();
    expect(c.openCharge, isNull);
  });

  group('recarga quando o webhook muda os pagamentos', () {
    test(
      'primeira emissão já paga não recarrega; pendente → paga recarrega',
      () async {
        final reloads = <int>[];
        final charges = StreamController<List<OrderCharge>>();
        addTearDown(charges.close);
        controllerWith(store: storeCounting(reloads), charges: charges.stream);
        await pumpEventQueue();

        charges.add([charge(status: ChargeStatus.paid, id: 'old')]);
        await pumpEventQueue();
        expect(reloads, isEmpty);

        charges.add([charge(status: ChargeStatus.paid, id: 'old'), charge()]);
        await pumpEventQueue();
        expect(reloads, isEmpty);

        charges.add([
          charge(status: ChargeStatus.paid, id: 'old'),
          charge(status: ChargeStatus.paid),
        ]);
        await pumpEventQueue();
        expect(reloads, hasLength(1));
      },
    );

    test('parcela paga com cobrança ainda pendente recarrega', () async {
      final reloads = <int>[];
      final charges = StreamController<List<OrderCharge>>();
      addTearDown(charges.close);
      controllerWith(store: storeCounting(reloads), charges: charges.stream);
      await pumpEventQueue();

      charges.add([
        charge(paid: ['pay_1']),
      ]);
      await pumpEventQueue();
      charges.add([
        charge(paid: ['pay_1', 'pay_2']),
      ]);
      await pumpEventQueue();
      expect(reloads, hasLength(1));
    });

    test('vencida ou cancelada não recarrega', () async {
      final reloads = <int>[];
      final charges = StreamController<List<OrderCharge>>();
      addTearDown(charges.close);
      controllerWith(store: storeCounting(reloads), charges: charges.stream);
      await pumpEventQueue();

      charges.add([charge()]);
      charges.add([charge(status: ChargeStatus.overdue)]);
      charges.add([charge(status: ChargeStatus.canceled)]);
      await pumpEventQueue();
      expect(reloads, isEmpty);
    });
  });
}
