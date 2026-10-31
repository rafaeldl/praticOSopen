import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/customer_charge.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/screens/payments/receive_customer_screen.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/secondary_button.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/payment_allocation.dart';

class _FakeService extends CustomerReceiptService {
  _FakeService({this.failOnline});

  final CustomerReceiptFailure? failOnline;
  final local = <CustomerReceiptRequest>[];
  final online = <CustomerReceiptRequest>[];

  @override
  Future<Receipt> record(CustomerReceiptRequest request) async {
    local.add(request);
    return Receipt();
  }

  @override
  Future<void> recordOnline(CustomerReceiptRequest request) async {
    online.add(request);
    if (failOnline != null) throw CustomerReceiptException(failOnline!);
  }
}

Order _order(String id, int number, double total, DateTime createdAt) => Order()
  ..id = id
  ..number = number
  ..total = total
  ..paidAmount = 0
  ..createdAt = createdAt;

final _customer = CustomerAggr()
  ..id = 'c1'
  ..name = 'João';

List<Order> _orders() => [
  _order('a', 182, 450, DateTime(2026, 9, 1)),
  _order('b', 190, 500, DateTime(2026, 9, 10)),
];

CustomerCharge _charge({String status = 'pending'}) => CustomerCharge.fromJson({
  'id': 'cc1',
  'customer': {'id': 'c1', 'name': 'João'},
  'value': 950,
  'dueDate': '2026-10-20',
  'status': status,
  'invoiceUrl': 'https://asaas.test/i/cc1',
  'allocations': [
    {'orderId': 'a', 'orderNumber': 182, 'amount': 450},
    {'orderId': 'b', 'orderNumber': 190, 'amount': 500},
  ],
});

