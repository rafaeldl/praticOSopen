import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/models/nfse_import.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/tenant/fiscal_emitter_repository.dart';
import 'package:praticos/screens/nfse/direct/fiscal_emitter_screen.dart';
import 'package:praticos/screens/nfse/direct/nfse_import_screen.dart';
import 'package:praticos/screens/nfse/direct/nfse_order_link.dart';
import 'package:praticos/screens/nfse/nfse_invoice_screen.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';

// Invented companies and numbers only.
const _revenda = '00000000000272';
const _nova = '00000000000434';

/// A fake nfseApi: records the calls, answers [handler].
class _Server {
  _Server(this.handler);

  final Object? Function(String method, String path, Map<String, dynamic> body)
  handler;
  final calls = <(String, String, Map<String, dynamic>)>[];

  NfseDirectApiService get api => NfseDirectApiService.withClient(
    MockClient((request) async {
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      final path = request.url.path.replaceFirst('/nfseApi', '');
      calls.add((request.method, path, body));
      final answer = handler(request.method, path, body);
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

http.Response _error(String code, {int status = 409}) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': 'raw'},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _proposal() => {
  'counts': {
    'notas': 9,
    'customers': 3,
    'newCustomers': 0,
    'completedCustomers': 2,
    'ask': 1,
    'linked': 7,
    'historyOnly': 2,
  },
  'emitter': {
    'view': {
      'legalName': 'OFICINA EXEMPLO LTDA',
      'regime': 'simples',
      'municipalRegistration': '12345',
      'service': {
        'nationalCode': '140101',
        'name': 'Lubrificação, limpeza e revisão',
        'issRate': 2.5,
      },
      'dpsSeries': '10',
    },
  },
  'groups': [
    {
      'key': _revenda,
      'taxId': _revenda,
      'legalName': 'REVENDA EXEMPLO LTDA',
      'action': 'complete',
      'customerId': 'norte',
      'customerName': 'Loja Exemplo Norte',
      'notas': 6,
      'stores': [
        {'customerId': 'sul', 'customerName': 'Loja Exemplo Sul', 'orders': 2},
      ],
      'links': [{}, {}, {}, {}, {}, {}],
    },
    {
      'key': _nova,
      'taxId': _nova,
      'legalName': 'NOVA EMPRESA EXEMPLO',
      'action': 'ask',
      'customerId': 'fulano',
      'customerName': 'Nova Empresa',
      'notas': 2,
      'stores': [],
      'links': [],
    },
  ],
  'autoIssue': [
    {'customerId': 'norte', 'customerName': 'Loja Exemplo Norte'},
  ],
};

Map<String, dynamic> _batch(String status, {int read = 0}) => {
  'id': 'b1',
  'emitterId': 'e1',
  'status': status,
  'read': {'documents': read},
  if (status == 'proposed') 'proposal': _proposal(),
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

Map<String, dynamic> _invoiceJson({
  String source = 'external',
  List<String> orderIds = const [],
}) => {
  'status': 'authorized',
  'provider': 'direct',
  'source': source,
  'value': 105.0,
  'effectiveDate': '2026-10-05',
  'number': '5',
  'orderIds': orderIds,
  'orders': [
    for (final id in orderIds)
      {'orderId': id, 'orderNumber': 105, 'value': 105},
  ],
  'recipient': {'taxId': _revenda, 'legalName': 'REVENDA EXEMPLO LTDA'},
};

void main() {
  setUp(() => FormatService().setLocale('pt_BR'));

  group('NfseImportBatch', () {
    test('reads the proposal and offers undo for 30 days', () {
      final batch = NfseImportBatch.fromJson({
        ..._batch('proposed'),
        'status': 'applied',
        'expiresAt': '2026-12-05T13:00:00.000Z',
      });
      expect(batch.proposal!.toAsk.single.key, _nova);
      expect(batch.proposal!.withStores.single.stores.single.customerId, 'sul');
      expect(batch.proposal!.groups.first.links, 6);
      expect(batch.proposal!.emitter.service!.issRate, 2.5);
      expect(batch.canUndo(now: DateTime.utc(2026, 12, 1)), isTrue);
      expect(batch.canUndo(now: DateTime.utc(2026, 12, 6)), isFalse);
    });
  });

  group('NfseImportScreen', () {
    testWidgets(
      'reads until the proposal, shows the summary and imports with the answers',
      (tester) async {
        final server = _Server((method, path, body) {
          if (path == '/v1/app/nfse/imports')
            return _batch('reading', read: 50);
          if (path.endsWith('/continue')) return _batch('proposed', read: 120);
          if (path.endsWith('/apply'))
            return {..._batch('proposed'), 'status': 'applied'};
          return null;
        });
        await _pump(
          tester,
          NfseImportScreen(emitterId: 'e1', service: server.api),
        );

        expect(server.calls.map((c) => c.$2), [
          '/v1/app/nfse/imports',
          '/v1/app/nfse/imports/b1/continue',
        ]);
        expect(server.calls.first.$3, {'emitterId': 'e1'});
        expect(
          find.text(
            'Achamos 9 notas para 3 clientes. Vamos preencher seus clientes e o serviço da nota.',
          ),
          findsOneWidget,
        );
        Future<void> show(Finder finder) => tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('OFICINA EXEMPLO LTDA'), findsOneWidget);
        await show(find.byKey(const Key('nfseImportSeries')));
        expect(find.text('10'), findsOneWidget);
        // "Este é o mesmo cliente?" → Sim.
        await show(find.byKey(const Key('nfseImportAsk-$_nova')));
        await tester.tap(find.byKey(const Key('nfseImportAsk-$_nova')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nfseImportAnswerSame')));
        await tester.pumpAndSettle();
        expect(find.text('Sim'), findsOneWidget);

        // "Emitir sozinha" starts off; the owner turns it on.
        await show(find.text('Loja Exemplo Sul'));
        expect(
          find.text('Nota fiscal para Loja Exemplo Norte'),
          findsOneWidget,
        );
        await show(find.byKey(const Key('nfseImportAuto-norte')));
        final toggle = find.descendant(
          of: find.byKey(const Key('nfseImportAuto-norte')),
          matching: find.byType(CupertinoSwitch),
        );
        expect(tester.widget<CupertinoSwitch>(toggle).value, isFalse);
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        await show(find.text('2 só no histórico'));
        expect(find.text('7 ligadas às suas OS'), findsOneWidget);

        await tester.tap(find.byKey(const Key('nfseImportApply')));
        await tester.pumpAndSettle();
        expect(server.calls.last.$2, '/v1/app/nfse/imports/b1/apply');
        expect(server.calls.last.$3, {
          'answers': {
            'sameCustomer': {_nova: true},
            'autoIssueCustomerIds': ['norte'],
          },
        });
      },
    );

    testWidgets('a failure shows the error and tries again', (tester) async {
      var fail = true;
      final server = _Server((method, path, body) {
        if (fail) return _error('SEFIN_UNAVAILABLE', status: 503);
        return _batch('proposed');
      });
      await _pump(
        tester,
        NfseImportScreen(emitterId: 'e1', service: server.api),
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nfseImportApply')), findsOneWidget);
    });
  });

  group('Ligar a uma OS', () {
    test('only direct notas: link without order, unlink only external', () {
      NfseInvoice inv(Map<String, dynamic> json) =>
          NfseInvoice.fromJson(json, id: 'i');
      expect(canLinkNfseToOrder(inv(_invoiceJson())), isTrue);
      expect(canLinkNfseToOrder(inv(_invoiceJson(orderIds: ['o5']))), isFalse);
      expect(
        canLinkNfseToOrder(inv({..._invoiceJson(), 'provider': null})),
        isFalse,
      );
      expect(
        canUnlinkNfseFromOrder(inv(_invoiceJson(orderIds: ['o5']))),
        isTrue,
      );
      expect(
        canUnlinkNfseFromOrder(
          inv(_invoiceJson(source: 'praticos', orderIds: ['o5'])),
        ),
        isFalse,
      );
    });

    testWidgets('picks the order (of the customer first) and links', (
      tester,
    ) async {
      final server = _Server((method, path, body) {
        if (path.endsWith('/candidates')) {
          return {
            'orders': [
              {
                'id': 'o5',
                'number': 105,
                'customerName': 'Loja Exemplo Sul',
                'value': 105,
                'date': '2026-10-05',
                'sameCustomer': true,
              },
              {
                'id': 'o9',
                'number': 109,
                'customerName': 'Outra',
                'value': 80,
                'hasNota': true,
              },
            ],
          };
        }
        return null;
      });
      await _pump(
        tester,
        NfseInvoiceScreen(
          invoice: NfseInvoice.fromJson(_invoiceJson(), id: 'inv1'),
          invoiceStream: const Stream.empty(),
          directService: server.api,
        ),
      );
      await tester.tap(find.byKey(const Key('nfseLinkOrder')));
      await tester.pumpAndSettle();
      expect(find.text('Qual OS é desta nota?'), findsWidgets);
      expect(find.text('Do cliente'), findsOneWidget);
      expect(find.textContaining('Já tem nota'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nfseLinkCandidate-o5')));
      await tester.pumpAndSettle();
      expect(server.calls.last.$2, '/v1/app/nfse/links/invoices/inv1/link');
      expect(server.calls.last.$3, {'orderId': 'o5'});
    });

    testWidgets('"Desligar da OS" in the "…" of an external nota', (
      tester,
    ) async {
      final server = _Server((method, path, body) => null);
      await _pump(
        tester,
        NfseInvoiceScreen(
          invoice: NfseInvoice.fromJson(
            _invoiceJson(orderIds: ['o5']),
            id: 'inv1',
          ),
          invoiceStream: const Stream.empty(),
          directService: server.api,
        ),
      );
      expect(find.byKey(const Key('nfseLinkOrder')), findsNothing);
      await tester.tap(find.byKey(const Key('nfseMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desligar da OS'));
      await tester.pumpAndSettle();
      expect(find.text('Desligar a nota da OS 105?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nfseUnlinkConfirm')));
      await tester.pumpAndSettle();
      expect(server.calls.last.$2, '/v1/app/nfse/links/invoices/inv1/unlink');
    });
  });

  group('emitter "…"', () {
    FiscalEmitter emitter() => FiscalEmitter(
      taxId: '00000000000191',
      legalName: 'OFICINA EXEMPLO LTDA',
      regime: FiscalRegime.simples,
      enabledInCity: true,
      importBatchId: 'b1',
      certificate: FiscalEmitterCertificate(
        holderName: 'OFICINA EXEMPLO LTDA',
        notAfter: DateTime(2027, 3, 12),
        uploadedAt: DateTime(2026, 11, 5),
        uploadedBy: UserAggr()..name = 'Dono',
        status: FiscalCertificateStatus.active,
      ),
    )..id = 'e1';

    testWidgets('"Desfazer importação" while the import can be undone', (
      tester,
    ) async {
      final server = _Server(
        (method, path, body) => {..._batch('proposed'), 'status': 'undone'},
      );
      await _pump(
        tester,
        FiscalEmitterScreen(
          emitterId: 'e1',
          emitter: Stream.value(emitter()),
          settings: Stream.value(const NfseDirectSettings()),
          service: server.api,
          now: DateTime(2026, 11, 10),
          importBatchOf: (_) => Stream.value(
            NfseImportBatch.fromJson({
              ..._batch('proposed'),
              'status': 'applied',
              'expiresAt': '2026-12-05T13:00:00.000Z',
            }),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('emitterMenu')));
      await tester.pumpAndSettle();
      expect(find.text('Importar notas do governo'), findsOneWidget);
      await tester.tap(find.text('Desfazer importação'));
      await tester.pumpAndSettle();
      expect(find.text('Desfazer a importação?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('emitterUndoImportConfirm')));
      await tester.pumpAndSettle();
      expect(server.calls.last.$2, '/v1/app/nfse/imports/b1/undo');
    });

    testWidgets('no undo after 30 days', (tester) async {
      final server = _Server((method, path, body) => null);
      await _pump(
        tester,
        FiscalEmitterScreen(
          emitterId: 'e1',
          emitter: Stream.value(emitter()),
          settings: Stream.value(const NfseDirectSettings()),
          service: server.api,
          now: DateTime(2026, 12, 10),
          importBatchOf: (_) => Stream.value(
            NfseImportBatch.fromJson({
              ..._batch('proposed'),
              'status': 'applied',
              'expiresAt': '2026-12-05T13:00:00.000Z',
            }),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('emitterMenu')));
      await tester.pumpAndSettle();
      expect(find.text('Desfazer importação'), findsNothing);
    });
  });
}
