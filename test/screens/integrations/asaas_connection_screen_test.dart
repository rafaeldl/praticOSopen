import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/theme/app_colors.dart';

void main() {
  final l10n = AppLocalizationsPt();

  AsaasApiService service(MockClientHandler handler) =>
      AsaasApiService.withClient(
        MockClient(handler),
        headersProvider: () async => {'Authorization': 'Bearer t'},
      );

  Widget app(Widget home, {double scale = 1}) => CupertinoApp(
    locale: const Locale('pt'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required PaymentSettings settings,
    required AsaasApiService api,
  }) async {
    await tester.pumpWidget(
      app(
        AsaasConnectionScreen(
          service: api,
          settingsStream: Stream.value(settings),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// "…" → "Desconectar" → the confirmation alert.
  Future<void> openDisconnect(WidgetTester tester) async {
    await tapKey(tester, 'asaasMenuButton');
    await tester.tap(find.text(l10n.asaasDisconnect));
    await tester.pumpAndSettle();
  }

  /// Lets the toast go away so no timer is left pending.
  Future<void> clearToast(WidgetTester tester) async {
    await tester.pump(kAppToastDuration);
    await tester.pumpAndSettle();
  }

  final disconnected = PaymentSettings(asaasEnabled: true);

  group('AsaasConnectionScreen desconectada', () {
    testWidgets('texto grande não estoura', (tester) async {
      await tester.pumpWidget(
        app(
          AsaasConnectionScreen(
            service: service((_) async => http.Response('{}', 500)),
            settingsStream: Stream.value(disconnected),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.asaasConnectHeadline), findsOneWidget);
    });

    testWidgets('mostra instruções, links e campo oculto', (tester) async {
      await pumpScreen(
        tester,
        settings: disconnected,
        api: service((_) async => http.Response('{}', 500)),
      );

      expect(find.text(l10n.asaasConnectHeadline), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text(l10n.asaasConnect), findsOneWidget);
      expect(find.byKey(const Key('asaasMenuButton')), findsNothing);
      expect(find.text(l10n.asaasConnectStep1), findsOneWidget);
      expect(find.text(l10n.asaasOpenPanel), findsOneWidget);
      expect(find.text(l10n.asaasOpenSandboxPanel), findsOneWidget);
      final field = tester.widget<CupertinoTextField>(
        find.byKey(const Key('asaasApiKeyField')),
      );
      expect(field.obscureText, isTrue);
      expect(field.enableSuggestions, isFalse);
    });

    testWidgets('Conectar sem chave não chama a API', (tester) async {
      var calls = 0;
      await pumpScreen(
        tester,
        settings: disconnected,
        api: service((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      await tapKey(tester, 'asaasConnectButton');

      expect(calls, 0);
    });

    testWidgets('conecta e mostra conta e ambiente Teste', (tester) async {
      await pumpScreen(
        tester,
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
        }),
      );

      await tester.enterText(
        find.byKey(const Key('asaasApiKeyField')),
        '\$aact_hmlg_000',
      );
      await tapKey(tester, 'asaasConnectButton');

      expect(find.text('Rafsoft'), findsOneWidget);
      expect(find.text(l10n.asaasEnvironmentSandbox), findsOneWidget);
      expect(find.byKey(const Key('asaasApiKeyField')), findsNothing);
      expect(find.text(l10n.asaasConnectedToast), findsOneWidget);
      await clearToast(tester);
    });

    testWidgets('chave inválida mostra erro traduzido', (tester) async {
      await pumpScreen(
        tester,
        settings: disconnected,
        api: service(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'ASAAS_INVALID_API_KEY',
                'message': 'raw backend text',
              },
            }),
            400,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('asaasApiKeyField')),
        '\$aact_hmlg_bad',
      );
      await tapKey(tester, 'asaasConnectButton');

      expect(find.text(l10n.asaasErrorInvalidKey), findsOneWidget);
      expect(find.textContaining('raw backend text'), findsNothing);
      await clearToast(tester);
    });
  });

  testWidgets('resposta 200 malformada ao conectar mostra erro genérico', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      settings: disconnected,
      api: service((_) async => http.Response('not json', 200)),
    );

    await tester.enterText(
      find.byKey(const Key('asaasApiKeyField')),
      '\$aact_hmlg_000',
    );
    await tapKey(tester, 'asaasConnectButton');

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.asaasErrorGeneric), findsOneWidget);
    final button = tester.widget<PrimaryButton>(
      find.byKey(const Key('asaasConnectButton')),
    );
    expect(button.onPressed, isNotNull);
    await clearToast(tester);
  });

  testWidgets('erro inesperado ao desconectar mostra erro genérico', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      settings: PaymentSettings(
        asaasEnabled: true,
        asaasConnected: true,
        asaasAccountName: 'Oficina do João',
      ),
      api: service((_) async => throw StateError('unexpected')),
    );

    await openDisconnect(tester);
    await tester.tap(find.byKey(const Key('confirmAsaasDisconnectAction')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.asaasErrorGeneric), findsOneWidget);
    await clearToast(tester);
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
      await pumpScreen(
        tester,
        settings: connected,
        api: service((request) async {
          expect(request.method, 'DELETE');
          deleted = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      expect(find.text('Oficina do João'), findsOneWidget);
      expect(find.text(l10n.asaasEnvironmentProduction), findsOneWidget);
      expect(find.text(l10n.asaasConnectedHeadline), findsOneWidget);
      // Status as a dot, no blue button once connected.
      expect(
        find.descendant(
          of: find.byKey(const Key('asaasEnvironmentRow')),
          matching: find.byType(StatusDot),
        ),
        findsOneWidget,
      );
      expect(find.byType(PrimaryButton), findsNothing);

      await openDisconnect(tester);
      expect(find.text(l10n.asaasDisconnectConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmAsaasDisconnectAction')));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(find.byKey(const Key('asaasConnectButton')), findsOneWidget);
      expect(find.text(l10n.asaasDisconnectedToast), findsOneWidget);
      await clearToast(tester);
    });

    testWidgets('o "…" tem só Desconectar, em vermelho', (tester) async {
      await pumpScreen(
        tester,
        settings: connected,
        api: service((_) async => http.Response('{}', 200)),
      );

      await tapKey(tester, 'asaasMenuButton');
      expect(find.text(l10n.asaasDisconnect), findsOneWidget);
      final label = tester.widget<Text>(find.text(l10n.asaasDisconnect));
      expect(label.style?.color?.toARGB32(), AppColors.danger.color.toARGB32());
    });

    testWidgets('texto grande não estoura', (tester) async {
      await tester.pumpWidget(
        app(
          AsaasConnectionScreen(
            service: service((_) async => http.Response('{}', 200)),
            settingsStream: Stream.value(connected),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Oficina do João'), findsOneWidget);
    });

    testWidgets('cancelar o diálogo não desconecta', (tester) async {
      var calls = 0;
      await pumpScreen(
        tester,
        settings: connected,
        api: service((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      await openDisconnect(tester);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.text('Oficina do João'), findsOneWidget);
    });
  });

  group('PaymentsIntegrationSection', () {
    testWidgets('some quando o piloto está desligado', (tester) async {
      await tester.pumpWidget(
        app(
          CupertinoPageScaffold(
            child: PaymentsIntegrationSection(
              settingsStream: Stream.value(PaymentSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asaas'), findsNothing);
    });

    testWidgets('mostra Asaas com status de conexão', (tester) async {
      await tester.pumpWidget(
        app(
          CupertinoPageScaffold(
            child: PaymentsIntegrationSection(
              settingsStream: Stream.value(
                PaymentSettings(asaasEnabled: true, asaasConnected: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asaas'), findsOneWidget);
      expect(find.text(l10n.asaasConnected), findsOneWidget);
      expect(find.text(l10n.payments), findsOneWidget);
      expect(find.byType(StatusDot), findsOneWidget);
    });

    testWidgets('mostra Não conectado', (tester) async {
      await tester.pumpWidget(
        app(
          CupertinoPageScaffold(
            child: PaymentsIntegrationSection(
              settingsStream: Stream.value(PaymentSettings(asaasEnabled: true)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.asaasDisconnected), findsOneWidget);
    });
  });

  group('R8 erro no stream de configurações', () {
    testWidgets('permission-denied cai em desconectado, sem travar', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          AsaasConnectionScreen(
            service: service((_) async => http.Response('{}', 500)),
            settingsStream: Stream<PaymentSettings>.error('permission-denied'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('asaasConnectButton')), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('seção de pagamentos some em erro', (tester) async {
      await tester.pumpWidget(
        app(
          CupertinoPageScaffold(
            child: PaymentsIntegrationSection(
              settingsStream: safePaymentSettings(
                Stream<PaymentSettings>.error('permission-denied'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asaas'), findsNothing);
    });
  });
}
