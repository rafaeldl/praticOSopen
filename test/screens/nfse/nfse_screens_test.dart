import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/nfse/nfse_invoice_screen.dart';
import 'package:praticos/screens/nfse/nfse_issue_sheet.dart';
import 'package:praticos/screens/nfse/nfse_setup_screen.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';

/// A fake `/v1/app/nfse` server: records the calls, answers [handler].
class _Server {
  _Server(this.handler);

  final Object? Function(String method, String path, Map<String, dynamic> body)
  handler;
  final calls = <(String, String, Map<String, dynamic>)>[];

  AsaasApiService get api => AsaasApiService.withClient(
    MockClient((request) async {
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      final path = request.url.path.replaceFirst(RegExp(r'^.*/nfse'), '');
      calls.add((request.method, path, body));
      final answer = handler(request.method, path, body);
      if (answer is http.Response) return answer;
      return http.Response(
        jsonEncode({'success': true, 'data': answer}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    headersProvider: () async => {'Authorization': 'Bearer t'},
  );
}

http.Response _error(String code, {int status = 409}) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': 'raw'},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: page!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the issue sheet from a button and returns what it popped.
Future<List<NfseInvoice?>> _openIssue(
  WidgetTester tester,
  AsaasApiService api, {
  List<String> orderIds = const ['o1'],
  String? customerId,
  double textScale = 1,
}) async {
  final results = <NfseInvoice?>[];
  await _pump(
    tester,
    Builder(
      builder: (context) => CupertinoPageScaffold(
        child: Center(
          child: CupertinoButton(
            child: const Text('open'),
            onPressed: () async => results.add(
              await NfseIssueSheet.show(
                context,
                orderIds: orderIds,
                customerId: customerId,
                service: api,
              ),
            ),
          ),
        ),
      ),
    ),
    textScale: textScale,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Map<String, dynamic> _preview({
  bool hasTaxId = true,
  bool hasProducts = true,
  Map<String, String> invoiced = const {},
  List<Map<String, dynamic>>? orders,
}) => {
  'value': 270,
  'orders':
      orders ??
      [
        {
          'orderId': 'o1',
          'orderNumber': 182,
          'value': 270,
          'servicesTotal': 300,
          'productsTotal': 100,
          'discount': 40,
        },
      ],
  'hasProducts': hasProducts,
  'serviceDescription': 'OS 182: Troca de óleo',
  'effectiveDate': '2026-10-15',
  'customer': {'id': 'c1', 'name': 'João Silva', 'hasTaxId': hasTaxId},
  'invoicedOrders': invoiced,
  'municipalServiceName': 'Manutenção de veículos',
};

Map<String, dynamic> _invoiceJson(
  String status, {
  Map<String, dynamic>? extra,
}) => {
  'id': 'inv1',
  'status': status,
  'customer': {'id': 'c1', 'name': 'João Silva'},
  'orderIds': ['o1'],
  'orders': [
    {'orderId': 'o1', 'orderNumber': 182, 'value': 270},
  ],
  'value': 270,
  'effectiveDate': '2026-10-15',
  ...?extra,
};

Order _order({
  String status = 'done',
  double services = 300,
  double products = 100,
  double discount = 40,
}) => Order()
  ..id = 'o1'
  ..number = 182
  ..status = status
  ..services = [OrderService()..value = services]
  ..products = [
    if (products > 0)
      OrderProduct()
        ..value = products
        ..quantity = 1
        ..total = products,
  ]
  ..discount = discount;

void main() {
  setUp(() => FormatService().setLocale('pt-BR'));

  group('value rule', () {
    test('services minus their share of the discount', () {
      // 300 services + 100 products, 40 off: services take 75% of it.
      expect(nfseValueOfOrder(_order()), 270);
      expect(nfseValueOfOrder(_order(products: 0, discount: 50)), 250);
      expect(nfseValueOfOrder(_order(services: 0)), 0);
    });

    test('only orders with services, not quotes nor canceled', () {
      expect(orderCanHaveNfse(_order()), isTrue);
      expect(orderCanHaveNfse(_order(status: 'quote')), isFalse);
      expect(orderCanHaveNfse(_order(status: 'canceled')), isFalse);
      expect(orderCanHaveNfse(_order(services: 0)), isFalse);
    });
  });

  group('current nota of an order', () {
    NfseInvoice inv(String status, {DateTime? at, String id = 'x'}) =>
        NfseInvoice.fromJson({
          'status': status,
          'createdAt': (at ?? DateTime.now()).toIso8601String(),
        }, id: id);

    test('active wins over the latest refused one', () {
      final now = DateTime.now();
      final current = currentInvoiceOf([
        inv('authorized', at: now.subtract(const Duration(days: 2)), id: 'a'),
        inv('error', at: now, id: 'b'),
      ]);
      expect(current?.id, 'a');
    });

    test('a refused or canceled one still shows when it is the only', () {
      expect(currentInvoiceOf([inv('error')])?.status, NfseStatus.error);
      expect(currentInvoiceOf([inv('canceled')])?.isActive(), isFalse);
    });

    test('"creating" that never reached Asaas stops counting', () {
      final old = inv(
        'creating',
        at: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(old.isActive(), isFalse);
      expect(currentInvoiceOf([old]), isNull);
      expect(inv('creating').isActive(), isTrue);
    });
  });

  group('NfseController', () {
    PaymentSettings settings({bool nfse = true, bool ready = true}) =>
        PaymentSettings(
          asaasEnabled: true,
          asaasConnected: true,
          nfseEnabled: nfse,
          nfseReady: ready,
        );

    test('flag off: disabled and reads no notas', () async {
      var reads = 0;
      final c = NfseController(
        canIssue: true,
        settingsStream: Stream.value(settings(nfse: false)),
        invoicesOf: (_) {
          reads++;
          return Stream.value([NfseInvoice.fromJson({}, id: 'x')]);
        },
      )..watchOrder('o1');
      await pumpEventQueue();
      expect(c.enabled, isFalse);
      expect(c.invoices, isEmpty);
      expect(reads, 0);
      c.dispose();
    });

    test('without permission (consultant) it stays off', () async {
      final c = NfseController(
        canIssue: false,
        settingsStream: Stream.value(settings()),
        invoicesOf: (_) => Stream.value(const []),
      );
      await pumpEventQueue();
      expect(c.enabled, isFalse);
      c.dispose();
    });

    test('flag on: notas of the order and the invoiced ids', () async {
      final c = NfseController(
        canIssue: true,
        settingsStream: Stream.value(settings(ready: false)),
        invoicesOf: (_) => Stream.value([
          NfseInvoice.fromJson(_invoiceJson('scheduled'), id: 'inv1'),
        ]),
      )..watchOrder('o1');
      await pumpEventQueue();
      expect(c.enabled, isTrue);
      expect(c.ready, isFalse);
      expect(c.invoicedOrderIds, {'o1'});
      c.dispose();
    });
  });

  group('NfseIssueSheet', () {
    testWidgets('shows the value of the services and creates the nota', (
      tester,
    ) async {
      final server = _Server((method, path, body) {
        if (path == '/invoices/preview') return _preview();
        return _invoiceJson('scheduled');
      });
      final results = await _openIssue(tester, server.api);

      expect(find.textContaining('270,00'), findsOneWidget);
      expect(
        find.textContaining('Só os serviços entram na nota'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nfseIssueTaxId')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();

      final create = server.calls.last;
      expect(create.$2, '/invoices');
      expect(create.$3['orderIds'], ['o1']);
      expect(create.$3['serviceDescription'], 'OS 182: Troca de óleo');
      expect(results.single?.status, NfseStatus.scheduled);
    });

    testWidgets('asks the CPF/CNPJ when the customer has none', (tester) async {
      final server = _Server((method, path, body) {
        if (path == '/invoices/preview') return _preview(hasTaxId: false);
        return _invoiceJson('scheduled');
      });
      await _openIssue(tester, server.api);

      expect(find.byKey(const Key('nfseIssueTaxId')), findsOneWidget);
      // ✓ stays gray: nothing is sent.
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(server.calls.where((c) => c.$2 == '/invoices'), isEmpty);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('nfseIssueTaxId')),
          matching: find.byType(CupertinoTextField),
        ),
        '529.982.247-25',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(server.calls.last.$3['customerTaxId'], '52998224725');
    });

    testWidgets('an order that already has a nota blocks it', (tester) async {
      final server = _Server(
        (method, path, body) => _preview(invoiced: {'o1': 'inv0'}),
      );
      await _openIssue(tester, server.api);
      expect(find.textContaining('182'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(server.calls.where((c) => c.$2 == '/invoices'), isEmpty);
    });

    testWidgets('server error shows plain Portuguese, never raw text', (
      tester,
    ) async {
      final server = _Server((method, path, body) {
        if (path == '/invoices/preview') return _preview();
        return _error('ORDER_HAS_INVOICE');
      });
      await _openIssue(tester, server.api);
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(find.text('raw'), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    });

    testWidgets('several orders list each one; fits at text size 2', (
      tester,
    ) async {
      final server = _Server(
        (method, path, body) => _preview(
          hasTaxId: false,
          orders: [
            {
              'orderId': 'o1',
              'orderNumber': 182,
              'value': 150,
              'servicesTotal': 150,
              'productsTotal': 0,
              'discount': 0,
            },
            {
              'orderId': 'o2',
              'orderNumber': 190,
              'value': 120,
              'servicesTotal': 120,
              'productsTotal': 0,
              'discount': 0,
            },
          ],
        ),
      );
      await _openIssue(
        tester,
        server.api,
        orderIds: const ['o1', 'o2'],
        customerId: 'c1',
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(server.calls.first.$3['customerId'], 'c1');
      expect(find.textContaining('190'), findsWidgets);
    });
  });

  group('NfseInvoiceScreen', () {
    Future<_Server> pumpInvoice(
      WidgetTester tester,
      String status, {
      Map<String, dynamic>? extra,
      Object? Function(String, String, Map<String, dynamic>)? handler,
      List<String>? opened,
      double textScale = 1,
    }) async {
      final server = _Server(
        handler ?? (method, path, body) => _invoiceJson('canceled'),
      );
      await _pump(
        tester,
        NfseInvoiceScreen(
          invoice: NfseInvoice.fromJson(
            _invoiceJson(status, extra: extra),
            id: 'inv1',
          ),
          invoiceStream: const Stream.empty(),
          service: server.api,
          openUrl: (url) async => opened?.add(url),
        ),
        textScale: textScale,
      );
      return server;
    }

    testWidgets('issued: PDF and XML links', (tester) async {
      final opened = <String>[];
      await pumpInvoice(
        tester,
        'authorized',
        extra: {
          'number': '77',
          'pdfUrl': 'https://x/pdf',
          'xmlUrl': 'https://x/xml',
        },
        opened: opened,
      );
      expect(find.text('Emitida · nº 77'), findsWidgets);
      await tester.tap(find.byKey(const Key('nfseOpenPdf')));
      expect(opened, ['https://x/pdf']);
    });

    testWidgets('refused: shows the reason; fits at text size 2', (
      tester,
    ) async {
      await pumpInvoice(
        tester,
        'error',
        extra: {'statusDescription': 'Inscrição municipal inválida'},
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('nfseInvoiceReason')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('nfseInvoiceReason')), findsOneWidget);
      // Nothing to cancel on a refused nota.
      expect(find.byKey(const Key('nfseMenuButton')), findsNothing);
    });

    testWidgets('"Cancelar nota" asks first, then calls the server', (
      tester,
    ) async {
      final server = await pumpInvoice(tester, 'authorized');
      await tester.tap(find.byKey(const Key('nfseMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar nota').last);
      await tester.pumpAndSettle();
      expect(server.calls, isEmpty);
      await tester.tap(find.byKey(const Key('nfseCancelConfirm')));
      await tester.pumpAndSettle();
      expect(server.calls.single.$2, '/invoices/inv1/cancel');
      expect(server.calls.single.$3, isEmpty);
    });

    testWidgets('city that does not cancel: marks it after the user did', (
      tester,
    ) async {
      final server = await pumpInvoice(
        tester,
        'authorized',
        handler: (method, path, body) => body['onlyOnAsaas'] == true
            ? _invoiceJson('canceled')
            : _error('CANCEL_NOT_SUPPORTED'),
      );
      await tester.tap(find.byKey(const Key('nfseMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar nota').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nfseCancelConfirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nfseCanceledAtCity')));
      await tester.pumpAndSettle();
      expect(server.calls.last.$3, {'onlyOnAsaas': true});
    });
  });

  group('NfseSetupScreen', () {
    Map<String, dynamic> setup({
      List<String> missing = const [],
      bool fiscal = true,
    }) => {
      'ready': missing.isEmpty,
      'missing': missing,
      if (fiscal)
        'fiscalInfo': {
          'email': 'nf@oficina.com',
          'municipalInscription': '123',
          'simplesNacional': true,
        },
      'municipalOptions': {
        'authenticationType': 'CERTIFICATE',
        'supportsCancellation': false,
      },
      if (!missing.contains('service'))
        'service': {
          'municipalServiceId': '10',
          'municipalServiceName': 'Manutenção de veículos',
          'taxes': {'iss': 2},
        },
    };

    testWidgets('lists what is missing with one blue button', (tester) async {
      final server = _Server(
        (method, path, body) => setup(missing: const ['cityAccess', 'service']),
      );
      final opened = <String>[];
      await _pump(
        tester,
        NfseSetupScreen(
          service: server.api,
          sandbox: true,
          openUrl: (url) async => opened.add(url),
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('nfseSetupNext')), findsOneWidget);
      expect(find.text('Falta'), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.textContaining('certificado digital'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('não deixa cancelar'), findsOneWidget);

      // Next missing step: the city access, in the Asaas sandbox panel.
      await tester.tap(find.byKey(const Key('nfseSetupNext')));
      await tester.pumpAndSettle();
      expect(opened.single, contains('sandbox'));
    });

    testWidgets('ready: no button', (tester) async {
      final server = _Server((method, path, body) => setup());
      await _pump(tester, NfseSetupScreen(service: server.api));
      expect(find.byKey(const Key('nfseSetupNext')), findsNothing);
      expect(find.text('Pronto'), findsNWidgets(2));
    });

    testWidgets('service sheet saves service and taxes', (tester) async {
      final server = _Server((method, path, body) {
        if (path == '/setup/service') return setup();
        return setup(missing: const ['service']);
      });
      await _pump(tester, NfseSetupScreen(service: server.api));
      await tester.tap(find.byKey(const Key('nfseSetupService')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nfseServiceToggleTyping')));
      await tester.pumpAndSettle();

      Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(CupertinoTextField),
      );
      await tester.enterText(field('nfseServiceCode'), '14.01');
      await tester.enterText(field('nfseServiceName'), 'Conserto');
      await tester.enterText(field('nfseTax_iss'), '2,5');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();

      final save = server.calls.last;
      expect(save.$1, 'PUT');
      expect(save.$3['municipalServiceCode'], '14.01');
      expect(save.$3['municipalServiceName'], 'Conserto');
      expect((save.$3['taxes'] as Map)['iss'], 2.5);
    });
  });
}
