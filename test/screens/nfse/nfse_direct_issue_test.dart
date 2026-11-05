import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/models/nfse.dart' hide NfseDirectAutoIssue;
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_issue_sheet.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/nfse/nfse_invoice_screen.dart';
import 'package:praticos/screens/nfse/nfse_list_screen.dart';
import 'package:praticos/services/fiscal_lookup_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';

/// A fake nfseApi: records the calls, answers [handler].
class _Server {
  _Server(this.handler);

  final Object? Function(String path, Map<String, dynamic> body) handler;
  final calls = <(String, Map<String, dynamic>)>[];

  List<Map<String, dynamic>> bodiesOf(String path) => [
    for (final c in calls)
      if (c.$1 == path) c.$2,
  ];

  NfseDirectApiService get api => NfseDirectApiService.withClient(
    MockClient((request) async {
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      final path = request.url.path.replaceFirst(
        '/nfseApi/v1/app/nfse/direct',
        '',
      );
      calls.add((path, body));
      final answer = handler(path, body);
      if (answer is http.Response) return answer;
      return http.Response(
        jsonEncode({'success': true, 'data': answer ?? {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    headersProvider: () async => {'Authorization': 'Bearer t'},
  );
}

http.Response _error(
  String code, {
  int status = 422,
  Map<String, dynamic>? details,
}) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': 'raw', 'details': ?details},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _emitterJson(
  String id,
  String name, {
  String regime = 'simples',
  String taxId = '00000000000191',
  String? problem,
  bool isDefault = false,
}) => {
  'id': id,
  'legalName': name,
  'taxId': taxId,
  'regime': regime,
  'problem': problem,
  'isDefault': isDefault,
  'serviceName': 'Revisão de veículos',
};

Map<String, dynamic> _preview({
  Map<String, dynamic>? emitter,
  List<Map<String, dynamic>>? emitters,
  Map<String, dynamic>? recipient,
  List<String> missing = const [],
  String meiWarning = 'none',
}) {
  final marked =
      emitter ?? _emitterJson('e1', 'OFICINA EXEMPLO LTDA', isDefault: true);
  return {
    'value': 270,
    'orders': [
      {
        'orderId': 'o1',
        'orderNumber': 182,
        'value': 270,
        'servicesTotal': 300,
        'productsTotal': 100,
        'discount': 40,
      },
    ],
    'hasProducts': true,
    'description': 'CONSERTO/PINTURA DE CAPÔ',
    'complementaryInfo': 'OS 182 · Emitida pelo PraticOS (praticos.app)',
    'emitter': marked,
    'emitters': emitters ?? [marked],
    'customer': {'id': 'cu2', 'name': 'Loja Centro'},
    'recipient':
        recipient ??
        {
          'customerId': 'cu1',
          'name': 'Revenda Exemplo',
          'legalName': 'REVENDA EXEMPLO LTDA',
          'taxId': '00000000000272',
          'address': null,
          'email': 'nota@example.com',
          'viaInvoiceRecipient': true,
        },
    'missing': missing,
    'meiWarning': meiWarning,
    'invoicedOrders': <String, String>{},
  };
}

Map<String, dynamic> _invoiceJson(
  String status, {
  Map<String, dynamic> extra = const {},
}) => {
  'id': 'inv1',
  'status': status,
  'provider': 'direct',
  'source': 'praticos',
  'customer': {'id': 'cu2', 'name': 'Loja Centro'},
  'orderIds': ['o1'],
  'orders': [
    {'orderId': 'o1', 'orderNumber': 182, 'value': 270},
  ],
  'value': 270,
  'effectiveDate': '2026-11-05',
  'createdAt': '2026-11-05T10:00:00.000',
  'emitter': {
    'id': 'e1',
    'legalName': 'OFICINA EXEMPLO LTDA',
    'taxId': '00000000000191',
    'regime': 'simples',
  },
  'recipient': {
    'customerId': 'cu1',
    'legalName': 'REVENDA EXEMPLO LTDA',
    'taxId': '00000000000272',
  },
  ...extra,
};

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the sheet from a button and returns what it popped.
Future<List<NfseInvoice?>> _openSheet(
  WidgetTester tester,
  _Server server, {
  List<Customer> customers = const [],
  FiscalLookupService? lookup,
  bool? canSetUp,
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
              await NfseDirectIssueSheet.show(
                context,
                orderIds: const ['o1'],
                service: server.api,
                loadCustomers: () async => customers,
                lookup: lookup,
                canSetUp: canSetUp,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('new_order_save')));
  await tester.pumpAndSettle();
}

Customer _customer(String id, String name, {String? taxId}) => Customer()
  ..id = id
  ..name = name
  ..taxId = taxId;

void main() {
  setUp(() => FormatService().setLocale('pt_BR'));

  test('daily limit and manager not allowed in plain words', () {
    final l10n = lookupAppLocalizations(const Locale('pt'));
    expect(
      nfseDirectErrorText(
        l10n,
        NfseDirectApiException('DAILY_LIMIT_REACHED', 'x'),
      ),
      l10n.nfseDirectErrorDailyLimit,
    );
    expect(
      nfseDirectErrorText(
        l10n,
        NfseDirectApiException(
          'FORBIDDEN',
          'x',
          details: {'reason': 'managerNotAllowed'},
        ),
      ),
      l10n.nfseDirectErrorManagerNotAllowed,
    );
    expect(
      nfseDirectErrorText(l10n, NfseDirectApiException('FORBIDDEN', 'x')),
      l10n.nfseDirectErrorForbidden,
    );
  });

  group('NfseDirectIssueSheet', () {
    testWidgets('shows who issues, who gets it, value and text; ✓ issues', (
      tester,
    ) async {
      final server = _Server((path, body) {
        if (path == '/invoices/preview') return _preview();
        return _invoiceJson('authorized', extra: {'number': '29'});
      });
      final results = await _openSheet(tester, server);

      expect(find.text('Emitir por'), findsOneWidget);
      expect(find.textContaining('OFICINA EXEMPLO LTDA'), findsOneWidget);
      expect(find.textContaining('Simples · CNPJ'), findsOneWidget);
      expect(find.textContaining('REVENDA EXEMPLO LTDA'), findsOneWidget);
      expect(
        find.textContaining('Pelo “Nota fiscal para” de Loja Centro'),
        findsOneWidget,
      );
      expect(find.textContaining('270,00'), findsOneWidget);
      expect(find.text('CONSERTO/PINTURA DE CAPÔ'), findsOneWidget);
      expect(
        find.text(
          'Vai junto na nota: OS 182 · Emitida pelo PraticOS (praticos.app)',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nfseDirectIssueMeiWarning')), findsNothing);

      await _save(tester);
      final issued = server.bodiesOf('/invoices').single;
      expect(issued['orderIds'], ['o1']);
      expect(issued['emitterId'], 'e1');
      // Unedited text: the server writes it by the rule.
      expect(issued.containsKey('description'), isFalse);
      expect(issued.containsKey('recipient'), isFalse);
      expect(results.single?.status, NfseStatus.authorized);
      expect(results.single?.number, '29');
    });

    testWidgets('edited text goes only in this nota', (tester) async {
      final server = _Server((path, body) {
        if (path == '/invoices/preview') return _preview();
        return _invoiceJson('authorized');
      });
      await _openSheet(tester, server);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('nfseDirectIssueDescription')),
          matching: find.byType(CupertinoTextField),
        ),
        'PINTURA DO CAPÔ',
      );
      await tester.pump();
      await _save(tester);
      expect(
        server.bodiesOf('/invoices').single['description'],
        'PINTURA DO CAPÔ',
      );
    });

    testWidgets('another CNPJ: picker, preview again, MEI warning', (
      tester,
    ) async {
      final simples = _emitterJson(
        'e1',
        'OFICINA EXEMPLO LTDA',
        isDefault: true,
      );
      final mei = _emitterJson(
        'e2',
        'FULANO MEI',
        regime: 'mei',
        taxId: '11222333000181',
      );
      final server = _Server((path, body) {
        if (path == '/invoices/preview') {
          final chosen = body['emitterId'] == 'e2' ? mei : simples;
          return _preview(
            emitter: chosen,
            emitters: [simples, mei],
            meiWarning: chosen == mei ? 'near' : 'none',
          );
        }
        return _invoiceJson('authorized');
      });
      await _openSheet(tester, server);

      await tester.tap(find.byKey(const Key('nfseDirectIssueEmitter')));
      await tester.pumpAndSettle();
      expect(find.text('Por qual CNPJ emitir?'), findsWidgets);
      await tester.tap(find.byKey(const Key('nfseDirectEmitterOption_e2')));
      await tester.pumpAndSettle();

      expect(server.bodiesOf('/invoices/preview').last['emitterId'], 'e2');
      expect(
        find.text('Com esta nota, o MEI passa de 80% do teto do ano.'),
        findsOneWidget,
      );
      // The warning never blocks.
      await _save(tester);
      expect(server.bodiesOf('/invoices').single['emitterId'], 'e2');
    });

    testWidgets('MEI over the limit: says to talk to the accountant', (
      tester,
    ) async {
      final server = _Server((path, body) {
        if (path == '/invoices/preview') {
          return _preview(
            emitter: _emitterJson('e2', 'FULANO MEI', regime: 'mei'),
            meiWarning: 'over',
          );
        }
        return _invoiceJson('authorized');
      });
      await _openSheet(tester, server);
      expect(
        find.text(
          'Com esta nota, o MEI passa do teto do ano. Fale com o seu contador.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Para" to another customer only in this nota', (tester) async {
      final server = _Server((path, body) {
        if (path == '/invoices/preview') {
          if (body['recipientCustomerId'] == 'cu9') {
            return _preview(
              recipient: {
                'customerId': 'cu9',
                'name': 'Outra Loja',
                'legalName': 'OUTRA LOJA LTDA',
                'taxId': '11444777000161',
                'address': {
                  'postalCode': '88000000',
                  'street': 'Rua A',
                  'number': '1',
                  'district': 'Centro',
                  'cityCode': '4200000',
                  'cityName': 'Cidade',
                  'state': 'SC',
                },
                'email': 'loja@example.com',
                'viaInvoiceRecipient': true,
              },
            );
          }
          return _preview();
        }
        return _invoiceJson('authorized');
      });
      await _openSheet(
        tester,
        server,
        customers: [
          _customer('cu1', 'Revenda Exemplo', taxId: '00000000000272'),
          _customer('cu9', 'Outra Loja', taxId: '11444777000161'),
        ],
      );
      await tester.tap(find.byKey(const Key('nfseDirectIssueRecipient')));
      await tester.pumpAndSettle();
      expect(find.text('Para quem vai esta nota?'), findsWidgets);
      expect(find.text('Vale só para esta nota'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nfseDirectRecipientOption_cu9')));
      await tester.pumpAndSettle();

      expect(
        server.bodiesOf('/invoices/preview').last['recipientCustomerId'],
        'cu9',
      );
      expect(find.textContaining('OUTRA LOJA LTDA'), findsOneWidget);
      await _save(tester);
      expect(server.bodiesOf('/invoices').single['recipient'], {
        'customerId': 'cu9',
      });
    });

    testWidgets('missing address and e-mail: asked, CEP finds the city', (
      tester,
    ) async {
      final lookup = FiscalLookupService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'logradouro': 'Rua Exemplo',
              'bairro': 'Centro',
              'localidade': 'Cidade Exemplo',
              'uf': 'SC',
              'ibge': '4200000',
            }),
            200,
          ),
        ),
      );
      final server = _Server((path, body) {
        if (path == '/invoices/preview') {
          return _preview(
            recipient: {
              'customerId': 'cu1',
              'name': 'Revenda Exemplo',
              'legalName': 'REVENDA EXEMPLO LTDA',
              'taxId': '00000000000272',
              'viaInvoiceRecipient': false,
            },
            missing: ['address', 'email'],
          );
        }
        return _invoiceJson('authorized');
      });
      final results = await _openSheet(tester, server, lookup: lookup);

      expect(
        find.text(
          'Faltam dados de REVENDA EXEMPLO LTDA para a nota. '
          'Ficam salvos no cadastro.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Falta o endereço com CEP de quem recebe a nota.'),
        findsOneWidget,
      );
      Future<void> type(String key, String text) async {
        await tester.enterText(
          find.descendant(
            of: find.byKey(Key('nfseDirectIssueField_$key')),
            matching: find.byType(CupertinoTextField),
          ),
          text,
        );
        await tester.pumpAndSettle();
      }

      await type('postalCode', '88000-000');
      await type('number', '10');
      expect(
        find.text('Falta o e-mail de quem recebe a nota.'),
        findsOneWidget,
      );
      await type('email', 'nota@example.com');
      await _save(tester);

      final recipient =
          server.bodiesOf('/invoices').single['recipient']
              as Map<String, dynamic>;
      expect(recipient['email'], 'nota@example.com');
      expect(recipient['address'], {
        'postalCode': '88000000',
        'street': 'Rua Exemplo',
        'number': '10',
        'district': 'Centro',
        'cityCode': '4200000',
        'cityName': 'Cidade Exemplo',
        'state': 'SC',
      });
      expect(results.single, isNotNull);
    });

    testWidgets('CNPJ that cannot issue: ✓ stays gray and says why', (
      tester,
    ) async {
      final server = _Server((path, body) {
        if (path == '/invoices/preview') {
          return _preview(
            emitter: _emitterJson(
              'e1',
              'OFICINA EXEMPLO LTDA',
              problem: 'certificateExpired',
            ),
          );
        }
        return _invoiceJson('authorized');
      });
      await _openSheet(tester, server);
      expect(
        find.text('Este CNPJ não emite agora: Certificado vencido'),
        findsOneWidget,
      );
      await _save(tester);
      expect(server.bodiesOf('/invoices'), isEmpty);
    });

    testWidgets('refused for the recipient: plain words, fields open', (
      tester,
    ) async {
      final server = _Server((path, body) {
        if (path == '/invoices/preview') return _preview();
        return _error(
          'NFSE_REFUSED',
          details: {
            'refusal': {
              'code': 'E0200',
              'group': 'customerData',
              'message': {
                'pt': 'O endereço do cliente está incompleto.',
                'en': 'Incomplete address.',
                'es': 'Dirección incompleta.',
              },
              'govText': 'raw',
            },
          },
        );
      });
      final results = await _openSheet(tester, server);
      await _save(tester);

      expect(
        find.textContaining('O endereço do cliente está incompleto.'),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('nfseDirectIssueField_postalCode')),
        findsOneWidget,
      );
      expect(results, isEmpty);
    });

    testWidgets('refused for the setup, user cannot set up: says who can', (
      tester,
    ) async {
      final server = _Server((path, body) {
        if (path == '/invoices/preview') return _preview();
        return _error(
          'NFSE_REFUSED',
          details: {
            'refusal': {
              'code': 'E0312',
              'group': 'emitterSetup',
              'message': {'pt': 'O serviço da nota não é aceito pela cidade.'},
            },
          },
        );
      });
      await _openSheet(tester, server, canSetUp: false);
      await _save(tester);
      expect(
        find.textContaining('O serviço da nota não é aceito pela cidade.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nfseDirectIssueAlertAction')), findsNothing);
    });

    testWidgets('government did not answer: plain sentence', (tester) async {
      final server = _Server((path, body) {
        if (path == '/invoices/preview') return _preview();
        return _error('SEFIN_UNAVAILABLE', status: 503);
      });
      await _openSheet(tester, server);
      await _save(tester);
      expect(
        find.text('O governo não respondeu. Tente de novo em alguns minutos.'),
        findsOneWidget,
      );
    });
  });

  group('NfseInvoiceScreen (direct)', () {
    Future<(_Server, List<String>)> pumpInvoice(
      WidgetTester tester,
      String status, {
      Map<String, dynamic> extra = const {},
      Object? Function(String path, Map<String, dynamic> body)? handler,
      DateTime? now,
    }) async {
      final opened = <String>[];
      final server = _Server(handler ?? (path, body) => null);
      await _pump(
        tester,
        NfseInvoiceScreen(
          invoice: NfseInvoice.fromJson(
            _invoiceJson(status, extra: extra),
            id: 'inv1',
          ),
          invoiceStream: const Stream.empty(),
          directService: server.api,
          storageUrl: (path) async => 'https://storage/$path',
          openUrl: (url) async => opened.add(url),
          now: now,
        ),
      );
      return (server, opened);
    }

    testWidgets('issued: emitter, recipient, key; PDF made by the server', (
      tester,
    ) async {
      final (server, opened) = await pumpInvoice(
        tester,
        'authorized',
        extra: {
          'number': '29',
          'accessKey': '42000002200000000000191000000000002926110000000001',
          'xmlPath': 'tenants/c1/invoices/inv1/nfse.xml',
        },
        handler: (path, body) => path == '/invoices/inv1/pdf'
            ? {'pdfPath': 'tenants/c1/invoices/inv1/danfse.pdf'}
            : null,
      );
      expect(find.text('Emitida · nº 29'), findsWidgets);
      expect(find.text('Emitida por'), findsOneWidget);
      expect(find.textContaining('OFICINA EXEMPLO LTDA'), findsOneWidget);
      expect(find.textContaining('REVENDA EXEMPLO LTDA'), findsOneWidget);
      expect(find.text('Chave de acesso'), findsOneWidget);
      expect(find.byKey(const Key('nfseInvoiceExternal')), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('nfseOpenPdf')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nfseOpenPdf')));
      await tester.pumpAndSettle();
      expect(server.calls.single.$1, '/invoices/inv1/pdf');
      expect(opened, ['https://storage/tenants/c1/invoices/inv1/danfse.pdf']);

      await tester.ensureVisible(find.byKey(const Key('nfseOpenXml')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nfseOpenXml')));
      await tester.pumpAndSettle();
      expect(opened.last, 'https://storage/tenants/c1/invoices/inv1/nfse.xml');
    });

    testWidgets('made outside PraticOS: says so', (tester) async {
      await pumpInvoice(tester, 'authorized', extra: {'source': 'external'});
      expect(find.text('Emitida fora do PraticOS'), findsOneWidget);
    });

    testWidgets('"Cancelar nota" asks the reason and sends it', (tester) async {
      final (server, _) = await pumpInvoice(
        tester,
        'authorized',
        handler: (path, body) => _invoiceJson(
          'canceled',
          extra: {'cancelReason': 'serviceNotProvided'},
        ),
      );
      await tester.tap(find.byKey(const Key('nfseMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar nota').last);
      await tester.pumpAndSettle();
      expect(find.text('Erro na nota'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('nfseCancelReason_serviceNotProvided')),
      );
      await tester.pumpAndSettle();

      expect(server.calls.single.$1, '/invoices/inv1/cancel');
      expect(server.calls.single.$2, {'reason': 'serviceNotProvided'});
      expect(find.text('Cancelada'), findsWidgets);
      expect(find.text('Serviço não prestado'), findsOneWidget);
    });

    testWidgets('the city refuses the cancellation: points to the portal', (
      tester,
    ) async {
      await pumpInvoice(
        tester,
        'authorized',
        handler: (path, body) =>
            _error('CANCEL_REFUSED', details: {'usePortal': true}),
      );
      await tester.tap(find.byKey(const Key('nfseMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar nota').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nfseCancelReason_issueError')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cancele no portal do governo'),
        findsOneWidget,
      );
    });

    testWidgets('refused: the government\'s reason in plain words', (
      tester,
    ) async {
      await pumpInvoice(
        tester,
        'error',
        extra: {
          'errorCode': 'E0312',
          'refusal': {
            'code': 'E0312',
            'group': 'emitterSetup',
            'message': {'pt': 'O serviço da nota não é aceito pela cidade.'},
          },
        },
      );
      expect(
        find.text('O serviço da nota não é aceito pela cidade.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nfseReissue')), findsOneWidget);
    });

    testWidgets('no answer for minutes: "Conferir agora" asks again', (
      tester,
    ) async {
      final (server, _) = await pumpInvoice(
        tester,
        'creating',
        now: DateTime(2026, 11, 5, 10, 10),
        handler: (path, body) =>
            _invoiceJson('authorized', extra: {'number': '30'}),
      );
      await tester.tap(find.byKey(const Key('nfseReconcile')));
      await tester.pumpAndSettle();
      expect(server.calls.single.$1, '/invoices/inv1/reconcile');
      expect(find.text('Emitida · nº 30'), findsWidgets);
    });
  });

  group('direct notas on the list and the order', () {
    NfseInvoice nota(
      String id,
      String emitterId,
      String emitterName, {
      String source = 'praticos',
    }) => NfseInvoice.fromJson(
      _invoiceJson(
        'authorized',
        extra: {
          'number': id,
          'source': source,
          'orderIds': ['o$id'],
          'orders': [
            {'orderId': 'o$id', 'orderNumber': 100, 'value': 270},
          ],
          'emitter': {'id': emitterId, 'legalName': emitterName},
          'customer': {'id': 'c$id', 'name': 'Cliente $id'},
        },
      ),
      id: id,
    );

    NfseController controller(
      List<NfseInvoice> invoices, {
      List<FiscalEmitter> emitters = const [],
    }) => NfseController(
      canIssue: true,
      settingsStream: Stream.value(PaymentSettings(nfseDirectEnabled: true)),
      invoicesOf: (_) => Stream.value(invoices),
      emittersStream: Stream.value(emitters),
    );

    test(
      'direct on: notas on without Asaas; ready once there is a CNPJ',
      () async {
        final none = controller(const [])..watchOrder('o1');
        await pumpEventQueue();
        expect(none.enabled, isTrue);
        expect(none.direct, isTrue);
        expect(none.ready, isFalse);

        final one = controller(
          const [],
          emitters: [FiscalEmitter(legalName: 'OFICINA')..id = 'e1'],
        )..watchOrder('o1');
        await pumpEventQueue();
        expect(one.ready, isTrue);
        expect(one.emitters, hasLength(1));
      },
    );

    testWidgets('list: "Emitida fora do PraticOS" and the CNPJ filter', (
      tester,
    ) async {
      final invoices = [
        nota('1', 'e1', 'OFICINA EXEMPLO LTDA'),
        nota('2', 'e2', 'FULANO MEI', source: 'external'),
      ];
      await _pump(
        tester,
        NfseListScreen(
          month: DateTime(2026, 11),
          today: DateTime(2026, 11, 20),
          nfse: controller(invoices),
          canSetUp: false,
        ),
      );
      expect(find.textContaining('Emitida fora do PraticOS'), findsOneWidget);
      expect(find.text('Cliente 1'), findsOneWidget);
      expect(find.text('Cliente 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nfseListEmitterFilter')));
      await tester.pumpAndSettle();
      expect(find.text('Notas de qual CNPJ?'), findsWidgets);
      await tester.tap(find.byKey(const Key('nfseListEmitter_e2')));
      await tester.pumpAndSettle();

      expect(find.text('Cliente 1'), findsNothing);
      expect(find.text('Cliente 2'), findsOneWidget);
    });

    testWidgets('one CNPJ only: no filter', (tester) async {
      await _pump(
        tester,
        NfseListScreen(
          month: DateTime(2026, 11),
          today: DateTime(2026, 11, 20),
          nfse: controller([nota('1', 'e1', 'OFICINA EXEMPLO LTDA')]),
          canSetUp: false,
        ),
      );
      expect(find.byKey(const Key('nfseListEmitterFilter')), findsNothing);
    });
  });
}
