import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';

void main() {
  final l10n = AppLocalizationsPt();
  final format = FormatService();

  final order = Order()
    ..id = 'o1'
    ..number = 42
    ..total = 1000
    ..paidAmount = 0;

  OrderCharge charge({
    String id = 'ch1',
    ChargeStatus status = ChargeStatus.pending,
    double value = 1000,
    ChargeMode mode = ChargeMode.single,
    int? installmentCount,
    List<String>? paidAsaasPaymentIds,
  }) =>
      OrderCharge(
        id: id,
        status: status,
        value: value,
        mode: mode,
        installmentCount: installmentCount,
        dueDate: '2026-10-07',
        invoiceUrl: 'https://sandbox.asaas.com/i/abc',
        paidAsaasPaymentIds: paidAsaasPaymentIds,
      );

  AsaasApiService service(MockClientHandler handler) =>
      AsaasApiService.withClient(
        MockClient(handler),
        headersProvider: () async => {'Authorization': 'Bearer t'},
      );

  final unusedService = service((_) async => http.Response('{}', 500));

  Future<void> pumpCard(
    WidgetTester tester, {
    List<OrderCharge> charges = const [],
    Stream<List<OrderCharge>>? stream,
    double remaining = 1000,
    bool canCreate = true,
    FutureOr<void> Function()? onCreate,
    VoidCallback? onSettled,
    AsaasApiService? api,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ListView(
            children: [
              OrderChargeCard(
                order: order,
                remainingBalance: remaining,
                canCreateCharge: canCreate,
                onCreateCharge: onCreate ?? () {},
                onChargeSettled: onSettled,
                chargesStream: stream ?? Stream.value(charges),
                service: api ?? unusedService,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int dotColor(WidgetTester tester) {
    final dot =
        tester.widget<Container>(find.byKey(const Key('chargeStatusDot')));
    return (dot.decoration as BoxDecoration).color!.toARGB32();
  }

  group('chargeStatusColor', () {
    test('azul pendente, vermelho vencida, verde paga, cinza encerrada', () {
      expect(chargeStatusColor(ChargeStatus.pending), CupertinoColors.systemBlue);
      expect(chargeStatusColor(ChargeStatus.overdue), CupertinoColors.systemRed);
      expect(chargeStatusColor(ChargeStatus.paid), CupertinoColors.systemGreen);
      expect(chargeStatusColor(ChargeStatus.canceled), CupertinoColors.systemGrey);
      expect(chargeStatusColor(ChargeStatus.refunded), CupertinoColors.systemGrey);
      expect(chargeStatusColor(null), CupertinoColors.systemGrey);
    });
  });

  group('chargeSettled', () {
    OrderCharge c(ChargeStatus? status, [int paid = 0]) => OrderCharge(
        id: 'ch1',
        status: status,
        paidAsaasPaymentIds: [for (var i = 0; i < paid; i++) 'pay_$i']);

    test('true quando passa para paga ou estornada', () {
      expect(chargeSettled(c(ChargeStatus.pending), c(ChargeStatus.paid)),
          isTrue);
      expect(chargeSettled(c(ChargeStatus.overdue), c(ChargeStatus.paid)),
          isTrue);
      expect(chargeSettled(c(ChargeStatus.paid), c(ChargeStatus.refunded)),
          isTrue);
      // Charge not seen before (after the first emission) already paid
      expect(chargeSettled(null, c(ChargeStatus.paid)), isTrue);
    });

    test('true quando o número de parcelas pagas muda', () {
      expect(
          chargeSettled(
              c(ChargeStatus.pending, 1), c(ChargeStatus.pending, 2)),
          isTrue);
      expect(
          chargeSettled(c(ChargeStatus.pending), c(ChargeStatus.pending, 1)),
          isTrue);
      expect(chargeSettled(null, c(ChargeStatus.pending, 1)), isTrue);
      // Refund of an installment shrinks the list
      expect(
          chargeSettled(
              c(ChargeStatus.pending, 2), c(ChargeStatus.pending, 1)),
          isTrue);
    });

    test('false sem mudança ou para status sem pagamento', () {
      expect(chargeSettled(c(ChargeStatus.paid), c(ChargeStatus.paid)),
          isFalse);
      expect(
          chargeSettled(c(ChargeStatus.refunded), c(ChargeStatus.refunded)),
          isFalse);
      expect(chargeSettled(c(ChargeStatus.pending), c(ChargeStatus.overdue)),
          isFalse);
      expect(
          chargeSettled(c(ChargeStatus.pending), c(ChargeStatus.canceled)),
          isFalse);
      expect(chargeSettled(null, c(ChargeStatus.pending)), isFalse);
      expect(chargeSettled(c(ChargeStatus.paid), c(null)), isFalse);
      expect(
          chargeSettled(
              c(ChargeStatus.pending, 2), c(ChargeStatus.overdue, 2)),
          isFalse);
    });
  });

  group('OrderChargeCard', () {
    testWidgets('sem cobrança mostra só o botão Cobrar', (tester) async {
      var created = 0;
      await pumpCard(tester, charges: const [], onCreate: () => created++);

      expect(find.byKey(const Key('chargeStatusTile')), findsNothing);
      await tester.tap(find.text(l10n.chargeWithAsaas));
      await tester.pumpAndSettle();

      expect(created, 1);
    });

    testWidgets('sem cobrança e sem permissão não mostra nada', (tester) async {
      await pumpCard(tester, charges: const [], canCreate: false);

      expect(find.byType(CupertinoListSection), findsNothing);
    });

    testWidgets('erro no stream é tratado como sem cobrança', (tester) async {
      await pumpCard(tester,
          stream: Stream<List<OrderCharge>>.error(
              Exception('permission-denied')));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('chargeStatusTile')), findsNothing);
      expect(find.text(l10n.chargeWithAsaas), findsOneWidget);
    });

    testWidgets('saldo zero esconde o botão Cobrar', (tester) async {
      await pumpCard(tester,
          charges: [charge(status: ChargeStatus.paid)], remaining: 0);

      expect(find.text(l10n.chargeWithAsaas), findsNothing);
    });

    testWidgets('pendente: dot azul, valor, vencimento e ações',
        (tester) async {
      await pumpCard(tester, charges: [charge()]);

      expect(find.text(l10n.chargeStatusPending), findsOneWidget);
      expect(dotColor(tester), CupertinoColors.systemBlue.color.toARGB32());
      expect(find.text(format.formatCurrency(1000)), findsOneWidget);
      expect(
        find.text(l10n.chargeDueOn(format.formatDate(DateTime(2026, 10, 7)))),
        findsOneWidget,
      );
      expect(find.text(l10n.chargeShareOrderLink), findsOneWidget);
      expect(find.text(l10n.chargeCopyInvoiceLink), findsOneWidget);
      expect(find.byKey(const Key('chargeCancelTile')), findsOneWidget);
      expect(find.byKey(const Key('chargeBalanceWarning')), findsNothing);
    });

    testWidgets('parcelada mostra Nx no cartão', (tester) async {
      await pumpCard(tester,
          charges: [
            charge(mode: ChargeMode.cardInstallments, installmentCount: 3),
          ]);

      expect(find.textContaining(l10n.chargeInstallmentsSummary(3)),
          findsOneWidget);
    });

    testWidgets('vencida: dot vermelho', (tester) async {
      await pumpCard(tester, charges: [charge(status: ChargeStatus.overdue)]);

      expect(find.text(l10n.chargeStatusOverdue), findsOneWidget);
      expect(dotColor(tester), CupertinoColors.systemRed.color.toARGB32());
    });

    testWidgets('paga: dot verde e sem cancelar', (tester) async {
      await pumpCard(tester,
          charges: [charge(status: ChargeStatus.paid)], remaining: 0);

      expect(find.text(l10n.chargeStatusPaid), findsOneWidget);
      expect(dotColor(tester), CupertinoColors.systemGreen.color.toARGB32());
      expect(find.byKey(const Key('chargeCancelTile')), findsNothing);
      expect(find.text(l10n.chargeCopyInvoiceLink), findsOneWidget);
    });

    testWidgets('cancelada: sem ações', (tester) async {
      await pumpCard(tester, charges: [charge(status: ChargeStatus.canceled)]);

      expect(find.text(l10n.chargeStatusCanceled), findsOneWidget);
      expect(find.text(l10n.chargeShareOrderLink), findsNothing);
      expect(find.byKey(const Key('chargeCancelTile')), findsNothing);
    });

    testWidgets('saldo menor que a cobrança mostra aviso e oferece regerar',
        (tester) async {
      var created = 0;
      await pumpCard(tester,
          charges: [charge(value: 1000)],
          remaining: 800,
          onCreate: () => created++);

      expect(
        find.text(l10n.chargeTotalChanged(
            format.formatCurrency(800), format.formatCurrency(1000))),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.chargeRegenerate));
      await tester.pumpAndSettle();

      expect(created, 1);
    });

    testWidgets('cobrança de entrada (saldo maior) não mostra aviso',
        (tester) async {
      await pumpCard(tester, charges: [charge(value: 1000)], remaining: 1200);

      expect(find.byKey(const Key('chargeBalanceWarning')), findsNothing);
    });

    testWidgets('diferença dentro da tolerância não mostra aviso',
        (tester) async {
      await pumpCard(tester,
          charges: [charge(value: 1000)], remaining: 999.996);

      expect(find.byKey(const Key('chargeBalanceWarning')), findsNothing);
    });

    testWidgets(
        'parcelamento com parcela paga: sem cancelar, sem regerar e sem aviso',
        (tester) async {
      await pumpCard(tester,
          charges: [
            charge(
              value: 1200,
              mode: ChargeMode.cardInstallments,
              installmentCount: 3,
              paidAsaasPaymentIds: ['pay_1'],
            ),
          ],
          remaining: 800);

      expect(find.text(l10n.chargeStatusPending), findsOneWidget);
      expect(find.byKey(const Key('chargeCancelTile')), findsNothing);
      expect(find.byKey(const Key('chargeBalanceWarning')), findsNothing);
      expect(find.text(l10n.chargeRegenerate), findsNothing);
      expect(find.text(l10n.chargeWithAsaas), findsNothing);
      // Link actions stay available
      expect(find.text(l10n.chargeCopyInvoiceLink), findsOneWidget);
    });

    testWidgets('Cobrar com cobrança aberta pede confirmação', (tester) async {
      var created = 0;
      await pumpCard(tester, charges: [charge()], onCreate: () => created++);

      await tester.tap(find.text(l10n.chargeWithAsaas));
      await tester.pumpAndSettle();
      expect(find.text(l10n.chargeReplaceTitle), findsOneWidget);
      expect(created, 0);

      await tester.tap(find.byKey(const Key('confirmReplaceChargeAction')));
      await tester.pumpAndSettle();
      expect(created, 1);
    });

    testWidgets('Cobrar ignora toque duplo enquanto a tela está aberta',
        (tester) async {
      var created = 0;
      final done = Completer<void>();
      await pumpCard(tester, onCreate: () {
        created++;
        return done.future;
      });

      await tester.tap(find.text(l10n.chargeWithAsaas));
      await tester.pump();
      await tester.tap(find.text(l10n.chargeWithAsaas));
      await tester.pump();
      expect(created, 1);

      done.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.chargeWithAsaas));
      await tester.pump();
      expect(created, 2);
    });

    testWidgets('copia o link da fatura', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpCard(tester, charges: [charge()]);
      await tester.tap(find.text(l10n.chargeCopyInvoiceLink));
      await tester.pumpAndSettle();

      expect(copied, ['https://sandbox.asaas.com/i/abc']);
      expect(find.text(l10n.chargeInvoiceLinkCopied), findsOneWidget);
    });

    testWidgets('cancela a cobrança após confirmar', (tester) async {
      var deleted = false;
      await pumpCard(tester,
          charges: [charge()],
          api: service((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, endsWith('/v1/app/orders/o1/charges/ch1'));
            deleted = true;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'id': 'ch1', 'status': 'canceled'},
              }),
              200,
            );
          }));

      await tester.tap(find.byKey(const Key('chargeCancelTile')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.chargeCancelConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmCancelChargeAction')));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('erro ao cancelar mostra texto traduzido', (tester) async {
      await pumpCard(tester,
          charges: [charge()],
          api: service((_) async => http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'code': 'CHARGE_NOT_OPEN', 'message': 'raw'},
                }),
                409,
              )));

      await tester.tap(find.byKey(const Key('chargeCancelTile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmCancelChargeAction')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.asaasErrorChargeNotOpen), findsOneWidget);
      expect(find.text('raw'), findsNothing);
    });

    testWidgets('Manter no diálogo não cancela', (tester) async {
      var calls = 0;
      await pumpCard(tester,
          charges: [charge()],
          api: service((_) async {
            calls++;
            return http.Response('{}', 200);
          }));

      await tester.tap(find.byKey(const Key('chargeCancelTile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.chargeKeep));
      await tester.pumpAndSettle();

      expect(calls, 0);
    });

    group('onChargeSettled', () {
      late StreamController<List<OrderCharge>> controller;
      late int settled;

      setUp(() {
        controller = StreamController<List<OrderCharge>>();
        settled = 0;
      });

      tearDown(() => controller.close());

      Future<void> emit(WidgetTester tester, List<OrderCharge> charges) async {
        controller.add(charges);
        await tester.pumpAndSettle();
      }

      testWidgets('primeira emissão já paga não recarrega', (tester) async {
        await pumpCard(tester,
            stream: controller.stream, onSettled: () => settled++);
        await emit(tester, [charge(status: ChargeStatus.paid)]);

        expect(settled, 0);
      });

      testWidgets('pendente → paga recarrega uma vez', (tester) async {
        await pumpCard(tester,
            stream: controller.stream, onSettled: () => settled++);
        await emit(tester, [charge()]);
        expect(settled, 0);

        await emit(tester, [charge(status: ChargeStatus.paid)]);
        expect(settled, 1);
        expect(find.text(l10n.chargeStatusPaid), findsOneWidget);

        // Same status again (e.g. another field changed): no reload
        await emit(tester, [charge(status: ChargeStatus.paid)]);
        expect(settled, 1);

        await emit(tester, [charge(status: ChargeStatus.refunded)]);
        expect(settled, 2);
      });

      testWidgets('parcela paga com cobrança ainda pendente recarrega',
          (tester) async {
        OrderCharge installments(int paid) => charge(
              mode: ChargeMode.cardInstallments,
              installmentCount: 3,
              paidAsaasPaymentIds: [for (var i = 0; i < paid; i++) 'pay_$i'],
            );
        await pumpCard(tester,
            stream: controller.stream, onSettled: () => settled++);
        // First emission with paid installments: initial state, no reload
        await emit(tester, [installments(1)]);
        expect(settled, 0);

        await emit(tester, [installments(2)]);
        expect(settled, 1);

        // Same count again: no reload
        await emit(tester, [installments(2)]);
        expect(settled, 1);
      });

      testWidgets('várias mudanças na mesma emissão recarregam uma vez',
          (tester) async {
        await pumpCard(tester,
            stream: controller.stream, onSettled: () => settled++);
        await emit(tester, [
          charge(id: 'ch2'),
          charge(id: 'ch1', status: ChargeStatus.overdue),
        ]);
        await emit(tester, [
          charge(id: 'ch2', paidAsaasPaymentIds: ['pay_1']),
          charge(id: 'ch1', status: ChargeStatus.paid),
        ]);

        expect(settled, 1);
      });

      testWidgets('cancelada ou vencida não recarrega', (tester) async {
        await pumpCard(tester,
            stream: controller.stream, onSettled: () => settled++);
        await emit(tester, [charge()]);
        await emit(tester, [charge(status: ChargeStatus.overdue)]);
        await emit(tester, [charge(status: ChargeStatus.canceled)]);

        expect(settled, 0);
      });

      testWidgets('cobrança antiga paga enquanto outra está aberta recarrega',
          (tester) async {
        await pumpCard(tester,
            stream: controller.stream, onSettled: () => settled++);
        await emit(tester, [
          charge(id: 'ch2'),
          charge(id: 'ch1', status: ChargeStatus.overdue),
        ]);
        await emit(tester, [
          charge(id: 'ch2'),
          charge(id: 'ch1', status: ChargeStatus.paid),
        ]);

        expect(settled, 1);
      });
    });
  });
}
