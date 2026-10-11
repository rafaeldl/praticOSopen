import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/payments/send_charge_flow.dart';

Order _order({String status = 'approved', double total = 950, double paid = 0}) =>
    Order()
      ..id = 'o1'
      ..number = 42
      ..status = status
      ..total = total
      ..paidAmount = paid;

final _connected = PaymentSettings(asaasEnabled: true, asaasConnected: true);

void main() {
  group('decideSendChargeAction', () {
    SendChargeAction decide({
      bool canCharge = true,
      PaymentSettings? settings,
      Order? order,
      OrderCharge? openCharge,
    }) =>
        decideSendChargeAction(
          canCharge: canCharge,
          settings: settings ?? _connected,
          order: order ?? _order(),
          openCharge: openCharge,
        );

    test('without Asaas keeps sharing the order link', () {
      expect(decide(settings: PaymentSettings()), SendChargeAction.shareOrderLink);
      expect(decide(settings: PaymentSettings(asaasEnabled: true)),
          SendChargeAction.shareOrderLink);
      expect(decide(settings: PaymentSettings(asaasConnected: true)),
          SendChargeAction.shareOrderLink);
    });

    test('without chargeOrder permission keeps sharing the order link', () {
      expect(decide(canCharge: false), SendChargeAction.shareOrderLink);
    });

    test('quote, canceled or nothing left to pay never creates a charge', () {
      expect(decide(order: _order(status: 'quote')), SendChargeAction.shareOrderLink);
      expect(decide(order: _order(status: 'canceled')), SendChargeAction.shareOrderLink);
      expect(decide(order: _order(paid: 950)), SendChargeAction.shareOrderLink);
      expect(decide(order: _order()..id = null), SendChargeAction.shareOrderLink);
    });

    test('Asaas with an open charge reuses it', () {
      expect(decide(openCharge: OrderCharge(status: ChargeStatus.pending)),
          SendChargeAction.shareExistingCharge);
      expect(decide(openCharge: OrderCharge(status: ChargeStatus.overdue)),
          SendChargeAction.shareExistingCharge);
    });

    test('Asaas without an open charge creates one first', () {
      expect(decide(), SendChargeAction.createChargeThenShare);
      expect(decide(openCharge: OrderCharge(status: ChargeStatus.paid)),
          SendChargeAction.createChargeThenShare);
    });
  });

  group('SendChargeFlow.send', () {
    late List<String> calls;
    late BuildContext ctx;

    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(CupertinoApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ));
    }

    SendChargeFlow flow({
      bool canCharge = true,
      Future<PaymentSettings> Function()? settings,
      Future<OrderCharge?> Function(Order)? openCharge,
      OrderCharge? created,
    }) {
      return SendChargeFlow(
        canCharge: canCharge,
        settingsLoader: settings ?? () async => _connected,
        openChargeLoader: openCharge ?? (_) async => null,
        createCharge: (_, order, remaining) async {
          calls.add('create:$remaining');
          return created;
        },
        share: (_, order) async => calls.add('share:${order.id}'),
        timeout: const Duration(milliseconds: 200),
      );
    }

    setUp(() => calls = []);

    testWidgets('no Asaas: only shares, never creates', (tester) async {
      await pumpHost(tester);
      final action = await flow(settings: () async => PaymentSettings())
          .send(ctx, _order());
      expect(action, SendChargeAction.shareOrderLink);
      expect(calls, ['share:o1']);
    });

    testWidgets('no permission: does not even read Asaas state', (tester) async {
      await pumpHost(tester);
      var read = false;
      final action = await flow(
        canCharge: false,
        settings: () async {
          read = true;
          return _connected;
        },
      ).send(ctx, _order());
      expect(action, SendChargeAction.shareOrderLink);
      expect(read, isFalse);
      expect(calls, ['share:o1']);
    });

    testWidgets('Asaas without charge: creates with the balance, then shares',
        (tester) async {
      await pumpHost(tester);
      final action = await flow(created: OrderCharge(id: 'ch1'))
          .send(ctx, _order(total: 950, paid: 200));
      expect(action, SendChargeAction.createChargeThenShare);
      expect(calls, ['create:750.0', 'share:o1']);
    });

    testWidgets('Asaas: giving up on the charge screen shares nothing',
        (tester) async {
      await pumpHost(tester);
      await flow(created: null).send(ctx, _order());
      expect(calls, ['create:950.0']);
    });

    testWidgets('Asaas with open charge: shares without creating another',
        (tester) async {
      await pumpHost(tester);
      final action = await flow(
        openCharge: (_) async => OrderCharge(status: ChargeStatus.pending),
      ).send(ctx, _order());
      expect(action, SendChargeAction.shareExistingCharge);
      expect(calls, ['share:o1']);
    });

    testWidgets('charges cannot be read: falls back to the order link',
        (tester) async {
      await pumpHost(tester);
      final action = await flow(
        openCharge: (_) async => throw Exception('permission-denied'),
      ).send(ctx, _order());
      expect(action, SendChargeAction.shareOrderLink);
      expect(calls, ['share:o1']);
    });

    testWidgets('settings fail: falls back to the order link', (tester) async {
      await pumpHost(tester);
      final action = await flow(
        settings: () async => throw Exception('offline'),
      ).send(ctx, _order());
      expect(action, SendChargeAction.shareOrderLink);
      expect(calls, ['share:o1']);
    });
  });
}
