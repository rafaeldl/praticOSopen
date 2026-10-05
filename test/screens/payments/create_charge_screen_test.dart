import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/screens/payments/create_charge_screen.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';

void main() {
  final l10n = AppLocalizationsPt();
  final format = FormatService();

  Order order({String? taxId, bool withCustomer = true}) => Order()
    ..id = 'o1'
    ..number = 42
    ..total = 1000
    ..paidAmount = 0
    ..customer = withCustomer
        ? (CustomerAggr()
          ..id = 'c1'
          ..name = 'Maria'
          ..taxId = taxId)
        : null;

  AsaasApiService service(MockClientHandler handler) =>
      AsaasApiService.withClient(
        MockClient(handler),
        headersProvider: () async => {'Authorization': 'Bearer t'},
      );

  Future<List<OrderCharge?>> pumpHost(
    WidgetTester tester, {
    required Order order,
    required AsaasApiService api,
    double remaining = 1000,
    String? loadedTaxId,
  }) async {
    final results = <OrderCharge?>[];
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('open'),
            onPressed: () async {
              results.add(await Navigator.of(context).push<OrderCharge>(
                CupertinoPageRoute(
                  builder: (_) => CreateChargeScreen(
                    order: order,
                    remainingBalance: remaining,
                    service: api,
                    customerTaxIdLoader: () async => loadedTaxId,
                  ),
                ),
              ));
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('validateChargeInput', () {
    ChargeFormError? validate({
      bool hasCustomer = true,
      double value = 100,
      double remaining = 1000,
      bool needsTaxId = false,
      String taxId = '',
    }) =>
        validateChargeInput(
          hasCustomer: hasCustomer,
          value: value,
          remainingBalance: remaining,
          needsTaxId: needsTaxId,
          taxIdInput: taxId,
        );

    test('entrada válida', () {
      expect(validate(), isNull);
      expect(validate(value: 1000), isNull);
    });

    test('OS sem cliente', () {
      expect(validate(hasCustomer: false), ChargeFormError.customerRequired);
    });

    test('valor zero', () {
      expect(validate(value: 0), ChargeFormError.valueRequired);
    });

    test('valor acima do saldo', () {
      expect(validate(value: 1000.01), ChargeFormError.valueExceedsBalance);
    });

    test('CPF/CNPJ obrigatório, vazio ou inválido', () {
      expect(validate(needsTaxId: true), ChargeFormError.taxIdRequired);
      expect(validate(needsTaxId: true, taxId: '123.456.789-00'),
          ChargeFormError.taxIdInvalid);
      expect(validate(needsTaxId: true, taxId: '529.982.247-25'), isNull);
    });

    test('CNPJ alfanumérico é aceito', () {
      expect(validate(needsTaxId: true, taxId: '12.ABC.345/01DE-35'), isNull);
      expect(validate(needsTaxId: true, taxId: '12abc34501de35'), isNull);
      expect(validate(needsTaxId: true, taxId: '12ABC34501DE36'),
          ChargeFormError.taxIdInvalid);
    });

    test('tolerância de meio centavo (CENT_TOLERANCE do servidor)', () {
      expect(validate(value: 1000.004), isNull);
      expect(validate(value: 1000.006), ChargeFormError.valueExceedsBalance);
    });
  });

  group('CreateChargeScreen', () {
    testWidgets('preenche o valor com o saldo e não pede CPF se já existe',
        (tester) async {
      await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) async => http.Response('{}', 500)));

      final field = tester
          .widget<CupertinoTextField>(find.byKey(const Key('chargeValueField')));
      expect(field.controller!.text, format.formatCurrency(1000));
      expect(find.byKey(const Key('chargeTaxIdField')), findsNothing);
      expect(find.text(l10n.chargeBalanceHint(format.formatCurrency(1000))),
          findsOneWidget);
    });

    testWidgets('usa o CPF do cadastro quando o agregado não tem',
        (tester) async {
      await pumpHost(tester,
          order: order(),
          loadedTaxId: '52998224725',
          api: service((_) async => http.Response('{}', 500)));

      expect(find.byKey(const Key('chargeTaxIdField')), findsNothing);
    });

    testWidgets('valor acima do saldo mostra erro e não chama a API',
        (tester) async {
      var calls = 0;
      await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) async {
            calls++;
            return http.Response('{}', 500);
          }));

      await tester.enterText(
          find.byKey(const Key('chargeValueField')), '150000');
      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorExceedsBalance), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('cliente sem CPF/CNPJ exige o documento', (tester) async {
      await pumpHost(tester,
          order: order(),
          api: service((_) async => http.Response('{}', 500)));

      expect(find.byKey(const Key('chargeTaxIdField')), findsOneWidget);
      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorTaxIdRequired), findsOneWidget);
    });

    testWidgets('CPF inválido mostra erro', (tester) async {
      await pumpHost(tester,
          order: order(),
          api: service((_) async => http.Response('{}', 500)));

      await tester.ensureVisible(find.byKey(const Key('chargeTaxIdField')));
      await tester.enterText(
          find.byKey(const Key('chargeTaxIdField')), '12345678900');
      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.invalidTaxId), findsOneWidget);
    });

    testWidgets('OS sem cliente mostra erro', (tester) async {
      await pumpHost(tester,
          order: order(withCustomer: false),
          api: service((_) async => http.Response('{}', 500)));

      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorCustomerRequired), findsOneWidget);
    });

    testWidgets('parcelado em 3x envia parcelas, vencimento e CPF e fecha',
        (tester) async {
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day + 3);

      final results = await pumpHost(tester,
          order: order(),
          api: service((request) async {
            expect(request.url.path, endsWith('/v1/app/orders/o1/charges'));
            expect(jsonDecode(request.body), {
              'value': 1000,
              'mode': 'cardInstallments',
              'installmentCount': 3,
              'dueDate': DateFormat('yyyy-MM-dd').format(due),
              'customerTaxId': '52998224725',
            });
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'ch1',
                  'mode': 'cardInstallments',
                  'installmentCount': 3,
                  'value': 1000,
                  'status': 'pending',
                  'invoiceUrl': 'https://sandbox.asaas.com/i/abc',
                },
              }),
              201,
            );
          }));

      await tester.tap(find.text(l10n.chargeModeInstallments));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.chargeInstallmentOption(2, format.formatCurrency(500))),
        findsOneWidget,
      );

      await tapKey(tester, 'chargeInstallmentsTile');
      await tester.tap(find.text(
          l10n.chargeInstallmentOption(3, format.formatCurrency(1000 / 3))));
      await tester.pumpAndSettle();
      expect(
        find.text(
            l10n.chargeInstallmentOption(3, format.formatCurrency(1000 / 3))),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('chargeTaxIdField')));
      await tester.enterText(
          find.byKey(const Key('chargeTaxIdField')), '52998224725');
      await tapKey(tester, 'generateChargeButton');

      expect(results, hasLength(1));
      expect(results.single?.id, 'ch1');
      expect(find.byType(CreateChargeScreen), findsNothing);
    });

    testWidgets('erro da API aparece traduzido e a tela continua aberta',
        (tester) async {
      await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) async => http.Response(
                jsonEncode({
                  'success': false,
                  'error': {
                    'code': 'ASAAS_NOT_CONNECTED',
                    'message': 'raw backend text',
                  },
                }),
                409,
              )));

      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorNotConnected), findsOneWidget);
      expect(find.byType(CreateChargeScreen), findsOneWidget);
    });

    testWidgets('CNPJ alfanumérico vai normalizado para a API', (tester) async {
      Map<String, dynamic>? sent;
      final results = await pumpHost(tester,
          order: order(),
          api: service((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'id': 'ch2', 'mode': 'single', 'status': 'pending'},
              }),
              201,
            );
          }));

      await tester.ensureVisible(find.byKey(const Key('chargeTaxIdField')));
      await tester.enterText(
          find.byKey(const Key('chargeTaxIdField')), '12.abc.345/01de-35');
      await tapKey(tester, 'generateChargeButton');

      expect(sent?['customerTaxId'], '12ABC34501DE35');
      expect(sent?['mode'], 'single');
      expect(sent?.containsKey('installmentCount'), isFalse);
      expect(results.single?.id, 'ch2');
    });

    testWidgets('botão fica desabilitado durante a requisição (sem duplo envio)',
        (tester) async {
      var calls = 0;
      final response = Completer<http.Response>();
      final results = await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) {
            calls++;
            return response.future;
          }));

      // No pumpAndSettle while in flight: the spinner never settles and the
      // fake clock would hit the service's 30s timeout.
      await tester.ensureVisible(find.byKey(const Key('generateChargeButton')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('generateChargeButton')));
      await tester.pump();

      final button = tester.widget<CupertinoButton>(
          find.byKey(const Key('generateChargeButton')));
      expect(button.onPressed, isNull);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      await tester.tap(find.byKey(const Key('generateChargeButton')),
          warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);

      response.complete(http.Response(
        jsonEncode({
          'success': true,
          'data': {'id': 'ch1', 'mode': 'single', 'status': 'pending'},
        }),
        201,
      ));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(results.single?.id, 'ch1');
    });

    testWidgets('erro de rede mostra sem conexão, não fecha e reabilita',
        (tester) async {
      final results = await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) async => throw http.ClientException('offline')));

      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.noInternetConnection), findsOneWidget);
      expect(find.byType(CreateChargeScreen), findsOneWidget);
      expect(results, isEmpty);

      await tester.tap(find.text(l10n.ok));
      await tester.pumpAndSettle();
      final button = tester.widget<CupertinoButton>(
          find.byKey(const Key('generateChargeButton')));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('resposta inesperada mostra erro genérico e não fecha',
        (tester) async {
      final results = await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) async => http.Response('not json', 201)));

      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorGeneric), findsOneWidget);
      expect(find.byType(CreateChargeScreen), findsOneWidget);
      expect(results, isEmpty);
    });
  });
}
