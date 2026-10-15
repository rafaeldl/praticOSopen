import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/customer_charge.dart';
import 'package:praticos/screens/payments/create_customer_charge_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/payment_allocation.dart';

void main() {
  setUp(() => FormatService().setLocale('pt-BR'));

  final customer = CustomerAggr()
    ..id = 'c1'
    ..name = 'João';
  const balances = [
    OpenBalance(orderId: 'a', orderNumber: 182, open: 450),
    OpenBalance(orderId: 'b', orderNumber: 190, open: 500),
  ];

  Future<(List<CustomerCharge?>, List<Map<String, dynamic>>)> pump(
    WidgetTester tester, {
    String? taxId = '12345678909',
    double initial = 950,
    double textScale = 1,
  }) async {
    final bodies = <Map<String, dynamic>>[];
    final api = AsaasApiService.withClient(
      MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'cc1',
              'value': bodies.last['value'],
              'status': 'pending',
              'invoiceUrl': 'https://asaas.test/i/cc1',
            },
          }),
          201,
        );
      }),
      headersProvider: () async => {'Authorization': 'Bearer t'},
    );
    final results = <CustomerCharge?>[];
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Builder(
            builder: (context) => CupertinoButton(
              child: const Text('open'),
              onPressed: () async {
                results.add(
                  await FormSheet.show<CustomerCharge>(
                    context,
                    (_) => CreateCustomerChargeScreen(
                      customer: customer,
                      balances: balances,
                      initialValue: initial,
                      service: api,
                      customerTaxIdLoader: () async => taxId,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (results, bodies);
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<CupertinoButton>(find.byKey(const ValueKey('new_order_save')))
          .onPressed !=
      null;

  testWidgets('prefilled with the amount, says which orders, sends them', (
    tester,
  ) async {
    final (results, bodies) = await pump(tester);

    expect(find.textContaining('950,00'), findsWidgets);
    expect(
      find.text(
        'João recebe um link só para pagar as OS 182, 190 por Pix, boleto '
        'ou cartão.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customerChargeTaxIdField')), findsNothing);
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.byKey(const ValueKey('new_order_save')));
    await tester.pumpAndSettle();
    expect(bodies.single['orderIds'], ['a', 'b']);
    expect(bodies.single['value'], 950);
    expect(bodies.single.containsKey('customerTaxId'), isFalse);
    expect(results.single?.id, 'cc1');
  });

  testWidgets('asks the CPF/CNPJ when the customer has none', (tester) async {
    final (_, bodies) = await pump(tester, taxId: null, initial: 300);
    expect(find.byKey(const Key('customerChargeTaxIdField')), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    // Only the field's hint explains it; no second "Informe o CPF" line.
    final l10n = lookupAppLocalizations(const Locale('pt'));
    expect(find.text(l10n.chargeTaxIdHint), findsOneWidget);
    expect(find.text(l10n.asaasErrorTaxIdRequired), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('customerChargeTaxIdField')),
        matching: find.byType(CupertinoTextField),
      ),
      '123.456.789-09',
    );
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('new_order_save')));
    await tester.pumpAndSettle();
    expect(bodies.single['customerTaxId'], '12345678909');
    expect(bodies.single['value'], 300);
  });

  testWidgets('more than they owe keeps the ✓ off', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('customerChargeValueField')),
        matching: find.byType(CupertinoTextField),
      ),
      '100000',
    );
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('text size 2 renders without overflow', (tester) async {
    await pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('createCustomerChargeSheet')), findsOneWidget);
  });
}
