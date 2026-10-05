import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart';
import 'package:praticos/services/asaas_api_service.dart';

void main() {
  final l10n = AppLocalizationsPt();

  AsaasApiService service(MockClientHandler handler) =>
      AsaasApiService.withClient(
        MockClient(handler),
        headersProvider: () async => {'Authorization': 'Bearer t'},
      );

  Widget app(Widget home) => CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required PaymentSettings settings,
    required AsaasApiService api,
  }) async {
    await tester.pumpWidget(app(AsaasConnectionScreen(
      service: api,
      settingsStream: Stream.value(settings),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  final disconnected = PaymentSettings(asaasEnabled: true);

  group('AsaasConnectionScreen desconectada', () {
    testWidgets('mostra instruções, links e campo oculto', (tester) async {
      await pumpScreen(tester,
          settings: disconnected,
          api: service((_) async => http.Response('{}', 500)));

      expect(find.text(l10n.asaasConnectStep1), findsOneWidget);
      expect(find.text(l10n.asaasOpenPanel), findsOneWidget);
      expect(find.text(l10n.asaasOpenSandboxPanel), findsOneWidget);
      final field = tester.widget<CupertinoTextField>(
          find.byKey(const Key('asaasApiKeyField')));
      expect(field.obscureText, isTrue);
      expect(field.enableSuggestions, isFalse);
    });

    testWidgets('Conectar sem chave não chama a API', (tester) async {
      var calls = 0;
      await pumpScreen(tester,
          settings: disconnected,
          api: service((_) async {
            calls++;
            return http.Response('{}', 200);
          }));

      await tapKey(tester, 'asaasConnectButton');

      expect(calls, 0);
    });

    testWidgets('conecta e mostra conta e ambiente Teste', (tester) async {
      await pumpScreen(tester,
          settings: disconnected,
          api: service((request) async {
            expect(jsonDecode(request.body), {'apiKey': '\$aact_hmlg_000'});
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'asaasEnabled': true,
                  'asaasConnected': true,
                  'asaasAccountName': 'Rafsoft',
                  'asaasEnvironment': 'sandbox',
                },
              }),
              200,
            );
          }));

      await tester.enterText(
          find.byKey(const Key('asaasApiKeyField')), '\$aact_hmlg_000');
      await tapKey(tester, 'asaasConnectButton');

      expect(find.text('Rafsoft'), findsOneWidget);
      expect(find.text(l10n.asaasEnvironmentSandbox), findsOneWidget);
      expect(find.byKey(const Key('asaasApiKeyField')), findsNothing);
    });

    testWidgets('chave inválida mostra erro traduzido', (tester) async {
      await pumpScreen(tester,
          settings: disconnected,
          api: service((_) async => http.Response(
                jsonEncode({
                  'success': false,
                  'error': {
                    'code': 'ASAAS_INVALID_API_KEY',
                    'message': 'raw backend text',
                  },
                }),
                400,
              )));

      await tester.enterText(
          find.byKey(const Key('asaasApiKeyField')), '\$aact_hmlg_bad');
      await tapKey(tester, 'asaasConnectButton');

      expect(find.text(l10n.asaasErrorInvalidKey), findsOneWidget);
      expect(find.textContaining('raw backend text'), findsNothing);
    });
  });

  group('AsaasConnectionScreen conectada', () {
    final connected = PaymentSettings(
      asaasEnabled: true,
      asaasConnected: true,
      asaasAccountName: 'Oficina do João',
      asaasEnvironment: 'production',
    );

    testWidgets('mostra conta, ambiente Produção e desconecta', (tester) async {
      var deleted = false;
      await pumpScreen(tester,
          settings: connected,
          api: service((request) async {
            expect(request.method, 'DELETE');
            deleted = true;
            return http.Response(jsonEncode({'success': true}), 200);
          }));

      expect(find.text('Oficina do João'), findsOneWidget);
      expect(find.text(l10n.asaasEnvironmentProduction), findsOneWidget);

      await tapKey(tester, 'asaasDisconnectTile');
      expect(find.text(l10n.asaasDisconnectConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmAsaasDisconnectAction')));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(find.byKey(const Key('asaasConnectButton')), findsOneWidget);
    });

    testWidgets('cancelar o diálogo não desconecta', (tester) async {
      var calls = 0;
      await pumpScreen(tester,
          settings: connected,
          api: service((_) async {
            calls++;
            return http.Response('{}', 200);
          }));

      await tapKey(tester, 'asaasDisconnectTile');
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.text('Oficina do João'), findsOneWidget);
    });
  });

  group('PaymentsIntegrationSection', () {
    testWidgets('some quando o piloto está desligado', (tester) async {
      await tester.pumpWidget(app(CupertinoPageScaffold(
        child: PaymentsIntegrationSection(
          settingsStream: Stream.value(PaymentSettings()),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Asaas'), findsNothing);
    });

    testWidgets('mostra Asaas com status de conexão', (tester) async {
      await tester.pumpWidget(app(CupertinoPageScaffold(
        child: PaymentsIntegrationSection(
          settingsStream: Stream.value(
              PaymentSettings(asaasEnabled: true, asaasConnected: true)),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Asaas'), findsOneWidget);
      expect(find.text(l10n.asaasConnected), findsOneWidget);
      expect(find.text(l10n.payments.toUpperCase()), findsOneWidget);
    });
  });

  group('R8 erro no stream de configurações', () {
    testWidgets('permission-denied cai em desconectado, sem travar',
        (tester) async {
      await tester.pumpWidget(app(AsaasConnectionScreen(
        service: service((_) async => http.Response('{}', 500)),
        settingsStream: Stream<PaymentSettings>.error('permission-denied'),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('asaasConnectButton')), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('seção de pagamentos some em erro', (tester) async {
      await tester.pumpWidget(app(CupertinoPageScaffold(
        child: PaymentsIntegrationSection(
          settingsStream: safePaymentSettings(
              Stream<PaymentSettings>.error('permission-denied')),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Asaas'), findsNothing);
    });
  });
}
