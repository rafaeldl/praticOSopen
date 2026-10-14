import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/payments/widgets/receive_block.dart';
import 'package:praticos/screens/payments/widgets/receive_discount_sheet.dart';
import 'package:praticos/screens/payments/widgets/receive_payment_row.dart';
import 'package:praticos/services/format_service.dart';

Widget app(Widget child) => CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CupertinoPageScaffold(child: SafeArea(child: child)),
    );

void main() {
  setUp(() => FormatService().setLocale('pt-BR'));

  group('ReceiveBlock', () {
    testWidgets('open: amount prefilled and button follows the amount',
        (tester) async {
      final controller = TextEditingController(
        text: FormatService().formatCurrency(950),
      );
      var confirmed = 0;
      await tester.pumpWidget(app(ReceiveBlock(
        isPaid: false,
        controller: controller,
        onConfirm: () => confirmed++,
        onAttachReceipt: () {},
      )));

      expect(find.text('Falta receber'), findsOneWidget);
      expect(find.textContaining('Recebi'), findsOneWidget);
      expect(find.textContaining('950,00'), findsWidgets);
      expect(find.text('Anexar comprovante'), findsOneWidget);
      // "Como pagou" does not exist.
      expect(find.textContaining('Como pagou'), findsNothing);

      controller.text = FormatService().formatCurrency(400);
      await tester.pump();
      expect(find.textContaining('400,00'), findsWidgets);

      await tester.tap(find.byKey(const Key('receiveConfirm')));
      expect(confirmed, 1);
    });

    testWidgets('open without attach permission hides "Anexar comprovante"',
        (tester) async {
      await tester.pumpWidget(app(ReceiveBlock(
        isPaid: false,
        controller: TextEditingController(text: 'R\$ 10,00'),
        onConfirm: () {},
      )));
      expect(find.text('Anexar comprovante'), findsNothing);
    });

    testWidgets('picked receipt shows chip with x', (tester) async {
      var removed = false;
      await tester.pumpWidget(app(ReceiveBlock(
        isPaid: false,
        controller: TextEditingController(text: 'R\$ 10,00'),
        onConfirm: () {},
        onAttachReceipt: () {},
        receiptName: 'pix.jpg',
        onRemoveReceipt: () => removed = true,
      )));
      expect(find.text('pix.jpg'), findsOneWidget);
      expect(find.text('Anexar comprovante'), findsNothing);
      await tester.tap(find.byKey(const Key('receiveRemoveReceipt')));
      expect(removed, isTrue);
    });

    testWidgets('empty amount disables the button', (tester) async {
      await tester.pumpWidget(app(ReceiveBlock(
        isPaid: false,
        controller: TextEditingController(),
        onConfirm: () {},
      )));
      final button = tester.widget<CupertinoButton>(
        find.byKey(const Key('receiveConfirm')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('paid: "Tudo recebido" and no button', (tester) async {
      await tester.pumpWidget(app(ReceiveBlock(
        isPaid: true,
        controller: TextEditingController(),
        onConfirm: () {},
      )));
      expect(find.text('Tudo recebido'), findsOneWidget);
      expect(find.byKey(const Key('receiveConfirm')), findsNothing);
    });

    testWidgets('blocked shows the message', (tester) async {
      await tester.pumpWidget(app(ReceiveBlock(
        isPaid: false,
        blockedMessage: 'Cancelada',
        controller: TextEditingController(),
        onConfirm: () {},
      )));
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.byKey(const Key('receiveConfirm')), findsNothing);
    });
  });

  group('ReceivePaymentRow', () {
    PaymentTransaction manual({String? receipt}) => PaymentTransaction(
          id: '1728000000000',
          type: PaymentTransactionType.payment,
          amount: 300,
          receiptDocumentId: receipt,
        );

    Future<void> pump(WidgetTester tester, PaymentTransaction tx) =>
        tester.pumpWidget(app(
          ReceivePaymentRow(transaction: tx, onTap: () {}),
        ));

    testWidgets('manual payment: no payment method, "sem comprovante"',
        (tester) async {
      await pump(tester, manual());
      expect(find.text('Pagamento'), findsOneWidget);
      expect(find.textContaining('pelo link'), findsNothing);
      expect(find.textContaining('sem comprovante'), findsOneWidget);
    });

    testWidgets('manual payment with receipt says "com comprovante"',
        (tester) async {
      await pump(tester, manual(receipt: 'doc1'));
      expect(find.textContaining('com comprovante'), findsOneWidget);
    });

    testWidgets('Asaas payment shows billing type', (tester) async {
      await pump(
        tester,
        PaymentTransaction(
          id: 'asaas_pay_1',
          type: PaymentTransactionType.payment,
          amount: 950,
          description: 'Asaas • Pix',
          receiptDocumentId: 'doc1',
        ),
      );
      expect(find.text('Pix pelo link'), findsOneWidget);
      expect(find.textContaining('com comprovante'), findsOneWidget);
    });

    testWidgets('Asaas boleto and card labels', (tester) async {
      await pump(
        tester,
        PaymentTransaction(
          id: 'asaas_pay_2',
          type: PaymentTransactionType.payment,
          amount: 100,
          description: 'Asaas • Boleto',
        ),
      );
      expect(find.text('Boleto pelo link'), findsOneWidget);
      await pump(
        tester,
        PaymentTransaction(
          id: 'asaas_pay_3',
          type: PaymentTransactionType.payment,
          amount: 100,
          description: 'Asaas • Cartão 1/2',
        ),
      );
      expect(find.text('Cartão pelo link'), findsOneWidget);
    });

    testWidgets('receipt state hidden without view permission', (tester) async {
      await tester.pumpWidget(app(ReceivePaymentRow(
        transaction: manual(),
        showReceiptState: false,
        onTap: () {},
      )));
      expect(find.textContaining('comprovante'), findsNothing);
    });

    testWidgets('discount row is negative and has no receipt state',
        (tester) async {
      await tester.pumpWidget(app(ReceivePaymentRow(
        transaction: PaymentTransaction(
          type: PaymentTransactionType.discount,
          amount: 50,
        ),
        onTap: () {},
      )));
      expect(find.text('Desconto'), findsOneWidget);
      expect(find.textContaining('- '), findsOneWidget);
      expect(find.textContaining('comprovante'), findsNothing);
    });
  });

  group('ReceiveDiscountSheet', () {
    testWidgets('tells the new total and returns the amount', (tester) async {
      double? result;
      await tester.pumpWidget(app(Builder(
        builder: (context) => CupertinoButton(
          onPressed: () async => result = await showReceiveDiscountSheet(
            context,
            currentTotal: 1250,
            maxDiscount: 950,
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Sheet with "X" and "✓", the amount in a card; the new total only
      // once there is an amount.
      expect(find.byType(FormSheet), findsOneWidget);
      expect(find.byKey(const Key('receiveDiscountHint')), findsNothing);
      await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('receiveDiscountField')),
            matching: find.byType(CupertinoTextField),
          ),
          '5000');
      await tester.pump();
      expect(find.textContaining('1.200,00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(result, 50);
    });

    testWidgets('too big keeps ✓ off; closing returns null',
        (tester) async {
      double? result = -1;
      await tester.pumpWidget(app(Builder(
        builder: (context) => CupertinoButton(
          onPressed: () async => result = await showReceiveDiscountSheet(
            context,
            currentTotal: 100,
            maxDiscount: 100,
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('receiveDiscountField')),
            matching: find.byType(CupertinoTextField),
          ),
          '20000');
      await tester.pump();
      expect(find.text('Desconto não pode ser maior que o saldo'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('new_order_save')));
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsOneWidget);

      // Something typed: closing asks before discarding.
      await tester.tap(find.byKey(const ValueKey('new_order_close')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });
}