void main() {
  setUp(() => FormatService().setLocale('pt-BR'));
  String brl(double v) => FormatService().formatCurrency(v);

  Future<void> pump(
    WidgetTester tester, {
    _FakeService? service,
    bool chargeReady = false,
    Stream<CustomerCharge?>? openCharge,
    Future<CustomerCharge?> Function(BuildContext, List<OpenBalance>, double)?
    createCharge,
    List<String>? shared,
    AsaasApiService? api,
    Future<List<CustomerOpenOrder>> Function()? others,
    double textScale = 1,
    Stream<Map<String, OrderCharge>>? orderCharges,
    bool startCharge = false,
  }) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(430, 1600),
            textScaler: TextScaler.linear(textScale),
          ),
          child: ReceiveCustomerScreen(
            orders: _orders(),
            customer: _customer,
            service: service ?? _FakeService(),
            canAttachReceipt: false,
            chargeReady: () async => chargeReady,
            openCharge: openCharge ?? Stream.value(null),
            orderCharges: orderCharges ?? Stream.value(const {}),
            startCharge: startCharge,
            createCharge: createCharge,
            shareLink: (_, url) async => shared?.add(url),
            api: api,
            otherOrdersLoader: others ?? () async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> receive(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new_order_save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Mandar cobrança', () {
    testWidgets('hidden without Asaas', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('receiveCustomerMenu')), findsNothing);
      expect(find.text('Mandar cobrança'), findsNothing);
    });

    testWidgets('creates one charge for the orders and shares it', (
      tester,
    ) async {
      final calls = <(List<String>, double)>[];
      final shared = <String>[];
      await pump(
        tester,
        chargeReady: true,
        shared: shared,
        createCharge: (_, balances, value) async {
          calls.add(([for (final b in balances) b.orderId], value));
          return _charge();
        },
      );

      // On the screen, beside the blue button; no "…" until a charge exists.
      expect(find.byKey(const Key('receiveCustomerMenu')), findsNothing);
      expect(find.byType(SecondaryButton), findsOneWidget);
      await tester.tap(find.text('Mandar cobrança'));
      await tester.pumpAndSettle();

      expect(calls.single.$1, ['a', 'b']);
      expect(calls.single.$2, 950);
      expect(shared, ['https://asaas.test/i/cc1']);
      expect(find.text('Esperando João pagar'), findsOneWidget);
    });

    testWidgets('only the orders checked go in the charge', (tester) async {
      final calls = <(List<String>, double)>[];
      await pump(
        tester,
        chargeReady: true,
        createCharge: (_, balances, value) async {
          calls.add(([for (final b in balances) b.orderId], value));
          return null;
        },
      );
      await tester.tap(find.byKey(const Key('receiveCustomerToggle_a')));
      await tester.pump();
      await tester.tap(find.text('Mandar cobrança'));
      await tester.pumpAndSettle();
      expect(calls.single.$1, ['b']);
      expect(calls.single.$2, 500);
    });

    testWidgets('an open charge is shown and sent again, not duplicated', (
      tester,
    ) async {
      var created = 0;
      final shared = <String>[];
      await pump(
        tester,
        chargeReady: true,
        shared: shared,
        openCharge: Stream.value(_charge()),
        createCharge: (_, _, _) async {
          created++;
          return null;
        },
      );

      expect(find.text('Esperando João pagar'), findsOneWidget);
      expect(
        find.text('Cobrança de ${brl(950)} · vale até 20/10/2026'),
        findsOneWidget,
      );
      // The customer is the one who acts: nothing blue.
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('Mandar cobrança'), findsNothing);
      await tester.tap(find.text('Mandar de novo'));
      await tester.pumpAndSettle();
      expect(created, 0);
      expect(shared, ['https://asaas.test/i/cc1']);
    });

    testWidgets('overdue: red, and "Mandar de novo" turns blue', (
      tester,
    ) async {
      await pump(
        tester,
        chargeReady: true,
        openCharge: Stream.value(_charge(status: 'overdue')),
      );
      expect(find.text('Venceu em 20/10/2026'), findsOneWidget);
      expect(
        find.text('Cobrança de ${brl(950)} · ainda dá para pagar'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const Key('receiveCustomerResend')),
            )
            .label,
        'Mandar de novo',
      );
    });

    testWidgets('received another way: the sheet says the charge adjusts', (
      tester,
    ) async {
      final service = _FakeService();
      await pump(
        tester,
        service: service,
        chargeReady: true,
        openCharge: Stream.value(_charge()),
      );
      await tester.tap(find.byKey(const Key('receiveCustomerConfirm')));
      await tester.pumpAndSettle();
      expect(
        find.text('A cobrança aberta se ajusta sozinha, sem avisar João.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(service.local.single.allocations.map((a) => a.amount), [450, 500]);
    });

    testWidgets('a single-order link shows on its row and asks to replace', (
      tester,
    ) async {
      final calls = <double>[];
      await pump(
        tester,
        chargeReady: true,
        orderCharges: Stream.value({
          'a': OrderCharge(
            id: 'ch1',
            status: ChargeStatus.pending,
            value: 450,
            dueDate: '2026-10-20',
          ),
        }),
        createCharge: (_, _, value) async {
          calls.add(value);
          return null;
        },
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('receiveCustomerLine_a')))
            .data,
        'Esperando o pagamento',
      );

      await tester.tap(find.text('Mandar cobrança'));
      await tester.pumpAndSettle();
      expect(find.text('Já existe uma cobrança em aberto'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.tap(find.byKey(const Key('receiveCustomerChargeReplace')));
      await tester.pumpAndSettle();
      expect(calls, [950]);
    });

    testWidgets('startCharge opens the charge sheet right away', (
      tester,
    ) async {
      final calls = <double>[];
      await pump(
        tester,
        chargeReady: true,
        startCharge: true,
        createCharge: (_, _, value) async {
          calls.add(value);
          return null;
        },
      );
      expect(calls, [950]);
    });

    testWidgets('startCharge with a charge open only shows it', (tester) async {
      final calls = <double>[];
      await pump(
        tester,
        chargeReady: true,
        startCharge: true,
        openCharge: Stream.value(_charge()),
        createCharge: (_, _, value) async {
          calls.add(value);
          return null;
        },
      );
      expect(calls, isEmpty);
      expect(find.text('Esperando João pagar'), findsOneWidget);
    });

    testWidgets('"…" cancels the charge through the API', (tester) async {
      final requests = <http.Request>[];
      final api = AsaasApiService.withClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {..._charge().toTestJson(), 'status': 'canceled'},
            }),
            200,
          );
        }),
        headersProvider: () async => {'Authorization': 'Bearer t'},
      );
      await pump(
        tester,
        chargeReady: true,
        api: api,
        openCharge: Stream.value(_charge()),
      );

      await tester.tap(find.byKey(const Key('receiveCustomerMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar cobrança').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('receiveCustomerChargeCancelConfirm')),
      );
      await tester.pumpAndSettle();

      expect(requests.single.method, 'DELETE');
      expect(
        requests.single.url.path,
        endsWith('/v1/app/customers/c1/charges/cc1'),
      );
      expect(find.text('Esperando João pagar'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('Outras OS de João (consultor)', () {
    Future<List<CustomerOpenOrder>> others() async => [
      // Own order already on the screen: not repeated.
      CustomerOpenOrder(id: 'a', number: 182, open: 450, own: true),
      CustomerOpenOrder(
        id: 'x',
        number: 175,
        open: 200,
        createdAt: DateTime(2026, 8, 20),
      ),
    ];

    testWidgets('lists the others and keeps them out of the split', (
      tester,
    ) async {
      final service = _FakeService();
      await pump(tester, service: service, others: others);

      expect(find.text('Outras OS de João'), findsOneWidget);
      expect(find.byKey(const Key('receiveCustomerOther_x')), findsOneWidget);
      expect(find.byKey(const Key('receiveCustomerOther_a')), findsNothing);
      // Unchecked and not openable (no ⓘ).
      expect(find.byKey(const Key('receiveCustomerInfo_x')), findsNothing);

      await receive(tester);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(service.local.single.allocations.map((a) => a.orderId), [
        'a',
        'b',
      ]);
      expect(service.online, isEmpty);
    });

    testWidgets('including one saves through the server, oldest first', (
      tester,
    ) async {
      final service = _FakeService();
      await pump(tester, service: service, others: others);

      // Check 175 (someone else's) and uncheck 190.
      await tester.tap(find.byKey(const Key('receiveCustomerToggle_x')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('receiveCustomerToggle_b')));
      await tester.pump();
      // The total followed the checked orders: 200 + 450.
      expect(
        tester.widget<Text>(find.byKey(const Key('receiveSummaryAmount'))).data,
        brl(650),
      );

      await receive(tester);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(service.local, isEmpty);
      final request = service.online.single;
      expect(request.allocations.map((a) => a.orderId), ['x', 'a']);
      expect(request.allocations.map((a) => a.amount), [200, 450]);
    });

    testWidgets('offline: toast and keeps what was typed', (tester) async {
      final service = _FakeService(failOnline: CustomerReceiptFailure.offline);
      await pump(tester, service: service, others: others);
      await tester.tap(find.byKey(const Key('receiveCustomerToggle_a')));
      await tester.tap(find.byKey(const Key('receiveCustomerToggle_b')));
      await tester.tap(find.byKey(const Key('receiveCustomerToggle_x')));
      await tester.pump();
      await receive(tester);

      expect(
        find.text(
          'Sem internet. Para receber em OS de outra pessoa, precisa estar '
          'conectado.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('receiveCustomerConfirm')), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('server list failing leaves the screen as before', (
      tester,
    ) async {
      await pump(tester, others: () => Future.error(Exception('offline')));
      expect(find.text('Outras OS de João'), findsNothing);
      expect(find.byKey(const Key('receiveCustomerConfirm')), findsOneWidget);
    });
  });

  testWidgets('text size 2: open link and other orders without overflow', (
    tester,
  ) async {
    await pump(
      tester,
      textScale: 2,
      chargeReady: true,
      openCharge: Stream.value(_charge()),
      others: () async => [
        CustomerOpenOrder(
          id: 'x',
          number: 175,
          open: 200,
          createdAt: DateTime(2026, 8, 20),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('receiveCustomerOpenCharge')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('receiveCustomerOthersNote')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('receiveCustomerMenu')), findsOneWidget);
  });

  test('customerChargeReady needs permission, pilot, connection, customer', () {
    bool ready({
      bool canCharge = true,
      bool enabled = true,
      bool connected = true,
      String? customerId = 'c1',
    }) => customerChargeReady(
      canCharge: canCharge,
      asaasEnabled: enabled,
      asaasConnected: connected,
      customerId: customerId,
    );
    expect(ready(), isTrue);
    expect(ready(canCharge: false), isFalse);
    expect(ready(enabled: false), isFalse);
    expect(ready(connected: false), isFalse);
    expect(ready(customerId: null), isFalse);
  });
}

extension on CustomerCharge {
  Map<String, dynamic> toTestJson() => {
    'id': id,
    'customer': {'id': customerId, 'name': customerName},
    'value': value,
    'dueDate': dueDate,
    'status': status,
    'invoiceUrl': invoiceUrl,
    'allocations': [
      for (final a in allocations)
        {
          'orderId': a.orderId,
          'orderNumber': a.orderNumber,
          'amount': a.amount,
        },
    ],
  };
}
