import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/integrations/integration_list_screen.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/integration_api_service.dart';
import 'package:praticos/theme/app_colors.dart';

void main() {
  final l10n = AppLocalizationsPt();

  IntegrationApiService service(MockClientHandler handler) =>
      IntegrationApiService.withClient(
        MockClient(handler),
        tokenProvider: () async => 't',
      );

  http.Response tokens(List<Map<String, dynamic>> data) =>
      http.Response(jsonEncode({'success': true, 'data': data}), 200);

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

  Future<void> pump(
    WidgetTester tester, {
    required IntegrationApiService api,
    Stream<PaymentSettings>? payments,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      app(
        IntegrationListScreen(service: api, paymentSettings: payments),
        scale: scale,
      ),
    );
    await tester.pumpAndSettle();
  }

  final chatGpt = {
    'id': 't1',
    'name': 'Meu ChatGPT',
    'lastUsedAt': '2026-10-01T10:00:00.000Z',
  };

  testWidgets('título, seção e conexões com o último uso', (tester) async {
    await pump(tester, api: service((_) async => tokens([chatGpt])));

    expect(find.text(l10n.integrations), findsWidgets);
    expect(find.text(l10n.integrationsAiSection), findsOneWidget);
    expect(find.text('Meu ChatGPT'), findsOneWidget);
    expect(find.text(l10n.integrationsLastUsed('01/10/2026')), findsOneWidget);
    expect(find.byKey(const Key('integrationsAdd')), findsOneWidget);
    // Consult screen: no blue button.
    expect(find.byType(PrimaryButton), findsNothing);
  });

  testWidgets('sem conexões: uma linha', (tester) async {
    await pump(tester, api: service((_) async => tokens([])));

    expect(find.byKey(const Key('integrationsEmpty')), findsOneWidget);
    expect(find.text(l10n.integrationsEmptyLine), findsOneWidget);
  });

  testWidgets('erro ao carregar mostra o texto traduzido', (tester) async {
    await pump(
      tester,
      api: service(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'FORBIDDEN', 'message': 'raw'},
          }),
          403,
        ),
      ),
    );

    expect(find.text(l10n.integrationsErrorForbidden), findsOneWidget);
    expect(find.text('raw'), findsNothing);
  });

  testWidgets('Asaas aparece com ponto e "Conectado"', (tester) async {
    await pump(
      tester,
      api: service((_) async => tokens([])),
      payments: Stream.value(
        PaymentSettings(asaasEnabled: true, asaasConnected: true),
      ),
    );

    expect(find.text('Asaas'), findsOneWidget);
    expect(find.text(l10n.asaasConnected), findsOneWidget);
    expect(find.byType(StatusDot), findsOneWidget);
  });

  testWidgets('tocar na conexão: "…" com Desligar em vermelho, confirma e '
      'desliga', (tester) async {
    var deleted = false;
    var listed = 0;
    await pump(
      tester,
      api: service((request) async {
        if (request.method == 'DELETE') {
          expect(request.url.path, endsWith('/tokens/t1'));
          deleted = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }
        listed++;
        return tokens(listed == 1 ? [chatGpt] : []);
      }),
    );

    await tester.tap(find.text('Meu ChatGPT'));
    await tester.pumpAndSettle();
    final item = tester.widget<Text>(find.text(l10n.integrationsRevoke));
    expect(item.style?.color?.toARGB32(), AppColors.danger.color.toARGB32());

    await tester.tap(find.text(l10n.integrationsRevoke));
    await tester.pumpAndSettle();
    expect(find.text(l10n.integrationsRevokeConfirm), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmRevokeAction')));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.text(l10n.integrationsRevoked), findsOneWidget);
    expect(find.text(l10n.integrationsEmptyLine), findsOneWidget);
    await tester.pump(kAppToastDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('texto grande não estoura', (tester) async {
    await pump(
      tester,
      api: service((_) async => tokens([chatGpt])),
      payments: Stream.value(PaymentSettings(asaasEnabled: true)),
      scale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Meu ChatGPT'), findsOneWidget);
    expect(find.text(l10n.asaasDisconnected), findsOneWidget);
  });
}
