import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/tenant/fiscal_emitter_repository.dart';
import 'package:praticos/screens/nfse/direct/certificate_upload_sheet.dart';
import 'package:praticos/screens/nfse/direct/fiscal_emitter_screen.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_setup_screen.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';

/// A fake nfseApi: records the calls, answers [handler].
class _Server {
  _Server([this.handler]);

  final Object? Function(String method, String path, Map<String, dynamic> body)?
  handler;
  final calls = <(String, String, Map<String, dynamic>)>[];

  NfseDirectApiService get api => NfseDirectApiService.withClient(
    MockClient((request) async {
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      final path = request.url.path.replaceFirst('/nfseApi', '');
      calls.add((request.method, path, body));
      final answer = handler?.call(request.method, path, body);
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

http.Response _error(String code, {int status = 400}) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': 'raw'},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

final _now = DateTime(2026, 11, 5, 12);

FiscalEmitter _emitter({
  String id = 'e1',
  String name = 'OFICINA EXEMPLO LTDA',
  FiscalRegime regime = FiscalRegime.simples,
  DateTime? notAfter,
  FiscalCertificateStatus status = FiscalCertificateStatus.active,
  FiscalEmitterTotals? totals,
}) => FiscalEmitter(
  taxId: '00000000000191',
  legalName: name,
  regime: regime,
  cityName: 'Cidade Exemplo',
  enabledInCity: true,
  municipalRegistration: '12345',
  service: FiscalEmitterService(
    nationalCode: '140101',
    name: 'Revisão de veículos',
    issRate: 2.5,
  ),
  certificate: FiscalEmitterCertificate(
    holderName: name,
    notAfter: notAfter ?? DateTime(2027, 3, 12),
    uploadedAt: DateTime(2026, 11, 5),
    uploadedBy: UserAggr()..name = "Rafael",
    status: status,
  ),
  totals: totals,
)..id = id;

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

Future<PickedCertificate?> _file() async =>
    const PickedCertificate('oficina.pfx', [1, 2, 3]);

void main() {
  setUp(() => FormatService().setLocale('pt_BR'));

  group('certificate state', () {
    test('valid, expiring, expired and missing', () {
      expect(certificateState(_emitter(), now: _now), CertificateState.valid);
      expect(
        certificateState(_emitter(notAfter: DateTime(2026, 11, 12)), now: _now),
        CertificateState.expiring,
      );
      expect(
        certificateDaysLeft(
          _emitter(notAfter: DateTime(2026, 11, 12)),
          now: _now,
        ),
        7,
      );
      expect(
        certificateState(_emitter(notAfter: DateTime(2026, 11, 1)), now: _now),
        CertificateState.expired,
      );
      expect(
        certificateState(
          _emitter(status: FiscalCertificateStatus.deleted),
          now: _now,
        ),
        CertificateState.missing,
      );
    });

    test('the nfseApi lives next to the api function', () {
      expect(
        resolveNfseApiBaseUrl(
          'https://southamerica-east1-praticos.cloudfunctions.net/api',
        ),
        'https://southamerica-east1-praticos.cloudfunctions.net/nfseApi',
      );
    });
  });

  group('NfseDirectSetupScreen', () {
    testWidgets('without a CNPJ: one blue button adds the first', (
      tester,
    ) async {
      final server = _Server();
      await _pump(
        tester,
        NfseDirectSetupScreen(
          emitters: Stream.value(const []),
          settings: Stream.value(const NfseDirectSettings()),
          service: server.api,
          pickFile: _file,
          now: _now,
        ),
      );
      expect(
        find.text('Envie o certificado digital para emitir notas'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nfseDirectAdd')), findsNothing);
      expect(find.byKey(const Key('nfseDirectAutoIssueRow')), findsNothing);

      await tester.tap(find.byKey(const Key('nfseDirectAddFirst')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('certificateUploadSheet')), findsOneWidget);
    });

    testWidgets('lists the CNPJs with regime, certificate and the default', (
      tester,
    ) async {
      await _pump(
        tester,
        NfseDirectSetupScreen(
          emitters: Stream.value([
            _emitter(),
            _emitter(
              id: 'e2',
              name: 'JOAO MEI',
              regime: FiscalRegime.mei,
              notAfter: DateTime(2026, 11, 12),
            ),
            _emitter(
              id: 'e3',
              name: 'MARIA MEI',
              regime: FiscalRegime.mei,
              notAfter: DateTime(2026, 10, 1),
            ),
          ]),
          settings: Stream.value(
            const NfseDirectSettings(defaultEmitterId: 'e1'),
          ),
          service: _Server().api,
          now: _now,
        ),
      );
      expect(
        find.text('Notas saem pelo CNPJ que você escolher na hora'),
        findsOneWidget,
      );
      expect(find.text('Seus CNPJs'), findsOneWidget);
      expect(find.text('Certificado vale até 12/03/2027'), findsOneWidget);
      expect(find.text('Certificado vence em 7 dias'), findsOneWidget);
      expect(find.text('Certificado vencido'), findsOneWidget);
      expect(find.text('MEI'), findsNWidgets(2));
      expect(find.byKey(const Key('nfseDirectAddFirst')), findsNothing);
      expect(find.byKey(const Key('nfseDirectAdd')), findsOneWidget);
      // The ✓ marks only the default.
      AppListRow row(String id) => tester.widget<AppListRow>(
        find.byKey(ValueKey('nfseDirectEmitter_$id')),
      );
      expect(row('e1').selected, isTrue);
      expect(row('e2').selected, isFalse);
    });

    testWidgets('"Emitir sozinha" opens the picker and saves the choice', (
      tester,
    ) async {
      final server = _Server();
      await _pump(
        tester,
        NfseDirectSetupScreen(
          emitters: Stream.value([_emitter()]),
          settings: Stream.value(const NfseDirectSettings()),
          service: server.api,
          now: _now,
        ),
      );
      expect(find.text('Nunca'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nfseDirectAutoIssueRow')));
      await tester.pumpAndSettle();
      expect(find.text('Quando a nota sai sozinha?'), findsWidgets);
      await tester.tap(
        find.byKey(const Key('nfseDirectAutoIssue_selectedCustomers')),
      );
      await tester.pumpAndSettle();
      expect(server.calls.single.$1, 'PUT');
      expect(server.calls.single.$2, '/v1/app/nfse/setup/settings');
      expect(server.calls.single.$3, {'autoIssue': 'selectedCustomers'});
    });

    testWidgets('"Gerente pode emitir" saves the owner\'s choice', (
      tester,
    ) async {
      final server = _Server();
      await _pump(
        tester,
        NfseDirectSetupScreen(
          emitters: Stream.value([_emitter()]),
          settings: Stream.value(const NfseDirectSettings()),
          service: server.api,
          now: _now,
        ),
      );
      expect(find.text('Gerente pode emitir notas'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('nfseDirectManagerCanIssue')),
          matching: find.byType(CupertinoSwitch),
        ),
      );
      await tester.pumpAndSettle();
      expect(server.calls.single.$3, {'managerCanIssue': false});
    });

    testWidgets(
      'an admin who is not the owner is told only the owner changes it',
      (tester) async {
        final server = _Server((_, _, _) => _error('FORBIDDEN', status: 403));
        await _pump(
          tester,
          NfseDirectSetupScreen(
            emitters: Stream.value([_emitter()]),
            settings: Stream.value(
              NfseDirectSettings.fromJson({'managerCanIssue': false}),
            ),
            service: server.api,
            now: _now,
          ),
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('nfseDirectManagerCanIssue')),
            matching: find.byType(CupertinoSwitch),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(server.calls.single.$3, {'managerCanIssue': true});
        expect(find.text('Só o dono da conta muda isso.'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      },
    );
  });

  group('CertificateUploadSheet', () {
    Future<List<bool?>> open(
      WidgetTester tester,
      NfseDirectApiService api, {
      String? emitterId,
    }) async {
      final results = <bool?>[];
      await _pump(
        tester,
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('open'),
                onPressed: () async => results.add(
                  await CertificateUploadSheet.show(
                    context,
                    emitterId: emitterId,
                    legalName: 'OFICINA EXEMPLO LTDA',
                    service: api,
                    pickFile: _file,
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

    testWidgets('the ✓ waits for file, password and the terms, then sends', (
      tester,
    ) async {
      final server = _Server((_, _, _) => {'emitterId': 'e9'});
      final results = await open(tester, server.api);
      expect(find.text('Adicionar CNPJ'), findsOneWidget);
      expect(find.byKey(const ValueKey('form_sheet_missing')), findsOneWidget);

      await tester.tap(find.byKey(const Key('certificatePickFile')));
      await tester.pumpAndSettle();
      expect(find.text('oficina.pfx'), findsOneWidget);
      // Still missing the password.
      expect(find.byKey(const ValueKey('form_sheet_missing')), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('certificatePassword')),
          matching: find.byType(CupertinoTextField),
        ),
        'segredo',
      );
      await tester.pumpAndSettle();
      final field = tester.widget<CupertinoTextField>(
        find.descendant(
          of: find.byKey(const Key('certificatePassword')),
          matching: find.byType(CupertinoTextField),
        ),
      );
      expect(field.obscureText, isTrue);
      // Still missing the explicit acceptance of the terms.
      expect(find.byKey(const ValueKey('form_sheet_missing')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('certificateAcceptTermsSwitch')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('certificateUploadSheet')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('certificateAcceptTermsSwitch')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('certificateAcceptTermsSwitch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('form_sheet_missing')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(server.calls.single.$1, 'POST');
      expect(server.calls.single.$2, '/v1/app/nfse/emitters/certificate');
      expect(server.calls.single.$3, {
        'pfxBase64': base64Encode([1, 2, 3]),
        'password': 'segredo',
        'termsVersion': nfseCertificateTermsVersion,
      });
      expect(results, [true]);
    });

    testWidgets('a wrong password shows a plain sentence and keeps the sheet', (
      tester,
    ) async {
      final server = _Server((_, _, _) => _error('CERT_WRONG_PASSWORD'));
      final results = await open(tester, server.api, emitterId: 'e1');
      expect(find.text('Trocar certificado'), findsOneWidget);
      await tester.tap(find.byKey(const Key('certificatePickFile')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('certificatePassword')),
          matching: find.byType(CupertinoTextField),
        ),
        'errada',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('certificateAcceptTermsSwitch')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('certificateUploadSheet')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('certificateAcceptTermsSwitch')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('certificateAcceptTermsSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();

      expect(server.calls.single.$1, 'PUT');
      expect(server.calls.single.$2, '/v1/app/nfse/emitters/e1/certificate');
      expect(
        find.text('Senha errada. Confira com quem mandou o certificado.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('certificateUploadSheet')), findsOneWidget);
      expect(results, isEmpty);
    });
  });

  test('the terms link opens the page in the app language', () {
    expect(
      nfseCertificateTermsUrlFor('pt'),
      'https://praticos.app/termo-certificado.html',
    );
    expect(
      nfseCertificateTermsUrlFor('en'),
      'https://praticos.app/termo-certificado-en.html',
    );
    expect(
      nfseCertificateTermsUrlFor('es'),
      'https://praticos.app/termo-certificado-es.html',
    );
  });

  group('FiscalEmitterScreen', () {
    Future<_Server> pumpEmitter(
      WidgetTester tester,
      FiscalEmitter emitter, {
      String? defaultId,
    }) async {
      final server = _Server();
      await _pump(
        tester,
        FiscalEmitterScreen(
          emitterId: emitter.id!,
          emitter: Stream.value(emitter),
          settings: Stream.value(
            NfseDirectSettings(defaultEmitterId: defaultId),
          ),
          service: server.api,
          pickFile: _file,
          now: _now,
        ),
      );
      return server;
    }

    testWidgets('shows the totals, the lines and the certificate', (
      tester,
    ) async {
      await pumpEmitter(
        tester,
        _emitter(
          totals: FiscalEmitterTotals(
            year: 2026,
            yearValue: 214000,
            month: 11,
            monthValue: 31000,
          ),
        ),
        defaultId: 'e1',
      );
      expect(find.text('OFICINA EXEMPLO LTDA'), findsWidgets);
      expect(
        find.textContaining('00.000.000/0001-91 · Simples · Padrão'),
        findsOneWidget,
      );
      expect(find.textContaining('Notas este ano: R\$'), findsOneWidget);
      expect(find.byKey(const Key('emitterMeiLimit')), findsNothing);
      expect(find.text('Revisão de veículos'), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);
      expect(
        find.text('Vence em 12/03/2027 · enviado por Rafael em 05/11/2026'),
        findsOneWidget,
      );
    });

    testWidgets('a MEI shows how far from the limit', (tester) async {
      await pumpEmitter(
        tester,
        _emitter(
          regime: FiscalRegime.mei,
          totals: FiscalEmitterTotals(
            year: 2026,
            yearValue: 52000,
            month: 11,
            monthValue: 4000,
          ),
        ),
      );
      expect(find.byKey(const Key('emitterMeiLimit')), findsOneWidget);
      expect(find.textContaining('Faturou R\$'), findsOneWidget);
    });

    testWidgets('an expired certificate is red', (tester) async {
      await pumpEmitter(tester, _emitter(notAfter: DateTime(2026, 10, 1)));
      expect(find.text('Certificado vencido'), findsOneWidget);
      expect(find.textContaining('Venceu em 01/10/2026'), findsOneWidget);
    });

    testWidgets('"…" uses as default and deletes after confirming', (
      tester,
    ) async {
      final server = await pumpEmitter(tester, _emitter());
      await tester.tap(find.byKey(const Key('emitterMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar como padrão'));
      await tester.pumpAndSettle();
      expect(server.calls.last.$1, 'PUT');
      expect(server.calls.last.$2, '/v1/app/nfse/setup/settings');
      expect(server.calls.last.$3, {'defaultEmitterId': 'e1'});

      await tester.tap(find.byKey(const Key('emitterMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar certificado'));
      await tester.pumpAndSettle();
      expect(find.text('Apagar o certificado?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('emitterDeleteConfirm')));
      await tester.pumpAndSettle();
      expect(server.calls.last.$1, 'DELETE');
      expect(server.calls.last.$2, '/v1/app/nfse/emitters/e1/certificate');
    });

    testWidgets('the service line opens its editor and saves', (tester) async {
      final server = await pumpEmitter(tester, _emitter());
      await tester.tap(find.byKey(const Key('emitterServiceRow')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('emitterServiceCode')),
          matching: find.byType(CupertinoTextField),
        ),
        '140102',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(server.calls.single.$1, 'PATCH');
      expect(server.calls.single.$2, '/v1/app/nfse/setup/emitters/e1');
      expect(server.calls.single.$3['service'], {
        'nationalCode': '140102',
        'name': 'Revisão de veículos',
        'issRate': 2.5,
      });
      expect(find.byKey(const Key('emitterServiceSheet')), findsNothing);
    });
  });
}
