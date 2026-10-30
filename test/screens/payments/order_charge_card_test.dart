import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';

void main() {
  final l10n = AppLocalizationsPt();
  final format = FormatService();
  setUp(() => format.setLocale('pt-BR'));

  OrderCharge charge({
    String id = 'ch1',
    ChargeStatus status = ChargeStatus.pending,
    double value = 1000,
    ChargeMode mode = ChargeMode.single,
    int? installmentCount,
    List<String>? paidAsaasPaymentIds,
    DateTime? createdAt,
  }) => OrderCharge(
    id: id,
    status: status,
    value: value,
    mode: mode,
    installmentCount: installmentCount,
    dueDate: '2026-10-07',
    invoiceUrl: 'https://sandbox.asaas.com/i/abc',
    paidAsaasPaymentIds: paidAsaasPaymentIds,
    createdAt: createdAt,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(child: ListView(children: [child])),
      ),
    );
    await tester.pumpAndSettle();
  }

  String due() => format.formatDayMonthOrDate(DateTime(2026, 10, 7));

  group('chargeStatusColor', () {
    test('âmbar pendente, vermelho vencida, verde paga, cinza encerrada', () {
      expect(chargeStatusColor(ChargeStatus.pending), AppColors.warning);
      expect(chargeStatusColor(ChargeStatus.overdue), AppColors.danger);
      expect(chargeStatusColor(ChargeStatus.paid), AppColors.success);
      expect(chargeStatusColor(ChargeStatus.canceled), AppColors.textSecondary);
      expect(chargeStatusColor(ChargeStatus.refunded), AppColors.textSecondary);
      expect(chargeStatusColor(null), AppColors.textSecondary);
    });
  });

  group('chargeSettled', () {
    OrderCharge c(ChargeStatus? status, [int paid = 0]) => OrderCharge(
      id: 'ch1',
      status: status,
      paidAsaasPaymentIds: [for (var i = 0; i < paid; i++) 'pay_$i'],
    );

    test('true quando passa para paga ou estornada', () {
      expect(
        chargeSettled(c(ChargeStatus.pending), c(ChargeStatus.paid)),
        isTrue,
      );
      expect(
        chargeSettled(c(ChargeStatus.overdue), c(ChargeStatus.paid)),
        isTrue,
      );
      expect(
        chargeSettled(c(ChargeStatus.paid), c(ChargeStatus.refunded)),
        isTrue,
      );
      // Charge not seen before (after the first emission) already paid
      expect(chargeSettled(null, c(ChargeStatus.paid)), isTrue);
    });

    test('true quando o número de parcelas pagas muda', () {
      expect(
        chargeSettled(c(ChargeStatus.pending, 1), c(ChargeStatus.pending, 2)),
        isTrue,
      );
      expect(
        chargeSettled(c(ChargeStatus.pending), c(ChargeStatus.pending, 1)),
        isTrue,
      );
      expect(chargeSettled(null, c(ChargeStatus.pending, 1)), isTrue);
      // Refund of an installment shrinks the list
      expect(
        chargeSettled(c(ChargeStatus.pending, 2), c(ChargeStatus.pending, 1)),
        isTrue,
      );
    });

    test('false sem mudança ou para status sem pagamento', () {
      expect(
        chargeSettled(c(ChargeStatus.paid), c(ChargeStatus.paid)),
        isFalse,
      );
      expect(
        chargeSettled(c(ChargeStatus.refunded), c(ChargeStatus.refunded)),
        isFalse,
      );
      expect(
        chargeSettled(c(ChargeStatus.pending), c(ChargeStatus.overdue)),
        isFalse,
      );
      expect(
        chargeSettled(c(ChargeStatus.pending), c(ChargeStatus.canceled)),
        isFalse,
      );
      expect(chargeSettled(null, c(ChargeStatus.pending)), isFalse);
      expect(chargeSettled(c(ChargeStatus.paid), c(null)), isFalse);
      expect(
        chargeSettled(c(ChargeStatus.pending, 2), c(ChargeStatus.overdue, 2)),
        isFalse,
      );
    });
  });

  group('ChargeLinkBlock', () {
    testWidgets('pendente: quando mandou, o que falta e até quando vale', (
      tester,
    ) async {
      var reminded = 0;
      await pump(
        tester,
        ChargeLinkBlock(
          charge: charge(createdAt: DateTime(2026, 10, 1)),
          customerName: 'Ana Ribeiro',
          onRemind: () => reminded++,
        ),
      );
      final value = format.formatCurrency(1000);
      expect(
        find.text(
          l10n.chargeLinkSentOn(
            format.formatDayMonthOrDate(DateTime(2026, 10, 1)),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '${l10n.chargeNotPaidYet('Ana Ribeiro', value)} '
          '${l10n.chargeLinkValidUntil(due())}',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.chargeRemindWhatsApp));
      expect(reminded, 1);
      expect(
        tester.getSize(find.byKey(const Key('chargeRemindWhatsApp'))).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('sem data de criação: "Link mandado"', (tester) async {
      await pump(
        tester,
        ChargeLinkBlock(charge: charge(), customerName: null, onRemind: () {}),
      );
      expect(find.text(l10n.chargeLinkSent), findsOneWidget);
      expect(
        find.textContaining(
          l10n.chargeNotPaidYetNoCustomer(format.formatCurrency(1000)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('link menor que o saldo: diz quanto falta fora dele', (
      tester,
    ) async {
      await pump(
        tester,
        ChargeLinkBlock(
          charge: charge(),
          customerName: 'Ana Ribeiro',
          onRemind: () {},
          remaining: 1300,
        ),
      );
      expect(
        find.text(l10n.chargeMissingOutsideLink(format.formatCurrency(300))),
        findsOneWidget,
      );
    });

    testWidgets('link igual ao saldo: não fala de fora do link', (
      tester,
    ) async {
      await pump(
        tester,
        ChargeLinkBlock(
          charge: charge(),
          customerName: 'Ana Ribeiro',
          onRemind: () {},
          remaining: 1000,
        ),
      );
      expect(find.byKey(const Key('chargeMissingOutsideLink')), findsNothing);
    });

    testWidgets('vencida: diz quando venceu, sem "vale até"', (tester) async {
      await pump(
        tester,
        ChargeLinkBlock(
          charge: charge(status: ChargeStatus.overdue),
          customerName: 'Ana Ribeiro',
          onRemind: () {},
        ),
      );
      expect(find.text(l10n.chargeLinkExpiredOn(due())), findsOneWidget);
      expect(
        find.text(
          l10n.chargeNotPaidYet('Ana Ribeiro', format.formatCurrency(1000)),
        ),
        findsOneWidget,
      );
    });
  });

  group('ChargeChangedBlock', () {
    testWidgets('mostra a diferença e um botão para o link novo', (
      tester,
    ) async {
      var generated = 0;
      await pump(
        tester,
        ChargeChangedBlock(
          remaining: 800,
          chargeValue: 1000,
          onGenerate: () => generated++,
        ),
      );
      expect(find.text(l10n.chargeOrderChanged), findsOneWidget);
      expect(
        find.text(
          l10n.chargeNowMissing(
            format.formatCurrency(800),
            format.formatCurrency(1000),
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.text(l10n.chargeGenerateNew(format.formatCurrency(800))),
      );
      expect(generated, 1);
    });

    testWidgets('desconectado: sem o botão', (tester) async {
      await pump(
        tester,
        const ChargeChangedBlock(
          remaining: 800,
          chargeValue: 1000,
          onGenerate: null,
        ),
      );
      expect(find.byKey(const Key('chargeRegenerateButton')), findsNothing);
    });
  });

  group('ChargeLinkRow', () {
    Color dotColor(WidgetTester tester) => tester
        .widget<StatusDot>(find.byKey(const Key('chargeStatusDot')))
        .color;

    testWidgets('pendente: esperando o cliente, formas e prazo', (
      tester,
    ) async {
      await pump(
        tester,
        ChargeLinkRow(charge: charge(), customerName: 'Ana Ribeiro'),
      );
      expect(find.text(l10n.chargePaymentLink), findsOneWidget);
      expect(find.text(format.formatCurrency(1000)), findsOneWidget);
      expect(find.text(l10n.chargeWaitingFor('Ana Ribeiro')), findsOneWidget);
      expect(find.text(l10n.chargeMethodsUntil(due())), findsOneWidget);
      expect(dotColor(tester), AppColors.warning);
      // Informational: no chevron.
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
    });

    testWidgets('vencida: ponto e texto em vermelho', (tester) async {
      await pump(
        tester,
        ChargeLinkRow(
          charge: charge(status: ChargeStatus.overdue),
          customerName: 'Ana Ribeiro',
        ),
      );
      expect(find.text(l10n.chargeExpiredOn(due())), findsOneWidget);
      expect(dotColor(tester), AppColors.danger);
    });

    testWidgets('parcelado mostra Nx no cartão', (tester) async {
      await pump(
        tester,
        ChargeLinkRow(
          charge: charge(
            mode: ChargeMode.cardInstallments,
            installmentCount: 3,
          ),
          customerName: null,
        ),
      );
      expect(find.text(l10n.chargeWaitingPayment), findsOneWidget);
      expect(find.text(l10n.chargeInstallmentsUntil(3, due())), findsOneWidget);
    });

    testWidgets('com parcela paga mostra quantas foram pagas', (tester) async {
      await pump(
        tester,
        ChargeLinkRow(
          charge: charge(
            mode: ChargeMode.cardInstallments,
            installmentCount: 3,
            paidAsaasPaymentIds: ['pay_1'],
          ),
          customerName: 'Ana Ribeiro',
        ),
      );
      expect(find.text(l10n.chargeInstallmentsPaid(1, 3)), findsOneWidget);
    });

    testWidgets('com link novo sugerido avisa que ele cancela este', (
      tester,
    ) async {
      await pump(
        tester,
        ChargeLinkRow(
          charge: charge(),
          customerName: 'Ana Ribeiro',
          replacing: true,
        ),
      );
      expect(find.text(l10n.chargeUntilReplaced(due())), findsOneWidget);
    });
  });
}
