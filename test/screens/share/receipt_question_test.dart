import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/share/receipt_question.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/received_share.dart';

PaymentTransaction _payment(String id, double amount, {String? receipt}) =>
    PaymentTransaction.payment(amount: amount, paidAt: DateTime(2026, 10, 12))
      ..id = id
      ..receiptDocumentId = receipt;

Order _order({
  double total = 500,
  double paid = 0,
  List<PaymentTransaction> transactions = const [],
}) => Order()
  ..id = 'o1'
  ..number = 193
  ..total = total
  ..paidAmount = paid
  ..transactions = [...transactions];

final _onePdf = ReceivedBatch(const [
  ReceivedFile(path: '/c/pix.pdf', mimeType: 'application/pdf'),
]);
final _onePhoto = ReceivedBatch(const [
  ReceivedFile(path: '/c/pix.PNG'),
]);
final _two = ReceivedBatch(const [
  ReceivedFile(path: '/c/1.jpg', mimeType: 'image/jpeg'),
  ReceivedFile(path: '/c/2.pdf', mimeType: 'application/pdf'),
]);

Widget _app(Widget home) => CupertinoApp(
  locale: const Locale('pt', 'BR'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('pt', 'BR')],
  home: home,
);

void main() {
  setUp(() => FormatService().setLocale('pt-BR'));

  group('paymentsWithoutReceipt', () {
    test('keeps payments without receipt only', () {
      final asaas = PaymentTransaction.payment(amount: 10)
        ..id = 'asaas_1'
        ..receiptUrl = 'https://www.asaas.com/comprovantes/1';
      final group = PaymentTransaction.payment(amount: 10, receiptGroupId: 'r1')
        ..id = 't4';
      final discount = PaymentTransaction.discount(amount: 5)..id = 't5';
      final order = _order(
        transactions: [
          _payment('t1', 200),
          _payment('t2', 100, receipt: 'd1'),
          asaas,
          group,
          discount,
        ],
      );
      expect(paymentsWithoutReceipt(order).map((t) => t.id), ['t1']);
    });
  });

  group('shouldAskWhatFileIs', () {
    test('asks for one file when there is a payment without receipt', () {
      final order = _order(total: 200, paid: 200, transactions: [
        _payment('t1', 200),
      ]);
      expect(
        shouldAskWhatFileIs(batch: _onePdf, order: order, canReceive: true),
        isTrue,
      );
      expect(
        shouldAskWhatFileIs(batch: _onePhoto, order: order, canReceive: true),
        isTrue,
      );
    });

    test('asks when something is left to receive', () {
      expect(
        shouldAskWhatFileIs(
          batch: _onePdf,
          order: _order(total: 300),
          canReceive: true,
        ),
        isTrue,
      );
    });

    test('skips with several files, without access, or nothing to do', () {
      final order = _order(total: 300);
      expect(
        shouldAskWhatFileIs(batch: _two, order: order, canReceive: true),
        isFalse,
      );
      // Financial off / no access to receive on this order.
      expect(
        shouldAskWhatFileIs(batch: _onePdf, order: order, canReceive: false),
        isFalse,
      );
      // Paid, every payment with receipt.
      expect(
        shouldAskWhatFileIs(
          batch: _onePdf,
          order: _order(total: 100, paid: 100, transactions: [
            _payment('t1', 100, receipt: 'd1'),
          ]),
          canReceive: true,
        ),
        isFalse,
      );
      // No value and no payments.
      expect(
        shouldAskWhatFileIs(
          batch: _onePdf,
          order: _order(total: 0),
          canReceive: true,
        ),
        isFalse,
      );
    });
  });

  test('receiptFileOf keeps the file type', () {
    final pdf = receiptFileOf(_onePdf)!;
    expect(pdf.contentType, 'application/pdf');
    expect(pdf.name, 'pix.pdf');
    expect(receiptFileOf(_onePhoto)!.contentType, 'image/png');
    expect(
      receiptFileOf(ReceivedBatch(const [
        ReceivedFile(path: '/c/a.jpg', mimeType: 'image/heic'),
      ]))!.contentType,
      'image/heic',
    );
  });

  testWidgets('"O que é este arquivo?" lists payments, new payment and keep', (
    tester,
  ) async {
    final order = _order(total: 500, paid: 200, transactions: [
      _payment('t1', 200),
      _payment('t2', 50, receipt: 'd1'),
    ]);
    SharedFileUse? chosen;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => chosen = await askWhatFileIs(context, order),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('O que é este arquivo?'), findsOneWidget);
    expect(find.text('OS 193'), findsOneWidget);
    final row = find.byKey(const Key('sharedFileReceipt_t1'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining('Comprovante do pagamento de R\$'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('12/10'), findsOneWidget);
    expect(find.byKey(const Key('sharedFileReceipt_t2')), findsNothing);
    expect(find.text('Comprovante de um pagamento novo'), findsOneWidget);
    expect(find.text('Só guardar na OS'), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(chosen!.payment!.id, 't1');
    expect(chosen!.isKeep, isFalse);
  });

  testWidgets('no "pagamento novo" when nothing is left to receive; back '
      'keeps the file in the OS', (tester) async {
    final order = _order(total: 200, paid: 200, transactions: [
      _payment('t1', 200),
    ]);
    SharedFileUse? chosen;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => chosen = await askWhatFileIs(context, order),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Comprovante de um pagamento novo'), findsNothing);

    Navigator.of(tester.element(find.text('O que é este arquivo?'))).pop();
    await tester.pumpAndSettle();
    expect(chosen!.isKeep, isTrue);
  });

  testWidgets('"Comprovante de um pagamento novo" picks a new payment', (
    tester,
  ) async {
    SharedFileUse? chosen;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async =>
                chosen = await askWhatFileIs(context, _order(total: 300)),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprovante de um pagamento novo'));
    await tester.pumpAndSettle();
    expect(chosen!.isNewPayment, isTrue);
  });
}
